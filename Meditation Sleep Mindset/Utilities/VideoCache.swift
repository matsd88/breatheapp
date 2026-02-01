//
//  VideoCache.swift
//  Meditation Sleep Mindset
//
//  Caches video/audio files to disk for offline playback and faster loading.
//  Works with YouTubeService to download and store stream data.
//

import Foundation
import AVFoundation

actor VideoCache {
    static let shared = VideoCache()

    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxCacheSize: Int64 = 500 * 1024 * 1024 // 500MB max cache

    // Track download progress
    private var activeDownloads: [String: Task<URL?, Error>] = [:]
    private var downloadProgress: [String: Double] = [:]

    private init() {
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cacheDir.appendingPathComponent("VideoCache", isDirectory: true)

        // Create cache directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Cache Management

    /// Check if a video is cached
    func isCached(videoID: String, audioOnly: Bool = true) -> Bool {
        let fileURL = cacheFileURL(for: videoID, audioOnly: audioOnly)
        return fileManager.fileExists(atPath: fileURL.path)
    }

    /// Get cached file URL if available
    func getCachedURL(for videoID: String, audioOnly: Bool = true) -> URL? {
        let fileURL = cacheFileURL(for: videoID, audioOnly: audioOnly)
        if fileManager.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        return nil
    }

    /// Download and cache a video/audio file
    func cacheVideo(videoID: String, audioOnly: Bool = true) async throws -> URL? {
        // Return cached URL if already downloaded
        if let cachedURL = getCachedURL(for: videoID, audioOnly: audioOnly) {
            #if DEBUG
            print("[VideoCache] Already cached: \(videoID)")
            #endif
            return cachedURL
        }

        // Check if already downloading
        let downloadKey = "\(videoID)_\(audioOnly)"
        if let existingTask = activeDownloads[downloadKey] {
            #if DEBUG
            print("[VideoCache] Download already in progress: \(videoID)")
            #endif
            return try await existingTask.value
        }

        // Start new download
        let downloadTask = Task<URL?, Error> {
            do {
                // Get stream URL from YouTube service
                let streamURL = try await YouTubeService.shared.getStreamURL(for: videoID, audioOnly: audioOnly)

                // Download the file
                let localURL = try await downloadFile(from: streamURL, videoID: videoID, audioOnly: audioOnly)

                #if DEBUG
                print("[VideoCache] Successfully cached: \(videoID)")
                #endif
                return localURL
            } catch {
                #if DEBUG
                print("[VideoCache] Failed to cache \(videoID): \(error)")
                #endif
                throw error
            }
        }

        activeDownloads[downloadKey] = downloadTask

        defer {
            activeDownloads.removeValue(forKey: downloadKey)
            downloadProgress.removeValue(forKey: downloadKey)
        }

        return try await downloadTask.value
    }

    /// Download file from URL to local cache
    private func downloadFile(from url: URL, videoID: String, audioOnly: Bool) async throws -> URL {
        let destinationURL = cacheFileURL(for: videoID, audioOnly: audioOnly)
        let downloadKey = "\(videoID)_\(audioOnly)"

        // Use URLSession to download
        let (tempURL, response) = try await URLSession.shared.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw VideoDownloadError.downloadFailed
        }

        // Move temp file to cache directory
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: tempURL, to: destinationURL)

        downloadProgress[downloadKey] = 1.0

        // Clean up old cache if needed
        await cleanupCacheIfNeeded()

        return destinationURL
    }

    /// Get the local file URL for a video
    private func cacheFileURL(for videoID: String, audioOnly: Bool) -> URL {
        let filename = "\(videoID)_\(audioOnly ? "audio" : "video").mp4"
        return cacheDirectory.appendingPathComponent(filename)
    }

    // MARK: - Preloading

    /// Preload multiple videos in the background
    func preloadVideos(videoIDs: [String], audioOnly: Bool = true) async {
        await withTaskGroup(of: Void.self) { group in
            for videoID in videoIDs {
                group.addTask {
                    do {
                        _ = try await self.cacheVideo(videoID: videoID, audioOnly: audioOnly)
                    } catch {
                        // Silently fail for preloading
                        #if DEBUG
                        print("[VideoCache] Preload failed for \(videoID): \(error.localizedDescription)")
                        #endif
                    }
                }
            }
        }
    }

    /// Preload videos from Content array
    func preloadContent(_ contents: [Content], audioOnly: Bool = true) async {
        let videoIDs = contents.map { $0.youtubeVideoID }
        await preloadVideos(videoIDs: videoIDs, audioOnly: audioOnly)
    }

    // MARK: - Cache Cleanup

    /// Get total cache size in bytes
    func getCacheSize() -> Int64 {
        var totalSize: Int64 = 0

        if let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for file in files {
                if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
        }

        return totalSize
    }

    /// Get cache size formatted as string
    func getCacheSizeFormatted() -> String {
        let size = getCacheSize()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    /// Clean up cache if it exceeds max size (removes oldest files first)
    private func cleanupCacheIfNeeded() async {
        let currentSize = getCacheSize()

        guard currentSize > maxCacheSize else { return }

        #if DEBUG
        print("[VideoCache] Cache size \(currentSize) exceeds max \(maxCacheSize), cleaning up...")
        #endif

        // Get files sorted by modification date (oldest first)
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        ) else { return }

        let sortedFiles = files.compactMap { url -> (URL, Date, Int64)? in
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let date = values.contentModificationDate,
                  let size = values.fileSize else { return nil }
            return (url, date, Int64(size))
        }.sorted { $0.1 < $1.1 } // Sort by date, oldest first

        var freedSpace: Int64 = 0
        let targetFreeSpace = currentSize - (maxCacheSize / 2) // Free up to 50% of max

        for (fileURL, _, fileSize) in sortedFiles {
            guard freedSpace < targetFreeSpace else { break }

            try? fileManager.removeItem(at: fileURL)
            freedSpace += fileSize
            #if DEBUG
            print("[VideoCache] Removed old cache file: \(fileURL.lastPathComponent)")
            #endif
        }

        #if DEBUG
        print("[VideoCache] Freed \(freedSpace) bytes")
        #endif
    }

    /// Clear all cached videos
    func clearCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        #if DEBUG
        print("[VideoCache] Cache cleared")
        #endif
    }

    /// Remove specific cached video
    func removeFromCache(videoID: String, audioOnly: Bool = true) {
        let fileURL = cacheFileURL(for: videoID, audioOnly: audioOnly)
        try? fileManager.removeItem(at: fileURL)
    }

    // MARK: - Download Progress

    func getDownloadProgress(for videoID: String, audioOnly: Bool = true) -> Double {
        let key = "\(videoID)_\(audioOnly)"
        return downloadProgress[key] ?? 0
    }

    func isDownloading(videoID: String, audioOnly: Bool = true) -> Bool {
        let key = "\(videoID)_\(audioOnly)"
        return activeDownloads[key] != nil
    }
}

// MARK: - Errors

enum VideoDownloadError: Error, LocalizedError {
    case downloadFailed
    case invalidResponse
    case fileWriteError

    var errorDescription: String? {
        switch self {
        case .downloadFailed:
            return "Failed to download video file"
        case .invalidResponse:
            return "Invalid server response"
        case .fileWriteError:
            return "Failed to save video to cache"
        }
    }
}
