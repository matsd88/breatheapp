//
//  YouTubeSearchService.swift
//  Meditation Sleep Mindset
//

import Foundation

actor YouTubeSearchService {
    static let shared = YouTubeSearchService()

    // MARK: - Types

    struct SearchResult: Identifiable {
        let id: String // videoID
        let videoID: String
        let title: String
        let channelName: String
        let durationText: String
        let durationSeconds: Int
        let thumbnailURL: String
        let description: String?
    }

    struct SearchResponse {
        let results: [SearchResult]
        let continuation: String?
    }

    // MARK: - InnerTube Configuration

    private let baseURL = "https://www.youtube.com/youtubei/v1/search"
    private let apiKey = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"

    // MARK: - Search

    func search(query: String, continuation: String? = nil) async throws -> SearchResponse {
        var urlComponents = URLComponents(string: baseURL)!
        urlComponents.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "contentCheckOk", value: "true"),
            URLQueryItem(name: "racyCheckOk", value: "true")
        ]
        if continuation == nil {
            urlComponents.queryItems?.append(URLQueryItem(name: "query", value: query))
        }

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("en-US,en", forHTTPHeaderField: "accept-language")

        var body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB",
                    "clientVersion": "2.20240101.00.00"
                ]
            ]
        ]

        if let continuation {
            body["continuation"] = continuation
        } else {
            body["query"] = query
        }

        // Filter for videos only via search params
        if continuation == nil {
            body["params"] = "EgIQAQ%3D%3D" // Videos filter
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 10

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        return parseSearchResponse(json, isContinuation: continuation != nil)
    }

    // MARK: - Parsing

    private func parseSearchResponse(_ json: [String: Any], isContinuation: Bool) -> SearchResponse {
        var results: [SearchResult] = []
        var nextContinuation: String?

        // Navigate to the section list contents
        let sectionContents: [[String: Any]]

        if isContinuation {
            // Continuation responses have a different structure
            let actions = json["onResponseReceivedCommands"] as? [[String: Any]] ?? []
            let appendAction = actions.first?["appendContinuationItemsAction"] as? [String: Any]
            sectionContents = appendAction?["continuationItems"] as? [[String: Any]] ?? []
        } else {
            let contents = json["contents"] as? [String: Any]
            let twoColumn = contents?["twoColumnSearchResultsRenderer"] as? [String: Any]
            let primary = twoColumn?["primaryContents"] as? [String: Any]
            let sectionList = primary?["sectionListRenderer"] as? [String: Any]
            let sections = sectionList?["contents"] as? [[String: Any]] ?? []

            // First section typically contains the video results
            let itemSection = sections.first?["itemSectionRenderer"] as? [String: Any]
            sectionContents = itemSection?["contents"] as? [[String: Any]] ?? []

            // Check for continuation in sections
            for section in sections {
                if let cont = section["continuationItemRenderer"] as? [String: Any] {
                    let endpoint = cont["continuationEndpoint"] as? [String: Any]
                    let command = endpoint?["continuationCommand"] as? [String: Any]
                    nextContinuation = command?["token"] as? String
                }
            }
        }

        for item in sectionContents {
            if let videoRenderer = item["videoRenderer"] as? [String: Any] {
                if let result = parseVideoRenderer(videoRenderer) {
                    results.append(result)
                }
            }

            // Check for continuation token in items
            if let cont = item["continuationItemRenderer"] as? [String: Any] {
                let endpoint = cont["continuationEndpoint"] as? [String: Any]
                let command = endpoint?["continuationCommand"] as? [String: Any]
                nextContinuation = command?["token"] as? String
            }
        }

        return SearchResponse(results: results, continuation: nextContinuation)
    }

    private func parseVideoRenderer(_ renderer: [String: Any]) -> SearchResult? {
        guard let videoID = renderer["videoId"] as? String else { return nil }

        // Title
        let titleRuns = (renderer["title"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
        let title = titleRuns.compactMap { $0["text"] as? String }.joined()
        guard !title.isEmpty else { return nil }

        // Channel name
        let ownerRuns = (renderer["ownerText"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
        let channelName = ownerRuns.first?["text"] as? String ?? ""

        // Duration
        let lengthText = (renderer["lengthText"] as? [String: Any])?["simpleText"] as? String ?? ""
        let durationSeconds = parseDuration(lengthText)

        // Skip livestreams (no duration)
        guard durationSeconds > 0 else { return nil }

        // Thumbnail
        let thumbnails = (renderer["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]] ?? []
        let thumbnailURL = thumbnails.last?["url"] as? String ?? "https://img.youtube.com/vi/\(videoID)/mqdefault.jpg"

        // Description snippet
        let snippets = renderer["detailedMetadataSnippets"] as? [[String: Any]] ?? []
        let snippetRuns = (snippets.first?["snippetText"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
        let description = snippetRuns.compactMap { $0["text"] as? String }.joined()

        return SearchResult(
            id: videoID,
            videoID: videoID,
            title: title,
            channelName: channelName,
            durationText: lengthText,
            durationSeconds: durationSeconds,
            thumbnailURL: thumbnailURL,
            description: description.isEmpty ? nil : description
        )
    }

    private func parseDuration(_ text: String) -> Int {
        // Parse "1:23:45" or "10:32" or "5:03" into seconds
        let parts = text.split(separator: ":").compactMap { Int($0) }
        switch parts.count {
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
        case 2: return parts[0] * 60 + parts[1]
        case 1: return parts[0]
        default: return 0
        }
    }
}
