//
//  AppStateManager.swift
//  Meditation Sleep Mindset
//

import Foundation
import SwiftUI
import UserNotifications
import StoreKit

@MainActor
class AppStateManager: ObservableObject {
    static let shared = AppStateManager()

    // MARK: - Published Properties
    @Published var hasRequestedNotifications: Bool
    @Published var hasCompletedOnboarding: Bool
    @Published var appOpenCount: Int
    @Published var hasShownSharePrompt: Bool
    @Published var hasShownRatingPrompt: Bool
    @Published var shouldShowShareSheet: Bool = false
    @Published var isFirstLaunch: Bool
    @Published var dailyReminderTime: Date?
    @Published var skippedNotificationsDuringOnboarding: Bool
    @Published var shouldShowNotificationPrompt: Bool = false
    @Published var freeSessionsUsed: Int
    @Published var hasPlayedVideo: Bool

    // MARK: - Reinstall Detection
    @Published var isReinstall: Bool = false

    // MARK: - Deep Linking
    @Published var pendingDeepLinkVideoID: String?

    var reminderTimeFormatted: String {
        guard let time = dailyReminderTime else { return "Not set" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }

    // MARK: - UserDefaults Keys
    private enum Keys {
        static let hasRequestedNotifications = "hasRequestedNotifications"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let appOpenCount = "appOpenCount"
        static let hasShownSharePrompt = "hasShownSharePrompt"
        static let hasShownRatingPrompt = "hasShownRatingPrompt"
        static let isFirstLaunch = "isFirstLaunch"
        static let dailyReminderTime = "dailyReminderTime"
        static let skippedNotificationsDuringOnboarding = "skippedNotificationsDuringOnboarding"
        static let freeSessionsUsed = "freeSessionsUsed"
        static let hasPlayedVideo = "hasPlayedVideo"
    }

    private init() {
        let defaults = UserDefaults.standard

        // Check if this is truly the first launch
        let hasLaunchedBefore = defaults.bool(forKey: Keys.isFirstLaunch)
        self.isFirstLaunch = !hasLaunchedBefore

        self.hasRequestedNotifications = defaults.bool(forKey: Keys.hasRequestedNotifications)
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        self.appOpenCount = defaults.integer(forKey: Keys.appOpenCount)
        self.hasShownSharePrompt = defaults.bool(forKey: Keys.hasShownSharePrompt)
        self.hasShownRatingPrompt = defaults.bool(forKey: Keys.hasShownRatingPrompt)
        self.dailyReminderTime = defaults.object(forKey: Keys.dailyReminderTime) as? Date
        self.skippedNotificationsDuringOnboarding = defaults.bool(forKey: Keys.skippedNotificationsDuringOnboarding)
        self.freeSessionsUsed = defaults.integer(forKey: Keys.freeSessionsUsed)
        self.hasPlayedVideo = defaults.bool(forKey: Keys.hasPlayedVideo)

        // Mark that we've launched before
        if isFirstLaunch {
            defaults.set(true, forKey: Keys.isFirstLaunch)
        }
    }

    // MARK: - App Open Handling
    func handleAppOpen() {
        appOpenCount += 1
        UserDefaults.standard.set(appOpenCount, forKey: Keys.appOpenCount)

        // Check engagement triggers
        checkEngagementTriggers()
    }

    private func checkEngagementTriggers() {
        // On 2nd app open, show notification prompt if user skipped during onboarding
        if appOpenCount == 2 && skippedNotificationsDuringOnboarding && !hasRequestedNotifications {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.shouldShowNotificationPrompt = true
            }
        }

        // Rating and share prompts are triggered by session completion milestones only.
        // See onSessionCompleted() for the strategy.
    }

    // MARK: - Notification Permission
    func requestNotificationPermission() async -> Bool {
        guard !hasRequestedNotifications else { return true }

        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])

            hasRequestedNotifications = true
            UserDefaults.standard.set(true, forKey: Keys.hasRequestedNotifications)

            return granted
        } catch {
            #if DEBUG
            print("Notification permission error: \(error)")
            #endif
            return false
        }
    }

    // MARK: - Schedule Daily Reminder
    func scheduleDailyReminder(at time: Date) async {
        let center = UNUserNotificationCenter.current()

        // Save the reminder time
        dailyReminderTime = time
        UserDefaults.standard.set(time, forKey: Keys.dailyReminderTime)

        // Remove existing reminders
        center.removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])

        let content = UNMutableNotificationContent()
        content.title = "Time to Meditate"
        content.body = "Take a moment to find your calm today."
        content.sound = .default

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: "dailyReminder",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            #if DEBUG
            print("Daily reminder scheduled for \(components.hour ?? 0):\(components.minute ?? 0)")
            #endif
        } catch {
            #if DEBUG
            print("Failed to schedule reminder: \(error)")
            #endif
        }
    }

    // MARK: - Rating & Share
    func requestAppRating() {
        guard !hasShownRatingPrompt else { return }

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
            hasShownRatingPrompt = true
            UserDefaults.standard.set(true, forKey: Keys.hasShownRatingPrompt)
        }
    }

    func markSharePromptShown() {
        hasShownSharePrompt = true
        shouldShowShareSheet = false
        UserDefaults.standard.set(true, forKey: Keys.hasShownSharePrompt)
    }

    // MARK: - Onboarding
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: Keys.hasCompletedOnboarding)
    }

    /// Mark that user skipped notifications during onboarding (to prompt on 2nd app open)
    func markSkippedNotificationsDuringOnboarding() {
        skippedNotificationsDuringOnboarding = true
        UserDefaults.standard.set(true, forKey: Keys.skippedNotificationsDuringOnboarding)
    }

    /// Mark that notification prompt was handled (either accepted or dismissed on 2nd open)
    func markNotificationPromptHandled() {
        shouldShowNotificationPrompt = false
        hasRequestedNotifications = true
        UserDefaults.standard.set(true, forKey: Keys.hasRequestedNotifications)
    }

    /// Reset onboarding to show it again (for testing)
    func resetOnboarding() {
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: Keys.hasCompletedOnboarding)
    }

    // MARK: - Free Session Tracking

    var hasReachedFreeSessionLimit: Bool {
        #if DEBUG
        return false
        #else
        return freeSessionsUsed >= Constants.Engagement.freeSessionLimit
        #endif
    }

    func recordFreeSessionUsed() {
        freeSessionsUsed += 1
        UserDefaults.standard.set(freeSessionsUsed, forKey: Keys.freeSessionsUsed)
    }

    /// Reset free session counter (for testing)
    func resetFreeSessionCount() {
        freeSessionsUsed = 0
        UserDefaults.standard.set(0, forKey: Keys.freeSessionsUsed)
    }

    func recordVideoPlayed() {
        guard !hasPlayedVideo else { return }
        hasPlayedVideo = true
        UserDefaults.standard.set(true, forKey: Keys.hasPlayedVideo)
        AppsFlyerService.shared.logTutorialCompletion()
    }

    // MARK: - Session Completed Trigger
    /// Call after a user completes a meditation session (80%+ listened).
    /// Engagement prompts are staggered by session count:
    ///  - 5th session → Share prompt (user has enough experience to recommend)
    ///  - 8th session → Rating prompt via SKStoreReviewController
    func onSessionCompleted() {
        let completedKey = "totalCompletedSessions"
        let count = UserDefaults.standard.integer(forKey: completedKey) + 1
        UserDefaults.standard.set(count, forKey: completedKey)

        // After 5th completed session, show share prompt
        if count == 5 && !hasShownSharePrompt {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self, !self.hasShownSharePrompt else { return }
                self.shouldShowShareSheet = true
            }
        }

        // After 8th completed session, request App Store rating
        if count == 8 && !hasShownRatingPrompt {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.requestAppRating()
            }
        }

        // Check if we should prompt for account sign-in
        AccountService.shared.checkSessionMilestone(sessions: count)
    }

    // MARK: - Favorite Content Trigger
    func onContentFavorited() {
        // Favoriting is a lightweight action — no engagement popups.
        // Share and rating prompts are tied to session milestones only.
    }

    // MARK: - Reinstall Detection

    /// Called by AppDelegate when Keychain indicates a reinstall.
    /// Restores onboarding/subscription state so AppsFlyer doesn't misattribute returning users.
    func markAsReinstall() {
        isReinstall = true
        // Skip onboarding for reinstalls — they've already completed it
        if !hasCompletedOnboarding {
            hasCompletedOnboarding = true
            UserDefaults.standard.set(true, forKey: Keys.hasCompletedOnboarding)
        }
        #if DEBUG
        print("[AppStateManager] Reinstall detected — skipping onboarding")
        #endif
    }

    // MARK: - Deep Link Handling
    /// Handle incoming deep link URL
    /// - Parameter url: The deep link URL (e.g., meditation://content/VIDEO_ID)
    /// - Returns: true if the URL was handled successfully
    @discardableResult
    func handleDeepLink(_ url: URL) -> Bool {
        guard url.scheme == "meditation" else { return false }

        // Parse the URL path: meditation://content/VIDEO_ID
        if url.host == "content" {
            let videoID = url.lastPathComponent
            if !videoID.isEmpty && videoID != "content" {
                #if DEBUG
                print("[DeepLink] Opening content with video ID: \(videoID)")
                #endif
                pendingDeepLinkVideoID = videoID
                return true
            }
        }

        // Handle player control deep links from Live Activity
        if url.host == "player" {
            let action = url.lastPathComponent
            let playerManager = AudioPlayerManager.shared

            switch action {
            case "toggle":
                playerManager.togglePlayPause()
                #if DEBUG
                print("[DeepLink] Toggle play/pause")
                #endif
                return true
            case "skipForward":
                playerManager.skipForward(seconds: 15)
                #if DEBUG
                print("[DeepLink] Skip forward 15s")
                #endif
                return true
            case "skipBack":
                playerManager.skipBackward(seconds: 15)
                #if DEBUG
                print("[DeepLink] Skip backward 15s")
                #endif
                return true
            default:
                break
            }
        }

        return false
    }

    /// Clear the pending deep link after it has been handled
    func clearPendingDeepLink() {
        pendingDeepLinkVideoID = nil
    }
}
