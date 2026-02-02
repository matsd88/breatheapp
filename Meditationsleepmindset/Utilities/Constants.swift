//
//  Constants.swift
//  Meditation Sleep Mindset
//

import Foundation

enum Constants {
    // MARK: - Curator Mode
    // Set to true for your personal builds to enable YouTube search/add content
    // Set to false for App Store builds
    static let isCuratorMode = false

    // MARK: - App Store
    enum AppStore {
        static let appID = "6758229420"
        static let shareURL = URL(string: "https://apps.apple.com/app/id\(appID)")!
        static let reviewURL = URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review")!
    }

    // MARK: - Support
    enum Support {
        static let email = "matsdegerstedt@gmail.com"
        static let privacyURL = URL(string: "https://meditationandsleepapp.com/privacy")!
        static let termsURL = URL(string: "https://meditationandsleepapp.com/terms")!
        static let helpURL = URL(string: "https://meditationandsleepapp.com")!
    }

    // MARK: - Subscription Product IDs
    enum Subscriptions {
        static let weeklyID = "com.meditation.weekly"
        static let monthlyID = "com.meditation.monthly"
        static let annualID = "com.meditation.annual"
        static let annualDiscountedID = "com.meditation.annual.discounted"
    }

    // MARK: - User Defaults Keys
    enum UserDefaultsKeys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let appOpenCount = "appOpenCount"
        static let lastOpenDate = "lastOpenDate"
        static let selectedTheme = "selectedTheme"
        static let notificationsEnabled = "notificationsEnabled"
        static let reminderTime = "reminderTime"
        static let preferredPlaybackSpeed = "preferredPlaybackSpeed"
        static let autoPlayNextContent = "autoPlayNextContent"
        static let downloadOverCellular = "downloadOverCellular"
        static let showMoodCheckIn = "showMoodCheckIn"
        static let chatMessagesSentCount = "chatMessagesSentCount"
    }

    // MARK: - Engagement Thresholds
    enum Engagement {
        static let sharePromptOpenCount = 2
        static let ratingPromptOpenCount = 3
        static let ratingPromptMinSessions = 5
        static let freeSessionLimit = 3
    }

    // MARK: - Timer Presets
    enum TimerPresets {
        static let quickSession = 5 * 60 // 5 minutes
        static let shortSession = 10 * 60 // 10 minutes
        static let mediumSession = 15 * 60 // 15 minutes
        static let longSession = 20 * 60 // 20 minutes
        static let extendedSession = 30 * 60 // 30 minutes

        static let sleepTimerOptions = [15, 30, 45, 60, 90, 120] // minutes
    }

    // MARK: - Animation Durations
    enum Animation {
        static let quick: Double = 0.2
        static let standard: Double = 0.3
        static let slow: Double = 0.5
    }

    // MARK: - UI
    enum UI {
        static let scrollToTopThreshold = 19 // Show scroll-to-top button after this many items
    }

    // MARK: - Content Health (Dead Video Detection & Remote Replacement)
    enum ContentHealth {
        // Set to your GitHub Gist raw URL to enable remote dead video replacement
        static let manifestURL = ""
        static let cacheDuration: TimeInterval = 86400 // Re-fetch manifest every 24 hours
        static let failureThreshold = 3 // Failures before marking a video as dead
    }

    // MARK: - Cache
    enum Cache {
        static let streamURLExpirySeconds: TimeInterval = 2 * 60 * 60 // 2 hours
        static let thumbnailCacheSize = 100 // Number of thumbnails to cache
    }

    // MARK: - Streaming & Playback
    enum Streaming {
        static let preferredBufferDuration: Double = 2.0 // Seconds to buffer ahead
        static let playbackUpdateInterval: Double = 0.5 // How often to update time display
        static let networkTimeoutSeconds: UInt64 = 10 // Timeout for stream extraction
    }

    // MARK: - Session Tracking
    enum Session {
        static let minimumListenTimeForRecord: TimeInterval = 30 // Minimum seconds to count as session
        static let completionThreshold: Double = 0.8 // 80% completion counts as finished
    }

    // MARK: - Streaks
    enum Streaks {
        static let minimumStreakForNotification = 2
        static let milestones = [3, 7, 14, 21, 30, 60, 90, 365]
    }

    // MARK: - Recommendations
    enum Recommendations {
        static let maxResults = 6 // Number of recommendations to show
        static let poolSize = 15 // Top scored items to shuffle from
        static let goalTagScore = 4 // Points for matching user goal tags
        static let goalTypeScore = 5 // Points for matching user goal content type
        static let timeTypeScore = 3 // Points for time-appropriate content type
        static let timeTagScore = 2 // Points for time-appropriate tags
        static let profileGoalScore = 1 // Points for legacy profile goals
    }

    // MARK: - Chat
    enum Chat {
        static let freeMessageLimit = 10
        static let proxyBaseURL = "https://winter-hill-e14c.matsdegerstedt.workers.dev"
        static let maxTokens = 500
        static let modelName = "gpt-4o-mini"
        static let maxConversationHistory = 20
        static let historyRetentionDaysPremium = 30
        static let historyRetentionDaysFree = 0
        static let therapistReferralURL = "https://www.betterhelp.com/?utm_source=meditationapp"
    }

    // MARK: - Crisis Resources
    enum CrisisResources {
        static let suicidePreventionHotline = "988"
        static let crisisTextLine = "741741"
        static let emergencyNumber = "911"
        static let findHelpURL = "https://findahelpline.com/"
    }
}
