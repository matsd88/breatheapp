//
//  CacheManager.swift
//  Meditation Sleep Mindset
//
//  Coordinates preloading of thumbnails and videos for optimal user experience.
//  Call preloadContent() on app launch or when content is loaded.
//

import Foundation
import SwiftData

@MainActor
class CacheManager: ObservableObject {
    static let shared = CacheManager()

    @Published var isPreloadingThumbnails = false
    @Published var isPreloadingVideos = false
    @Published var thumbnailProgress: Double = 0
    @Published var videoProgress: Double = 0
    @Published var cachedVideoCount: Int = 0

    private init() {}

    // MARK: - Preload All Content

    /// Preload thumbnails and optionally videos for all content
    func preloadAllContent(_ contents: [Content], includeVideos: Bool = false) async {
        // Preload thumbnails first (fast, small files)
        await preloadThumbnails(for: contents)

        // Optionally preload videos (slower, larger files)
        if includeVideos {
            await preloadVideos(for: contents)
        }
    }

    // MARK: - Thumbnail Preloading

    /// Preload all thumbnails for content with full parallelism
    func preloadThumbnails(for contents: [Content]) async {
        guard !contents.isEmpty else { return }

        isPreloadingThumbnails = true
        thumbnailProgress = 0

        let urls = contents.compactMap { URL(string: $0.thumbnailURLComputed) }

        // Send all URLs at once — ImageCache uses a dedicated session
        // with 12 concurrent connections for maximum throughput
        await ImageCache.shared.preloadThumbnails(for: urls)

        isPreloadingThumbnails = false
        thumbnailProgress = 1.0
        #if DEBUG
        print("[CacheManager] Preloaded \(urls.count) thumbnails")
        #endif
    }

    // MARK: - Video Preloading

    /// Preload videos for content (audio-only by default for smaller file size)
    /// Downloads up to 3 videos concurrently for faster preloading.
    func preloadVideos(for contents: [Content], audioOnly: Bool = true, limit: Int? = nil) async {
        guard !contents.isEmpty else { return }

        isPreloadingVideos = true
        videoProgress = 0

        // Limit how many videos to preload (to save storage)
        let contentToPreload = limit.map { Array(contents.prefix($0)) } ?? contents
        let videoIDs = contentToPreload.map { $0.youtubeVideoID }

        let total = videoIDs.count
        let completed = Counter()

        // Download up to 3 videos concurrently
        await withTaskGroup(of: Void.self) { group in
            var queued = 0
            for videoID in videoIDs {
                // Limit concurrency to 3
                if queued >= 3 {
                    await group.next()
                }
                queued += 1

                group.addTask {
                    let isCached = await VideoCache.shared.isCached(videoID: videoID, audioOnly: audioOnly)
                    if !isCached {
                        do {
                            _ = try await VideoCache.shared.cacheVideo(videoID: videoID, audioOnly: audioOnly)
                        } catch {
                            #if DEBUG
                            print("[CacheManager] Failed to cache video \(videoID): \(error.localizedDescription)")
                            #endif
                        }
                    }
                    let count = await completed.increment()
                    await MainActor.run {
                        self.videoProgress = Double(count) / Double(total)
                        self.cachedVideoCount = count
                    }
                }
            }
        }

        isPreloadingVideos = false
        videoProgress = 1.0
        #if DEBUG
        print("[CacheManager] Preloaded \(await completed.value) videos")
        #endif
    }

    /// Preload featured/popular content first
    func preloadFeaturedContent(_ contents: [Content]) async {
        let featured = contents.filter { $0.isFeatured }
        if !featured.isEmpty {
            await preloadThumbnails(for: featured)
            // Preload only first 5 featured videos to save space
            await preloadVideos(for: featured, limit: 5)
        }
    }

    // MARK: - Cache Status

    /// Get cache statistics
    func getCacheStats() async -> CacheStats {
        let videoSize = await VideoCache.shared.getCacheSizeFormatted()
        return CacheStats(
            videoCacheSize: videoSize,
            isPreloadingThumbnails: isPreloadingThumbnails,
            isPreloadingVideos: isPreloadingVideos
        )
    }

    /// Clear all caches
    func clearAllCaches() async {
        await ImageCache.shared.clearCache()
        await VideoCache.shared.clearCache()
        await YouTubeService.shared.clearCache()
        cachedVideoCount = 0
        #if DEBUG
        print("[CacheManager] All caches cleared")
        #endif
    }
}

// MARK: - Cache Stats

struct CacheStats {
    let videoCacheSize: String
    let isPreloadingThumbnails: Bool
    let isPreloadingVideos: Bool
}

// MARK: - Thread-safe counter for parallel progress tracking

private actor Counter {
    private(set) var value: Int = 0

    @discardableResult
    func increment() -> Int {
        value += 1
        return value
    }
}
