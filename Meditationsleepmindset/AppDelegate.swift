//
//  AppDelegate.swift
//  Meditation Sleep Mindset
//

import UIKit
import SwiftUI
import UserNotifications
#if canImport(FirebaseCore)
import FirebaseCore
import FirebaseCrashlytics
#endif
#if canImport(AppsFlyerLib)
import AppsFlyerLib
#endif

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    /// Controls whether landscape is allowed. Only the player sets this to true.
    static var allowLandscape = false

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        if AppDelegate.allowLandscape {
            return .allButUpsideDown
        }
        // iPad should support all orientations; only lock portrait on iPhone
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .allButUpsideDown
        }
        return .portrait
    }

    // MARK: - Quick Actions
    enum QuickAction: String {
        case browseMeditation = "BrowseMeditationAction"
        case unguidedTimer = "UnguidedTimerAction"
        case openSleep = "OpenSleepAction"
        case openDiscover = "OpenDiscoverAction"
        case openChat = "OpenChatAction"

        var shortcutItem: UIApplicationShortcutItem {
            switch self {
            case .browseMeditation:
                return UIApplicationShortcutItem(
                    type: rawValue,
                    localizedTitle: "Meditate",
                    localizedSubtitle: "Browse meditation content",
                    icon: UIApplicationShortcutIcon(systemImageName: "brain.head.profile"),
                    userInfo: nil
                )
            case .unguidedTimer:
                return UIApplicationShortcutItem(
                    type: rawValue,
                    localizedTitle: "Unguided Timer",
                    localizedSubtitle: "Meditate in silence or with sound",
                    icon: UIApplicationShortcutIcon(systemImageName: "timer"),
                    userInfo: nil
                )
            case .openSleep:
                return UIApplicationShortcutItem(
                    type: rawValue,
                    localizedTitle: "Sleep",
                    localizedSubtitle: "Sleep stories & sounds",
                    icon: UIApplicationShortcutIcon(systemImageName: "moon.stars.fill"),
                    userInfo: nil
                )
            case .openDiscover:
                return UIApplicationShortcutItem(
                    type: rawValue,
                    localizedTitle: "Discover",
                    localizedSubtitle: "Browse all content",
                    icon: UIApplicationShortcutIcon(systemImageName: "magnifyingglass"),
                    userInfo: nil
                )
            case .openChat:
                return UIApplicationShortcutItem(
                    type: rawValue,
                    localizedTitle: "Chat",
                    localizedSubtitle: "Talk to Breathe AI",
                    icon: UIApplicationShortcutIcon(systemImageName: "bubble.left.and.text.bubble.right"),
                    userInfo: nil
                )
            }
        }
    }

    // Track which quick action was triggered
    static var pendingQuickAction: QuickAction?

    // MARK: - Notification Action Routes
    /// One-tap actions attached to reminder notifications.
    enum NotificationActionRoute: String {
        case startQuickSession = "START_QUICK_SESSION"
        case playSleepStory = "PLAY_SLEEP_STORY"
        case openAIChat = "OPEN_AI_CHAT"
    }

    /// Set when a notification action is tapped from a cold launch; consumed by RootView.
    static var pendingNotificationAction: NotificationActionRoute?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Detect reinstall via Keychain (survives uninstall, unlike UserDefaults)
        let isReinstall = KeychainService.checkAndMarkInstall()
        if isReinstall {
            AppStateManager.shared.markAsReinstall()
        }

        // Configure AppsFlyer (attribution tracking) — before Firebase
        AppsFlyerService.shared.configure()

        // Configure Firebase (Crashlytics + Analytics)
        FirebaseService.shared.configure()

        // Notification delegate + actionable categories (e.g. alarm snooze)
        configureNotifications()

        // Update quick actions based on subscription status
        updateQuickActions()

        // Handle quick action if app was launched from one
        if let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            handleQuickAction(shortcutItem)
        }

        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    // MARK: - Update Quick Actions
    func updateQuickActions() {
        Task { @MainActor in
            let shortcuts: [UIApplicationShortcutItem] = [
                QuickAction.browseMeditation.shortcutItem,
                QuickAction.unguidedTimer.shortcutItem,
                QuickAction.openSleep.shortcutItem,
                QuickAction.openDiscover.shortcutItem,
                QuickAction.openChat.shortcutItem
            ]

            UIApplication.shared.shortcutItems = shortcuts
        }
    }

    // MARK: - AppsFlyer Deep Link Attribution

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
        #endif
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().handleOpen(url, options: options)
        #endif
        return true
    }

    // MARK: - Notifications

    private func configureNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // Alarm category with a working Snooze action (previously the snooze toggle was dead UI).
        let snooze = UNNotificationAction(identifier: "SNOOZE_ALARM", title: "Snooze", options: [])
        let stop = UNNotificationAction(identifier: "STOP_ALARM", title: "I'm awake", options: [.foreground])
        let alarmCategory = UNNotificationCategory(
            identifier: "ALARM",
            actions: [snooze, stop],
            intentIdentifiers: [],
            options: []
        )

        // One-tap actions turn passive reminders into action: a daily nudge becomes
        // "Start a session", a bedtime nudge becomes "Play a sleep story", etc.
        let startSession = UNNotificationAction(
            identifier: NotificationActionRoute.startQuickSession.rawValue,
            title: "Start a session",
            options: [.foreground]
        )
        let playSleep = UNNotificationAction(
            identifier: NotificationActionRoute.playSleepStory.rawValue,
            title: "Play a sleep story",
            options: [.foreground]
        )
        let openChat = UNNotificationAction(
            identifier: NotificationActionRoute.openAIChat.rawValue,
            title: "Chat now",
            options: [.foreground]
        )

        // Trial-conversion + win-back notifications route to the paywall so a
        // tapped "your trial ends tonight" actually lands on plans, not a cold
        // home screen. Body taps are handled by identifier in didReceive too.
        let seePlans = UNNotificationAction(
            identifier: "OPEN_PREMIUM",
            title: "See plans",
            options: [.foreground]
        )

        let dailyReminder = UNNotificationCategory(identifier: "DAILY_REMINDER", actions: [startSession], intentIdentifiers: [], options: [])
        let streakAtRisk = UNNotificationCategory(identifier: "STREAK_AT_RISK", actions: [startSession], intentIdentifiers: [], options: [])
        let reEngagement = UNNotificationCategory(identifier: "RE_ENGAGEMENT", actions: [startSession], intentIdentifiers: [], options: [])
        let bedtimeReminder = UNNotificationCategory(identifier: "BEDTIME_REMINDER", actions: [playSleep], intentIdentifiers: [], options: [])
        let aiCheckIn = UNNotificationCategory(identifier: "AI_CHECKIN", actions: [openChat], intentIdentifiers: [], options: [])
        let trialConversion = UNNotificationCategory(identifier: "TRIAL_CONVERSION", actions: [seePlans], intentIdentifiers: [], options: [])

        center.setNotificationCategories([
            alarmCategory, dailyReminder, streakAtRisk, reEngagement, bedtimeReminder, aiCheckIn, trialConversion
        ])
    }

    /// Handle notification action taps (e.g. "Snooze" on the alarm, "Start a session" on a reminder).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let notifID = response.notification.request.identifier
        let isPremiumBound = notifID.hasPrefix("trial-") || notifID.hasPrefix("winback-")

        if response.actionIdentifier == "SNOOZE_ALARM" {
            Task { @MainActor in
                AlarmService.shared.snooze()
            }
        } else if response.actionIdentifier == "OPEN_PREMIUM"
                    || (response.actionIdentifier == UNNotificationDefaultActionIdentifier && isPremiumBound) {
            // Tapping a trial/win-back notification (button OR body) opens the
            // paywall. navigate() is consumed by RootView (onChange when warm,
            // onAppear when cold-launched).
            Task { @MainActor in
                AppStateManager.shared.navigate(to: .premium)
            }
        } else if let route = NotificationActionRoute(rawValue: response.actionIdentifier) {
            // Cache for cold launch, then post for a running app to handle.
            AppDelegate.pendingNotificationAction = route
            NotificationCenter.default.post(
                name: .notificationActionTriggered,
                object: nil,
                userInfo: ["route": route]
            )
        }
        completionHandler()
    }

    // MARK: - Handle Quick Action
    func handleQuickAction(_ shortcutItem: UIApplicationShortcutItem) {
        guard let action = QuickAction(rawValue: shortcutItem.type) else { return }
        AppDelegate.pendingQuickAction = action

        // Post notification for the app to handle
        NotificationCenter.default.post(
            name: .quickActionTriggered,
            object: nil,
            userInfo: ["action": action]
        )
    }
}

// MARK: - Scene Delegate
class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            completionHandler(false)
            return
        }
        appDelegate.handleQuickAction(shortcutItem)
        completionHandler(true)
    }
}

// MARK: - Notification Name
extension Notification.Name {
    static let quickActionTriggered = Notification.Name("quickActionTriggered")
    static let notificationActionTriggered = Notification.Name("notificationActionTriggered")
    static let dismissAllSheetsAndPlay = Notification.Name("dismissAllSheetsAndPlay")
}
