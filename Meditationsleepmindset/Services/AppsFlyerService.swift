//
//  AppsFlyerService.swift
//  Meditation Sleep Mindset
//
//  AppsFlyer attribution SDK integration for ad campaign tracking.
//
//  SETUP INSTRUCTIONS:
//  1. In Xcode: File > Add Package Dependencies > paste:
//     https://github.com/AppsFlyerSDK/AppsFlyerFramework
//  2. Select the "AppsFlyerLib" product for the main app target
//  3. Replace [YOUR_APPSFLYER_DEV_KEY] with your AppsFlyer dev key
//  4. Replace [YOUR_APP_STORE_APP_ID] with your numeric App Store ID (no "id" prefix)
//  5. Build & run — check Xcode console for [AppsFlyer] debug logs
//

import Foundation
import AppTrackingTransparency

#if canImport(AppsFlyerLib)
import AppsFlyerLib

@MainActor
class AppsFlyerService: NSObject {
    static let shared = AppsFlyerService()

    private override init() {
        super.init()
    }

    // MARK: - Configuration

    /// Call once on app launch in AppDelegate.didFinishLaunchingWithOptions, BEFORE Firebase.
    /// This configures the SDK but does NOT start it — call requestTrackingAndStart() after UI is visible.
    func configure() {
        let appsFlyer = AppsFlyerLib.shared()
        appsFlyer.appsFlyerDevKey = "tUnkwgLhA8WqJ632qfhnAR"
        appsFlyer.appleAppID = "6758229420"
        appsFlyer.delegate = self
        #if DEBUG
        appsFlyer.isDebug = true
        #endif
    }

    /// Request ATT permission then start the SDK. Call from onAppear after UI is visible.
    func requestTrackingAndStart() {
        // Delay to ensure the app is fully active and visible (ATT requires active state)
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            if #available(iOS 14, *) {
                await ATTrackingManager.requestTrackingAuthorization()
            }
            // Enable Firebase Analytics only after ATT authorization completes (Guideline 5.1.2)
            FirebaseService.shared.enableAnalyticsCollection()
            AppsFlyerLib.shared().start()
            #if DEBUG
            print("[AppsFlyerService] SDK started, analytics collection enabled")
            #endif
        }
    }

    // MARK: - Attribution Events

    func logCompleteRegistration() {
        AppsFlyerLib.shared().logEvent(AFEventCompleteRegistration, withValues: [
            AFEventParamContent: "onboarding_complete"
        ])
    }

    func logTutorialCompletion() {
        AppsFlyerLib.shared().logEvent(AFEventTutorial_completion, withValues: [
            AFEventParamDescription: "first_meditation_session"
        ])
    }

    func logPurchase(price: Decimal, currencyCode: String, productID: String) {
        AppsFlyerLib.shared().logEvent(AFEventPurchase, withValues: [
            AFEventParamRevenue: price,
            AFEventParamCurrency: currencyCode,
            AFEventParamContentId: productID,
            AFEventParamQuantity: 1
        ])
    }

    func logRenewal(price: Decimal, currencyCode: String, productID: String) {
        AppsFlyerLib.shared().logEvent("af_renewed", withValues: [
            AFEventParamRevenue: price,
            AFEventParamCurrency: currencyCode,
            AFEventParamContentId: productID,
            AFEventParamQuantity: 1
        ])
    }

    // MARK: - Onboarding Events

    func logOnboardingStep(step: Int, stepName: String, action: String) {
        AppsFlyerLib.shared().logEvent("onboarding_\(action)", withValues: [
            "step_index": step,
            "step_name": stepName
        ])
    }

    // MARK: - Paywall Events

    func logPaywallEvent(eventName: String, plan: String? = nil) {
        var values: [String: Any] = [:]
        if let plan { values["plan"] = plan }
        AppsFlyerLib.shared().logEvent(eventName, withValues: values)
    }

    // MARK: - Trial Events

    func logTrialStarted(productID: String) {
        AppsFlyerLib.shared().logEvent("trial_started", withValues: [
            AFEventParamContentId: productID
        ])
    }
}

// MARK: - AppsFlyerLibDelegate
extension AppsFlyerService: AppsFlyerLibDelegate {
    nonisolated func onConversionDataSuccess(_ conversionInfo: [AnyHashable: Any]) {
        #if DEBUG
        print("[AppsFlyerService] Conversion data: \(conversionInfo)")
        #endif

        // Forward attribution data to Firebase as user properties for CAC analysis
        let mediaSource = conversionInfo["media_source"] as? String
        let campaign = conversionInfo["campaign"] as? String
        let adSet = conversionInfo["adset"] as? String
        let ad = conversionInfo["ad"] as? String

        Task { @MainActor in
            FirebaseService.shared.setAttributionUserProperties(
                mediaSource: mediaSource,
                campaign: campaign,
                adSet: adSet,
                ad: ad
            )
        }
    }

    nonisolated func onConversionDataFail(_ error: any Error) {
        #if DEBUG
        print("[AppsFlyerService] Conversion data error: \(error)")
        #endif
    }
}

#else

// MARK: - Stub (AppsFlyerLib not yet added via SPM)
@MainActor
class AppsFlyerService {
    static let shared = AppsFlyerService()
    private init() {}

    func configure() {}
    func requestTrackingAndStart() {
        // Still need to handle ATT + Firebase analytics even without AppsFlyer
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if #available(iOS 14, *) {
                await ATTrackingManager.requestTrackingAuthorization()
            }
            FirebaseService.shared.enableAnalyticsCollection()
        }
    }
    func logCompleteRegistration() {}
    func logTutorialCompletion() {}
    func logPurchase(price: Decimal, currencyCode: String, productID: String) {}
    func logRenewal(price: Decimal, currencyCode: String, productID: String) {}
    func logOnboardingStep(step: Int, stepName: String, action: String) {}
    func logPaywallEvent(eventName: String, plan: String? = nil) {}
    func logTrialStarted(productID: String) {}
}

#endif
