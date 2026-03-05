//
//  ThemeManager.swift
//  Meditation Sleep Mindset
//

import SwiftUI
import Combine

@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    // Local storage as fallback
    @AppStorage("selectedThemeID") private var selectedThemeIDRaw: String = PlayerThemeID.midnight.rawValue
    @AppStorage("selectedBackgroundID") private var selectedBackgroundIDRaw: String = AnimatedBackgroundID.none.rawValue

    @Published var currentTheme: PlayerTheme = .midnight
    @Published var currentBackground: AnimatedBackgroundID = .none

    // iCloud KeyValue Store keys
    private enum CloudKeys {
        static let themeID = "cloud_selectedThemeID"
        static let backgroundID = "cloud_selectedBackgroundID"
    }

    private let cloudStore = NSUbiquitousKeyValueStore.default
    private var cloudObserver: Any?

    private init() {
        loadSavedPreferences()
        setupCloudSync()
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
        }
    }

    private func loadSavedPreferences() {
        // First try to load from iCloud
        if let cloudThemeID = cloudStore.string(forKey: CloudKeys.themeID),
           let themeID = PlayerThemeID(rawValue: cloudThemeID) {
            selectedThemeIDRaw = cloudThemeID
            currentTheme = PlayerTheme.theme(for: themeID)
        } else if let themeID = PlayerThemeID(rawValue: selectedThemeIDRaw) {
            // Fall back to local storage
            currentTheme = PlayerTheme.theme(for: themeID)
            // Sync local to cloud
            cloudStore.set(selectedThemeIDRaw, forKey: CloudKeys.themeID)
        }

        if let cloudBgID = cloudStore.string(forKey: CloudKeys.backgroundID),
           let bgID = AnimatedBackgroundID(rawValue: cloudBgID) {
            selectedBackgroundIDRaw = cloudBgID
            currentBackground = bgID
        } else if let bgID = AnimatedBackgroundID(rawValue: selectedBackgroundIDRaw) {
            // Fall back to local storage
            currentBackground = bgID
            // Sync local to cloud
            cloudStore.set(selectedBackgroundIDRaw, forKey: CloudKeys.backgroundID)
        }
    }

    private func loadFromCloud() {
        if let cloudThemeID = cloudStore.string(forKey: CloudKeys.themeID),
           let themeID = PlayerThemeID(rawValue: cloudThemeID) {
            selectedThemeIDRaw = cloudThemeID
            withAnimation(.easeInOut(duration: 0.5)) {
                currentTheme = PlayerTheme.theme(for: themeID)
            }
        }

        if let cloudBgID = cloudStore.string(forKey: CloudKeys.backgroundID),
           let bgID = AnimatedBackgroundID(rawValue: cloudBgID) {
            selectedBackgroundIDRaw = cloudBgID
            withAnimation(.easeInOut(duration: 0.3)) {
                currentBackground = bgID
            }
        }
    }

    func setTheme(_ themeID: PlayerThemeID) {
        selectedThemeIDRaw = themeID.rawValue
        cloudStore.set(themeID.rawValue, forKey: CloudKeys.themeID)

        withAnimation(.easeInOut(duration: 0.5)) {
            currentTheme = PlayerTheme.theme(for: themeID)
        }
    }

    func setBackground(_ backgroundID: AnimatedBackgroundID) {
        selectedBackgroundIDRaw = backgroundID.rawValue
        cloudStore.set(backgroundID.rawValue, forKey: CloudKeys.backgroundID)

        withAnimation(.easeInOut(duration: 0.3)) {
            currentBackground = backgroundID
        }
    }
}
