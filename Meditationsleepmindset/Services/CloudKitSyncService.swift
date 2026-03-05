//
//  CloudKitSyncService.swift
//  Meditation Sleep Mindset
//

import Foundation
import CloudKit
import SwiftData

@MainActor
class CloudKitSyncService: ObservableObject {
    static let shared = CloudKitSyncService()

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?

    private let container = CKContainer.default()
    private var privateDB: CKDatabase { container.privateCloudDatabase }

    // MARK: - Record Type Names
    private enum RecordType {
        static let favorite = "Favorite"
        static let playlist = "Playlist"
        static let playlistItem = "PlaylistItem"
        static let session = "MeditationSession"
        static let streakData = "StreakData"
        static let userPreferences = "UserPreferences"
        static let programProgress = "ProgramProgress"
    }

    private init() {}

    // MARK: - Migration & Full Sync

    /// Called on first sign-in: upload all local data to CloudKit
    func migrateAndSync() async {
        guard AccountService.shared.isSignedIn else { return }
        guard !AccountService.shared.hasMigratedToCloudKit else {
            // Already migrated — just do a regular sync
            await syncAll()
            return
        }

        isSyncing = true
        defer {
            isSyncing = false
            lastSyncDate = Date()
        }

        // Upload all local data
        await uploadAllLocalData()

        AccountService.shared.hasMigratedToCloudKit = true
    }

    /// Regular bidirectional sync
    func syncAll() async {
        guard AccountService.shared.isSignedIn else { return }
        guard !isSyncing else { return }

        isSyncing = true
        defer {
            isSyncing = false
            lastSyncDate = Date()
        }

        // Upload local changes, then fetch and merge cloud data
        await uploadAllLocalData()
        await fetchAndMergeAll()
    }

    // MARK: - Upload All Local Data

    private func uploadAllLocalData() async {
        await uploadFavorites()
        await uploadStreakData()
        await uploadUserPreferences()
    }

    // MARK: - Upload Favorites

    private func uploadFavorites() async {
        let cloudStore = NSUbiquitousKeyValueStore.default

        // Read favorites from iCloud KVS (same source as iCloudSyncService)
        guard let favData = cloudStore.array(forKey: "sync_favorites") as? [[String: Any]] else { return }

        var records: [CKRecord] = []
        for fav in favData {
            guard let contentID = fav["contentID"] as? String else { continue }
            let recordID = CKRecord.ID(recordName: "favorite-\(contentID)")
            let record = CKRecord(recordType: RecordType.favorite, recordID: recordID)
            record["contentID"] = contentID as CKRecordValue
            record["contentTitle"] = (fav["contentTitle"] as? String ?? "") as CKRecordValue
            record["contentType"] = (fav["contentType"] as? String ?? "") as CKRecordValue
            record["thumbnailURL"] = (fav["thumbnailURL"] as? String ?? "") as CKRecordValue
            record["youtubeVideoID"] = (fav["youtubeVideoID"] as? String ?? "") as CKRecordValue
            if let addedAt = fav["addedAt"] as? Date {
                record["addedAt"] = addedAt as CKRecordValue
            }
            records.append(record)
        }

        await batchSave(records: records)
    }

    // MARK: - Upload Streak Data

    private func uploadStreakData() async {
        let streakService = StreakService.shared
        let recordID = CKRecord.ID(recordName: "streakdata-singleton")
        let record = CKRecord(recordType: RecordType.streakData, recordID: recordID)
        record["currentStreak"] = streakService.currentStreak as CKRecordValue
        record["longestStreak"] = streakService.longestStreak as CKRecordValue
        record["totalMinutes"] = streakService.totalMinutes as CKRecordValue
        record["totalSessions"] = streakService.totalSessions as CKRecordValue
        if let lastDate = streakService.lastSessionDate {
            record["lastSessionDate"] = lastDate as CKRecordValue
        }
        record["updatedAt"] = Date() as CKRecordValue

        await batchSave(records: [record])
    }

    // MARK: - Upload User Preferences

    private func uploadUserPreferences() async {
        let defaults = UserDefaults.standard
        let recordID = CKRecord.ID(recordName: "preferences-singleton")
        let record = CKRecord(recordType: RecordType.userPreferences, recordID: recordID)

        record["selectedTheme"] = (defaults.string(forKey: "selectedTheme") ?? "default") as CKRecordValue
        record["notificationsEnabled"] = defaults.bool(forKey: "notificationsEnabled") as CKRecordValue
        record["autoPlayNextContent"] = defaults.bool(forKey: Constants.UserDefaultsKeys.autoPlayNextContent) as CKRecordValue
        record["preferredPlaybackSpeed"] = defaults.float(forKey: Constants.UserDefaultsKeys.preferredPlaybackSpeed) as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue

        await batchSave(records: [record])
    }

    // MARK: - Fetch & Merge

    private func fetchAndMergeAll() async {
        await fetchAndMergeStreakData()
    }

    private func fetchAndMergeStreakData() async {
        let recordID = CKRecord.ID(recordName: "streakdata-singleton")
        do {
            let record = try await privateDB.record(for: recordID)
            let streakService = StreakService.shared

            let cloudCurrent = record["currentStreak"] as? Int ?? 0
            let cloudLongest = record["longestStreak"] as? Int ?? 0
            let cloudTotalMin = record["totalMinutes"] as? Int ?? 0
            let cloudTotalSess = record["totalSessions"] as? Int ?? 0
            let cloudLastDate = record["lastSessionDate"] as? Date

            // Merge: take the max of each field
            var changed = false

            if cloudLongest > streakService.longestStreak {
                streakService.longestStreak = cloudLongest
                changed = true
            }
            if cloudTotalMin > streakService.totalMinutes {
                streakService.totalMinutes = cloudTotalMin
                changed = true
            }
            if cloudTotalSess > streakService.totalSessions {
                streakService.totalSessions = cloudTotalSess
                changed = true
            }

            // For current streak, prefer the data with more recent session date
            if let cloudDate = cloudLastDate {
                if let localDate = streakService.lastSessionDate {
                    if cloudDate > localDate {
                        streakService.lastSessionDate = cloudDate
                        streakService.currentStreak = cloudCurrent
                        changed = true
                    }
                } else {
                    streakService.lastSessionDate = cloudDate
                    streakService.currentStreak = cloudCurrent
                    changed = true
                }
            }

            // Note: StreakService properties are @Published, so UI updates automatically.
            // The merged data will be saved on next recordSession() call or app background.
        } catch {
            // Record doesn't exist yet — that's fine on first sync
            #if DEBUG
            print("[CloudKitSync] Streak data not found in cloud: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Delete All Cloud Data

    func deleteAllCloudData() async {
        // Query and delete all records of each type
        for type in [RecordType.favorite, RecordType.playlist, RecordType.playlistItem,
                     RecordType.session, RecordType.streakData, RecordType.userPreferences,
                     RecordType.programProgress] {
            await deleteAllRecords(ofType: type)
        }
    }

    private func deleteAllRecords(ofType recordType: String) async {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        do {
            let (results, _) = try await privateDB.records(matching: query)
            let recordIDs = results.compactMap { result -> CKRecord.ID? in
                guard case .success = result.1 else { return nil }
                return result.0
            }

            if !recordIDs.isEmpty {
                _ = try await privateDB.modifyRecords(saving: [], deleting: recordIDs)
            }
        } catch {
            #if DEBUG
            print("[CloudKitSync] Failed to delete \(recordType) records: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Batch Save Helper

    private func batchSave(records: [CKRecord]) async {
        guard !records.isEmpty else { return }

        // CloudKit allows max 400 records per operation
        let batchSize = 400
        for i in stride(from: 0, to: records.count, by: batchSize) {
            let batch = Array(records[i..<min(i + batchSize, records.count)])
            do {
                let (saved, _) = try await privateDB.modifyRecords(saving: batch, deleting: [], savePolicy: .changedKeys)
                #if DEBUG
                print("[CloudKitSync] Saved \(saved.count) records")
                #endif
            } catch {
                #if DEBUG
                print("[CloudKitSync] Batch save failed: \(error.localizedDescription)")
                #endif
            }
        }
    }
}
