//
//  StreakService.swift
//  Meditation Sleep Mindset
//

import Foundation
import SwiftUI
import SwiftData
import WidgetKit

@MainActor
class StreakService: ObservableObject {
    static let shared = StreakService()

    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var lastSessionDate: Date?
    @Published var totalMinutes: Int = 0
    @Published var totalSessions: Int = 0
    @Published var weeklyActivity: [DayActivity] = []
    @Published var meditatedToday: Bool = false
    /// True when today's session was kept alive by a forgiven "grace" day rather than a real consecutive day.
    @Published var streakFrozenToday: Bool = false

    /// A streak freeze (one forgiven missed day) is available if none has been used in the last 7 days.
    private func isStreakFreezeAvailable(on day: Date) -> Bool {
        guard let last = UserDefaults.standard.object(forKey: "lastStreakFreezeDate") as? Date else { return true }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: last), to: day).day ?? 0
        return days >= 7
    }

    private func consumeStreakFreeze(on day: Date) {
        UserDefaults.standard.set(day, forKey: "lastStreakFreezeDate")
    }

    // MARK: - Streak Shield (public surface for the grace day)

    /// Date the weekly grace "streak shield" was last consumed, if ever.
    var lastStreakShieldUsedDate: Date? {
        UserDefaults.standard.object(forKey: "lastStreakFreezeDate") as? Date
    }

    /// True when the streak shield is ready — no grace day has been consumed in the last 7 days.
    var isStreakShieldAvailable: Bool {
        isStreakFreezeAvailable(on: Calendar.current.startOfDay(for: Date()))
    }

    /// Whole days until the shield renews (0 when it's already available).
    var daysUntilStreakShieldRenews: Int {
        guard let last = lastStreakShieldUsedDate else { return 0 }
        let lastDay = Calendar.current.startOfDay(for: last)
        let today = Calendar.current.startOfDay(for: Date())
        let elapsed = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0
        return max(0, 7 - elapsed)
    }

    @AppStorage("isFirstMeditationSession") private var isFirstSession = true

    // iCloud KeyValue Store for persistence across reinstalls
    private let cloudStore = NSUbiquitousKeyValueStore.default

    private enum CloudKeys {
        static let currentStreak = "cloud_currentStreak"
        static let longestStreak = "cloud_longestStreak"
        static let lastSessionDate = "cloud_lastSessionDate"
        static let totalMinutes = "cloud_totalMinutes"
        static let totalSessions = "cloud_totalSessions"
        static let weeklyMinutes = "cloud_weeklyMinutes"
    }

    private var cloudObserver: Any?

    private init() {
        setupCloudSync()
        loadStreakData()
        checkTodayStatus()
    }

    deinit {
        if let observer = cloudObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupCloudSync() {
        // Listen for iCloud changes from other devices
        cloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleCloudUpdate(notification)
            }
        }
    }

    private func handleCloudUpdate(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let changeReason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }

        // Only update if the change is from the server or initial sync
        if changeReason == NSUbiquitousKeyValueStoreServerChange ||
           changeReason == NSUbiquitousKeyValueStoreInitialSyncChange {
            loadFromCloud()
            checkTodayStatus()
            updateWeeklyActivity()
        }
    }

    private func loadFromCloud() {
        // Load from iCloud and use if values are greater (user might have data on another device)
        let cloudCurrentStreak = Int(cloudStore.longLong(forKey: CloudKeys.currentStreak))
        let cloudLongestStreak = Int(cloudStore.longLong(forKey: CloudKeys.longestStreak))
        let cloudTotalMinutes = Int(cloudStore.longLong(forKey: CloudKeys.totalMinutes))
        let cloudTotalSessions = Int(cloudStore.longLong(forKey: CloudKeys.totalSessions))
        let cloudLastSessionDate = cloudStore.object(forKey: CloudKeys.lastSessionDate) as? Date

        // Use cloud data if it's more recent or has higher values
        if cloudLongestStreak > longestStreak {
            longestStreak = cloudLongestStreak
        }
        if cloudTotalMinutes > totalMinutes {
            totalMinutes = cloudTotalMinutes
        }
        if cloudTotalSessions > totalSessions {
            totalSessions = cloudTotalSessions
        }

        // For current streak, use cloud if last session date is more recent
        if let cloudDate = cloudLastSessionDate {
            if let localDate = lastSessionDate {
                if cloudDate > localDate {
                    lastSessionDate = cloudDate
                    currentStreak = cloudCurrentStreak
                }
            } else {
                lastSessionDate = cloudDate
                currentStreak = cloudCurrentStreak
            }
        }

        // Save merged data back
        saveStreakData()
    }

    // MARK: - Data Model
    struct DayActivity: Identifiable {
        let id = UUID()
        let date: Date
        let dayName: String
        let minutes: Int
        let hasActivity: Bool
    }

    // MARK: - Load Data
    func loadStreakData() {
        let defaults = UserDefaults.standard

        // First load from local UserDefaults
        let localCurrentStreak = defaults.integer(forKey: "currentStreak")
        let localLongestStreak = defaults.integer(forKey: "longestStreak")
        let localLastSessionDate = defaults.object(forKey: "lastSessionDate") as? Date
        let localTotalMinutes = defaults.integer(forKey: "totalMinutes")
        let localTotalSessions = defaults.integer(forKey: "totalSessions")

        // Then load from iCloud
        let cloudCurrentStreak = Int(cloudStore.longLong(forKey: CloudKeys.currentStreak))
        let cloudLongestStreak = Int(cloudStore.longLong(forKey: CloudKeys.longestStreak))
        let cloudLastSessionDate = cloudStore.object(forKey: CloudKeys.lastSessionDate) as? Date
        let cloudTotalMinutes = Int(cloudStore.longLong(forKey: CloudKeys.totalMinutes))
        let cloudTotalSessions = Int(cloudStore.longLong(forKey: CloudKeys.totalSessions))

        // Use the higher/more recent values (merge strategy)
        longestStreak = max(localLongestStreak, cloudLongestStreak)
        totalMinutes = max(localTotalMinutes, cloudTotalMinutes)
        totalSessions = max(localTotalSessions, cloudTotalSessions)

        // For current streak, prefer the data with the more recent session date
        if let cloudDate = cloudLastSessionDate, let localDate = localLastSessionDate {
            if cloudDate >= localDate {
                lastSessionDate = cloudDate
                currentStreak = cloudCurrentStreak
            } else {
                lastSessionDate = localDate
                currentStreak = localCurrentStreak
            }
        } else if let cloudDate = cloudLastSessionDate {
            lastSessionDate = cloudDate
            currentStreak = cloudCurrentStreak
        } else {
            lastSessionDate = localLastSessionDate
            currentStreak = localCurrentStreak
        }

        // Sync the merged data back to both stores
        saveStreakData()
        updateWeeklyActivity()
    }

    // MARK: - Record Session
    func recordSession(durationMinutes: Int, context: ModelContext? = nil) {
        let today = Calendar.current.startOfDay(for: Date())
        let previousStreak = currentStreak

        // Update totals
        totalMinutes += durationMinutes
        totalSessions += 1

        // Check streak logic (non-punitive: one forgiven "grace" miss per 7 days
        // keeps a single skipped day from resetting the whole streak).
        if let lastDate = lastSessionDate {
            let lastDay = Calendar.current.startOfDay(for: lastDate)
            let daysDifference = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysDifference == 0 {
                // Same day, don't increment streak
            } else if daysDifference == 1 {
                // Consecutive day, increment streak
                currentStreak += 1
                streakFrozenToday = false
            } else if daysDifference == 2 && isStreakFreezeAvailable(on: today) {
                // Missed exactly one day — forgive it with a streak freeze instead of resetting.
                currentStreak += 1
                consumeStreakFreeze(on: today)
                streakFrozenToday = true
            } else {
                // Streak broken, reset to 1
                currentStreak = 1
                streakFrozenToday = false
            }
        } else {
            // First session ever
            currentStreak = 1
        }

        // Update longest streak
        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }

        lastSessionDate = Date()
        meditatedToday = true

        // Save to UserDefaults
        saveStreakData()

        // Per-day minutes feed the week strip (Home + session summary). This was
        // only ever written by the Watch, so phone sessions never showed up.
        // A sub-minute session still counts as an active day.
        recordMinutesForToday(max(durationMinutes, 1))

        // Sync to shared UserDefaults for widgets (after the weekly data above)
        syncWidgetData()

        // Also save to SwiftData if context provided
        if let context = context {
            let session = MeditationSession(
                contentID: nil,
                durationSeconds: durationMinutes * 60,
                completedAt: Date()
            )
            context.insert(session)
        }

        // Notification integrations
        NotificationService.shared.cancelStreakAtRisk()

        // Milestones only on the session that actually reached them. A second
        // or third session on the same day left the streak at e.g. 7 and
        // re-sent the "One Week!" notification and rating ask every time.
        if currentStreak != previousStreak {
            checkStreakMilestone()
        }

        // Update challenge streak progress
        ChallengeService.shared.updateStreakProgress(currentStreak: currentStreak)

        // Handle first session
        if isFirstSession {
            isFirstSession = false
            // "You have 7 days to explore everything free" is only true for
            // someone actually in a trial — free users and payers got it too.
            if UserDefaults.standard.object(forKey: Constants.AnalyticsKeys.trialStartDate) != nil {
                NotificationService.shared.scheduleTrialDay1Notification()
            }
        }
    }

    /// Extra listening on a session that was already counted (e.g. a track
    /// that kept playing after the phone locked). Minutes only — no new
    /// session, no streak change.
    func addMinutes(_ minutes: Int) {
        guard minutes > 0 else { return }
        totalMinutes += minutes
        saveStreakData()
        recordMinutesForToday(minutes)
        syncWidgetData()
    }

    // MARK: - Check Today Status
    private func checkTodayStatus() {
        guard let lastDate = lastSessionDate else {
            meditatedToday = false
            scheduleStreakAtRiskIfNeeded()
            return
        }

        let today = Calendar.current.startOfDay(for: Date())
        let lastDay = Calendar.current.startOfDay(for: lastDate)

        meditatedToday = (today == lastDay)

        if !meditatedToday {
            scheduleStreakAtRiskIfNeeded()
        }
    }

    private func scheduleStreakAtRiskIfNeeded() {
        // Only schedule if user has a streak to lose
        if currentStreak >= 2 {
            NotificationService.shared.scheduleStreakAtRisk()
        }
    }

    private func checkStreakMilestone() {
        let milestones = [3, 7, 14, 21, 30, 60, 90, 365]

        if milestones.contains(currentStreak) {
            NotificationService.shared.scheduleStreakMilestone(days: currentStreak)
            SmartRatingManager.shared.checkAndPromptIfAppropriate(trigger: .streakMilestone(days: currentStreak))
        }

        // Check if we should prompt for account sign-in
        AccountService.shared.checkStreakMilestone(streak: currentStreak)
    }

    // MARK: - Check Streak Status
    func checkAndUpdateStreak() {
        guard let lastDate = lastSessionDate else { return }

        let today = Calendar.current.startOfDay(for: Date())
        let lastDay = Calendar.current.startOfDay(for: lastDate)
        let daysDifference = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0

        // One missed day (daysDifference == 2) is still recoverable by the
        // Streak Shield when the user meditates today — recordSession handles
        // that path. Resetting here would wipe the streak the shield promises
        // to protect (and consumption must stay in recordSession only).
        if daysDifference > 2 || (daysDifference == 2 && !isStreakFreezeAvailable(on: today)) {
            if currentStreak != 0 {
                currentStreak = 0
                saveStreakData()
                syncWidgetData()
                NotificationService.shared.cancelStreakAtRisk()
            }
        }
        // Day rollover: "meditated today" must flip back after midnight.
        checkTodayStatus()
    }

    // MARK: - Weekly Activity
    private func updateWeeklyActivity() {
        let calendar = Calendar.current
        let today = Date()
        var activities: [DayActivity] = []

        // Get sessions from this week
        let weeklyMinutes = getWeeklyMinutesFromDefaults()

        for i in (0..<7).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "EEE"
                let dayName = dayFormatter.string(from: date)

                let dateKey = formatDateKey(date)
                let minutes = weeklyMinutes[dateKey] ?? 0

                activities.append(DayActivity(
                    date: date,
                    dayName: dayName,
                    minutes: minutes,
                    hasActivity: minutes > 0
                ))
            }
        }

        weeklyActivity = activities
    }

    private func getWeeklyMinutesFromDefaults() -> [String: Int] {
        // Get local data
        let localWeekly = UserDefaults.standard.dictionary(forKey: "weeklyMinutes") as? [String: Int] ?? [:]

        // Get cloud data
        let cloudWeekly = cloudStore.dictionary(forKey: CloudKeys.weeklyMinutes) as? [String: Int] ?? [:]

        // Merge: take the higher value for each day
        var merged = localWeekly
        for (key, value) in cloudWeekly {
            merged[key] = max(merged[key] ?? 0, value)
        }

        return merged
    }

    /// Minutes recorded on each day of the current calendar week (locale's
    /// first weekday), oldest first. Future days report 0.
    func currentWeekActivity() -> [DayActivity] {
        let calendar = Calendar.current
        guard let week = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        let weeklyMinutes = getWeeklyMinutesFromDefaults()
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEEE"
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: week.start) else { return nil }
            let minutes = weeklyMinutes[formatDateKey(date)] ?? 0
            return DayActivity(date: date, dayName: dayFormatter.string(from: date), minutes: minutes, hasActivity: minutes > 0)
        }
    }

    /// Minutes per day for the current Monday–Sunday week (what the widgets'
    /// fixed M…S labels expect), regardless of the locale's first weekday.
    private func mondayFirstWeekActivity() -> [DayActivity] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        guard let week = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return weeklyActivity }
        let weeklyMinutes = getWeeklyMinutesFromDefaults()
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: week.start) else { return nil }
            let minutes = weeklyMinutes[formatDateKey(date)] ?? 0
            return DayActivity(date: date, dayName: "", minutes: minutes, hasActivity: minutes > 0)
        }
    }

    private func formatDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    func recordMinutesForToday(_ minutes: Int) {
        var weeklyMinutes = getWeeklyMinutesFromDefaults()
        let todayKey = formatDateKey(Date())
        weeklyMinutes[todayKey] = (weeklyMinutes[todayKey] ?? 0) + minutes

        // Prune entries older than 14 days to prevent unbounded growth
        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .day, value: -14, to: Date()) else { return }
        let cutoffKey = formatDateKey(cutoffDate)
        weeklyMinutes = weeklyMinutes.filter { $0.key >= cutoffKey }

        // Save to local
        UserDefaults.standard.set(weeklyMinutes, forKey: "weeklyMinutes")

        // Save to iCloud
        cloudStore.set(weeklyMinutes, forKey: CloudKeys.weeklyMinutes)

        updateWeeklyActivity()
    }

    // MARK: - Save Data
    private func saveStreakData() {
        let defaults = UserDefaults.standard

        // Save to local UserDefaults
        defaults.set(currentStreak, forKey: "currentStreak")
        defaults.set(longestStreak, forKey: "longestStreak")
        defaults.set(lastSessionDate, forKey: "lastSessionDate")
        defaults.set(totalMinutes, forKey: "totalMinutes")
        defaults.set(totalSessions, forKey: "totalSessions")

        // Save to iCloud KeyValue Store (persists across reinstalls)
        cloudStore.set(Int64(currentStreak), forKey: CloudKeys.currentStreak)
        cloudStore.set(Int64(longestStreak), forKey: CloudKeys.longestStreak)
        cloudStore.set(lastSessionDate, forKey: CloudKeys.lastSessionDate)
        cloudStore.set(Int64(totalMinutes), forKey: CloudKeys.totalMinutes)
        cloudStore.set(Int64(totalSessions), forKey: CloudKeys.totalSessions)
    }

    /// Persist values another sync source (CloudKit) merged into the
    /// published properties — they otherwise lived only in memory until the
    /// next session, and were lost if the app was killed first.
    func persistMergedData() {
        saveStreakData()
        checkTodayStatus()
        syncWidgetData()
    }

    // MARK: - Widget Data Sync
    private func syncWidgetData() {
        guard let shared = UserDefaults(suiteName: "group.com.meditation.shared") else { return }

        // Basic streak data
        shared.set(currentStreak, forKey: "widget_currentStreak")
        shared.set(totalMinutes, forKey: "widget_totalMinutes")
        shared.set(lastSessionDate, forKey: "widget_lastSessionDate")

        // Both widgets label their 7 slots M T W T F S S, but were handed the
        // rolling last-7-days (today always in the final "S" slot) — so a
        // Wednesday session lit up Sunday. Send this Monday–Sunday week.
        let widgetWeek = mondayFirstWeekActivity()

        // Weekly activity for streak widget (7 bools, Monday first)
        let weeklyActivityBools = widgetWeek.map { $0.hasActivity }
        shared.set(weeklyActivityBools, forKey: "widget_weeklyActivity")

        // Weekly stats for progress widget
        let weeklyMinutesTotal = widgetWeek.reduce(0) { $0 + $1.minutes }
        let weeklySessionsCount = widgetWeek.filter { $0.hasActivity }.count
        let dailyMinutesArray = widgetWeek.map { $0.minutes }

        shared.set(weeklyMinutesTotal, forKey: "widget_weeklyMinutes")
        shared.set(weeklySessionsCount, forKey: "widget_weeklySessions")
        shared.set(dailyMinutesArray, forKey: "widget_dailyMinutes")

        // Weekly goal (default 70 min = 10 min/day)
        let weeklyGoal = UserDefaults.standard.integer(forKey: "weeklyGoalMinutes")
        shared.set(weeklyGoal > 0 ? weeklyGoal : 70, forKey: "widget_weeklyGoalMinutes")

        // Reload widget timelines
        WidgetCenter.shared.reloadAllTimelines()

        // Keep the Watch's streak/minutes in step with the phone.
        PhoneWatchConnectivityService.shared.sendSyncData()
    }

    /// Sync recent content for quick actions widget
    func syncRecentContent(title: String, type: String, id: String) {
        guard let shared = UserDefaults(suiteName: "group.com.meditation.shared") else { return }
        shared.set(title, forKey: "widget_recentContentTitle")
        shared.set(type, forKey: "widget_recentContentType")
        shared.set(id, forKey: "widget_recentContentId")
        WidgetCenter.shared.reloadTimelines(ofKind: "QuickActionsWidget")
    }

    // MARK: - Reset (for testing)
    func resetStreak() {
        currentStreak = 0
        longestStreak = 0
        lastSessionDate = nil
        totalMinutes = 0
        totalSessions = 0
        weeklyActivity = []

        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "currentStreak")
        defaults.removeObject(forKey: "longestStreak")
        defaults.removeObject(forKey: "lastSessionDate")
        defaults.removeObject(forKey: "totalMinutes")
        defaults.removeObject(forKey: "totalSessions")
        defaults.removeObject(forKey: "weeklyMinutes")
    }

    // MARK: - Formatted Stats
    var totalTimeFormatted: String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var streakEmoji: String {
        switch currentStreak {
        case 0: return ""
        case 1...6: return "🔥"
        case 7...13: return "🔥🔥"
        case 14...29: return "🔥🔥🔥"
        default: return "🔥🔥🔥🔥"
        }
    }

    var streakMessage: String {
        switch currentStreak {
        case 0: return String(localized: "Start your streak today!")
        case 1: return String(localized: "Great start! Keep it going!")
        case 2...6: return String(localized: "You're building momentum!")
        case 7...13: return String(localized: "One week strong!")
        case 14...29: return String(localized: "Amazing dedication!")
        default: return String(localized: "Incredible consistency!")
        }
    }
}
