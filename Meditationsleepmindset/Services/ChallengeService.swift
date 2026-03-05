//
//  ChallengeService.swift
//  Meditation Sleep Mindset
//

import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
final class ChallengeService: ObservableObject {
    static let shared = ChallengeService()

    @Published var activeChallenges: [Challenge] = []
    @Published var completedChallenges: [Challenge] = []
    @Published var featuredChallenge: Challenge?
    @Published var showCelebration = false
    @Published var recentlyCompletedChallenge: Challenge?
    @Published var totalXPEarned: Int = 0

    // UserDefaults keys
    private let activeChallengesKey = "challenge_active"
    private let completedChallengesKey = "challenge_completed"
    private let weekStartKey = "challenge_weekStart"
    private let totalXPKey = "challenge_totalXP"
    private let contentTypesTriedKey = "challenge_contentTypesTried"
    private let morningSessionsKey = "challenge_morningSessions"
    private let nightSessionsKey = "challenge_nightSessions"
    private let focusTimerSessionsKey = "challenge_focusTimerSessions"
    private let dailySessionDatesKey = "challenge_dailySessionDates"

    // iCloud KeyValue Store for persistence across reinstalls
    private let cloudStore = NSUbiquitousKeyValueStore.default

    private var cloudObserver: Any?

    private init() {
        loadData()
        setupCloudSync()
        checkAndRotateChallenges()
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
                self?.loadData()
            }
        }
    }

    // MARK: - Load/Save

    func reloadChallenges() {
        loadData()
    }

    private func loadData() {
        let defaults = UserDefaults.standard

        // Load total XP
        let localXP = defaults.integer(forKey: totalXPKey)
        let cloudXP = Int(cloudStore.longLong(forKey: totalXPKey))
        totalXPEarned = max(localXP, cloudXP)

        // Load active challenges
        if let data = defaults.data(forKey: activeChallengesKey),
           let challenges = try? JSONDecoder().decode([Challenge].self, from: data) {
            activeChallenges = challenges
        }

        // Load completed challenges
        if let data = defaults.data(forKey: completedChallengesKey),
           let challenges = try? JSONDecoder().decode([Challenge].self, from: data) {
            completedChallenges = challenges
        }

        // Merge with cloud data
        if let cloudData = cloudStore.data(forKey: completedChallengesKey),
           let cloudChallenges = try? JSONDecoder().decode([Challenge].self, from: cloudData) {
            // Merge completed challenges - keep unique by ID
            let existingIDs = Set(completedChallenges.map { $0.id })
            let newFromCloud = cloudChallenges.filter { !existingIDs.contains($0.id) }
            completedChallenges.append(contentsOf: newFromCloud)
        }

        // Update featured challenge
        featuredChallenge = activeChallenges.first { $0.isFeatured } ?? activeChallenges.first
    }

    private func saveData() {
        let defaults = UserDefaults.standard

        // Save active challenges
        if let data = try? JSONEncoder().encode(activeChallenges) {
            defaults.set(data, forKey: activeChallengesKey)
        }

        // Save completed challenges
        if let data = try? JSONEncoder().encode(completedChallenges) {
            defaults.set(data, forKey: completedChallengesKey)
            cloudStore.set(data, forKey: completedChallengesKey)
        }

        // Save total XP
        defaults.set(totalXPEarned, forKey: totalXPKey)
        cloudStore.set(Int64(totalXPEarned), forKey: totalXPKey)

        cloudStore.synchronize()

        // Update featured challenge
        featuredChallenge = activeChallenges.first { $0.isFeatured } ?? activeChallenges.first
    }

    // MARK: - Challenge Rotation

    /// Check if challenges need to be rotated (every Monday)
    func checkAndRotateChallenges() {
        let defaults = UserDefaults.standard
        let currentWeekStart = Challenge.currentWeekStart()

        // Check if we have a stored week start
        if let storedWeekStart = defaults.object(forKey: weekStartKey) as? Date {
            // If we're still in the same week, don't rotate
            if Calendar.current.isDate(storedWeekStart, equalTo: currentWeekStart, toGranularity: .weekOfYear) {
                // Just ensure we have active challenges
                if activeChallenges.isEmpty {
                    generateWeeklyChallenges()
                }
                return
            }
        }

        // New week - rotate challenges
        rotateChallenges()
        defaults.set(currentWeekStart, forKey: weekStartKey)
    }

    /// Generate new weekly challenges
    private func generateWeeklyChallenges() {
        let weekStart = Challenge.currentWeekStart()
        let weekEnd = Challenge.currentWeekEnd()

        // Reset weekly tracking
        resetWeeklyTracking()

        // Select 5-6 challenges based on user history
        var selectedChallenges: [Challenge] = []

        // Always include "Consistent" as the featured challenge
        var consistent = Challenge.consistent(weekStart: weekStart, weekEnd: weekEnd)
        consistent.isFeatured = true
        selectedChallenges.append(consistent)

        // Shuffle and pick from remaining templates
        var templates = Challenge.allTemplates.filter { template in
            let sample = template(weekStart, weekEnd)
            return sample.type != .streakDays // Exclude streakDays since we already have Consistent
        }
        templates.shuffle()

        // Pick 4-5 more challenges
        let additionalCount = Int.random(in: 4...5)
        for template in templates.prefix(additionalCount) {
            let challenge = template(weekStart, weekEnd)
            selectedChallenges.append(challenge)
        }

        activeChallenges = selectedChallenges
        saveData()
    }

    /// Rotate challenges for a new week
    private func rotateChallenges() {
        // Move any incomplete challenges to history (they expired)
        // Completed challenges are already in completedChallenges

        // Generate new challenges
        generateWeeklyChallenges()
    }

    private func resetWeeklyTracking() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: contentTypesTriedKey)
        defaults.removeObject(forKey: morningSessionsKey)
        defaults.removeObject(forKey: nightSessionsKey)
        defaults.removeObject(forKey: focusTimerSessionsKey)
        defaults.removeObject(forKey: dailySessionDatesKey)
    }

    // MARK: - Progress Tracking

    /// Record a completed session and update challenge progress
    func recordSession(
        contentType: ContentType,
        durationMinutes: Int,
        context: ModelContext,
        streakService: StreakService
    ) {
        let hour = Calendar.current.component(.hour, from: Date())
        var updatedChallenges: [Challenge] = []
        var newlyCompleted: [Challenge] = []

        for var challenge in activeChallenges {
            guard !challenge.isCompleted else {
                updatedChallenges.append(challenge)
                continue
            }

            var progressIncrement = 0

            switch challenge.type {
            case .dailySessions:
                // Track unique days with sessions
                if recordDailySession() {
                    progressIncrement = getDailySessionCount()
                    challenge.progress = progressIncrement
                }

            case .weeklyMinutes:
                progressIncrement = durationMinutes
                challenge.progress += progressIncrement

            case .streakDays:
                challenge.progress = streakService.currentStreak

            case .tryContentTypes:
                if recordContentTypeTried(contentType) {
                    challenge.progress = getContentTypesTriedCount()
                }

            case .morningMeditations:
                if hour < 9 {
                    progressIncrement = 1
                    challenge.progress += progressIncrement
                    recordMorningSession()
                }

            case .nightMeditations:
                if hour >= 20 {
                    progressIncrement = 1
                    challenge.progress += progressIncrement
                    recordNightSession()
                }

            case .sleepSessions:
                if contentType == .sleepStory || contentType == .soundscape {
                    progressIncrement = 1
                    challenge.progress += progressIncrement
                }

            case .focusTimerSessions:
                // Handled separately via recordFocusTimerSession()
                break

            case .meditationSessions:
                if contentType == .meditation {
                    progressIncrement = 1
                    challenge.progress += progressIncrement
                }

            case .musicSessions:
                if contentType == .music {
                    progressIncrement = 1
                    challenge.progress += progressIncrement
                }

            case .movementSessions:
                if contentType == .movement {
                    progressIncrement = 1
                    challenge.progress += progressIncrement
                }

            case .mindsetSessions:
                if contentType == .mindset {
                    progressIncrement = 1
                    challenge.progress += progressIncrement
                }

            case .soundscapeSessions:
                if contentType == .soundscape {
                    progressIncrement = 1
                    challenge.progress += progressIncrement
                }

            case .completeProgram:
                // Handled separately via recordProgramCompleted()
                break
            }

            // Check if challenge is now completed
            if challenge.progress >= challenge.target && !challenge.isCompleted {
                challenge.isCompleted = true
                challenge.completedDate = Date()
                newlyCompleted.append(challenge)
                awardReward(for: challenge)
            }

            updatedChallenges.append(challenge)
        }

        activeChallenges = updatedChallenges
        saveData()

        // Show celebration for completed challenges
        if let mostSignificant = newlyCompleted.sorted(by: { xpValue($0.reward) > xpValue($1.reward) }).first {
            triggerCelebration(for: mostSignificant)
        }
    }

    /// Record a focus timer session
    func recordFocusTimerSession() {
        let defaults = UserDefaults.standard
        var count = defaults.integer(forKey: focusTimerSessionsKey)
        count += 1
        defaults.set(count, forKey: focusTimerSessionsKey)

        // Update focus timer challenges
        var updatedChallenges: [Challenge] = []
        var newlyCompleted: [Challenge] = []

        for var challenge in activeChallenges {
            if challenge.type == .focusTimerSessions && !challenge.isCompleted {
                challenge.progress = count

                if challenge.progress >= challenge.target {
                    challenge.isCompleted = true
                    challenge.completedDate = Date()
                    newlyCompleted.append(challenge)
                    awardReward(for: challenge)
                }
            }
            updatedChallenges.append(challenge)
        }

        activeChallenges = updatedChallenges
        saveData()

        if let completed = newlyCompleted.first {
            triggerCelebration(for: completed)
        }
    }

    /// Update streak progress for streak-based challenges
    func updateStreakProgress(currentStreak: Int) {
        var updatedChallenges: [Challenge] = []
        var newlyCompleted: [Challenge] = []

        for var challenge in activeChallenges {
            if challenge.type == .streakDays && !challenge.isCompleted {
                challenge.progress = currentStreak

                if challenge.progress >= challenge.target {
                    challenge.isCompleted = true
                    challenge.completedDate = Date()
                    newlyCompleted.append(challenge)
                    awardReward(for: challenge)
                }
            }
            updatedChallenges.append(challenge)
        }

        activeChallenges = updatedChallenges
        saveData()

        if let completed = newlyCompleted.first {
            triggerCelebration(for: completed)
        }
    }

    // MARK: - Helper Tracking Methods

    private func recordDailySession() -> Bool {
        let defaults = UserDefaults.standard
        var dates = defaults.stringArray(forKey: dailySessionDatesKey) ?? []
        let today = formatDateKey(Date())

        if !dates.contains(today) {
            dates.append(today)
            defaults.set(dates, forKey: dailySessionDatesKey)
            return true
        }
        return false
    }

    private func getDailySessionCount() -> Int {
        let defaults = UserDefaults.standard
        let dates = defaults.stringArray(forKey: dailySessionDatesKey) ?? []
        return dates.count
    }

    private func recordContentTypeTried(_ contentType: ContentType) -> Bool {
        let defaults = UserDefaults.standard
        var types = defaults.stringArray(forKey: contentTypesTriedKey) ?? []

        if !types.contains(contentType.rawValue) {
            types.append(contentType.rawValue)
            defaults.set(types, forKey: contentTypesTriedKey)
            return true
        }
        return false
    }

    private func getContentTypesTriedCount() -> Int {
        let defaults = UserDefaults.standard
        let types = defaults.stringArray(forKey: contentTypesTriedKey) ?? []
        return types.count
    }

    private func recordMorningSession() {
        let defaults = UserDefaults.standard
        let count = defaults.integer(forKey: morningSessionsKey)
        defaults.set(count + 1, forKey: morningSessionsKey)
    }

    private func recordNightSession() {
        let defaults = UserDefaults.standard
        let count = defaults.integer(forKey: nightSessionsKey)
        defaults.set(count + 1, forKey: nightSessionsKey)
    }

    private func formatDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - Rewards

    private func awardReward(for challenge: Challenge) {
        switch challenge.reward {
        case .xp(let amount):
            totalXPEarned += amount
        case .badge:
            // Badge rewards could trigger BadgeService
            break
        }

        // Move to completed challenges
        completedChallenges.append(challenge)

        saveData()
    }

    private func xpValue(_ reward: ChallengeReward) -> Int {
        switch reward {
        case .xp(let amount):
            return amount
        case .badge:
            return 500 // Badges are worth more
        }
    }

    // MARK: - Celebration

    private func triggerCelebration(for challenge: Challenge) {
        recentlyCompletedChallenge = challenge
        showCelebration = true
        HapticManager.success()

        // Show toast notification
        ToastManager.shared.show(
            "Challenge Complete: \(challenge.title)",
            icon: "trophy.fill",
            style: .success
        )

        // Prompt for rating after celebration
        SmartRatingManager.shared.checkAndPromptIfAppropriate(trigger: .challengeCompleted)
    }

    func dismissCelebration() {
        withAnimation(.easeOut(duration: 0.3)) {
            showCelebration = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.recentlyCompletedChallenge = nil
        }
    }

    // MARK: - Statistics

    var completedThisWeek: Int {
        let weekStart = Challenge.currentWeekStart()
        return activeChallenges.filter { $0.isCompleted }.count
    }

    var totalCompletedAllTime: Int {
        completedChallenges.count + activeChallenges.filter { $0.isCompleted }.count
    }

    var activeCount: Int {
        activeChallenges.filter { !$0.isCompleted }.count
    }

    var weeklyProgress: Double {
        guard !activeChallenges.isEmpty else { return 0 }
        let completed = Double(activeChallenges.filter { $0.isCompleted }.count)
        return completed / Double(activeChallenges.count)
    }

    // MARK: - Reset (for testing)

    func resetAllChallenges() {
        activeChallenges = []
        completedChallenges = []
        totalXPEarned = 0

        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: activeChallengesKey)
        defaults.removeObject(forKey: completedChallengesKey)
        defaults.removeObject(forKey: weekStartKey)
        defaults.removeObject(forKey: totalXPKey)
        resetWeeklyTracking()

        // Generate fresh challenges
        generateWeeklyChallenges()
    }
}
