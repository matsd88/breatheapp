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
        Task {
            if #available(iOS 14, *) {
                await ATTrackingManager.requestTrackingAuthorization()
            }
            AppsFlyerLib.shared().start()
            #if DEBUG
            print("[AppsFlyerService] SDK started")
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
}

// MARK: - AppsFlyerLibDelegate
extension AppsFlyerService: AppsFlyerLibDelegate {
    nonisolated func onConversionDataSuccess(_ conversionInfo: [AnyHashable: Any]) {
        #if DEBUG
        print("[AppsFlyerService] Conversion data: \(conversionInfo)")
        #endif
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
    func requestTrackingAndStart() {}
    func logCompleteRegistration() {}
    func logTutorialCompletion() {}
    func logPurchase(price: Decimal, currencyCode: String, productID: String) {}
    func logRenewal(price: Decimal, currencyCode: String, productID: String) {}
}

#endif
