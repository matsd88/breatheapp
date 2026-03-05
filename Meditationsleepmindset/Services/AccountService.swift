//
//  AccountService.swift
//  Meditation Sleep Mindset
//

import Foundation
import AuthenticationServices
import SwiftUI

@MainActor
class AccountService: NSObject, ObservableObject {
    static let shared = AccountService()

    // MARK: - Published State
    @Published var isSignedIn: Bool = false
    @Published var userDisplayName: String?
    @Published var userEmail: String?
    @Published var shouldShowSignInSheet: Bool = false
    @Published var signInReason: SignInReason = .manual

    // MARK: - Sign-In Reason
    enum SignInReason {
        case streak
        case sessions
        case multiDevice
        case favorites
        case manual

        var title: String {
            switch self {
            case .streak: return String(localized: "Protect Your Streak")
            case .sessions: return String(localized: "Save Your Progress")
            case .multiDevice: return String(localized: "Sync Your Journey")
            case .favorites: return String(localized: "Save Your Favorites")
            case .manual: return String(localized: "Sign In")
            }
        }

        var subtitle: String {
            switch self {
            case .streak: return String(localized: "Keep your streak safe across all your devices")
            case .sessions: return String(localized: "Never lose your meditation history and favorites")
            case .multiDevice: return String(localized: "Pick up right where you left off on any device")
            case .favorites: return String(localized: "Sign in to keep your favorites safe across devices")
            case .manual: return String(localized: "Sync your data across all your Apple devices")
            }
        }

        var iconName: String {
            switch self {
            case .streak: return "flame.fill"
            case .sessions: return "figure.mind.and.body"
            case .multiDevice: return "iphone.and.ipad"
            case .favorites: return "heart.fill"
            case .manual: return "person.crop.circle"
            }
        }
    }

    // MARK: - Persistence Keys
    private enum Keys {
        static let appleUserID = "account_appleUserID"
        static let userName = "account_userName"
        static let userEmail = "account_userEmail"
        static let lastPromptDate = "account_lastPromptDate"
        static let promptDismissCount = "account_promptDismissCount"
        static let hasShownStreakPrompt = "account_hasShownStreakPrompt"
        static let hasShownSessionPrompt = "account_hasShownSessionPrompt"
        static let hasShownFavoritesPrompt = "account_hasShownFavoritesPrompt"
        static let deviceUUID = "account_deviceUUID"
        static let hasMigratedToCloudKit = "account_hasMigratedToCloudKit"
    }

    // MARK: - Private State
    private let defaults = UserDefaults.standard
    private let cloudStore = NSUbiquitousKeyValueStore.default

    private override init() {
        super.init()
        loadPersistedState()
    }

    // MARK: - Load Persisted State
    private func loadPersistedState() {
        let storedUserID = defaults.string(forKey: Keys.appleUserID)
        userDisplayName = defaults.string(forKey: Keys.userName)
        userEmail = defaults.string(forKey: Keys.userEmail)

        if let userID = storedUserID, !userID.isEmpty {
            isSignedIn = true
            // Verify credential is still valid
            checkCredentialState(userID: userID)
        }

        // Ensure this device has a UUID for multi-device detection
        ensureDeviceUUID()
    }

    // MARK: - Credential Verification
    func checkCredentialState(userID: String? = nil) {
        guard let uid = userID ?? defaults.string(forKey: Keys.appleUserID) else { return }

        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: uid) { [weak self] state, _ in
            Task { @MainActor in
                switch state {
                case .authorized:
                    self?.isSignedIn = true
                case .revoked, .notFound:
                    // User revoked access or account not found — sign out locally
                    self?.signOut()
                default:
                    break
                }
            }
        }
    }

    // MARK: - Handle Sign-In Result
    func handleSignIn(result: ASAuthorization) {
        guard let credential = result.credential as? ASAuthorizationAppleIDCredential else { return }

        let userID = credential.user

        // Persist Apple User ID
        defaults.set(userID, forKey: Keys.appleUserID)

        // Apple only provides name/email on the VERY FIRST sign-in
        // We must persist them immediately
        if let fullName = credential.fullName {
            let name = [fullName.givenName, fullName.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            if !name.isEmpty {
                defaults.set(name, forKey: Keys.userName)
                userDisplayName = name
            }
        }

        if let email = credential.email {
            defaults.set(email, forKey: Keys.userEmail)
            userEmail = email
        }

        // Load any previously stored name/email if Apple didn't provide them this time
        if userDisplayName == nil {
            userDisplayName = defaults.string(forKey: Keys.userName)
        }
        if userEmail == nil {
            userEmail = defaults.string(forKey: Keys.userEmail)
        }

        isSignedIn = true
        shouldShowSignInSheet = false

        // Trigger initial CloudKit sync
        Task {
            await CloudKitSyncService.shared.migrateAndSync()
        }

        // Refresh subscription status (VIP email bypass takes effect after sign-in)
        Task {
            await StoreManager.shared.refreshSubscriptionStatus()
        }

        HapticManager.success()
    }

    // MARK: - Sign Out
    func signOut() {
        defaults.removeObject(forKey: Keys.appleUserID)
        // Keep name/email in case they sign back in (Apple won't provide them again)
        isSignedIn = false
        shouldShowSignInSheet = false
    }

    // MARK: - Delete Account
    func deleteAccount() async {
        // Delete cloud data first
        if isSignedIn {
            await CloudKitSyncService.shared.deleteAllCloudData()
        }

        // Clear all account-related data
        defaults.removeObject(forKey: Keys.appleUserID)
        defaults.removeObject(forKey: Keys.userName)
        defaults.removeObject(forKey: Keys.userEmail)
        defaults.removeObject(forKey: Keys.lastPromptDate)
        defaults.removeObject(forKey: Keys.promptDismissCount)
        defaults.removeObject(forKey: Keys.hasShownStreakPrompt)
        defaults.removeObject(forKey: Keys.hasShownSessionPrompt)
        defaults.removeObject(forKey: Keys.hasShownFavoritesPrompt)
        defaults.removeObject(forKey: Keys.hasMigratedToCloudKit)

        userDisplayName = nil
        userEmail = nil
        isSignedIn = false
        shouldShowSignInSheet = false
    }

    // MARK: - Smart Prompt Logic

    /// Called after streak is updated in StreakService
    func checkStreakMilestone(streak: Int) {
        guard !isSignedIn else { return }
        guard streak >= Constants.Account.streakMilestoneForPrompt else { return }
        guard !defaults.bool(forKey: Keys.hasShownStreakPrompt) else { return }
        guard shouldShowPrompt() else { return }

        defaults.set(true, forKey: Keys.hasShownStreakPrompt)
        signInReason = .streak
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.shouldShowSignInSheet = true
        }
    }

    /// Called after a session is completed in AppStateManager
    func checkSessionMilestone(sessions: Int) {
        guard !isSignedIn else { return }
        guard sessions >= Constants.Account.sessionMilestoneForPrompt else { return }
        guard !defaults.bool(forKey: Keys.hasShownSessionPrompt) else { return }
        guard shouldShowPrompt() else { return }

        defaults.set(true, forKey: Keys.hasShownSessionPrompt)
        signInReason = .sessions
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.shouldShowSignInSheet = true
        }
    }

    /// Called when the user favorites content; triggers sign-in prompt at milestone
    func checkFavoriteMilestone(count: Int) {
        guard !isSignedIn else { return }
        guard count >= Constants.Account.favoriteMilestoneForPrompt else { return }
        guard !defaults.bool(forKey: Keys.hasShownFavoritesPrompt) else { return }
        guard shouldShowPrompt() else { return }

        defaults.set(true, forKey: Keys.hasShownFavoritesPrompt)
        signInReason = .favorites
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.shouldShowSignInSheet = true
        }
    }

    /// Check if another device has been detected via iCloud KVS
    func checkSecondDevice() {
        guard !isSignedIn else { return }

        let myUUID = getDeviceUUID()
        let cloudDeviceKey = "account_knownDeviceUUID"

        let cloudUUID = cloudStore.string(forKey: cloudDeviceKey)

        if let cloudUUID = cloudUUID, cloudUUID != myUUID {
            // Another device exists — prompt for sign-in
            guard shouldShowPrompt() else { return }
            signInReason = .multiDevice
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.shouldShowSignInSheet = true
            }
        } else {
            // Store our UUID so other devices can detect us
            cloudStore.set(myUUID, forKey: cloudDeviceKey)
        }
    }

    /// Rate limiting: max 1 prompt per cooldown period, max total dismissals
    private func shouldShowPrompt() -> Bool {
        let dismissCount = defaults.integer(forKey: Keys.promptDismissCount)
        guard dismissCount < Constants.Account.maxPromptDismissals else { return false }

        if let lastPromptDate = defaults.object(forKey: Keys.lastPromptDate) as? Date {
            let daysSinceLastPrompt = Calendar.current.dateComponents([.day], from: lastPromptDate, to: Date()).day ?? 0
            guard daysSinceLastPrompt >= Constants.Account.promptCooldownDays else { return false }
        }

        return true
    }

    /// Called when user dismisses the sign-in sheet without signing in
    func recordPromptDismissed() {
        let count = defaults.integer(forKey: Keys.promptDismissCount) + 1
        defaults.set(count, forKey: Keys.promptDismissCount)
        defaults.set(Date(), forKey: Keys.lastPromptDate)
    }

    /// Manually trigger sign-in from Settings
    func showManualSignIn() {
        signInReason = .manual
        shouldShowSignInSheet = true
    }

    // MARK: - Device UUID
    private func ensureDeviceUUID() {
        if defaults.string(forKey: Keys.deviceUUID) == nil {
            defaults.set(UUID().uuidString, forKey: Keys.deviceUUID)
        }
    }

    private func getDeviceUUID() -> String {
        defaults.string(forKey: Keys.deviceUUID) ?? UUID().uuidString
    }

    // MARK: - Migration State
    var hasMigratedToCloudKit: Bool {
        get { defaults.bool(forKey: Keys.hasMigratedToCloudKit) }
        set { defaults.set(newValue, forKey: Keys.hasMigratedToCloudKit) }
    }
}
