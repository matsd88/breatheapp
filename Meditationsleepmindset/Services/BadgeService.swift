//
//  BadgeService.swift
//  Meditation Sleep Mindset
//

import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
final class BadgeService: ObservableObject {
    static let shared = BadgeService()

    @Published var earnedBadges: [Badge] = []
    @Published var recentlyEarnedBadge: Badge?
    @Published var showCelebration = false

    private let earnedBadgeIDsKey = "earnedBadgeIDs"
    private let badgeDatesKey = "badgeDates"

    // Stats tracking keys
    private let weekendSessionsKey = "badge_weekendSessions"
    private let hasSharedContentKey = "badge_hasSharedContent"
    private let morningMeditationKey = "badge_morningMeditation"
    private let nightMeditationKey = "badge_nightMeditation"

    // iCloud KeyValue Store for persistence across reinstalls
    private let cloudStore = NSUbiquitousKeyValueStore.default

    private var cloudObserver: Any?

    private init() {
        loadEarnedBadges()
        setupCloudSync()
    }

    deinit {
        if let observer = cloudObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Cloud Sync

    private func setupCloudSync() {
        cloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loadEarnedBadges()
            }
        }
    }

    // MARK: - Load/Save

    func reloadBadges() {
        loadEarnedBadges()
    }

    private func loadEarnedBadges() {
        let defaults = UserDefaults.standard

        // Load earned badge IDs and dates
        let localBadgeIDs = Set(defaults.stringArray(forKey: earnedBadgeIDsKey) ?? [])
        let cloudBadgeIDs = Set(cloudStore.array(forKey: earnedBadgeIDsKey) as? [String] ?? [])
        let mergedBadgeIDs = localBadgeIDs.union(cloudBadgeIDs)

        let localDates = defaults.dictionary(forKey: badgeDatesKey) as? [String: Date] ?? [:]
        let cloudDates = cloudStore.dictionary(forKey: badgeDatesKey) as? [String: Date] ?? [:]

        // Merge dates - prefer earlier date if both exist
        var mergedDates: [String: Date] = [:]
        for badgeID in mergedBadgeIDs {
            if let localDate = localDates[badgeID], let cloudDate = cloudDates[badgeID] {
                mergedDates[badgeID] = min(localDate, cloudDate)
            } else {
                mergedDates[badgeID] = localDates[badgeID] ?? cloudDates[badgeID]
            }
        }

        // Build earned badges list
        earnedBadges = Badge.allBadges.compactMap { badge in
            guard mergedBadgeIDs.contains(badge.id) else { return nil }
            var earnedBadge = badge
            earnedBadge.dateEarned = mergedDates[badge.id]
            return earnedBadge
        }

        // Save merged data back
        saveBadges()
    }

    private func saveBadges() {
        let defaults = UserDefaults.standard

        let badgeIDs = earnedBadges.map { $0.id }
        var badgeDates: [String: Date] = [:]
        for badge in earnedBadges {
            if let date = badge.dateEarned {
                badgeDates[badge.id] = date
            }
        }

        // Save locally
        defaults.set(badgeIDs, forKey: earnedBadgeIDsKey)
        defaults.set(badgeDates, forKey: badgeDatesKey)

        // Save to iCloud
        cloudStore.set(badgeIDs, forKey: earnedBadgeIDsKey)
        cloudStore.set(badgeDates, forKey: badgeDatesKey)
    }

    // MARK: - Badge Checking

    /// Check all badges after a session and award any newly earned ones
    func checkBadges(
        context: ModelContext,
        streakService: StreakService,
        currentContentType: ContentType? = nil
    ) {
        var newlyEarned: [Badge] = []

        for badge in Badge.allBadges {
            // Skip already earned badges
            if earnedBadges.contains(where: { $0.id == badge.id }) {
                continue
            }

            // Check if requirement is met
            if checkRequirement(
                badge.requirement,
                context: context,
                streakService: streakService,
                currentContentType: currentContentType
            ) {
                var earnedBadge = badge
                earnedBadge.dateEarned = Date()
                earnedBadges.append(earnedBadge)
                newlyEarned.append(earnedBadge)
            }
        }

        if !newlyEarned.isEmpty {
            saveBadges()

            // Show celebration for the most significant badge
            if let mostSignificant = newlyEarned.sorted(by: { significance($0) > significance($1) }).first {
                triggerCelebration(for: mostSignificant)
            }
        }
    }

    private func checkRequirement(
        _ requirement: BadgeRequirement,
        context: ModelContext,
        streakService: StreakService,
        currentContentType: ContentType?
    ) -> Bool {
        switch requirement {
        case .firstSession:
            return streakService.totalSessions >= 1

        case .sessionsCompleted(let count):
            return streakService.totalSessions >= count

        case .streakDays(let days):
            return streakService.longestStreak >= days

        case .totalMinutes(let minutes):
            return streakService.totalMinutes >= minutes

        case .meditationSessions(let count):
            return countSessions(ofTypes: [.meditation], context: context) >= count

        case .musicSessions(let count):
            return countSessions(ofTypes: [.music], context: context) >= count

        case .soundscapeSessions(let count):
            return countSessions(ofTypes: [.soundscape], context: context) >= count

        case .movementSessions(let count):
            return countSessions(ofTypes: [.movement], context: context) >= count

        case .mindsetSessions(let count):
            return countSessions(ofTypes: [.mindset], context: context) >= count

        case .asmrSessions(let count):
            return countSessions(ofTypes: [.asmr], context: context) >= count

        case .sleepStorySessions(let count):
            return countSessions(ofTypes: [.sleepStory], context: context) >= count

        case .triedAllContentTypes:
            return hasTriedAllContentTypes(context: context)

        case .morningMeditation:
            return UserDefaults.standard.bool(forKey: morningMeditationKey)

        case .nightMeditation:
            return UserDefaults.standard.bool(forKey: nightMeditationKey)

        case .weekendWarrior:
            return UserDefaults.standard.integer(forKey: weekendSessionsKey) >= 4

        case .createdPlaylist:
            return countPlaylists(context: context) >= 1

        case .favorited(let count):
            return countFavorites(context: context) >= count

        case .sharedContent:
            return UserDefaults.standard.bool(forKey: hasSharedContentKey)
        }
    }

    // MARK: - Session Counting Helpers

    private func countSessions(ofTypes types: [ContentType], context: ModelContext) -> Int {
        // We need to count sessions by looking at the content they reference
        let descriptor = FetchDescriptor<MeditationSession>()
        guard let sessions = try? context.fetch(descriptor) else { return 0 }

        // Get all content to match session video IDs
        let contentDescriptor = FetchDescriptor<Content>()
        guard let allContent = try? context.fetch(contentDescriptor) else { return 0 }

        // Create lookup dictionary
        let contentByVideoID = Dictionary(uniqueKeysWithValues: allContent.compactMap { content -> (String, Content)? in
            return (content.youtubeVideoID, content)
        })

        var count = 0
        for session in sessions {
            if let videoID = session.youtubeVideoID,
               let content = contentByVideoID[videoID],
               types.contains(content.contentType) {
                count += 1
            }
        }
        return count
    }

    private func hasTriedAllContentTypes(context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<MeditationSession>()
        guard let sessions = try? context.fetch(descriptor) else { return false }

        let contentDescriptor = FetchDescriptor<Content>()
        guard let allContent = try? context.fetch(contentDescriptor) else { return false }

        let contentByVideoID = Dictionary(uniqueKeysWithValues: allContent.compactMap { content -> (String, Content)? in
            return (content.youtubeVideoID, content)
        })

        var triedTypes = Set<ContentType>()
        for session in sessions {
            if let videoID = session.youtubeVideoID,
               let content = contentByVideoID[videoID] {
                triedTypes.insert(content.contentType)
            }
        }

        // Check if all content types have been tried
        return ContentType.allCases.allSatisfy { triedTypes.contains($0) }
    }

    private func countPlaylists(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<Playlist>()
        return (try? context.fetch(descriptor).count) ?? 0
    }

    private func countFavorites(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<FavoriteContent>()
        return (try? context.fetch(descriptor).count) ?? 0
    }

    // MARK: - Event Tracking

    /// Call when content is shared
    func recordContentShared() {
        UserDefaults.standard.set(true, forKey: hasSharedContentKey)
    }

    /// Call after a session is completed to track time-based badges
    func recordSessionTime() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())

        // Morning meditation (before 8 AM)
        if hour < 8 {
            UserDefaults.standard.set(true, forKey: morningMeditationKey)
        }

        // Night meditation (after 10 PM)
        if hour >= 22 {
            UserDefaults.standard.set(true, forKey: nightMeditationKey)
        }

        // Weekend sessions
        let weekday = calendar.component(.weekday, from: Date())
        if weekday == 1 || weekday == 7 { // Sunday = 1, Saturday = 7
            let current = UserDefaults.standard.integer(forKey: weekendSessionsKey)
            UserDefaults.standard.set(current + 1, forKey: weekendSessionsKey)
        }
    }

    // MARK: - Celebration

    private func triggerCelebration(for badge: Badge) {
        recentlyEarnedBadge = badge
        showCelebration = true
        HapticManager.success()

        // Show toast notification
        ToastManager.shared.show(
            "Badge Earned: \(badge.name)",
            icon: badge.iconName,
            style: .success
        )

        // Prompt for rating after celebration (skip "First Session" badge)
        if badge.requirement != .firstSession {
            SmartRatingManager.shared.checkAndPromptIfAppropriate(trigger: .badgeEarned)
        }
    }

    func dismissCelebration() {
        withAnimation(.easeOut(duration: 0.3)) {
            showCelebration = false
        }
        // Keep the badge visible for a moment before clearing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.recentlyEarnedBadge = nil
        }
    }

    // MARK: - Helpers

    /// Returns a significance score for a badge (higher = more significant)
    private func significance(_ badge: Badge) -> Int {
        switch badge.requirement {
        case .streakDays(let days):
            return days * 2
        case .sessionsCompleted(let count):
            return count
        case .totalMinutes(let minutes):
            return minutes / 10
        case .firstSession:
            return 100 // First session is significant
        case .triedAllContentTypes:
            return 150
        default:
            return 50
        }
    }

    /// Get all badges with their current earned status
    var allBadgesWithStatus: [Badge] {
        Badge.allBadges.map { badge in
            if let earned = earnedBadges.first(where: { $0.id == badge.id }) {
                return earned
            }
            return badge
        }
    }

    /// Get recently earned badges (last 7 days)
    var recentlyEarnedBadges: [Badge] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return earnedBadges.filter { badge in
            guard let dateEarned = badge.dateEarned else { return false }
            return dateEarned > weekAgo
        }.sorted { ($0.dateEarned ?? .distantPast) > ($1.dateEarned ?? .distantPast) }
    }

    /// Get progress toward a specific badge (0.0 to 1.0)
    func progress(for badge: Badge, context: ModelContext, streakService: StreakService) -> Double {
        guard !badge.isEarned else { return 1.0 }

        switch badge.requirement {
        case .firstSession:
            return streakService.totalSessions >= 1 ? 1.0 : 0.0

        case .sessionsCompleted(let count):
            return min(1.0, Double(streakService.totalSessions) / Double(count))

        case .streakDays(let days):
            return min(1.0, Double(streakService.longestStreak) / Double(days))

        case .totalMinutes(let minutes):
            return min(1.0, Double(streakService.totalMinutes) / Double(minutes))

        case .meditationSessions(let count):
            return min(1.0, Double(countSessions(ofTypes: [.meditation], context: context)) / Double(count))

        case .musicSessions(let count):
            return min(1.0, Double(countSessions(ofTypes: [.music], context: context)) / Double(count))

        case .soundscapeSessions(let count):
            return min(1.0, Double(countSessions(ofTypes: [.soundscape], context: context)) / Double(count))

        case .movementSessions(let count):
            return min(1.0, Double(countSessions(ofTypes: [.movement], context: context)) / Double(count))

        case .mindsetSessions(let count):
            return min(1.0, Double(countSessions(ofTypes: [.mindset], context: context)) / Double(count))

        case .asmrSessions(let count):
            return min(1.0, Double(countSessions(ofTypes: [.asmr], context: context)) / Double(count))

        case .sleepStorySessions(let count):
            return min(1.0, Double(countSessions(ofTypes: [.sleepStory], context: context)) / Double(count))

        case .triedAllContentTypes:
            let descriptor = FetchDescriptor<MeditationSession>()
            guard let sessions = try? context.fetch(descriptor) else { return 0 }
            let contentDescriptor = FetchDescriptor<Content>()
            guard let allContent = try? context.fetch(contentDescriptor) else { return 0 }
            let contentByVideoID = Dictionary(uniqueKeysWithValues: allContent.compactMap { ($0.youtubeVideoID, $0) })
            var triedTypes = Set<ContentType>()
            for session in sessions {
                if let videoID = session.youtubeVideoID,
                   let content = contentByVideoID[videoID] {
                    triedTypes.insert(content.contentType)
                }
            }
            return Double(triedTypes.count) / Double(ContentType.allCases.count)

        case .morningMeditation:
            return UserDefaults.standard.bool(forKey: morningMeditationKey) ? 1.0 : 0.0

        case .nightMeditation:
            return UserDefaults.standard.bool(forKey: nightMeditationKey) ? 1.0 : 0.0

        case .weekendWarrior:
            return min(1.0, Double(UserDefaults.standard.integer(forKey: weekendSessionsKey)) / 4.0)

        case .createdPlaylist:
            return countPlaylists(context: context) >= 1 ? 1.0 : 0.0

        case .favorited(let count):
            return min(1.0, Double(countFavorites(context: context)) / Double(count))

        case .sharedContent:
            return UserDefaults.standard.bool(forKey: hasSharedContentKey) ? 1.0 : 0.0
        }
    }

    // MARK: - Reset (for testing)

    func resetAllBadges() {
        earnedBadges = []
        saveBadges()
        UserDefaults.standard.removeObject(forKey: weekendSessionsKey)
        UserDefaults.standard.removeObject(forKey: hasSharedContentKey)
        UserDefaults.standard.removeObject(forKey: morningMeditationKey)
        UserDefaults.standard.removeObject(forKey: nightMeditationKey)
    }
}
