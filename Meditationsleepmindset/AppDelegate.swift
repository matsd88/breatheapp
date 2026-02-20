//
//  AppDelegate.swift
//  Meditation Sleep Mindset
//

import UIKit
import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
import FirebaseCrashlytics
#endif
#if canImport(AppsFlyerLib)
import AppsFlyerLib
#endif

class AppDelegate: NSObject, UIApplicationDelegate {

    /// Controls whether landscape is allowed. Only the player sets this to true.
    static var allowLandscape = false

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        if AppDelegate.allowLandscape {
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
    static let dismissAllSheetsAndPlay = Notification.Name("dismissAllSheetsAndPlay")
}
