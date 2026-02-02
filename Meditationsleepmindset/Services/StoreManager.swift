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

    // Product IDs - Configure these in App Store Connect
    private let productIDs = [
        Constants.Subscriptions.weeklyID,
        Constants.Subscriptions.monthlyID,
        Constants.Subscriptions.annualID,
        Constants.Subscriptions.annualDiscountedID
    ]

    @Published var subscriptions: [Product] = []
    @Published var purchasedSubscriptions: [Product] = []
    @Published var isPurchasing = false
    @Published var error: String?
    @Published var showError = false
    @Published var isSubscribed = false
    @Published var isRestoring = false

    private var updateListenerTask: Task<Void, Error>?

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
                await transaction.finish()

            case .userCancelled:
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
            self.error = error.localizedDescription
            self.showError = true
        }
    }

    // MARK: - Restore Purchases
    func restorePurchases() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            #if DEBUG
            print("Restore failed: \(error)")
            #endif
            self.error = error.localizedDescription
            self.showError = true
        }
    }

    // MARK: - Check Subscription Status
    func isPremiumSubscriber() async -> Bool {
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

    private func updatePurchasedProducts() async {
        var purchased: [Product] = []
        var hasSubscription = false

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productType == .autoRenewable {
                    hasSubscription = true
                }
                if let product = subscriptions.first(where: { $0.id == transaction.productID }) {
                    purchased.append(product)
                }
            }
        }

        purchasedSubscriptions = purchased
        isSubscribed = hasSubscription
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
