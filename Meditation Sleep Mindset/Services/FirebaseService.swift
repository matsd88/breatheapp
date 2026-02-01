//
//  FirebaseService.swift
//  Meditation Sleep Mindset
//
//  Firebase Crashlytics + Analytics integration.
//
//  SETUP INSTRUCTIONS:
//  1. Go to https://console.firebase.google.com → Create project → Add iOS app
//  2. Download GoogleService-Info.plist → drag into Xcode project root
//  3. In Xcode: File → Add Package Dependencies → paste:
//     https://github.com/firebase/firebase-ios-sdk
//  4. Select these products: FirebaseAnalytics, FirebaseCrashlytics
//  5. Build & run — Firebase will auto-configure from the plist
//

import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
import FirebaseCrashlytics
import FirebaseAnalytics

@MainActor
class FirebaseService {
    static let shared = FirebaseService()

    private init() {}

    // MARK: - Configuration

    /// Call once on app launch in AppDelegate.didFinishLaunchingWithOptions
    func configure() {
        FirebaseApp.configure()
        #if DEBUG
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        Analytics.setAnalyticsCollectionEnabled(false)
        #else
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        Analytics.setAnalyticsCollectionEnabled(true)
        #endif
    }

    // MARK: - Crash Reporting

    /// Log a non-fatal error for Crashlytics
    func logError(_ error: Error, context: String? = nil) {
        var userInfo: [String: Any] = [:]
        if let context = context {
            userInfo["context"] = context
        }
        Crashlytics.crashlytics().record(error: error, userInfo: userInfo)
    }

    /// Log a breadcrumb message for crash context
    func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }

    /// Set a custom key-value for crash reports
    func setCustomValue(_ value: Any, forKey key: String) {
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }

    // MARK: - Analytics Events

    func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
    }

    func logContentPlayed(contentType: String, title: String, durationSeconds: Int) {
        Analytics.logEvent("content_played", parameters: [
            "content_type": contentType,
            "title": title,
            "duration_seconds": durationSeconds
        ])
    }

    func logSessionCompleted(sessionType: String, durationMinutes: Int) {
        Analytics.logEvent("session_completed", parameters: [
            "session_type": sessionType,
            "duration_minutes": durationMinutes
        ])
    }

    func logStreakMilestone(days: Int) {
        Analytics.logEvent("streak_milestone", parameters: [
            "streak_days": days
        ])
    }

    func logSubscriptionEvent(_ event: String) {
        Analytics.logEvent("subscription_event", parameters: [
            "event_type": event
        ])
    }

    func logFeatureUsed(_ feature: String) {
        Analytics.logEvent("feature_used", parameters: [
            "feature": feature
        ])
    }

    func logOnboardingStep(_ step: String) {
        Analytics.logEvent("onboarding_step", parameters: [
            "step": step
        ])
    }

    func logScreenView(_ screenName: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName
        ])
    }

    func logDeadVideoDetected(videoID: String, title: String) {
        Analytics.logEvent("dead_video_detected", parameters: [
            "video_id": videoID,
            "title": title
        ])
    }
}

#else

// MARK: - Stub (Firebase not yet added via SPM)
@MainActor
class FirebaseService {
    static let shared = FirebaseService()
    private init() {}

    func configure() {}
    func logError(_ error: Error, context: String? = nil) {}
    func log(_ message: String) {}
    func setCustomValue(_ value: Any, forKey key: String) {}
    func logEvent(_ name: String, parameters: [String: Any]? = nil) {}
    func logContentPlayed(contentType: String, title: String, durationSeconds: Int) {}
    func logSessionCompleted(sessionType: String, durationMinutes: Int) {}
    func logStreakMilestone(days: Int) {}
    func logSubscriptionEvent(_ event: String) {}
    func logFeatureUsed(_ feature: String) {}
    func logOnboardingStep(_ step: String) {}
    func logScreenView(_ screenName: String) {}
    func logDeadVideoDetected(videoID: String, title: String) {}
}

#endif
