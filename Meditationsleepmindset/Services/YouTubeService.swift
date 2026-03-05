//
//  YouTubeService.swift
//  Meditation Sleep Mindset
//
//  Uses YouTubeKit library (github.com/alexeichhorn/YouTubeKit) to extract
//  audio/video stream URLs from YouTube videos.
//

import Foundation
import YouTubeKit

actor YouTubeService {
    static let shared = YouTubeService()

    // MARK: - Cache (in-memory + persistent disk)
    private var urlCache: [String: CachedStream] = [:]
    private static let diskCacheKey = "YouTubeStreamURLCache"

    private struct CachedStream: Codable {
        let urlString: String
        let cachedAt: Date

        var url: URL? { URL(string: urlString) }

        var isExpired: Bool {
            // YouTube URLs typically valid for ~6 hours, use 5h to be safe
            Date().timeIntervalSince(cachedAt) > 5 * 60 * 60
        }

        init(url: URL, cachedAt: Date) {
            self.urlString = url.absoluteString
            self.cachedAt = cachedAt
        }
    }

    /// Load persisted URL cache from disk on first access
    private var diskCacheLoaded = false
    private func loadDiskCacheIfNeeded() {
        guard !diskCacheLoaded else { return }
        diskCacheLoaded = true
        if let data = UserDefaults.standard.data(forKey: Self.diskCacheKey),
           let saved = try? JSONDecoder().decode([String: CachedStream].self, from: data) {
            // Only restore non-expired entries
            var loadedCount = 0
            for (key, entry) in saved where !entry.isExpired {
                if urlCache[key] == nil {
                    urlCache[key] = entry
                    loadedCount += 1
                }
            }
            // Persist back only valid entries (cleans up expired ones from disk)
            if loadedCount < saved.count {
                saveDiskCache()
            }
            #if DEBUG
            print("[YouTubeService] Loaded \(loadedCount) cached URLs from disk (purged \(saved.count - loadedCount) expired)")
            #endif
        }
    }

    private func saveDiskCache() {
        // Save non-expired entries to disk
        let valid = urlCache.filter { !$0.value.isExpired }
        if let data = try? JSONEncoder().encode(valid) {
            UserDefaults.standard.set(data, forKey: Self.diskCacheKey)
        }
    }

    // MARK: - Get Stream URL
    /// Extracts a stream URL for the given YouTube video ID.
    /// - Parameters:
    ///   - videoID: The YouTube video ID (e.g., "dQw4w9WgXcQ")
    ///   - audioOnly: If true, returns audio-only stream (smaller file size). Default is true.
    /// - Returns: A URL to the stream that can be played with AVPlayer
    func getStreamURL(for videoID: String, audioOnly: Bool = true) async throws -> URL {
        // Load persisted cache on first call
        loadDiskCacheIfNeeded()

        // Check cache first
        let cacheKey = "\(videoID)_\(audioOnly ? "audio" : "video")"
        if let cached = urlCache[cacheKey], !cached.isExpired, let url = cached.url {
            #if DEBUG
            print("[YouTubeService] Cache hit for \(videoID)")
            #endif
            return url
        }

        #if DEBUG
        print("[YouTubeService] Fetching stream for \(videoID), audioOnly: \(audioOnly)")
        #endif

        // Retry up to 3 attempts with exponential backoff
        // YouTube extraction can be flaky - give it more chances with longer waits
        var lastError: Error = YouTubeError.extractionFailed
        let maxAttempts = 3
        let backoffDelays: [UInt64] = [1_000_000_000, 2_000_000_000, 4_000_000_000] // 1s, 2s, 4s between retries
        for attempt in 1...maxAttempts {
            do {
                let url = try await Self.extractWithTimeout(videoID: videoID, audioOnly: audioOnly)
                urlCache[cacheKey] = CachedStream(url: url, cachedAt: Date())
                saveDiskCache()
                #if DEBUG
                print("[YouTubeService] Extraction successful (attempt \(attempt))")
                #endif
                return url
            } catch {
                lastError = error
                #if DEBUG
                print("[YouTubeService] Attempt \(attempt)/\(maxAttempts) failed: \(error)")
                #endif
                if attempt < maxAttempts, attempt - 1 < backoffDelays.count {
                    try? await Task.sleep(nanoseconds: backoffDelays[attempt - 1])
                }
            }
        }

        // Report failure to health service and check for replacement
        await ContentHealthService.shared.reportFailure(videoID: videoID)

        if let replacement = await ContentHealthService.shared.replacement(for: videoID) {
            #if DEBUG
            print("[YouTubeService] Trying replacement video \(replacement.videoID) for dead \(videoID)")
            #endif
            // Try the replacement — if it also fails, let the error propagate naturally
            return try await Self.extractWithTimeout(videoID: replacement.videoID, audioOnly: audioOnly)
        }

        // No replacement available — try force-refreshing the manifest in case one was just added
        await ContentHealthService.shared.forceRefreshManifest()
        if let replacement = await ContentHealthService.shared.replacement(for: videoID) {
            #if DEBUG
            print("[YouTubeService] Replacement found after manifest refresh: \(replacement.videoID)")
            #endif
            return try await Self.extractWithTimeout(videoID: replacement.videoID, audioOnly: audioOnly)
        }

        if lastError is YouTubeError {
            throw lastError
        }
        throw YouTubeError.extractionFailed
    }

    /// Single extraction attempt with timeout — runs OFF the actor to allow proper timeout
    private static func extractWithTimeout(videoID: String, audioOnly: Bool) async throws -> URL {
        try await withThrowingTaskGroup(of: URL.self) { group in
            // Extraction task — runs detached from the actor so it doesn't block
            group.addTask {
                try await Self.extractStream(videoID: videoID, audioOnly: audioOnly)
            }

            // Timeout task - 8 seconds to allow for slower extractions
            group.addTask {
                try await Task.sleep(nanoseconds: 12_000_000_000) // 12 second timeout
                throw YouTubeError.networkError
            }

            guard let result = try await group.next() else {
                throw YouTubeError.networkError
            }
            group.cancelAll()
            return result
        }
    }

    // MARK: - Stream Extraction (using YouTubeKit)
    /// Nonisolated static method so it runs outside the actor — allows timeout to actually fire
    private static func extractStream(videoID: String, audioOnly: Bool) async throws -> URL {
        // Create YouTube instance with video ID
        let video = YouTube(videoID: videoID)

        // Load streams
        let streams = try await video.streams

        guard !streams.isEmpty else {
            throw YouTubeError.noStreamsAvailable
        }

        #if DEBUG
        let audioCount = streams.filterAudioOnly().count
        let progressiveCount = streams.filter { $0.isProgressive }.count
        let nativeCount = streams.filter { $0.isNativelyPlayable }.count
        print("[YouTubeService] \(videoID): \(streams.count) streams (\(audioCount) audio, \(progressiveCount) progressive, \(nativeCount) native)")
        #endif

        if audioOnly {
            // Prefer natively playable audio streams for fastest start
            let allAudio = streams.filterAudioOnly()

            // Try natively playable audio first (no transcoding needed by AVPlayer)
            let nativeAudio = allAudio.filter { $0.isNativelyPlayable }.sorted {
                ($0.bitrate ?? Int.max) < ($1.bitrate ?? Int.max)
            }

            let audioStreams = nativeAudio.isEmpty ? allAudio.sorted {
                ($0.bitrate ?? Int.max) < ($1.bitrate ?? Int.max)
            } : nativeAudio

            guard !audioStreams.isEmpty else {
                throw YouTubeError.noAudioStream
            }

            // For meditation/sleep content, low bitrate = faster buffering.
            // ~64kbps is plenty for spoken word; use ~128kbps for music/soundscapes.
            // Pick the lowest bitrate that's at least 48kbps for acceptable quality.
            let minAcceptable = 48_000
            let targetBitrate = 96_000
            let acceptable = audioStreams.filter { ($0.bitrate ?? 0) >= minAcceptable }
            guard let bestStream = (acceptable.isEmpty ? audioStreams : acceptable).min(by: {
                abs(($0.bitrate ?? 0) - targetBitrate) < abs(($1.bitrate ?? 0) - targetBitrate)
            }) else {
                throw YouTubeError.noAudioStream
            }

            #if DEBUG
            print("[YouTubeService] Selected audio: bitrate=\(bestStream.bitrate ?? 0), native=\(bestStream.isNativelyPlayable)")
            #endif
            return bestStream.url
        } else {
            // Get progressive video streams (video + audio combined)
            // Prefer natively playable for fastest AVPlayer start
            let allProgressive = streams.filter { $0.isProgressive }
            let nativeProgressive = allProgressive.filter { $0.isNativelyPlayable }
            let progressiveStreams = (nativeProgressive.isEmpty ? allProgressive : nativeProgressive).sorted {
                ($0.bitrate ?? 0) < ($1.bitrate ?? 0)
            }

            // For mobile, 360p is plenty for meditation visuals and loads MUCH faster.
            // Target ~500kbps progressive stream — prioritize fast start over resolution.
            let targetBitrate = 500_000
            if let best = progressiveStreams.min(by: {
                abs(($0.bitrate ?? 0) - targetBitrate) < abs(($1.bitrate ?? 0) - targetBitrate)
            }) {
                #if DEBUG
                print("[YouTubeService] Selected video: bitrate=\(best.bitrate ?? 0), res=\(best.videoResolution ?? 0)p, native=\(best.isNativelyPlayable)")
                #endif
                return best.url
            }

            // Fallback: any progressive stream (prefer lowest bitrate for speed)
            if let smallest = progressiveStreams.first {
                return smallest.url
            }

            // If no progressive streams, try any stream with both audio and video
            if let combined = streams.first(where: { $0.includesVideoAndAudioTrack }) {
                return combined.url
            }

            // Last resort: video-only
            let videoOnlyStreams = streams.filterVideoOnly()
            if let firstVideoOnly = videoOnlyStreams.first {
                return firstVideoOnly.url
            }

            throw YouTubeError.noVideoStream
        }
    }

    // MARK: - Get Video Info
    /// Returns basic info about a YouTube video using the video ID
    func getVideoInfo(for videoID: String) -> YouTubeVideoInfo {
        // Return basic info - actual metadata is stored in our Content model
        return YouTubeVideoInfo(
            id: videoID,
            title: "Meditation",
            author: "Unknown",
            durationSeconds: 0,
            thumbnailURL: URL(string: "https://img.youtube.com/vi/\(videoID)/maxresdefault.jpg"),
            viewCount: nil
        )
    }

    // MARK: - Prefetching
    /// Prefetch stream URLs for multiple videos in the background
    /// Call this when content cards become visible to warm up the cache
    func prefetchStreamURLs(for videoIDs: [String], audioOnly: Bool = true) async {
        loadDiskCacheIfNeeded()
        await withTaskGroup(of: Void.self) { group in
            for videoID in videoIDs {
                let cacheKey = "\(videoID)_\(audioOnly ? "audio" : "video")"
                // Skip if already cached and not expired
                if let cached = urlCache[cacheKey], !cached.isExpired, cached.url != nil {
                    continue
                }

                group.addTask {
                    do {
                        _ = try await self.getStreamURL(for: videoID, audioOnly: audioOnly)
                    } catch {
                        // Silently fail for prefetch - it's just optimization
                        #if DEBUG
                        print("[YouTubeService] Prefetch failed for \(videoID)")
                        #endif
                    }
                }
            }
        }
    }

    // MARK: - Cache Management
    func evictCacheEntry(for videoID: String) {
        urlCache.removeValue(forKey: "\(videoID)_audio")
        urlCache.removeValue(forKey: "\(videoID)_video")
        saveDiskCache()
    }

    func clearCache() {
        urlCache.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.diskCacheKey)
        #if DEBUG
        print("[YouTubeService] Cache cleared (memory + disk)")
        #endif
    }

    func clearExpiredCache() {
        let before = urlCache.count
        urlCache = urlCache.filter { !$0.value.isExpired }
        let removed = before - urlCache.count
        if removed > 0 {
            #if DEBUG
            print("[YouTubeService] Removed \(removed) expired cache entries")
            #endif
        }
    }

    func getCacheStats() -> (total: Int, expired: Int) {
        let expired = urlCache.values.filter { $0.isExpired }.count
        return (urlCache.count, expired)
    }
}

// MARK: - Video Info Model
struct YouTubeVideoInfo {
    let id: String
    let title: String
    let author: String
    let durationSeconds: Int
    let thumbnailURL: URL?
    let viewCount: Int?

    var durationFormatted: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return String(format: "%d:%02d:%02d", hours, remainingMinutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

}

// MARK: - Errors
enum YouTubeError: Error, LocalizedError {
    case extractionFailed
    case invalidVideoID
    case networkError
    case noAudioStream
    case noVideoStream
    case noStreamsAvailable

    var errorDescription: String? {
        switch self {
        case .extractionFailed:
            return "Unable to load content. Please check your connection and try again."
        case .invalidVideoID:
            return "This content is temporarily unavailable."
        case .networkError:
            return "No internet connection. Please check your network and try again."
        case .noAudioStream:
            return "Audio is temporarily unavailable for this content."
        case .noVideoStream:
            return "Video is temporarily unavailable for this content."
        case .noStreamsAvailable:
            return "This content is currently unavailable. Please try again later."
        }
    }
}
