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

    /// Call once on app launch in AppDelegate.didFinishLaunchingWithOptions.
    /// Analytics collection starts disabled and is enabled after ATT authorization.
    func configure() {
        FirebaseApp.configure()
        #if DEBUG
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        Analytics.setAnalyticsCollectionEnabled(false)
        #else
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        // Analytics collection deferred until ATT authorization completes (Guideline 5.1.2)
        Analytics.setAnalyticsCollectionEnabled(false)
        #endif
    }

    /// Enable analytics collection. Call after ATT authorization completes.
    func enableAnalyticsCollection() {
        #if !DEBUG
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

    // MARK: - Revenue Events (LTV)

    func logPurchase(price: Decimal, currencyCode: String, productID: String) {
        Analytics.logEvent(AnalyticsEventPurchase, parameters: [
            AnalyticsParameterValue: NSDecimalNumber(decimal: price).doubleValue,
            AnalyticsParameterCurrency: currencyCode,
            AnalyticsParameterItemID: productID
        ])
    }

    func logSubscriptionRenewal(price: Decimal, currencyCode: String, productID: String) {
        Analytics.logEvent("subscription_renewal", parameters: [
            AnalyticsParameterValue: NSDecimalNumber(decimal: price).doubleValue,
            AnalyticsParameterCurrency: currencyCode,
            AnalyticsParameterItemID: productID
        ])
    }

    // MARK: - Onboarding Funnel Events

    func logOnboardingStepViewed(step: Int, stepName: String) {
        Analytics.logEvent("onboarding_step_viewed", parameters: [
            "step_index": step,
            "step_name": stepName
        ])
    }

    func logOnboardingStepCompleted(step: Int, stepName: String) {
        Analytics.logEvent("onboarding_step_completed", parameters: [
            "step_index": step,
            "step_name": stepName
        ])
    }

    func logOnboardingStepSkipped(step: Int, stepName: String) {
        Analytics.logEvent("onboarding_step_skipped", parameters: [
            "step_index": step,
            "step_name": stepName
        ])
    }

    func logOnboardingCompleted() {
        Analytics.logEvent("onboarding_completed", parameters: nil)
    }

    // MARK: - Paywall Events

    func logPaywallViewed(source: String) {
        Analytics.logEvent("paywall_viewed", parameters: [
            "source": source
        ])
    }

    func logPaywallPlanSelected(plan: String) {
        Analytics.logEvent("paywall_plan_selected", parameters: [
            "plan": plan
        ])
    }

    func logPaywallSubscribeTapped(plan: String) {
        Analytics.logEvent("paywall_subscribe_tapped", parameters: [
            "plan": plan
        ])
    }

    func logPaywallDismissed(source: String) {
        Analytics.logEvent("paywall_dismissed", parameters: [
            "source": source
        ])
    }

    func logPurchaseFailed(productID: String, error: String) {
        Analytics.logEvent("purchase_failed", parameters: [
            AnalyticsParameterItemID: productID,
            "error": String(error.prefix(100))
        ])
    }

    func logPurchaseCancelled(productID: String) {
        Analytics.logEvent("purchase_cancelled", parameters: [
            AnalyticsParameterItemID: productID
        ])
    }

    func logRestoreTapped() {
        Analytics.logEvent("restore_tapped", parameters: nil)
    }

    func logRestoreSucceeded() {
        Analytics.logEvent("restore_succeeded", parameters: nil)
    }

    func logRestoreFailed(error: String) {
        Analytics.logEvent("restore_failed", parameters: [
            "error": String(error.prefix(100))
        ])
    }

    func logProductsLoadFailed(error: String) {
        Analytics.logEvent("products_load_failed", parameters: [
            "error": String(error.prefix(100))
        ])
    }

    // MARK: - Trial Events

    func logTrialStarted(productID: String) {
        Analytics.logEvent("trial_started", parameters: [
            AnalyticsParameterItemID: productID
        ])
    }

    func logTrialConverted(productID: String, price: Decimal, currencyCode: String) {
        Analytics.logEvent("trial_converted", parameters: [
            AnalyticsParameterItemID: productID,
            AnalyticsParameterValue: NSDecimalNumber(decimal: price).doubleValue,
            AnalyticsParameterCurrency: currencyCode
        ])
    }

    func logTrialCancelled(productID: String) {
        Analytics.logEvent("trial_cancelled", parameters: [
            AnalyticsParameterItemID: productID
        ])
    }

    // MARK: - User Properties

    func setSubscriptionStatus(_ status: String) {
        Analytics.setUserProperty(status, forName: "subscription_status")
    }

    func setOnboardingStatus(_ completed: Bool) {
        Analytics.setUserProperty(completed ? "completed" : "in_progress", forName: "onboarding_status")
    }

    // MARK: - Activation Events

    func logFirstHomeView() {
        Analytics.logEvent("first_home_view", parameters: nil)
    }

    // MARK: - Playback Failure Events

    func logPlaybackFailed(videoID: String, reason: String, retryCount: Int, contentTitle: String) {
        Analytics.logEvent("playback_failed", parameters: [
            "video_id": videoID,
            "reason": reason,
            "retry_count": retryCount,
            "content_title": String(contentTitle.prefix(100))
        ])
    }

    // MARK: - Attribution User Properties (CAC)

    func setAttributionUserProperties(mediaSource: String?, campaign: String?, adSet: String?, ad: String?) {
        if let mediaSource { Analytics.setUserProperty(mediaSource, forName: "af_media_source") }
        if let campaign { Analytics.setUserProperty(campaign, forName: "af_campaign") }
        if let adSet { Analytics.setUserProperty(adSet, forName: "af_adset") }
        if let ad { Analytics.setUserProperty(ad, forName: "af_ad") }
    }
}

#else

// MARK: - Stub (Firebase not yet added via SPM)
@MainActor
class FirebaseService {
    static let shared = FirebaseService()
    private init() {}

    func configure() {}
    func enableAnalyticsCollection() {}
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
    func logPurchase(price: Decimal, currencyCode: String, productID: String) {}
    func logSubscriptionRenewal(price: Decimal, currencyCode: String, productID: String) {}
    func logOnboardingStepViewed(step: Int, stepName: String) {}
    func logOnboardingStepCompleted(step: Int, stepName: String) {}
    func logOnboardingStepSkipped(step: Int, stepName: String) {}
    func logOnboardingCompleted() {}
    func logPaywallViewed(source: String) {}
    func logPaywallPlanSelected(plan: String) {}
    func logPaywallSubscribeTapped(plan: String) {}
    func logPaywallDismissed(source: String) {}
    func logPurchaseFailed(productID: String, error: String) {}
    func logPurchaseCancelled(productID: String) {}
    func logRestoreTapped() {}
    func logRestoreSucceeded() {}
    func logRestoreFailed(error: String) {}
    func logProductsLoadFailed(error: String) {}
    func logTrialStarted(productID: String) {}
    func logTrialConverted(productID: String, price: Decimal, currencyCode: String) {}
    func logTrialCancelled(productID: String) {}
    func setSubscriptionStatus(_ status: String) {}
    func setOnboardingStatus(_ completed: Bool) {}
    func logFirstHomeView() {}
    func logPlaybackFailed(videoID: String, reason: String, retryCount: Int, contentTitle: String) {}
    func setAttributionUserProperties(mediaSource: String?, campaign: String?, adSet: String?, ad: String?) {}
}

#endif
