//
//  PremiumView.swift
//  Meditation Sleep Mindset
//

import SwiftUI
import SwiftData
import StoreKit

struct PremiumView: View {
    @Query private var userProfiles: [UserProfile]
    @StateObject private var storeManager = StoreManager.shared
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }

    private var userProfile: UserProfile? {
        userProfiles.first
    }

    private var isPremium: Bool {
        userProfile?.isPremiumSubscriber ?? false
    }

    var body: some View {
        ZStack {
            Theme.profileGradient.ignoresSafeArea()

            if isPremium {
                ScrollView {
                    PremiumStatusView(profile: userProfile)
                        .frame(maxWidth: 700)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                        .padding(.bottom, 16)
                }
            } else {
                PremiumPaywallView(storeManager: storeManager, context: .settings, showDismissButton: false)
                    .frame(maxWidth: 700)
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Premium")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Paywall Context

/// Where the paywall was opened from, and what the user was reaching for.
///
/// Previously every entry point rendered an identical paywall — same headline,
/// same feature order — and only an optional subtitle string differed. Someone
/// blocked from an AI meditation saw "Sleep Stories" pitched first. This makes
/// the pitch answer the question the user actually asked, and leads with the
/// feature they just tried to use.
enum PaywallContext: String {
    case general
    case chatLimit
    case aiStudio
    case kidsStories
    case offlinePacks
    case premiumSession
    case sleepStories
    case settings
    case homeBanner
    case postSession

    var headline: String {
        switch self {
        case .chatLimit:      return String(localized: "Keep the conversation going")
        case .aiStudio:       return String(localized: "Meditations made for you")
        case .kidsStories:    return String(localized: "A new story every night")
        case .offlinePacks:   return String(localized: "Take it with you, offline")
        case .premiumSession: return String(localized: "Unlock the full library")
        case .sleepStories:   return String(localized: "Fall asleep to a story")
        case .postSession:    return String(localized: "Keep this going")
        case .general, .settings, .homeBanner:
            return String(localized: "Unlock Your Full Potential")
        }
    }

    /// Nil falls back to the generic line, or to an explicit override.
    var subtitle: String? {
        switch self {
        case .chatLimit:      return String(localized: "You've reached today's free messages. Premium keeps Breathe AI available whenever you need it.")
        case .aiStudio:       return String(localized: "Generate a meditation for any mood, any length, in your chosen voice.")
        case .kidsStories:    return String(localized: "Unlimited personalized bedtime stories, so bedtime never runs out of material.")
        case .offlinePacks:   return String(localized: "Download packs and play them on a plane, a commute, or anywhere without signal.")
        case .premiumSession: return String(localized: "This session is part of Premium — along with the rest of the library.")
        case .sleepStories:   return String(localized: "100+ narrated stories designed to get you to sleep, not keep you listening.")
        case .postSession:    return String(localized: "You just finished a session. Premium opens the full library, so there's always a next one waiting.")
        case .general, .settings, .homeBanner: return nil
        }
    }

    /// SF Symbol of the preview card that should lead, so the first thing the
    /// user sees is the thing they just reached for.
    var leadFeatureIcon: String? {
        switch self {
        case .chatLimit:      return "bubble.left.and.text.bubble.right.fill"
        case .aiStudio:       return "wand.and.stars"
        case .kidsStories:    return "bubble.left.and.text.bubble.right.fill"
        case .sleepStories:   return "moon.stars.fill"
        case .offlinePacks:   return "music.note.list"
        case .premiumSession, .postSession, .general, .settings, .homeBanner: return nil
        }
    }

    var analyticsSource: String { rawValue }
}

// MARK: - Premium Paywall (Matches Onboarding Paywall)
struct PremiumPaywallView: View {
    @ObservedObject var storeManager: StoreManager
    /// Drives the headline, supporting line and which feature leads.
    var context: PaywallContext = .general
    /// Explicit override; when nil the context supplies the line.
    var sessionLimitMessage: String? = nil
    var onSubscribed: (() -> Void)? = nil
    var showDismissButton: Bool = true
    @State private var selectedPlan: PremiumSubscriptionPlan = .annual
    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfService = false
    @State private var animateFeatures = false
    @State private var countdownSeconds: Int = 86400
    @State private var countdownTimer: Timer?
    @State private var showCountdown = true
    @State private var previewIndex = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }

    // Feature preview cards — AI studio leads by default (the feature
    // competitors can't match), but the context can promote whichever card
    // matches what the user just reached for.
    private var previewCards: [(image: String, title: String, description: String)] {
        let base: [(image: String, title: String, description: String)] = [
            ("wand.and.stars", String(localized: "Personal AI Meditation Studio"), String(localized: "Meditations generated just for you — any mood, any length")),
            ("bubble.left.and.text.bubble.right.fill", String(localized: "AI Companion & Kids Stories"), String(localized: "24/7 wellness chat, plus personalized AI bedtime stories")),
            ("moon.stars.fill", String(localized: "100+ Sleep Stories"), String(localized: "Drift off with narrated stories designed for deep sleep")),
            ("music.note.list", String(localized: "Calming Soundscapes"), String(localized: "Rain, ocean waves, forest — mix your own"))
        ]
        guard let lead = context.leadFeatureIcon,
              let idx = base.firstIndex(where: { $0.image == lead }), idx != 0
        else { return base }
        var reordered = base
        let card = reordered.remove(at: idx)
        reordered.insert(card, at: 0)
        return reordered
    }

    // MARK: - Trial Timeline

    /// Spells out exactly what happens and when, including the reminder before
    /// billing. Nothing here is a promise the app can't keep — the day-5 line
    /// describes Apple's own pre-renewal notice for introductory offers.
    private var trialTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            timelineRow(
                icon: "lock.open.fill",
                title: String(localized: "Today"),
                detail: String(localized: "Full access unlocks — the whole library, AI studio and sleep stories."),
                isLast: false
            )
            timelineRow(
                icon: "bell.fill",
                title: String(localized: "Day 5"),
                detail: String(localized: "Apple emails you a reminder that the trial is ending."),
                isLast: false
            )
            timelineRow(
                icon: "creditcard.fill",
                title: String(localized: "Day 7"),
                detail: String(localized: "Your subscription begins. Cancel any time before then and you pay nothing."),
                isLast: true
            )
        }
        .padding(16)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Free trial timeline: full access today, a reminder on day 5, billing begins on day 7. Cancel before then and you pay nothing."))
    }

    private func timelineRow(icon: String, title: String, detail: String, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 26, height: 26)
                    Image(systemName: icon)
                        .font(.caption2)
                        .foregroundStyle(.white)
                }
                if !isLast {
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(minHeight: isLast ? 26 : 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : 12)

            Spacer(minLength: 0)
        }
    }

    // Before/after metrics
    private var beforeAfterItems: [(label: String, before: String, after: String, icon: String)] {[
        (String(localized: "Sleep Quality"), String(localized: "Poor"), String(localized: "Great"), "moon.fill"),
        (String(localized: "Stress Level"), String(localized: "High"), String(localized: "Low"), "heart.fill"),
        (String(localized: "Daily Streak"), String(localized: "0 days"), String(localized: "30 days"), "flame.fill"),
        (String(localized: "Mindfulness"), String(localized: "Never"), String(localized: "Daily"), "brain.head.profile")
    ]}

    var body: some View {
        ZStack(alignment: .topTrailing) {
        ScrollView {
            VStack(spacing: 18) {
                // Feature preview cards (swipeable)
                featurePreviewSection

                // Urgency countdown banner (only while the first-run offer is genuinely live)
                if showCountdown {
                    urgencyBanner
                }

                // Header text — headline and supporting line both follow the
                // context the paywall was opened from.
                VStack(spacing: 10) {
                    Text(context.headline)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Text(sessionLimitMessage
                         ?? context.subtitle
                         ?? String(localized: "Transform your mind, transform your life"))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Before / After comparison
                beforeAfterSection

                // Star rating + social proof
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .font(.system(size: 14))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())

                    Text("Loved by over 100,000 people finding calm")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                // Plan options
                VStack(spacing: 14) {
                    ForEach(PremiumSubscriptionPlan.allCases) { plan in
                        PremiumPlanOptionView(
                            plan: plan,
                            isSelected: selectedPlan == plan
                        ) {
                            withAnimation(.spring(response: 0.2)) {
                                selectedPlan = plan
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Subscribe button
                Button {
                    FirebaseService.shared.logPaywallSubscribeTapped(plan: selectedPlan.rawValue)
                    Task {
                        var products = storeManager.subscriptions
                        if products.isEmpty {
                            await storeManager.loadProducts()
                            products = storeManager.subscriptions
                        }

                        let selectedProduct: Product?

                        switch selectedPlan {
                        case .annual:
                            selectedProduct = products.first { $0.subscription?.subscriptionPeriod.unit == .year }
                        case .monthly:
                            selectedProduct = products.first { $0.subscription?.subscriptionPeriod.unit == .month }
                        case .weekly:
                            selectedProduct = products.first { $0.subscription?.subscriptionPeriod.unit == .week }
                        }

                        if let product = selectedProduct ?? products.first {
                            await storeManager.purchase(product)
                            if storeManager.isSubscribed {
                                onSubscribed?()
                            }
                        } else {
                            storeManager.presentAlert(
                                title: String(localized: "Can't Load Plans"),
                                message: String(localized: "Please check your internet connection and try again.")
                            )
                        }
                    }
                } label: {
                    HStack {
                        if storeManager.isPurchasing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            VStack(spacing: 2) {
                                Text("Start My \(Constants.Subscriptions.freeTrialDays)-Day Free Trial")
                                    .fontWeight(.semibold)
                                Text("then \(selectedPlan.price), auto-renews")
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .contentShape(Rectangle())
                }
                .disabled(storeManager.isPurchasing)
                .padding(.horizontal, 24)

                // Auto-renewal terms (Apple requirement)
                Text(subscriptionTermsText)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Trial timeline — the single strongest trust device on a
                // wellness paywall: it removes the "when am I actually charged?"
                // doubt that stops people starting a trial at all.
                trialTimeline

                // Trust signals
                VStack(spacing: 12) {
                    Text("Cancel anytime · No commitment")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))

                    Button("Restore Purchase") {
                        Task {
                            switch await storeManager.restorePurchases() {
                            case .restored:
                                onSubscribed?()
                            case .nothingFound:
                                storeManager.presentAlert(
                                    title: String(localized: "No Purchases Found"),
                                    message: StoreManager.nothingToRestoreMessage
                                )
                            case .failed:
                                break // restorePurchases() already raised the alert
                            }
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.white)
                }
                .padding(.top, 8)

                // Legal links
                HStack(spacing: 16) {
                    Button("Terms of Service") {
                        showingTermsOfService = true
                    }

                    Text("·")

                    Button("Privacy Policy") {
                        showingPrivacyPolicy = true
                    }
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
                .padding(.top, 20)
            }
            .frame(maxWidth: isRegular ? 800 : 500)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                animateFeatures = true
            }
            startCountdown()
            AppStateManager.shared.recordPaywallShown()
            FirebaseService.shared.logPaywallViewed(source: context.analyticsSource)
        }
        .task {
            if storeManager.subscriptions.isEmpty {
                await storeManager.loadProducts()
            }
        }
        .onDisappear {
            countdownTimer?.invalidate()
            countdownTimer = nil
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            NavigationStack {
                PrivacyPolicyView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showingPrivacyPolicy = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingTermsOfService) {
            NavigationStack {
                TermsOfServiceView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showingTermsOfService = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }
            }
        }
        .alert(storeManager.alertTitle, isPresented: $storeManager.showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(storeManager.alertMessage ?? "Something went wrong. Please try again.")
        }

            // Dismiss X button (top-right corner)
            if showDismissButton {
                Button {
                    FirebaseService.shared.logPaywallDismissed(source: context.analyticsSource)
                    SmartRatingManager.recordPaywallDismiss()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .accessibilityLabel("Close")
                        .font(.system(size: isRegular ? 14 : 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: isRegular ? 40 : 32, height: isRegular ? 40 : 32)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
                .padding(.top, 12)
                .padding(.trailing, 16)
            }
        } // ZStack
        .background(Theme.profileGradient.ignoresSafeArea())
        .presentationBackground(Theme.profileGradient)
    }

    // MARK: - StoreKit Price Helpers

    private func storeKitProduct(for plan: PremiumSubscriptionPlan) -> Product? {
        let products = storeManager.subscriptions
        switch plan {
        case .annual:
            return products.first { $0.subscription?.subscriptionPeriod.unit == .year }
        case .monthly:
            return products.first { $0.subscription?.subscriptionPeriod.unit == .month }
        case .weekly:
            return products.first { $0.subscription?.subscriptionPeriod.unit == .week }
        }
    }

    private var subscriptionTermsText: String {
        if let product = storeKitProduct(for: selectedPlan) {
            let period: String
            switch product.subscription?.subscriptionPeriod.unit {
            case .year: period = "year"
            case .month: period = "month"
            case .week: period = "week"
            default: period = "period"
            }
            return "After the 7-day free trial, you will be charged \(product.displayPrice)/\(period). Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Payment is charged to your Apple ID account."
        }
        return "Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Payment is charged to your Apple ID account."
    }

    // MARK: - Urgency Countdown Banner

    private var urgencyBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.fill")
                .font(.caption)
                .foregroundStyle(.yellow)

            Text("Special offer expires in ")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            +
            Text(formattedCountdown)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.yellow)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
        .padding(.horizontal, 24)
    }

    private var formattedCountdown: String {
        let hours = countdownSeconds / 3600
        let minutes = (countdownSeconds % 3600) / 60
        let seconds = countdownSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func startCountdown() {
        // Invalidate any existing timer first to prevent duplicates
        countdownTimer?.invalidate()
        countdownTimer = nil

        // Real, persisted expiry tied to first view — once it genuinely ends,
        // hide the banner instead of rolling over a fresh 24h (honest urgency).
        let key = "paywallCountdownExpiry"
        let now = Date()
        if let stored = UserDefaults.standard.object(forKey: key) as? Date {
            if stored > now {
                countdownSeconds = Int(stored.timeIntervalSince(now))
            } else {
                showCountdown = false
                return
            }
        } else {
            let expiry = now.addingTimeInterval(86400)
            UserDefaults.standard.set(expiry, forKey: key)
            countdownSeconds = 86400
        }

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if countdownSeconds > 0 {
                    countdownSeconds -= 1
                    if countdownSeconds == 0 { showCountdown = false }
                }
            }
        }
    }

    // MARK: - Feature Preview Cards

    private var featurePreviewSection: some View {
        TabView(selection: $previewIndex) {
            ForEach(Array(previewCards.enumerated()), id: \.offset) { index, card in
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Theme.profileAccent.opacity(0.2))
                            .frame(width: 64, height: 64)

                        Image(systemName: card.image)
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.profileAccent)
                    }
                    .scaleEffect(animateFeatures ? 1.0 : 0.7)
                    .opacity(animateFeatures ? 1.0 : 0.4)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.6)
                        .delay(0.1),
                        value: animateFeatures
                    )

                    Text(card.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text(card.description)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(height: 230)
    }

    // MARK: - Before / After Comparison

    private var beforeAfterSection: some View {
        // Adaptive widths for iPad
        let labelWidth: CGFloat = isRegular ? 160 : 120
        let valueWidth: CGFloat = isRegular ? 90 : 70

        return VStack(spacing: 12) {
            // Header row
            HStack {
                Text("")
                    .frame(width: labelWidth, alignment: .leading)
                Spacer()
                Text("Day 1")
                    .font(isRegular ? .subheadline : .caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: valueWidth)
                Image(systemName: "arrow.right")
                    .font(isRegular ? .subheadline : .caption)
                    .foregroundStyle(.white.opacity(0.3))
                Text("Day 30")
                    .font(isRegular ? .subheadline : .caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
                    .frame(width: valueWidth)
            }
            .padding(.horizontal, 24)

            ForEach(Array(beforeAfterItems.enumerated()), id: \.offset) { index, item in
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: item.icon)
                            .font(isRegular ? .subheadline : .caption)
                            .foregroundStyle(.white.opacity(0.6))
                        Text(item.label)
                            .font(isRegular ? .body : .subheadline)
                            .foregroundStyle(.white)
                    }
                    .frame(width: labelWidth, alignment: .leading)

                    Spacer()

                    Text(item.before)
                        .font(isRegular ? .subheadline : .caption)
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: valueWidth)

                    Image(systemName: "arrow.right")
                        .font(isRegular ? .caption : .caption2)
                        .foregroundStyle(.white.opacity(0.2))

                    Text(item.after)
                        .font(isRegular ? .subheadline : .caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                        .frame(width: valueWidth)
                }
                .padding(.horizontal, 24)
                .opacity(animateFeatures ? 1 : 0)
                .offset(x: animateFeatures ? 0 : 20)
                .animation(
                    .spring(response: 0.4, dampingFraction: 0.8)
                    .delay(Double(index) * 0.1 + 0.3),
                    value: animateFeatures
                )
            }
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .padding(.horizontal, 24)
    }
}

// MARK: - Premium Subscription Plan
enum PremiumSubscriptionPlan: String, CaseIterable, Identifiable {
    case annual
    case monthly
    case weekly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .annual: return String(localized: "Annual")
        case .monthly: return String(localized: "Monthly")
        case .weekly: return String(localized: "Weekly")
        }
    }

    var price: String {
        switch self {
        case .annual: return "$49.99/year"
        case .monthly: return "$8.99/month"
        case .weekly: return "$2.99/week"
        }
    }

    /// Every plan normalised to the same unit so the comparison needs no mental
    /// arithmetic. Previously annual read "$49.99/year" against "$8.99/month",
    /// which hid how much better the annual plan is.
    var subtitle: String? {
        switch self {
        case .annual: return String(localized: "$4.17/month · billed yearly")
        case .monthly: return String(localized: "$8.99/month · billed monthly")
        case .weekly: return String(localized: "$12.96/month · billed weekly")
        }
    }

    /// Only one plan carries a badge. Annual said "BEST VALUE" while monthly
    /// said "MOST POPULAR" — two competing recommendations cancel out and leave
    /// the user to decide unaided.
    var badge: String? {
        switch self {
        case .annual: return String(localized: "BEST VALUE")
        case .monthly: return nil
        case .weekly: return nil
        }
    }

    var discount: String? {
        switch self {
        case .annual: return String(localized: "Save 54%")
        case .monthly: return nil
        case .weekly: return nil
        }
    }
}

// MARK: - Premium Plan Option View
struct PremiumPlanOptionView: View {
    let plan: PremiumSubscriptionPlan
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                // Radio button
                Circle()
                    .stroke(isSelected ? Color.white : Color.white.opacity(0.4), lineWidth: 2)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .fill(isSelected ? Color.white : Color.clear)
                            .frame(width: 14, height: 14)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(plan.title)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)

                        if let badge = plan.badge {
                            Text(badge)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.15))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                )
                                .clipShape(Capsule())
                        }
                    }

                    if let subtitle = plan.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.price)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)

                    if let discount = plan.discount {
                        Text(discount)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.white.opacity(0.15) : Theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.white.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Premium Status View (for subscribed users)
struct PremiumStatusView: View {
    let profile: UserProfile?

    var body: some View {
        VStack(spacing: 24) {
            // Crown Badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.yellow, Color.orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "crown.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
            }

            Text("You're Premium!")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Theme.textPrimary)

            Text("Thank you for your support. Enjoy unlimited access to all content.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Subscription Info
            VStack(spacing: 12) {
                if let expiryDate = profile?.subscriptionExpiryDate {
                    HStack {
                        Text("Next billing date")
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text(expiryDate, style: .date)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding()
                    .background(Theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Manage Subscription")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)

            // Premium Features List
            VStack(alignment: .leading, spacing: 16) {
                Text("Your Benefits")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)

                PremiumFeatureRow(icon: "infinity", title: "Unlimited Meditations", description: "Access all guided sessions")
                PremiumFeatureRow(icon: "moon.stars.fill", title: "All Sleep Stories", description: "100+ sleep stories & soundscapes")
                PremiumFeatureRow(icon: "waveform", title: "Calming Soundscapes", description: "Relaxing ambient sounds")
                PremiumFeatureRow(icon: "sparkles", title: "Exclusive Content", description: "Premium-only programs")
            }
            .padding()
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }
}

struct PremiumFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.textPrimary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

#Preview {
    PremiumView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
