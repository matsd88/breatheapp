//
//  NotificationService.swift
//  Meditation Sleep Mindset
//

import Foundation
import UserNotifications
import SwiftUI

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var isAuthorized = false
    @Published var dailyReminderEnabled = false
    @Published var bedtimeReminderEnabled = false
    @Published var streakNotificationsEnabled = false
    @Published var newContentNotificationsEnabled = false

    // User-chosen reminder times
    @AppStorage("dailyReminderTime") private var dailyReminderTimeInterval: Double = 72000 // 8:00 PM default
    @AppStorage("bedtimeReminderTime") private var bedtimeReminderTimeInterval: Double = 79200 // 10:00 PM default
    @AppStorage("dailyReminderEnabledStorage") private var storedDailyReminderEnabled = false
    @AppStorage("bedtimeReminderEnabledStorage") private var storedBedtimeReminderEnabled = false
    @AppStorage("streakNotificationsEnabledStorage") private var storedStreakNotificationsEnabled = false
    @AppStorage("newContentNotificationsEnabledStorage") private var storedNewContentNotificationsEnabled = false

    var dailyReminderTime: Date {
        get {
            Calendar.current.startOfDay(for: Date()).addingTimeInterval(dailyReminderTimeInterval)
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            dailyReminderTimeInterval = Double((components.hour ?? 20) * 3600 + (components.minute ?? 0) * 60)
            if dailyReminderEnabled {
                scheduleDailyReminder()
            }
        }
    }

    var bedtimeReminderTime: Date {
        get {
            Calendar.current.startOfDay(for: Date()).addingTimeInterval(bedtimeReminderTimeInterval)
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            bedtimeReminderTimeInterval = Double((components.hour ?? 22) * 3600 + (components.minute ?? 0) * 60)
            if bedtimeReminderEnabled {
                scheduleBedtimeReminder()
            }
        }
    }

    private init() {
        dailyReminderEnabled = storedDailyReminderEnabled
        bedtimeReminderEnabled = storedBedtimeReminderEnabled
        streakNotificationsEnabled = storedStreakNotificationsEnabled
        newContentNotificationsEnabled = storedNewContentNotificationsEnabled

        Task {
            await checkAuthorizationStatus()
        }
    }

    // MARK: - Authorization

    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            isAuthorized = granted
            return granted
        } catch {
            #if DEBUG
            print("Notification authorization error: \(error)")
            #endif
            return false
        }
    }

    // MARK: - Onboarding Defaults

    /// Enable all notification types (called when user says yes to notifications in onboarding)
    func enableAllNotifications() {
        setDailyReminder(enabled: true)
        setBedtimeReminder(enabled: true)
        streakNotificationsEnabled = true
        storedStreakNotificationsEnabled = true
        newContentNotificationsEnabled = true
        storedNewContentNotificationsEnabled = true
    }

    /// Disable all notification types (called when user says no to notifications in onboarding)
    func disableAllNotifications() {
        setDailyReminder(enabled: false)
        setBedtimeReminder(enabled: false)
        streakNotificationsEnabled = false
        storedStreakNotificationsEnabled = false
        newContentNotificationsEnabled = false
        storedNewContentNotificationsEnabled = false
    }

    // MARK: - Daily Practice Reminder

    func setDailyReminder(enabled: Bool) {
        dailyReminderEnabled = enabled
        storedDailyReminderEnabled = enabled

        if enabled {
            scheduleDailyReminder()
        } else {
            cancelNotifications(withIdentifier: "daily-reminder")
        }
    }

    private func scheduleDailyReminder() {
        cancelNotifications(withIdentifier: "daily-reminder")

        let messages = [
            "Your evening calm awaits. Ready for 5 minutes of peace?",
            "Time for your daily meditation. Your mind will thank you.",
            "The day is winding down. Let's breathe together.",
            "Your mind called. It's asking for a few quiet minutes.",
            "3 minutes is all it takes. Your meditation is ready.",
            "A moment of stillness is waiting for you.",
            "Pause. Breathe. You've earned this.",
        ]

        let components = Calendar.current.dateComponents([.hour, .minute], from: dailyReminderTime)

        var dateComponents = DateComponents()
        dateComponents.hour = components.hour
        dateComponents.minute = components.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "Mindful Moments"
        content.body = messages.randomElement() ?? messages[0]
        content.sound = .default
        content.categoryIdentifier = "DAILY_REMINDER"

        let request = UNNotificationRequest(
            identifier: "daily-reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Bedtime Reminder

    func setBedtimeReminder(enabled: Bool) {
        bedtimeReminderEnabled = enabled
        storedBedtimeReminderEnabled = enabled

        if enabled {
            scheduleBedtimeReminder()
        } else {
            cancelNotifications(withIdentifier: "bedtime-reminder")
        }
    }

    private func scheduleBedtimeReminder() {
        cancelNotifications(withIdentifier: "bedtime-reminder")

        let messages = [
            "Wind down time. A sleep story is waiting for you.",
            "Ready for better sleep tonight?",
            "Your body is tired. Let's help your mind follow.",
            "Time to drift off. Tonight's sleep story awaits.",
            "The stars are out. Time for rest.",
        ]

        let components = Calendar.current.dateComponents([.hour, .minute], from: bedtimeReminderTime)

        var dateComponents = DateComponents()
        dateComponents.hour = components.hour
        dateComponents.minute = components.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "Bedtime"
        content.body = messages.randomElement() ?? messages[0]
        content.sound = .default
        content.categoryIdentifier = "BEDTIME_REMINDER"

        let request = UNNotificationRequest(
            identifier: "bedtime-reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Streak Notifications

    func scheduleStreakMilestone(days: Int) {
        guard streakNotificationsEnabled else { return }

        let (title, body) = streakMessage(for: days)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "STREAK_MILESTONE"

        // Send immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "streak-\(days)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func streakMessage(for days: Int) -> (title: String, body: String) {
        switch days {
        case 3:
            return ("3 Days!", "You're building something powerful. Keep going!")
        case 7:
            return ("One Week!", "7 days of mindfulness. You're in the top 20% of users!")
        case 14:
            return ("Two Weeks!", "14 days strong. Your mind is thanking you.")
        case 21:
            return ("21 Days!", "Science says it takes 21 days to form a habit. You did it!")
        case 30:
            return ("30 Days!", "One month of meditation! You've built a lasting practice.")
        case 60:
            return ("60 Days!", "Two months of daily calm. You're inspiring!")
        case 90:
            return ("90 Days!", "A quarter year of mindfulness. Incredible dedication!")
        case 365:
            return ("ONE YEAR!", "365 days of meditation. You're a true master!")
        default:
            return ("Streak: \(days) Days", "Keep the momentum going!")
        }
    }

    func scheduleStreakAtRisk() {
        guard streakNotificationsEnabled else { return }

        // Schedule for 8 PM if user hasn't meditated today
        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = "Don't lose your streak!"
        content.body = "Just 3 minutes to keep your streak alive. You've got this!"
        content.sound = .default
        content.categoryIdentifier = "STREAK_AT_RISK"

        let request = UNNotificationRequest(
            identifier: "streak-at-risk",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func cancelStreakAtRisk() {
        cancelNotifications(withIdentifier: "streak-at-risk")
    }

    // MARK: - Trial Notifications

    func scheduleTrialNotifications(trialEndDate: Date) {
        // Day 2: Feature highlight
        scheduleTrialDay2Notification(trialEndDate: trialEndDate)

        // Day 3 Morning: Urgency
        scheduleTrialDay3MorningNotification(trialEndDate: trialEndDate)

        // Day 3 Evening: Final push
        scheduleTrialDay3EveningNotification(trialEndDate: trialEndDate)
    }

    func scheduleTrialDay1Notification() {
        // Called after first meditation session
        let content = UNMutableNotificationContent()
        content.title = "Great first session!"
        content.body = "You have 3 days to explore everything free. Try a Sleep Story tonight!"
        content.sound = .default
        content.categoryIdentifier = "TRIAL_DAY_1"

        // Send 2 hours after first session
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 7200, repeats: false)

        let request = UNNotificationRequest(
            identifier: "trial-day-1",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleTrialDay2Notification(trialEndDate: Date) {
        guard let day2 = Calendar.current.date(byAdding: .day, value: -1, to: trialEndDate) else { return }

        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: day2)
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = "Pro tip"
        content.body = "The best time to meditate is right before bed. Try tonight's Sleep Story!"
        content.sound = .default
        content.categoryIdentifier = "TRIAL_DAY_2"

        let request = UNNotificationRequest(
            identifier: "trial-day-2",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleTrialDay3MorningNotification(trialEndDate: Date) {
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: trialEndDate)
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = "Last day of your free trial"
        content.body = "Lock in annual today—that's just $0.96/week."
        content.sound = .default
        content.categoryIdentifier = "TRIAL_DAY_3_AM"

        let request = UNNotificationRequest(
            identifier: "trial-day-3-am",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleTrialDay3EveningNotification(trialEndDate: Date) {
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: trialEndDate)
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = "Your trial ends tonight"
        content.body = "Don't lose access to 500+ meditations. Continue for just $0.96/week."
        content.sound = .default
        content.categoryIdentifier = "TRIAL_DAY_3_PM"

        let request = UNNotificationRequest(
            identifier: "trial-day-3-pm",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func cancelTrialNotifications() {
        let identifiers = ["trial-day-1", "trial-day-2", "trial-day-3-am", "trial-day-3-pm"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Re-engagement Notifications

    func scheduleReengagementSequence() {
        // Day 3 of inactivity
        scheduleReengagement(days: 3, title: "We miss you", body: "A few minutes of calm is waiting for you.")

        // Day 7 of inactivity
        scheduleReengagement(days: 7, title: "It's been a week", body: "Your mind might need a moment of peace.")

        // Day 14 of inactivity
        scheduleReengagement(days: 14, title: "Welcome back anytime", body: "Here's a free session, on us.")

        // Day 30 of inactivity (final message)
        scheduleReengagement(days: 30, title: "We're here when you're ready", body: "Life gets busy. Your calm is waiting.")
    }

    private func scheduleReengagement(days: Int, title: String, body: String) {
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(days * 24 * 60 * 60),
            repeats: false
        )

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "RE_ENGAGEMENT"

        let request = UNNotificationRequest(
            identifier: "reengagement-day-\(days)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func cancelReengagementNotifications() {
        let identifiers = ["reengagement-day-3", "reengagement-day-7", "reengagement-day-14", "reengagement-day-30"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func resetReengagementOnAppOpen() {
        // Cancel existing re-engagement notifications
        cancelReengagementNotifications()
        // Reschedule from day 0
        scheduleReengagementSequence()
    }

    // MARK: - New Content Notification

    func sendNewContentNotification(title: String, contentName: String) {
        guard newContentNotificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "New: \(contentName)"
        content.sound = .default
        content.categoryIdentifier = "NEW_CONTENT"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "new-content-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Helpers

    private func cancelNotifications(withIdentifier identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Badge Management

    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}
