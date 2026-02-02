//
//  ContentHealthService.swift
//  Meditation Sleep Mindset
//
//  Monitors YouTube video health, fetches remote replacement mappings,
//  and self-heals dead videos without requiring an App Store update.
//

import Foundation
import SwiftData

@MainActor
class ContentHealthService: ObservableObject {
    static let shared = ContentHealthService()

    // MARK: - Types

    struct VideoReplacement: Codable {
        let videoID: String
        let durationSeconds: Int?
    }

    struct RemoteManifest: Codable {
        let version: Int
        let lastUpdated: String?
        let replacements: [String: VideoReplacement] // deadVideoID -> replacement
    }

    // MARK: - State

    /// In-memory failure counts per videoID
    private var failureCounts: [String: Int] = [:]

    /// Cached manifest replacements (deadVideoID -> replacement)
    private var replacements: [String: VideoReplacement] = [:]

    /// When we last fetched the manifest
    private var lastFetchDate: Date?

    /// Set of video IDs confirmed dead (failure count >= threshold)
    private var deadVideoIDs: Set<String> = []

    // MARK: - UserDefaults Keys

    private let manifestCacheKey = "contentHealth_manifestCache"
    private let manifestFetchDateKey = "contentHealth_lastFetchDate"
    private let deadVideosKey = "contentHealth_deadVideos"

    // MARK: - Init

    private init() {
        loadCachedManifest()
        loadDeadVideos()
    }

    // MARK: - Public API

    /// Report a video failure (call from YouTubeService/AudioPlayerManager)
    func reportFailure(videoID: String) {
        let count = (failureCounts[videoID] ?? 0) + 1
        failureCounts[videoID] = count
        #if DEBUG
        print("[ContentHealthService] Failure #\(count) for \(videoID)")
        #endif

        if count >= Constants.ContentHealth.failureThreshold {
            deadVideoIDs.insert(videoID)
            saveDeadVideos()
            #if DEBUG
            print("[ContentHealthService] Video \(videoID) marked as DEAD")
            #endif

            // Sync to iCloud for developer visibility
            syncDeadVideoReports()
        }
    }

    /// Check if we have a replacement for a dead/failing video
    func replacement(for videoID: String) -> VideoReplacement? {
        return replacements[videoID]
    }

    /// Fetch remote manifest and apply replacements to SwiftData content
    func fetchManifestAndApplyReplacements(in context: ModelContext) async {
        // Only re-fetch if cache expired
        if let lastFetch = lastFetchDate,
           Date().timeIntervalSince(lastFetch) < Constants.ContentHealth.cacheDuration {
            // Still apply cached replacements in case new content was seeded
            applyReplacements(in: context)
            return
        }

        await fetchManifest()
        applyReplacements(in: context)
    }

    /// Force re-fetch manifest (e.g., when a video just failed and we have no replacement)
    func forceRefreshManifest() async {
        // Rate limit: don't re-fetch more than once per hour
        if let lastFetch = lastFetchDate,
           Date().timeIntervalSince(lastFetch) < 3600 {
            return
        }
        await fetchManifest()
    }

    // MARK: - Manifest Fetching

    private func fetchManifest() async {
        guard let url = URL(string: Constants.ContentHealth.manifestURL) else {
            #if DEBUG
            print("[ContentHealthService] Invalid manifest URL")
            #endif
            return
        }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                #if DEBUG
                print("[ContentHealthService] Manifest fetch failed with non-200 status")
                #endif
                return
            }

            let manifest = try JSONDecoder().decode(RemoteManifest.self, from: data)
            replacements = manifest.replacements
            lastFetchDate = Date()

            // Cache to UserDefaults
            UserDefaults.standard.set(data, forKey: manifestCacheKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: manifestFetchDateKey)

            #if DEBUG
            print("[ContentHealthService] Manifest fetched: v\(manifest.version), \(manifest.replacements.count) replacements")
            #endif
        } catch {
            #if DEBUG
            print("[ContentHealthService] Manifest fetch error: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Apply Replacements

    private func applyReplacements(in context: ModelContext) {
        guard !replacements.isEmpty else { return }

        for (deadID, replacement) in replacements {
            let descriptor = FetchDescriptor<Content>(
                predicate: #Predicate<Content> { content in
                    content.youtubeVideoID == deadID
                }
            )

            do {
                let matches = try context.fetch(descriptor)
                for content in matches where !content.isUserAdded {
                    content.youtubeVideoID = replacement.videoID
                    if let duration = replacement.durationSeconds {
                        content.durationSeconds = duration
                    }
                    #if DEBUG
                    print("[ContentHealthService] Replaced \(deadID) → \(replacement.videoID) for '\(content.title)'")
                    #endif
                }
            } catch {
                #if DEBUG
                print("[ContentHealthService] Error applying replacement for \(deadID): \(error)")
                #endif
            }
        }

        try? context.save()
    }

    // MARK: - Dead Video Reporting (iCloud)

    private func syncDeadVideoReports() {
        guard !deadVideoIDs.isEmpty else { return }

        let store = NSUbiquitousKeyValueStore.default
        let reports = deadVideoIDs.map { id -> [String: Any] in
            return [
                "videoID": id,
                "failureCount": failureCounts[id] ?? 0,
                "reportedAt": ISO8601DateFormatter().string(from: Date())
            ]
        }

        // Store as array of dictionaries — fits well within 1MB KV limit
        store.set(reports, forKey: "health_dead_videos")
        store.synchronize()
        #if DEBUG
        print("[ContentHealthService] Synced \(reports.count) dead video reports to iCloud")
        #endif
    }

    // MARK: - Persistence

    private func loadCachedManifest() {
        if let data = UserDefaults.standard.data(forKey: manifestCacheKey) {
            do {
                let manifest = try JSONDecoder().decode(RemoteManifest.self, from: data)
                replacements = manifest.replacements
                #if DEBUG
                print("[ContentHealthService] Loaded cached manifest with \(replacements.count) replacements")
                #endif
            } catch {
                #if DEBUG
                print("[ContentHealthService] Failed to decode cached manifest")
                #endif
            }
        }

        let timestamp = UserDefaults.standard.double(forKey: manifestFetchDateKey)
        if timestamp > 0 {
            lastFetchDate = Date(timeIntervalSince1970: timestamp)
        }
    }

    private func loadDeadVideos() {
        if let saved = UserDefaults.standard.array(forKey: deadVideosKey) as? [String] {
            deadVideoIDs = Set(saved)
        }
    }

    private func saveDeadVideos() {
        UserDefaults.standard.set(Array(deadVideoIDs), forKey: deadVideosKey)
    }
}
