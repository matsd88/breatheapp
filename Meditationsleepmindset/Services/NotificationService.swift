//
//  NotificationService.swift
//  Meditation Sleep Mindset
//

import Foundation
import UserNotifications
import SwiftUI
import UIKit

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var isAuthorized = false
    @Published var dailyReminderEnabled = false
    @Published var bedtimeReminderEnabled = false
    @Published var streakNotificationsEnabled = false
    @Published var newContentNotificationsEnabled = false
    /// Proactive daily AI coach check-in (Bevel-style agentic nudge).
    @Published var aiCheckInEnabled = false

    // User-chosen reminder times
    @AppStorage("dailyReminderTime") private var dailyReminderTimeInterval: Double = 72000 // 8:00 PM default
    @AppStorage("bedtimeReminderTime") private var bedtimeReminderTimeInterval: Double = 79200 // 10:00 PM default
    @AppStorage("dailyReminderEnabledStorage") private var storedDailyReminderEnabled = false
    @AppStorage("bedtimeReminderEnabledStorage") private var storedBedtimeReminderEnabled = false
    @AppStorage("streakNotificationsEnabledStorage") private var storedStreakNotificationsEnabled = false
    @AppStorage("newContentNotificationsEnabledStorage") private var storedNewContentNotificationsEnabled = false
    @AppStorage("aiCheckInEnabledStorage") private var storedAICheckInEnabled = false

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
        aiCheckInEnabled = storedAICheckInEnabled

        Task {
            await checkAuthorizationStatus()
        }

        startObservingTimeChanges()
    }

    // MARK: - Time Zone / Clock Changes

    /// Repeating reminders are scheduled against wall-clock hour/minute. When the user
    /// crosses time zones (or the system clock changes), re-anchor the reminders so an
    /// "8:00 PM" nudge keeps firing at 8:00 PM local instead of the old zone's time.
    private func startObservingTimeChanges() {
        let reschedule: (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.rescheduleActiveReminders() }
        }
        NotificationCenter.default.addObserver(
            forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main, using: reschedule
        )
        NotificationCenter.default.addObserver(
            forName: UIApplication.significantTimeChangeNotification, object: nil, queue: .main, using: reschedule
        )
    }

    /// Re-schedule every currently-enabled repeating reminder (used after a time-zone change).
    func rescheduleActiveReminders() {
        if dailyReminderEnabled { scheduleDailyReminder() }
        if bedtimeReminderEnabled { scheduleBedtimeReminder() }
        if aiCheckInEnabled { scheduleAICheckIn() }
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

    /// Persisting setter for the streak-milestone toggle (updates both published + stored value).
    func setStreakNotifications(enabled: Bool) {
        streakNotificationsEnabled = enabled
        storedStreakNotificationsEnabled = enabled
    }

    /// Persisting setter for the new-content toggle (updates both published + stored value).
    func setNewContentNotifications(enabled: Bool) {
        newContentNotificationsEnabled = enabled
        storedNewContentNotificationsEnabled = enabled
    }

    /// Proactive daily AI coach check-in — a scheduled, agentic nudge to chat (Bevel-style).
    func setAICheckIn(enabled: Bool) {
        aiCheckInEnabled = enabled
        storedAICheckInEnabled = enabled
        if enabled {
            scheduleAICheckIn()
        } else {
            cancelNotifications(withIdentifier: "ai-checkin")
        }
    }

    private func scheduleAICheckIn() {
        cancelNotifications(withIdentifier: "ai-checkin")

        let messages = [
            String(localized: "Your coach has a check-in for you. How are you feeling tonight?"),
            String(localized: "Quick check-in: what's on your mind? I'm here to help you wind down."),
            String(localized: "Let's reflect on your day together. Tap to chat with your coach."),
            String(localized: "Time to decompress. Your AI coach is ready when you are."),
        ]

        var dateComponents = DateComponents()
        dateComponents.hour = 19
        dateComponents.minute = 30

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Your daily check-in")
        content.body = messages.randomElement() ?? String(localized: "Your coach has a check-in for you.")
        content.sound = .default
        content.categoryIdentifier = "AI_CHECKIN"

        let request = UNNotificationRequest(identifier: "ai-checkin", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
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
            String(localized: "Your evening calm awaits. Ready for 5 minutes of peace?"),
            String(localized: "Time for your daily meditation. Your mind will thank you."),
            String(localized: "The day is winding down. Let's breathe together."),
            String(localized: "Your mind called. It's asking for a few quiet minutes."),
            String(localized: "3 minutes is all it takes. Your meditation is ready."),
            String(localized: "A moment of stillness is waiting for you."),
            String(localized: "Pause. Breathe. You've earned this."),
        ]

        let components = Calendar.current.dateComponents([.hour, .minute], from: dailyReminderTime)

        var dateComponents = DateComponents()
        dateComponents.hour = components.hour
        dateComponents.minute = components.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Mindful Moments")
        content.body = messages.randomElement() ?? String(localized: "Time for a moment of calm.")
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
            String(localized: "Wind down time. A sleep story is waiting for you."),
            String(localized: "Ready for better sleep tonight?"),
            String(localized: "Your body is tired. Let's help your mind follow."),
            String(localized: "Time to drift off. Tonight's sleep story awaits."),
            String(localized: "The stars are out. Time for rest."),
        ]

        let components = Calendar.current.dateComponents([.hour, .minute], from: bedtimeReminderTime)

        var dateComponents = DateComponents()
        dateComponents.hour = components.hour
        dateComponents.minute = components.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Bedtime")
        content.body = messages.randomElement() ?? String(localized: "Time for a moment of calm.")
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
            return (String(localized: "3 Days!"), String(localized: "You're building something powerful. Keep going!"))
        case 7:
            return (String(localized: "One Week!"), String(localized: "7 days of mindfulness. You're in the top 20% of users!"))
        case 14:
            return (String(localized: "Two Weeks!"), String(localized: "14 days strong. Your mind is thanking you."))
        case 21:
            return (String(localized: "21 Days!"), String(localized: "Science says it takes 21 days to form a habit. You did it!"))
        case 30:
            return (String(localized: "30 Days!"), String(localized: "One month of meditation! You've built a lasting practice."))
        case 60:
            return (String(localized: "60 Days!"), String(localized: "Two months of daily calm. You're inspiring!"))
        case 90:
            return (String(localized: "90 Days!"), String(localized: "A quarter year of mindfulness. Incredible dedication!"))
        case 365:
            return (String(localized: "ONE YEAR!"), String(localized: "365 days of meditation. You're a true master!"))
        default:
            return (String(localized: "Streak: \(days) Days"), String(localized: "Keep the momentum going!"))
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
        content.title = String(localized: "A moment for you?")
        content.body = String(localized: "Even 3 mindful minutes counts today. And if today slips by, that's okay — your progress is safe.")
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

        // Day 4: Mid-trial engagement
        scheduleTrialDay4Notification(trialEndDate: trialEndDate)

        // 24 hours before charge: transparency reminder (reduces refund disputes / chargebacks)
        scheduleTrialChargeReminderNotification(trialEndDate: trialEndDate)

        // Day 7 Morning: Urgency (last day)
        scheduleTrialDay7MorningNotification(trialEndDate: trialEndDate)

        // Day 7 Evening: Final push
        scheduleTrialDay7EveningNotification(trialEndDate: trialEndDate)
    }

    /// Fires ~24 hours before the trial converts to a paid subscription.
    /// Apple-friendly transparency notice; research shows a pre-charge reminder cuts
    /// dispute/refund rates by 30–40% without materially hurting conversion.
    private func scheduleTrialChargeReminderNotification(trialEndDate: Date) {
        guard let reminderDate = Calendar.current.date(byAdding: .hour, value: -24, to: trialEndDate),
              reminderDate > Date() else { return }

        var dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        // Normalize to a civil hour if the computed time lands overnight.
        if let hour = dateComponents.hour, hour < 8 || hour > 21 {
            dateComponents.hour = 18
            dateComponents.minute = 0
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Your free trial ends in 24 hours")
        content.body = String(localized: "Tomorrow your subscription begins so you keep unlimited access. Manage or cancel anytime in Settings.")
        content.sound = .default
        content.categoryIdentifier = "TRIAL_CONVERSION"

        let request = UNNotificationRequest(
            identifier: "trial-charge-reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func scheduleTrialDay1Notification() {
        // Called after first meditation session
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Great first session!")
        content.body = String(localized: "You have 7 days to explore everything free. Try a Sleep Story tonight!")
        content.sound = .default
        content.categoryIdentifier = "TRIAL_CONVERSION"

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
        guard let day2 = Calendar.current.date(byAdding: .day, value: -5, to: trialEndDate) else { return }

        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: day2)
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Pro tip")
        content.body = String(localized: "The best time to meditate is right before bed. Try tonight's Sleep Story!")
        content.sound = .default
        content.categoryIdentifier = "TRIAL_CONVERSION"

        let request = UNNotificationRequest(
            identifier: "trial-day-2",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleTrialDay4Notification(trialEndDate: Date) {
        guard let day4 = Calendar.current.date(byAdding: .day, value: -3, to: trialEndDate) else { return }

        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: day4)
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Halfway through your trial!")
        content.body = String(localized: "Have you tried the AI meditation generator? Create a session just for you.")
        content.sound = .default
        content.categoryIdentifier = "TRIAL_CONVERSION"

        let request = UNNotificationRequest(
            identifier: "trial-day-4",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleTrialDay7MorningNotification(trialEndDate: Date) {
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: trialEndDate)
        dateComponents.hour = 9
        dateComponents.minute = 0

        // Don't schedule a non-repeating notification in the past — it would silently never fire.
        guard let fireDate = Calendar.current.date(from: dateComponents), fireDate > Date() else { return }

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Last day of your free trial")
        content.body = String(localized: "Lock in annual today—that's just $0.96/week.")
        content.sound = .default
        content.categoryIdentifier = "TRIAL_CONVERSION"

        let request = UNNotificationRequest(
            identifier: "trial-day-7-am",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleTrialDay7EveningNotification(trialEndDate: Date) {
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: trialEndDate)
        dateComponents.hour = 20
        dateComponents.minute = 0

        // Don't schedule a non-repeating notification in the past — it would silently never fire.
        guard let fireDate = Calendar.current.date(from: dateComponents), fireDate > Date() else { return }

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Your trial ends tonight")
        content.body = String(localized: "Don't lose access to 500+ meditations. Continue for just $0.96/week.")
        content.sound = .default
        content.categoryIdentifier = "TRIAL_CONVERSION"

        let request = UNNotificationRequest(
            identifier: "trial-day-7-pm",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func cancelTrialNotifications() {
        let identifiers = ["trial-day-1", "trial-day-2", "trial-day-4", "trial-charge-reminder", "trial-day-7-am", "trial-day-7-pm"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Win-Back (lapsed trial)

    /// A single gentle win-back a few days after a trial lapses without
    /// converting. The "winback-" identifier prefix + TRIAL_CONVERSION
    /// category route the tap to the discounted plans (AppDelegate).
    func scheduleWinBackOffer() {
        // Don't stack duplicates if this somehow runs twice.
        cancelWinBackOffer()

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(3 * 24 * 60 * 60), // 3 days after lapse
            repeats: false
        )

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Your calm space is still here")
        content.body = String(localized: "Come back and unlock everything — at a special price, just for you.")
        content.sound = .default
        content.categoryIdentifier = "TRIAL_CONVERSION"

        let request = UNNotificationRequest(
            identifier: "winback-offer",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func cancelWinBackOffer() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["winback-offer"])
    }

    // MARK: - Re-engagement Notifications

    func scheduleReengagementSequence() {
        // Day 3 of inactivity
        scheduleReengagement(days: 3, title: String(localized: "We miss you"), body: String(localized: "A few minutes of calm is waiting for you."))

        // Day 7 of inactivity
        scheduleReengagement(days: 7, title: String(localized: "It's been a week"), body: String(localized: "Your mind might need a moment of peace."))

        // Day 14 of inactivity
        scheduleReengagement(days: 14, title: String(localized: "Welcome back anytime"), body: String(localized: "Your calm space is waiting for you."))

        // Day 30 of inactivity (final message)
        scheduleReengagement(days: 30, title: String(localized: "We're here when you're ready"), body: String(localized: "Life gets busy. Your calm is waiting."))
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
