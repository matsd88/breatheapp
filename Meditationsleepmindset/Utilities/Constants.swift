//
//  Constants.swift
//  Meditation Sleep Mindset
//

import Foundation

enum Constants {
    // MARK: - Demo Mode
    // Set to true for App Store screenshots with fake user data
    // Set to false for App Store and normal builds
    static let isDemoMode = false

    // MARK: - Curator Mode
    // Set to true for your personal builds to enable YouTube search/add content
    // Set to false for App Store builds
    static let isCuratorMode = false

    // MARK: - App Store
    enum AppStore {
        static let appID = "6758229420"
        // Safe URL creation with fallback (these hardcoded URLs should never fail)
        static let shareURL: URL = URL(string: "https://apps.apple.com/app/id\(appID)") ?? URL(string: "https://apps.apple.com")!
        static let reviewURL: URL = URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review") ?? URL(string: "https://apps.apple.com")!
    }

    // MARK: - Support
    enum Support {
        static let email = "matsdegerstedt@gmail.com"
        // Safe URL creation with fallback
        static let privacyURL: URL = URL(string: "https://meditationandsleepapp.com/privacy") ?? URL(string: "https://meditationandsleepapp.com")!
        static let termsURL: URL = URL(string: "https://meditationandsleepapp.com/terms") ?? URL(string: "https://meditationandsleepapp.com")!
        static let helpURL: URL = URL(string: "https://meditationandsleepapp.com") ?? URL(string: "https://apple.com")!
    }

    // MARK: - Subscription Product IDs
    enum Subscriptions {
        static let weeklyID = "WeeklySubscription"
        static let monthlyID = "MonthlySubscription"
        static let annualID = "AnnualSubscription"
        static let annualDiscountedID = "AnnualSubscription"
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

    // MARK: - Analytics Keys (Trial Tracking)
    enum AnalyticsKeys {
        static let trialStartDate = "analyticsTrialStartDate"
        static let trialProductID = "analyticsTrialProductID"
        static let trialOriginalTransactionID = "analyticsTrialOriginalTransactionID"
        static let trialConvertedLogged = "analyticsTrialConvertedLogged"
    }

    // MARK: - Engagement Thresholds
    enum Engagement {
        static let sharePromptOpenCount = 2
        static let ratingPromptOpenCount = 3
        static let ratingPromptMinSessions = 5
        static let freeSessionLimit = 12
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

    // MARK: - Account
    enum Account {
        static let streakMilestoneForPrompt = 7
        static let sessionMilestoneForPrompt = 5
        static let favoriteMilestoneForPrompt = 3
        static let promptCooldownDays = 7
        static let maxPromptDismissals = 3
    }

    // MARK: - Chat
    enum Chat {
        static let freeMessageLimit = 5
        static let proxyBaseURL = "https://winter-hill-e14c.matsdegerstedt.workers.dev"
        static let maxTokens = 300
        static let modelName = "gpt-4o-mini"
        static let maxConversationHistory = 10
        static let historyRetentionDaysPremium = 30
        static let historyRetentionDaysFree = 3
    }

    // MARK: - Crisis Resources
    enum CrisisResources {
        static let suicidePreventionHotline = "988"
        static let crisisTextLine = "741741"
        static let emergencyNumber = "911"
        static let findHelpURL = "https://findahelpline.com/"
    }

    // MARK: - AI Meditation Generation
    enum AIMeditation {
        /// OpenAI model for script generation (use gpt-4o-mini for cost efficiency)
        static let scriptModel = "gpt-4o-mini"

        /// Maximum tokens for script generation
        static let maxScriptTokens = 4000

        /// OpenAI TTS model (tts-1 for speed/cost, tts-1-hd for quality)
        static let ttsModel = "tts-1"

        /// Maximum number of AI meditations a free user can generate (lifetime)
        static let freeGenerationLimit = 1

        /// Maximum number of AI meditations a premium user can generate per day
        static let premiumDailyGenerationLimit = 5

        /// Name of the "My Creations" playlist
        static let myCreationsPlaylistName = "My Creations"
    }
}
