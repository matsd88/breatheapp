//
//  VideoService.swift
//  Meditation Sleep Mindset
//
//  Self-hosted video service using Cloudflare R2 storage.
//  This provides direct URLs to media files without extraction.
//
//  URL Structure:
//    {baseURL}/videos/{videoID}/audio.m4a
//    {baseURL}/videos/{videoID}/video.mp4
//    {baseURL}/videos/{videoID}/thumb.jpg
//

import Foundation

actor VideoService {
    static let shared = VideoService()

    // MARK: - Configuration

    /// Toggle between self-hosted R2 and YouTube extraction
    /// Defaults to true since R2 bucket is set up and populated
    static var useR2: Bool {
        get {
            // Default to true (R2 enabled) if not explicitly set
            if UserDefaults.standard.object(forKey: "VideoService.useR2") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "VideoService.useR2")
        }
        set { UserDefaults.standard.set(newValue, forKey: "VideoService.useR2") }
    }

    /// Your Cloudflare R2 public URL
    private static let r2BaseURL = "https://pub-7b886d08f03c4e4ebcee90f70a22739e.r2.dev"

    // MARK: - URL Generation

    /// Get the stream URL for a video
    /// - Parameters:
    ///   - videoID: The YouTube video ID
    ///   - audioOnly: If true, returns audio stream URL; otherwise video
    /// - Returns: Direct URL to the media file on R2
    func getStreamURL(for videoID: String, audioOnly: Bool = true) async throws -> URL {
        // Validate video ID format
        guard !videoID.isEmpty, videoID.count == 11 else {
            throw VideoServiceError.invalidVideoID
        }

        let filename = audioOnly ? "audio.m4a" : "video.mp4"
        let urlString = "\(Self.r2BaseURL)/videos/\(videoID)/\(filename)"

        guard let url = URL(string: urlString) else {
            throw VideoServiceError.invalidURL
        }

        // HEAD request to verify file exists on R2 before handing to AVPlayer
        // Adds ~100ms but saves 10s of user wait on 404s
        var headRequest = URLRequest(url: url)
        headRequest.httpMethod = "HEAD"
        headRequest.timeoutInterval = 3

        do {
            let (_, response) = try await URLSession.shared.data(for: headRequest)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                throw VideoServiceError.videoNotFound
            }
        } catch let error as VideoServiceError {
            throw error
        } catch {
            // Network error on HEAD check — let AVPlayer try anyway
            #if DEBUG
            print("[VideoService] HEAD check failed, proceeding: \(error.localizedDescription)")
            #endif
        }

        #if DEBUG
        print("[VideoService] Validated URL: \(urlString)")
        #endif

        return url
    }

    /// Get the thumbnail URL for a video
    /// - Parameter videoID: The YouTube video ID
    /// - Returns: Direct URL to the thumbnail on R2
    func getThumbnailURL(for videoID: String) -> URL? {
        guard !videoID.isEmpty, videoID.count == 11 else { return nil }
        return URL(string: "\(Self.r2BaseURL)/videos/\(videoID)/thumb.jpg")
    }

    // MARK: - Validation

    /// Check if a video exists on R2 (HEAD request)
    /// Useful for verifying uploads completed successfully
    func videoExists(for videoID: String, audioOnly: Bool = true) async -> Bool {
        guard let url = try? await getStreamURL(for: videoID, audioOnly: audioOnly) else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }

    /// Batch check which videos exist on R2
    /// Returns set of video IDs that are available
    func checkAvailability(for videoIDs: [String]) async -> Set<String> {
        var available = Set<String>()

        await withTaskGroup(of: (String, Bool).self) { group in
            for videoID in videoIDs {
                group.addTask {
                    let exists = await self.videoExists(for: videoID)
                    return (videoID, exists)
                }
            }

            for await (videoID, exists) in group {
                if exists {
                    available.insert(videoID)
                }
            }
        }

        return available
    }
}

// MARK: - Unified Service Bridge

/// Provides a unified interface that switches between YouTubeService and VideoService
/// based on configuration. Use this in AudioPlayerManager instead of calling
/// services directly.
actor MediaStreamService {
    static let shared = MediaStreamService()

    /// Get stream URL using the configured backend (R2 or YouTube)
    func getStreamURL(for videoID: String, audioOnly: Bool = true) async throws -> URL {
        if VideoService.useR2 {
            return try await VideoService.shared.getStreamURL(for: videoID, audioOnly: audioOnly)
        } else {
            return try await YouTubeService.shared.getStreamURL(for: videoID, audioOnly: audioOnly)
        }
    }

    /// Get thumbnail URL using the configured backend
    func getThumbnailURL(for videoID: String) async -> URL? {
        if VideoService.useR2 {
            return await VideoService.shared.getThumbnailURL(for: videoID)
        } else {
            // Fall back to YouTube thumbnail
            return URL(string: "https://img.youtube.com/vi/\(videoID)/maxresdefault.jpg")
        }
    }

    /// Prefetch stream URLs (only applies to YouTube backend)
    func prefetchStreamURLs(for videoIDs: [String], audioOnly: Bool = true) async {
        // R2 URLs don't need prefetching - they're direct
        guard !VideoService.useR2 else { return }
        await YouTubeService.shared.prefetchStreamURLs(for: videoIDs, audioOnly: audioOnly)
    }

    /// Evict cache entry (only applies to YouTube backend)
    func evictCacheEntry(for videoID: String) async {
        guard !VideoService.useR2 else { return }
        await YouTubeService.shared.evictCacheEntry(for: videoID)
    }
}

// MARK: - Errors

enum VideoServiceError: Error, LocalizedError {
    case invalidVideoID
    case invalidURL
    case videoNotFound
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidVideoID:
            return "Invalid video ID"
        case .invalidURL:
            return "Could not construct video URL"
        case .videoNotFound:
            return "Video not found on server"
        case .networkError:
            return "Network error while accessing video"
        }
    }
}
