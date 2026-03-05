//
//  StoreManager.swift
//  Meditation Sleep Mindset
//

import Foundation
import StoreKit
import SwiftUI

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()

    // MARK: - VIP Access
    static let vipEmails: Set<String> = ["matsdegerstedt@gmail.com", "carinadeg@gmail.com"]

    var isVIP: Bool {
        guard let email = AccountService.shared.userEmail?.lowercased() else { return false }
        return Self.vipEmails.contains(email)
    }

    // Product IDs - Configure these in App Store Connect
    private let productIDs = [
        Constants.Subscriptions.weeklyID,
        Constants.Subscriptions.monthlyID,
        Constants.Subscriptions.annualID
    ]

    @Published var subscriptions: [Product] = []
    @Published var purchasedSubscriptions: [Product] = []
    @Published var isPurchasing = false
    @Published var error: String?
    @Published var showError = false
    @Published var isSubscribed = false
    @Published var isRestoring = false

    private var updateListenerTask: Task<Void, Error>?
    private var reportedTransactionIDs: Set<UInt64> = []

    init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products
    func loadProducts() async {
        do {
            let products = try await Product.products(for: productIDs)
            subscriptions = products.sorted { a, b in
                // Sort by subscription period (weekly, monthly, yearly)
                guard let periodA = a.subscription?.subscriptionPeriod,
                      let periodB = b.subscription?.subscriptionPeriod else {
                    return false
                }
                return periodA.value < periodB.value
            }
        } catch {
            #if DEBUG
            print("Failed to load products: \(error)")
            #endif
            FirebaseService.shared.logProductsLoadFailed(error: error.localizedDescription)
            self.error = error.localizedDescription
            self.showError = true
        }
    }

    // MARK: - Purchase
    func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePurchasedProducts()
                trackAnalyticsEvents(for: transaction)
                await transaction.finish()

            case .userCancelled:
                FirebaseService.shared.logPurchaseCancelled(productID: product.id)
                break

            case .pending:
                break

            @unknown default:
                break
            }
        } catch {
            #if DEBUG
            print("Purchase failed: \(error)")
            #endif
            FirebaseService.shared.logPurchaseFailed(productID: product.id, error: error.localizedDescription)
            self.error = error.localizedDescription
            self.showError = true
        }
    }

    // MARK: - Restore Purchases
    func restorePurchases() async {
        FirebaseService.shared.logRestoreTapped()
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            FirebaseService.shared.logRestoreSucceeded()
        } catch {
            #if DEBUG
            print("Restore failed: \(error)")
            #endif
            FirebaseService.shared.logRestoreFailed(error: error.localizedDescription)
            self.error = error.localizedDescription
            self.showError = true
        }
    }

    // MARK: - Check Subscription Status
    func isPremiumSubscriber() async -> Bool {
        if isVIP { return true }
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productType == .autoRenewable {
                    return true
                }
            }
        }
        return false
    }

    func getSubscriptionExpiryDate() async -> Date? {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productType == .autoRenewable {
                    return transaction.expirationDate
                }
            }
        }
        return nil
    }

    // MARK: - Private Methods
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await self.trackAnalyticsEvents(for: transaction)
                    await transaction.finish()
                } catch {
                    #if DEBUG
                    print("Transaction verification failed: \(error)")
                    #endif
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    private func trackAnalyticsEvents(for transaction: StoreKit.Transaction) {
        // Skip restores and family sharing
        guard transaction.ownershipType == .purchased else { return }

        // Deduplicate — don't fire the same event twice for the same transaction
        guard !reportedTransactionIDs.contains(transaction.id) else { return }
        reportedTransactionIDs.insert(transaction.id)

        // Find the matching product to get price and currency
        guard let product = subscriptions.first(where: { $0.id == transaction.productID }) else { return }

        let price = product.price
        let currencyCode = product.priceFormatStyle.currencyCode
        let isInitialPurchase = transaction.id == transaction.originalID

        if isInitialPurchase {
            if transaction.offerType == .introductory {
                // Free trial start — no revenue yet, only track trial lifecycle
                FirebaseService.shared.logTrialStarted(productID: product.id)
                AppsFlyerService.shared.logTrialStarted(productID: product.id)

                // Persist trial metadata for conversion/cancellation tracking
                let defaults = UserDefaults.standard
                defaults.set(Date(), forKey: Constants.AnalyticsKeys.trialStartDate)
                defaults.set(product.id, forKey: Constants.AnalyticsKeys.trialProductID)
                defaults.set(transaction.originalID, forKey: Constants.AnalyticsKeys.trialOriginalTransactionID)
                defaults.set(false, forKey: Constants.AnalyticsKeys.trialConvertedLogged)
            } else {
                // Paid initial purchase — fire revenue events to both platforms
                AppsFlyerService.shared.logPurchase(price: price, currencyCode: currencyCode, productID: product.id)
                FirebaseService.shared.logPurchase(price: price, currencyCode: currencyCode, productID: product.id)
            }
        } else {
            // Renewal — fire to both AppsFlyer and Firebase
            AppsFlyerService.shared.logRenewal(price: price, currencyCode: currencyCode, productID: product.id)
            FirebaseService.shared.logSubscriptionRenewal(price: price, currencyCode: currencyCode, productID: product.id)

            // Trial conversion: first renewal after a trial means the user converted
            let defaults = UserDefaults.standard
            if defaults.object(forKey: Constants.AnalyticsKeys.trialStartDate) != nil,
               !defaults.bool(forKey: Constants.AnalyticsKeys.trialConvertedLogged),
               let trialProductID = defaults.string(forKey: Constants.AnalyticsKeys.trialProductID) {
                FirebaseService.shared.logTrialConverted(productID: trialProductID, price: price, currencyCode: currencyCode)
                defaults.set(true, forKey: Constants.AnalyticsKeys.trialConvertedLogged)
            }
        }
    }

    /// Check if a trial user's entitlement expired without converting. Call on app launch.
    func checkTrialCancellation() async {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Constants.AnalyticsKeys.trialStartDate) != nil,
              !defaults.bool(forKey: Constants.AnalyticsKeys.trialConvertedLogged),
              let trialProductID = defaults.string(forKey: Constants.AnalyticsKeys.trialProductID) else {
            return
        }

        // If user has no active subscription, the trial lapsed without converting
        let hasActiveSubscription = await isPremiumSubscriber()
        if !hasActiveSubscription {
            FirebaseService.shared.logTrialCancelled(productID: trialProductID)
            // Clean up trial metadata so we don't fire this again
            defaults.removeObject(forKey: Constants.AnalyticsKeys.trialStartDate)
            defaults.removeObject(forKey: Constants.AnalyticsKeys.trialProductID)
            defaults.removeObject(forKey: Constants.AnalyticsKeys.trialOriginalTransactionID)
            defaults.removeObject(forKey: Constants.AnalyticsKeys.trialConvertedLogged)
        }
    }

    /// Re-check subscription status. Called on launch and when app returns to foreground.
    func refreshSubscriptionStatus() async {
        await updatePurchasedProducts()
    }

    private func updatePurchasedProducts() async {
        var purchased: [Product] = []
        var hasSubscription = isVIP
        var isOnTrial = false

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productType == .autoRenewable {
                    hasSubscription = true
                    // Detect active trial: introductory offer on the original purchase
                    if transaction.offerType == .introductory {
                        isOnTrial = true
                    }
                }
                if let product = subscriptions.first(where: { $0.id == transaction.productID }) {
                    purchased.append(product)
                }
            }
        }

        purchasedSubscriptions = purchased
        isSubscribed = hasSubscription

        // Update subscription_status user property for Firebase segmentation
        let status: String
        if isVIP {
            status = "vip"
        } else if isOnTrial {
            status = "trial"
        } else if hasSubscription {
            status = "paid"
        } else if UserDefaults.standard.object(forKey: Constants.AnalyticsKeys.trialStartDate) != nil {
            status = "lapsed"
        } else {
            status = "free"
        }
        FirebaseService.shared.setSubscriptionStatus(status)
    }
}

enum StoreError: Error, LocalizedError {
    case verificationFailed
    case purchaseFailed
    case productNotFound

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Transaction verification failed"
        case .purchaseFailed:
            return "Purchase could not be completed"
        case .productNotFound:
            return "Product not found"
        }
    }
}
