//
//  YouTubeDurationService.swift
//  Meditation Sleep Mindset
//
//  Fetches real video durations from the YouTube Data API v3 in batches of 50,
//  then updates Content records in SwiftData. Durations are cached locally so
//  each video is only looked up once.
//

import Foundation
import SwiftData

actor YouTubeDurationService {
    static let shared = YouTubeDurationService()

    // Same key used by YouTubeSearchService
    private let apiKey = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
    private let batchSize = 50

    private let cacheKey = "YouTubeDurationCache" // [videoID: durationSeconds]

    // MARK: - Public

    /// Fetches durations for all Content items that have durationSeconds == 0 (or haven't been fetched yet),
    /// updates the SwiftData records, and caches the results.
    @MainActor
    func fetchAndUpdateDurations(in context: ModelContext) async {
        let descriptor = FetchDescriptor<Content>()
        guard let allContent = try? context.fetch(descriptor), !allContent.isEmpty else { return }

        // Load cached durations
        var cache = loadCache()

        // Find videos needing duration lookup: not in cache, or content has duration 0
        var needsFetch: [String] = []
        for content in allContent {
            if let cached = cache[content.youtubeVideoID], cached > 0 {
                // Apply cached duration if content still has 0
                if content.durationSeconds == 0 {
                    content.durationSeconds = cached
                }
            } else {
                needsFetch.append(content.youtubeVideoID)
            }
        }

        // Deduplicate
        let uniqueIDs = Array(Set(needsFetch))

        guard !uniqueIDs.isEmpty else {
            #if DEBUG
            print("[YouTubeDuration] All \(allContent.count) videos have cached durations")
            #endif
            try? context.save()
            return
        }

        #if DEBUG
        print("[YouTubeDuration] Fetching durations for \(uniqueIDs.count) videos in \(Int(ceil(Double(uniqueIDs.count) / Double(batchSize)))) batches")
        #endif

        // Batch fetch
        var fetched: [String: Int] = [:]
        for batchStart in stride(from: 0, to: uniqueIDs.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, uniqueIDs.count)
            let batch = Array(uniqueIDs[batchStart..<batchEnd])

            do {
                let durations = try await fetchDurationBatch(videoIDs: batch)
                for (id, seconds) in durations {
                    fetched[id] = seconds
                    cache[id] = seconds
                }
            } catch {
                #if DEBUG
                print("[YouTubeDuration] Batch failed (\(batchStart/batchSize + 1)): \(error.localizedDescription)")
                #endif
                // Continue with remaining batches
            }

            // Small delay between batches to be polite to the API
            if batchEnd < uniqueIDs.count {
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
            }
        }

        // Apply fetched durations to Content records
        let videoIDToContent = Dictionary(grouping: allContent, by: { $0.youtubeVideoID })
        for (videoID, seconds) in fetched where seconds > 0 {
            if let contents = videoIDToContent[videoID] {
                for content in contents {
                    content.durationSeconds = seconds
                }
            }
        }

        // Save
        do {
            try context.save()
            saveCache(cache)
            #if DEBUG
            print("[YouTubeDuration] Updated \(fetched.count) durations, cache now has \(cache.count) entries")
            #endif
        } catch {
            #if DEBUG
            print("[YouTubeDuration] Failed to save: \(error)")
            #endif
        }
    }

    // MARK: - YouTube Data API v3

    /// Fetches durations for up to 50 video IDs in a single API call.
    /// Returns [videoID: durationInSeconds].
    private func fetchDurationBatch(videoIDs: [String]) async throws -> [String: Int] {
        let ids = videoIDs.joined(separator: ",")
        guard var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos") else {
            throw DurationError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "part", value: "contentDetails"),
            URLQueryItem(name: "id", value: ids),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "fields", value: "items(id,contentDetails/duration)")
        ]

        guard let url = components.url else {
            throw DurationError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            #if DEBUG
            if let body = String(data: data, encoding: .utf8) {
                print("[YouTubeDuration] API error \(statusCode): \(body.prefix(200))")
            }
            #endif
            throw DurationError.apiError(statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            throw DurationError.parseError
        }

        var result: [String: Int] = [:]
        for item in items {
            guard let id = item["id"] as? String,
                  let details = item["contentDetails"] as? [String: Any],
                  let duration = details["duration"] as? String else { continue }

            result[id] = parseISO8601Duration(duration)
        }

        return result
    }

    /// Parses ISO 8601 duration (e.g., "PT1H30M45S") into seconds.
    nonisolated private func parseISO8601Duration(_ iso: String) -> Int {
        var total = 0
        var numberBuffer = ""

        for char in iso {
            if char.isNumber {
                numberBuffer.append(char)
            } else if let value = Int(numberBuffer) {
                switch char {
                case "H": total += value * 3600
                case "M": total += value * 60
                case "S": total += value
                default: break
                }
                numberBuffer = ""
            } else {
                numberBuffer = ""
            }
        }

        return total
    }

    // MARK: - Cache (nonisolated — UserDefaults is thread-safe)

    nonisolated private func loadCache() -> [String: Int] {
        UserDefaults.standard.dictionary(forKey: cacheKey) as? [String: Int] ?? [:]
    }

    nonisolated private func saveCache(_ cache: [String: Int]) {
        UserDefaults.standard.set(cache, forKey: cacheKey)
    }

    enum DurationError: Error {
        case invalidURL
        case apiError(Int)
        case parseError
    }
}
