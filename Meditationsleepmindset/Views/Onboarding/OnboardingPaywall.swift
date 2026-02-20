//
//  OnboardingPaywall.swift
//  Meditation Sleep Mindset
//

import SwiftUI
import StoreKit

enum OnboardingSubscriptionPlan: String, CaseIterable, Identifiable {
    case annual
    case monthly
    case weekly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .annual: return "Annual"
        case .monthly: return "Monthly"
        case .weekly: return "Weekly"
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
        case .annual: return "Just $0.96/week"
        case .monthly: return nil
        case .weekly: return nil
        }
    }

    var badge: String? {
        switch self {
        case .annual: return "BEST VALUE"
        case .monthly: return "MOST POPULAR"
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

struct OnboardingPaywall: View {
    let painPoint: PainPoint
    let goals: Set<OnboardingGoal>
    let onSubscribe: () -> Void
    let onRestore: () -> Void
    let onDismiss: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isRegular: Bool { sizeClass == .regular }

    @StateObject private var storeManager = StoreManager.shared
    @State private var selectedPlan: OnboardingSubscriptionPlan = .annual
    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfService = false
    @State private var animateFeatures = false
    @State private var countdownSeconds: Int = 86400 // 24 hours
    @State private var countdownTimer: Timer?
    @State private var previewIndex = 0

    // Personalized headline based on goals
    private var personalizedHeadline: String {
        if goals.contains(.improveMindset) {
            return "Transform your mindset, transform your life"
        } else if goals.contains(.fallAsleep) && goals.contains(.wakeRefreshed) {
            return "Fall asleep faster and wake up refreshed"
        } else if goals.contains(.fallAsleep) || goals.contains(.stayAsleep) {
            return "Finally get the sleep you deserve"
        } else if goals.contains(.reduceStress) {
            return "Find calm in just minutes a day"
        } else if goals.contains(.buildHabit) {
            return "Build habits that transform your life"
        } else {
            return "Your journey to inner peace starts now"
        }
    }

    // Feature preview cards
    private let previewCards: [(image: String, title: String, description: String)] = [
        ("moon.stars.fill", "100+ Sleep Stories & Soundscapes", "Drift off with narrated stories, ASMR, rain, ocean waves & more"),
        ("sparkles", "AI-Personalized Meditations", "Custom meditations generated just for you — any mood, any length"),
        ("bolt.heart.fill", "Micro-Moments & Breathing", "Quick 1-3 minute resets, body scans & guided breathing exercises"),
        ("arrow.down.circle.fill", "Offline Packs & Watch App", "Download content for offline use and meditate from your wrist"),
        ("brain.head.profile", "Mindset Coaching & Programs", "Multi-day guided programs and daily mindset coaching"),
        ("bubble.left.and.text.bubble.right.fill", "AI Wellness Companion", "Chat with Breathe AI for personalized emotional support 24/7")
    ]

    // Before/after metrics
    private let beforeAfterItems: [(label: String, before: String, after: String, icon: String)] = [
        ("Sleep Quality", "Poor", "Great", "moon.fill"),
        ("Stress Level", "High", "Low", "heart.fill"),
        ("Daily Streak", "0 days", "30 days", "flame.fill"),
        ("Focus", "Scattered", "Sharp", "target"),
        ("Mindfulness", "Never", "Daily", "brain.head.profile")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        // Urgency countdown banner
                        urgencyBanner

                        // Feature preview cards (swipeable)
                        featurePreviewSection

                        // Header text
                        VStack(spacing: 10) {
                            Text("Unlock Your Full Potential")
                                .font(isRegular ? .title : .title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)

                            Text(personalizedHeadline)
                                .font(isRegular ? .body : .subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
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
                            ForEach(OnboardingSubscriptionPlan.allCases) { plan in
                                OnboardingPlanOptionView(
                                    plan: plan,
                                    product: storeKitProduct(for: plan),
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
                            Task {
                                if let product = storeKitProduct(for: selectedPlan) ?? storeManager.subscriptions.first {
                                    await storeManager.purchase(product)
                                }
                                onSubscribe()
                            }
                        } label: {
                            HStack {
                                if storeManager.isPurchasing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    VStack(spacing: 2) {
                                        Text("Start My 3-Day Free Trial")
                                            .fontWeight(.semibold)
                                        Text(selectedPlanPriceDescription)
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
                        }
                        .disabled(storeManager.isPurchasing)
                        .padding(.horizontal, 24)

                        // Auto-renewal terms (Apple requirement)
                        Text(subscriptionTermsText)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        // Trust signals
                        VStack(spacing: 12) {
                            Text("Cancel anytime · No commitment")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))

                            Button("Restore Purchase") {
                                Task {
                                    await storeManager.restorePurchases()
                                }
                                onRestore()
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
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        animateFeatures = true
                    }
                    startCountdown()
                }
                .onDisappear {
                    countdownTimer?.invalidate()
                    countdownTimer = nil
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
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

        // Use a stored expiry so it persists across views
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

    // MARK: - StoreKit Price Helpers

    private func storeKitProduct(for plan: OnboardingSubscriptionPlan) -> Product? {
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

    private var selectedPlanPriceDescription: String {
        if let product = storeKitProduct(for: selectedPlan) {
            let period: String
            switch product.subscription?.subscriptionPeriod.unit {
            case .year: period = "year"
            case .month: period = "month"
            case .week: period = "week"
            default: period = "period"
            }
            return "then \(product.displayPrice)/\(period), auto-renews"
        }
        return "then \(selectedPlan.price), auto-renews"
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
            return "After the 3-day free trial, you will be charged \(product.displayPrice)/\(period). Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Payment is charged to your Apple ID account."
        }
        return "Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Payment is charged to your Apple ID account."
    }

    // MARK: - Feature Preview Cards

    private var featurePreviewSection: some View {
        TabView(selection: $previewIndex) {
            ForEach(Array(previewCards.enumerated()), id: \.offset) { index, card in
                VStack(spacing: isRegular ? 16 : 12) {
                    ZStack {
                        Circle()
                            .fill(Theme.profileAccent.opacity(0.2))
                            .frame(width: isRegular ? 80 : 64, height: isRegular ? 80 : 64)

                        Image(systemName: card.image)
                            .font(.system(size: isRegular ? 36 : 28))
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
                        .font(isRegular ? .title3 : .headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text(card.description)
                        .font(isRegular ? .body : .subheadline)
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
        .frame(height: isRegular ? 260 : 200)
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

struct OnboardingPlanOptionView: View {
    let plan: OnboardingSubscriptionPlan
    var product: Product? = nil
    let isSelected: Bool
    let action: () -> Void

    private var displayPrice: String {
        guard let product else { return plan.price }
        let period: String
        switch product.subscription?.subscriptionPeriod.unit {
        case .year: period = "year"
        case .month: period = "month"
        case .week: period = "week"
        default: period = "period"
        }
        return "\(product.displayPrice)/\(period)"
    }

    private var displaySubtitle: String? {
        if plan == .annual, let product {
            let weeklyPrice = product.price / 52
            let formatted = weeklyPrice.formatted(.currency(code: product.priceFormatStyle.currencyCode))
            return "Just \(formatted)/week"
        }
        return plan.subtitle
    }

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
                                .foregroundStyle(plan == .annual ? .black : .white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(plan == .annual ? .white : Theme.profileAccent)
                                .clipShape(Capsule())
                        }
                    }

                    if let subtitle = displaySubtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(displayPrice)
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

#Preview {
    OnboardingPaywall(
        painPoint: .sleep,
        goals: [.fallAsleep, .wakeRefreshed],
        onSubscribe: {},
        onRestore: {},
        onDismiss: {}
    )
}
