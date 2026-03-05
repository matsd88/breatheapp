//
//  SmartRatingManager.swift
//  Meditation Sleep Mindset
//

import Foundation
import StoreKit
import UIKit

enum RatingTrigger {
    case streakMilestone(days: Int)
    case badgeEarned
    case challengeCompleted
    case sessionCompletedWithPositiveMood
}

@MainActor
class SmartRatingManager {
    static let shared = SmartRatingManager()

    private enum Keys {
        static let lastPromptDate = "smartRating_lastPromptDate"
        static let lifetimePromptCount = "smartRating_lifetimePromptCount"
        static let lastPaywallDismissDate = "smartRating_lastPaywallDismissDate"
    }

    private let maxLifetimePrompts = 3
    private let cooldownDays = 30
    private let minimumSessions = 5
    private let delayAfterCelebration: TimeInterval = 2.0
    private let paywallDismissCooldownHours: TimeInterval = 24

    private var lastPromptDate: Date? {
        get { UserDefaults.standard.object(forKey: Keys.lastPromptDate) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Keys.lastPromptDate) }
    }

    private var lifetimePromptCount: Int {
        get { UserDefaults.standard.integer(forKey: Keys.lifetimePromptCount) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.lifetimePromptCount) }
    }

    private init() {}

    /// Record that a paywall was dismissed (called from paywall views)
    static func recordPaywallDismiss() {
        UserDefaults.standard.set(Date(), forKey: Keys.lastPaywallDismissDate)
    }

    func checkAndPromptIfAppropriate(trigger: RatingTrigger) {
        // Rule 1: Never exceed lifetime cap
        guard lifetimePromptCount < maxLifetimePrompts else { return }

        // Rule 2: Respect cooldown period
        if let lastDate = lastPromptDate {
            let daysSinceLastPrompt = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
            guard daysSinceLastPrompt >= cooldownDays else { return }
        }

        // Rule 3: User must have enough sessions
        let totalSessions = UserDefaults.standard.integer(forKey: "totalCompletedSessions")
        guard totalSessions >= minimumSessions else { return }

        // Rule 4: Don't prompt if user dismissed a paywall in the last 24 hours
        if let lastPaywallDismiss = UserDefaults.standard.object(forKey: Keys.lastPaywallDismissDate) as? Date {
            let hoursSinceDismiss = Date().timeIntervalSince(lastPaywallDismiss) / 3600
            guard hoursSinceDismiss >= paywallDismissCooldownHours else { return }
        }

        // Rule 5: Delay after celebration animation, then prompt
        DispatchQueue.main.asyncAfter(deadline: .now() + delayAfterCelebration) { [weak self] in
            self?.requestReview()
        }
    }

    private func requestReview() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }

        SKStoreReviewController.requestReview(in: windowScene)
        lastPromptDate = Date()
        lifetimePromptCount += 1

        #if DEBUG
        print("[SmartRatingManager] Rating prompt shown (count: \(lifetimePromptCount))")
        #endif
    }
}
