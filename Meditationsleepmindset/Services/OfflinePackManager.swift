//
//  OfflinePackManager.swift
//  Meditation Sleep Mindset
//
//  Manages offline content packs for travelers - downloadable collections
//  that work without internet connection.
//

import Foundation
import SwiftUI
import SwiftData
import Combine

// MARK: - Offline Pack Definition

struct OfflinePack: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let accentColor: String // Hex color
    let category: PackCategory
    let contentTags: [String] // Tags to match content
    let contentTypes: [String] // ContentType raw values
    let targetCount: Int // How many items to include
    let estimatedSizeMB: Int
    let isPremium: Bool

    enum PackCategory: String, Codable, CaseIterable {
        case travel = "Travel"
        case sleep = "Sleep"
        case anxiety = "Anxiety"
        case focus = "Focus"
        case wellness = "Wellness"
    }

    var color: Color {
        Color(hex: accentColor)
    }

    // Built-in packs
    static let allPacks: [OfflinePack] = [
        // Travel Packs
        OfflinePack(
            id: "vacation_7day",
            name: "7-Day Vacation",
            description: "A week of relaxation for your getaway. Morning, afternoon, and evening sessions.",
            icon: "airplane",
            accentColor: "#4ECDC4",
            category: .travel,
            contentTags: ["relaxation", "calm", "peace", "vacation", "beach", "nature"],
            contentTypes: ["Meditation", "Soundscape", "Music"],
            targetCount: 21,
            estimatedSizeMB: 180,
            isPremium: false
        ),
        OfflinePack(
            id: "flight_anxiety",
            name: "Flight Anxiety Relief",
            description: "Calming content for nervous flyers. Use during takeoff, turbulence, or landing.",
            icon: "airplane.departure",
            accentColor: "#5C6BC0",
            category: .anxiety,
            contentTags: ["anxiety", "calm", "breathing", "grounding", "panic"],
            contentTypes: ["Meditation", "Soundscape"],
            targetCount: 10,
            estimatedSizeMB: 85,
            isPremium: false
        ),
        OfflinePack(
            id: "jet_lag_recovery",
            name: "Jet Lag Recovery",
            description: "Reset your body clock with sleep meditations and energizing morning sessions.",
            icon: "clock.arrow.2.circlepath",
            accentColor: "#FF7043",
            category: .travel,
            contentTags: ["sleep", "energy", "morning", "evening", "reset", "relax"],
            contentTypes: ["Sleep Story", "Meditation", "Music"],
            targetCount: 14,
            estimatedSizeMB: 120,
            isPremium: true
        ),
        OfflinePack(
            id: "road_trip",
            name: "Road Trip Companion",
            description: "Perfect for long drives. Calming music and soundscapes for the journey.",
            icon: "car.fill",
            accentColor: "#26A69A",
            category: .travel,
            contentTags: ["music", "ambient", "focus", "calm", "nature", "rain"],
            contentTypes: ["Music", "Soundscape"],
            targetCount: 15,
            estimatedSizeMB: 130,
            isPremium: false
        ),

        // Sleep Packs
        OfflinePack(
            id: "deep_sleep_collection",
            name: "Deep Sleep Collection",
            description: "Our best sleep stories and soundscapes for restful nights anywhere.",
            icon: "moon.zzz.fill",
            accentColor: "#7E57C2",
            category: .sleep,
            contentTags: ["sleep", "bedtime", "night", "dream", "rest"],
            contentTypes: ["Sleep Story", "Soundscape", "ASMR"],
            targetCount: 20,
            estimatedSizeMB: 200,
            isPremium: true
        ),
        OfflinePack(
            id: "hotel_sleep",
            name: "Hotel Sleep Aid",
            description: "Fall asleep in unfamiliar places. White noise, rain sounds, and calming stories.",
            icon: "bed.double.fill",
            accentColor: "#5C6BC0",
            category: .sleep,
            contentTags: ["white noise", "rain", "sleep", "ambient", "calm"],
            contentTypes: ["Soundscape", "Sleep Story"],
            targetCount: 12,
            estimatedSizeMB: 100,
            isPremium: false
        ),

        // Focus Packs
        OfflinePack(
            id: "work_focus",
            name: "Work Focus Pack",
            description: "Stay productive anywhere. Focus music and concentration meditations.",
            icon: "brain.head.profile",
            accentColor: "#42A5F5",
            category: .focus,
            contentTags: ["focus", "concentration", "productivity", "work", "study"],
            contentTypes: ["Music", "Meditation"],
            targetCount: 15,
            estimatedSizeMB: 125,
            isPremium: false
        ),

        // Anxiety Packs
        OfflinePack(
            id: "anxiety_toolkit",
            name: "Anxiety Toolkit",
            description: "Emergency calm for anxious moments. Breathing exercises and grounding meditations.",
            icon: "heart.circle.fill",
            accentColor: "#EC407A",
            category: .anxiety,
            contentTags: ["anxiety", "panic", "calm", "breathing", "grounding", "stress"],
            contentTypes: ["Meditation"],
            targetCount: 12,
            estimatedSizeMB: 90,
            isPremium: false
        ),

        // Wellness Packs
        OfflinePack(
            id: "morning_routine",
            name: "Morning Starter Pack",
            description: "Energizing morning meditations to start your day right, anywhere in the world.",
            icon: "sun.rise.fill",
            accentColor: "#FFA726",
            category: .wellness,
            contentTags: ["morning", "energy", "motivation", "gratitude", "intention"],
            contentTypes: ["Meditation", "Mindset"],
            targetCount: 10,
            estimatedSizeMB: 80,
            isPremium: false
        ),
        OfflinePack(
            id: "weekend_retreat",
            name: "Weekend Retreat",
            description: "A complete 2-day wellness experience. Like a spa weekend in your pocket.",
            icon: "leaf.fill",
            accentColor: "#66BB6A",
            category: .wellness,
            contentTags: ["relaxation", "yoga", "meditation", "spa", "peace", "nature"],
            contentTypes: ["Meditation", "Movement", "Soundscape", "Music"],
            targetCount: 18,
            estimatedSizeMB: 160,
            isPremium: true
        )
    ]
}

// MARK: - Download State

enum PackDownloadState: Codable, Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded(date: Date, sizeMB: Int)
    case failed(error: String)

    var isDownloaded: Bool {
        if case .downloaded = self { return true }
        return false
    }

    var isDownloading: Bool {
        if case .downloading = self { return true }
        return false
    }
}

// MARK: - Downloaded Pack Info

struct DownloadedPackInfo: Codable {
    let packID: String
    let downloadedAt: Date
    let contentIDs: [String] // YouTube video IDs
    let totalSizeMB: Int
}

// MARK: - Offline Pack Manager

@MainActor
class OfflinePackManager: ObservableObject {
    static let shared = OfflinePackManager()

    @Published var downloadStates: [String: PackDownloadState] = [:]
    @Published var downloadedPacks: [DownloadedPackInfo] = []
    @Published var totalOfflineSizeMB: Int = 0

    private let userDefaultsKey = "OfflinePackManager.downloadedPacks"
    private var downloadTasks: [String: Task<Void, Never>] = [:]

    private init() {
        loadDownloadedPacks()
        calculateTotalSize()
    }

    // MARK: - Public Methods

    /// Get all available packs with their current download state
    var allPacks: [OfflinePack] {
        OfflinePack.allPacks
    }

    /// Get packs by category
    func packs(for category: OfflinePack.PackCategory) -> [OfflinePack] {
        OfflinePack.allPacks.filter { $0.category == category }
    }

    /// Get download state for a pack
    func state(for packID: String) -> PackDownloadState {
        downloadStates[packID] ?? .notDownloaded
    }

    /// Check if a pack is fully downloaded
    func isDownloaded(_ packID: String) -> Bool {
        state(for: packID).isDownloaded
    }

    /// Start downloading a pack
    func downloadPack(_ pack: OfflinePack, content: [Content]) {
        guard !state(for: pack.id).isDownloading else { return }

        // Find matching content
        let matchingContent = findMatchingContent(for: pack, from: content)
        guard !matchingContent.isEmpty else {
            downloadStates[pack.id] = .failed(error: "No matching content found")
            return
        }

        // Start download
        downloadStates[pack.id] = .downloading(progress: 0)

        let task = Task {
            await performDownload(pack: pack, content: matchingContent)
        }
        downloadTasks[pack.id] = task
    }

    /// Cancel an ongoing download
    func cancelDownload(_ packID: String) {
        downloadTasks[packID]?.cancel()
        downloadTasks[packID] = nil
        downloadStates[packID] = .notDownloaded
    }

    /// Delete a downloaded pack
    func deletePack(_ packID: String) {
        guard let packInfo = downloadedPacks.first(where: { $0.packID == packID }) else { return }

        // Delete cached files
        Task {
            for videoID in packInfo.contentIDs {
                await VideoCache.shared.evictCacheEntry(for: videoID)
            }
        }

        // Remove from tracking
        downloadedPacks.removeAll { $0.packID == packID }
        downloadStates[packID] = .notDownloaded

        saveDownloadedPacks()
        calculateTotalSize()
    }

    /// Get content IDs for a downloaded pack
    func contentIDs(for packID: String) -> [String] {
        downloadedPacks.first { $0.packID == packID }?.contentIDs ?? []
    }

    // MARK: - Private Methods

    private func findMatchingContent(for pack: OfflinePack, from allContent: [Content]) -> [Content] {
        let matchingByType = allContent.filter { content in
            pack.contentTypes.contains(content.contentTypeRaw)
        }

        // Score content by tag matches
        let scored = matchingByType.map { content -> (Content, Int) in
            let tagScore = content.tags.reduce(0) { score, tag in
                let matches = pack.contentTags.contains { packTag in
                    tag.localizedCaseInsensitiveContains(packTag) ||
                    packTag.localizedCaseInsensitiveContains(tag)
                }
                return score + (matches ? 1 : 0)
            }
            return (content, tagScore)
        }

        // Sort by score (descending) and take target count
        let sorted = scored.sorted { $0.1 > $1.1 }
        return Array(sorted.prefix(pack.targetCount).map { $0.0 })
    }

    private func performDownload(pack: OfflinePack, content: [Content]) async {
        let totalItems = content.count
        var downloadedCount = 0
        var downloadedIDs: [String] = []
        var totalBytes: Int64 = 0

        for item in content {
            // Check if cancelled
            if Task.isCancelled {
                downloadStates[pack.id] = .notDownloaded
                return
            }

            // Download audio (smaller, faster)
            do {
                let (_, size) = try await downloadContent(item, audioOnly: true)
                downloadedIDs.append(item.youtubeVideoID)
                totalBytes += size
                downloadedCount += 1

                let progress = Double(downloadedCount) / Double(totalItems)
                downloadStates[pack.id] = .downloading(progress: progress)
            } catch {
                // Continue with other downloads even if one fails
                print("Failed to download \(item.title): \(error)")
            }
        }

        // Mark as complete
        let sizeMB = Int(totalBytes / 1_000_000)
        let packInfo = DownloadedPackInfo(
            packID: pack.id,
            downloadedAt: Date(),
            contentIDs: downloadedIDs,
            totalSizeMB: sizeMB
        )

        downloadedPacks.append(packInfo)
        downloadStates[pack.id] = .downloaded(date: Date(), sizeMB: sizeMB)

        saveDownloadedPacks()
        calculateTotalSize()
    }

    private func downloadContent(_ content: Content, audioOnly: Bool) async throws -> (URL, Int64) {
        guard let url = try await VideoCache.shared.cacheVideo(videoID: content.youtubeVideoID, audioOnly: audioOnly) else {
            throw NSError(domain: "OfflinePackManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to cache video"])
        }
        // Get file size
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        return (url, fileSize)
    }

    private func loadDownloadedPacks() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let packs = try? JSONDecoder().decode([DownloadedPackInfo].self, from: data) else {
            return
        }

        downloadedPacks = packs

        // Update states
        for pack in packs {
            downloadStates[pack.packID] = .downloaded(date: pack.downloadedAt, sizeMB: pack.totalSizeMB)
        }
    }

    private func saveDownloadedPacks() {
        guard let data = try? JSONEncoder().encode(downloadedPacks) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    private func calculateTotalSize() {
        totalOfflineSizeMB = downloadedPacks.reduce(0) { $0 + $1.totalSizeMB }
    }
}

// Note: Color.init(hex:) extension is defined in Theme.swift or another utility file
