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
                PremiumPaywallView(storeManager: storeManager, showDismissButton: false)
                    .frame(maxWidth: 700)
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Premium")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Premium Paywall (Matches Onboarding Paywall)
struct PremiumPaywallView: View {
    @ObservedObject var storeManager: StoreManager
    var sessionLimitMessage: String? = nil
    var onSubscribed: (() -> Void)? = nil
    var showDismissButton: Bool = true
    @State private var selectedPlan: PremiumSubscriptionPlan = .annual
    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfService = false
    @State private var animateFeatures = false
    @State private var countdownSeconds: Int = 86400
    @State private var countdownTimer: Timer?
    @State private var previewIndex = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }

    // Feature preview cards
    private var previewCards: [(image: String, title: String, description: String)] {[
        ("moon.stars.fill", String(localized: "100+ Sleep Stories"), String(localized: "Drift off with narrated stories designed for deep sleep")),
        ("waveform.path.ecg", String(localized: "Guided Meditations"), String(localized: "Sessions from 3 to 60 minutes for every mood")),
        ("music.note.list", String(localized: "Calming Soundscapes"), String(localized: "Rain, ocean waves, forest — mix your own")),
        ("brain.head.profile", String(localized: "Mindset Coaching"), String(localized: "Daily coaching to build resilience and positivity"))
    ]}

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

                // Urgency countdown banner
                urgencyBanner

                // Header text
                VStack(spacing: 10) {
                    Text("Unlock Your Full Potential")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    if let message = sessionLimitMessage {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    } else {
                        Text("Transform your mind, transform your life")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }

                // Before / After comparison
                beforeAfterSection

                // Star rating
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
                            storeManager.error = "Unable to load subscription options. Please check your internet connection and try again."
                            storeManager.showError = true
                        }
                    }
                } label: {
                    HStack {
                        if storeManager.isPurchasing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            VStack(spacing: 2) {
                                Text("Start My 7-Day Free Trial")
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

                // Trust signals
                VStack(spacing: 12) {
                    Text("Cancel anytime · No commitment")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))

                    Button("Restore Purchase") {
                        Task {
                            await storeManager.restorePurchases()
                            if storeManager.isSubscribed {
                                onSubscribed?()
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
            FirebaseService.shared.logPaywallViewed(source: "settings")
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
        .alert("Purchase Failed", isPresented: $storeManager.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(storeManager.error ?? "Something went wrong. Please try again.")
        }

            // Dismiss X button (top-right corner)
            if showDismissButton {
                Button {
                    FirebaseService.shared.logPaywallDismissed(source: "settings")
                    SmartRatingManager.recordPaywallDismiss()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
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

        let key = "paywallCountdownExpiry"
        let now = Date()
        if let stored = UserDefaults.standard.object(forKey: key) as? Date, stored > now {
            countdownSeconds = Int(stored.timeIntervalSince(now))
        } else {
            let expiry = now.addingTimeInterval(86400)
            UserDefaults.standard.set(expiry, forKey: key)
            countdownSeconds = 86400
        }

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if countdownSeconds > 0 {
                    countdownSeconds -= 1
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

    var subtitle: String? {
        switch self {
        case .annual: return String(localized: "Just $0.96/week")
        case .monthly: return nil
        case .weekly: return nil
        }
    }

    var badge: String? {
        switch self {
        case .annual: return String(localized: "BEST VALUE")
        case .monthly: return String(localized: "MOST POPULAR")
        case .weekly: return nil
        }
    }

    var discount: String? {
        switch self {
        case .annual: return "-60%"
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
