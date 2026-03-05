//
//  iCloudSyncService.swift
//  Meditation Sleep Mindset
//

import Foundation
import SwiftData

/// Syncs favorites, playlists, and playlist items to iCloud Key-Value Store
/// so they persist across app reinstalls. Uses NSUbiquitousKeyValueStore (1MB limit).
@MainActor
final class iCloudSyncService {
    static let shared = iCloudSyncService()

    private let store = NSUbiquitousKeyValueStore.default

    private enum Keys {
        static let favorites = "sync_favorites"
        static let playlists = "sync_playlists"
        static let playlistItems = "sync_playlistItems"
        static let sessions = "sync_sessions"
        static let lastSyncDate = "sync_lastDate"
    }

    private var cloudObserver: Any?

    private init() {
        // Listen for external iCloud changes
        cloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] _ in
            self?.handleExternalChange()
        }
        store.synchronize()
    }

    deinit {
        if let observer = cloudObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Sync to iCloud

    /// Call after any favorites change to persist to iCloud
    func syncFavorites(from context: ModelContext) {
        let descriptor = FetchDescriptor<FavoriteContent>()
        guard let favorites = try? context.fetch(descriptor) else { return }

        let encoded = favorites.map { fav -> [String: Any] in
            [
                "id": fav.id.uuidString,
                "contentID": fav.contentID.uuidString,
                "youtubeVideoID": fav.youtubeVideoID,
                "contentTitle": fav.contentTitle,
                "contentTypeRaw": fav.contentTypeRaw,
                "durationSeconds": fav.durationSeconds,
                "addedAt": fav.addedAt.timeIntervalSince1970
            ]
        }

        store.set(encoded as Any, forKey: Keys.favorites)
        store.set(Date().timeIntervalSince1970, forKey: Keys.lastSyncDate)
        store.synchronize()
    }

    /// Call after any playlist change to persist to iCloud
    func syncPlaylists(from context: ModelContext) {
        let playlistDescriptor = FetchDescriptor<Playlist>()
        guard let playlists = try? context.fetch(playlistDescriptor) else { return }

        let encodedPlaylists = playlists.map { playlist -> [String: Any] in
            var dict: [String: Any] = [
                "id": playlist.id.uuidString,
                "name": playlist.name,
                "createdAt": playlist.createdAt.timeIntervalSince1970,
                "updatedAt": playlist.updatedAt.timeIntervalSince1970
            ]
            if let videoID = playlist.coverYoutubeVideoID {
                dict["coverYoutubeVideoID"] = videoID
            }
            return dict
        }

        let itemDescriptor = FetchDescriptor<PlaylistItem>()
        guard let items = try? context.fetch(itemDescriptor) else { return }

        let encodedItems = items.map { item -> [String: Any] in
            [
                "id": item.id.uuidString,
                "playlistID": item.playlistID.uuidString,
                "contentID": item.contentID.uuidString,
                "youtubeVideoID": item.youtubeVideoID,
                "contentTitle": item.contentTitle,
                "contentTypeRaw": item.contentTypeRaw,
                "durationSeconds": item.durationSeconds,
                "orderIndex": item.orderIndex,
                "addedAt": item.addedAt.timeIntervalSince1970
            ]
        }

        store.set(encodedPlaylists as Any, forKey: Keys.playlists)
        store.set(encodedItems as Any, forKey: Keys.playlistItems)
        store.set(Date().timeIntervalSince1970, forKey: Keys.lastSyncDate)
        store.synchronize()
    }

    /// Call to persist recent meditation sessions to iCloud
    func syncSessions(from context: ModelContext) {
        var descriptor = FetchDescriptor<MeditationSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 50
        guard let sessions = try? context.fetch(descriptor) else { return }

        let encoded = sessions.map { session -> [String: Any] in
            var dict: [String: Any] = [
                "id": session.id.uuidString,
                "startedAt": session.startedAt.timeIntervalSince1970,
                "durationSeconds": session.durationSeconds,
                "wasCompleted": session.wasCompleted,
                "sessionType": session.sessionType
            ]
            if let contentID = session.contentID { dict["contentID"] = contentID.uuidString }
            if let youtubeVideoID = session.youtubeVideoID { dict["youtubeVideoID"] = youtubeVideoID }
            if let contentTitle = session.contentTitle { dict["contentTitle"] = contentTitle }
            if let completedAt = session.completedAt { dict["completedAt"] = completedAt.timeIntervalSince1970 }
            if let preMood = session.preMood { dict["preMood"] = preMood }
            if let postMood = session.postMood { dict["postMood"] = postMood }
            return dict
        }

        store.set(encoded as Any, forKey: Keys.sessions)
        store.synchronize()
    }

    // MARK: - Restore from iCloud

    /// Restores favorites from iCloud if local store is empty (e.g. after reinstall)
    func restoreFavoritesIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<FavoriteContent>()
        let localCount = (try? context.fetchCount(descriptor)) ?? 0
        guard localCount == 0 else { return }

        guard let encoded = store.array(forKey: Keys.favorites) as? [[String: Any]] else { return }
        guard !encoded.isEmpty else { return }

        for dict in encoded {
            guard let idStr = dict["id"] as? String,
                  let id = UUID(uuidString: idStr),
                  let contentIDStr = dict["contentID"] as? String,
                  let contentID = UUID(uuidString: contentIDStr),
                  let youtubeVideoID = dict["youtubeVideoID"] as? String,
                  let contentTitle = dict["contentTitle"] as? String,
                  let contentTypeRaw = dict["contentTypeRaw"] as? String,
                  let durationSeconds = dict["durationSeconds"] as? Int
            else { continue }

            let contentType = ContentType(rawValue: contentTypeRaw) ?? .meditation
            let fav = FavoriteContent(
                contentID: contentID,
                youtubeVideoID: youtubeVideoID,
                title: contentTitle,
                contentType: contentType,
                durationSeconds: durationSeconds
            )
            // Preserve original ID and date
            fav.id = id
            if let addedAt = dict["addedAt"] as? Double {
                fav.addedAt = Date(timeIntervalSince1970: addedAt)
            }
            context.insert(fav)
        }

        try? context.save()
    }

    /// Restores playlists from iCloud if local store is empty (e.g. after reinstall)
    func restorePlaylistsIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<Playlist>()
        let localCount = (try? context.fetchCount(descriptor)) ?? 0
        guard localCount == 0 else { return }

        // Restore playlists
        guard let encodedPlaylists = store.array(forKey: Keys.playlists) as? [[String: Any]] else { return }
        guard !encodedPlaylists.isEmpty else { return }

        for dict in encodedPlaylists {
            guard let idStr = dict["id"] as? String,
                  let id = UUID(uuidString: idStr),
                  let name = dict["name"] as? String
            else { continue }

            let playlist = Playlist(name: name)
            playlist.id = id
            if let createdAt = dict["createdAt"] as? Double {
                playlist.createdAt = Date(timeIntervalSince1970: createdAt)
            }
            if let updatedAt = dict["updatedAt"] as? Double {
                playlist.updatedAt = Date(timeIntervalSince1970: updatedAt)
            }
            playlist.coverYoutubeVideoID = dict["coverYoutubeVideoID"] as? String
            context.insert(playlist)
        }

        // Restore playlist items
        if let encodedItems = store.array(forKey: Keys.playlistItems) as? [[String: Any]] {
            for dict in encodedItems {
                guard let idStr = dict["id"] as? String,
                      let id = UUID(uuidString: idStr),
                      let playlistIDStr = dict["playlistID"] as? String,
                      let playlistID = UUID(uuidString: playlistIDStr),
                      let contentIDStr = dict["contentID"] as? String,
                      let contentID = UUID(uuidString: contentIDStr),
                      let youtubeVideoID = dict["youtubeVideoID"] as? String,
                      let contentTitle = dict["contentTitle"] as? String,
                      let contentTypeRaw = dict["contentTypeRaw"] as? String,
                      let durationSeconds = dict["durationSeconds"] as? Int,
                      let orderIndex = dict["orderIndex"] as? Int
                else { continue }

                let contentType = ContentType(rawValue: contentTypeRaw) ?? .meditation
                let item = PlaylistItem(
                    playlistID: playlistID,
                    contentID: contentID,
                    youtubeVideoID: youtubeVideoID,
                    title: contentTitle,
                    contentType: contentType,
                    durationSeconds: durationSeconds,
                    orderIndex: orderIndex
                )
                item.id = id
                if let addedAt = dict["addedAt"] as? Double {
                    item.addedAt = Date(timeIntervalSince1970: addedAt)
                }
                context.insert(item)
            }
        }

        try? context.save()
    }

    /// Restores meditation sessions from iCloud if local store is empty
    func restoreSessionsIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<MeditationSession>()
        let localCount = (try? context.fetchCount(descriptor)) ?? 0
        guard localCount == 0 else { return }

        guard let encoded = store.array(forKey: Keys.sessions) as? [[String: Any]] else { return }
        guard !encoded.isEmpty else { return }

        for dict in encoded {
            guard let idStr = dict["id"] as? String,
                  let id = UUID(uuidString: idStr),
                  let startedAt = dict["startedAt"] as? Double,
                  let durationSeconds = dict["durationSeconds"] as? Int,
                  let wasCompleted = dict["wasCompleted"] as? Bool,
                  let sessionType = dict["sessionType"] as? String
            else { continue }

            let contentID = (dict["contentID"] as? String).flatMap { UUID(uuidString: $0) }
            let youtubeVideoID = dict["youtubeVideoID"] as? String
            let contentTitle = dict["contentTitle"] as? String
            let completedAt = (dict["completedAt"] as? Double).map { Date(timeIntervalSince1970: $0) }

            let session = MeditationSession(
                contentID: contentID,
                youtubeVideoID: youtubeVideoID,
                contentTitle: contentTitle,
                durationSeconds: durationSeconds,
                sessionType: sessionType,
                completedAt: completedAt
            )
            session.id = id
            session.startedAt = Date(timeIntervalSince1970: startedAt)
            session.wasCompleted = wasCompleted
            session.preMood = dict["preMood"] as? String
            session.postMood = dict["postMood"] as? String
            context.insert(session)
        }

        try? context.save()
    }

    // MARK: - External Change Handler

    private func handleExternalChange() {
        // External changes detected — will be picked up on next restore check
    }
}
