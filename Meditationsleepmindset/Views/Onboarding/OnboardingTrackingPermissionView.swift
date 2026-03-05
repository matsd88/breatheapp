//
//  OnboardingTrackingPermissionView.swift
//  Meditation Sleep Mindset
//
//  Pre-permission explainer screen for App Tracking Transparency.
//  Shown during onboarding so the ATT system prompt is unmissable.
//  Required to pass App Store Guideline 5.1.2.
//

import SwiftUI
import AppTrackingTransparency

struct OnboardingTrackingPermissionView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var hasRequestedPermission = false

    private var isRegular: Bool { sizeClass == .regular }

    let onContinue: () -> Void
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Theme.profileGradient
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Navigation
                HStack {
                    Button {
                        onBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)

                // Progress indicator
                OnboardingProgressDotsView(current: 5, total: 7)

                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Theme.profileAccent.opacity(0.4),
                                    Theme.profileAccent.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)

                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: isRegular ? 64 : 50, weight: .light))
                        .foregroundStyle(.white)
                        .shadow(color: Theme.profileAccent.opacity(0.5), radius: 10)
                }

                // Headline
                VStack(spacing: isRegular ? 16 : 12) {
                    Text("Your Privacy Matters")
                        .font(isRegular ? .system(size: 44, weight: .bold) : .largeTitle.bold())
                        .foregroundStyle(.white)

                    Text("We'd like to understand which channels\nhelp people discover our app.")
                        .font(isRegular ? .title3 : .body)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }

                // Explanation card
                VStack(alignment: .leading, spacing: 12) {
                    ExplainerRow(icon: "chart.bar.fill", text: "Measure which ads help people find us")
                    ExplainerRow(icon: "sparkles", text: "Improve your app experience")
                    ExplainerRow(icon: "lock.shield.fill", text: "We never sell your personal data")
                }
                .padding()
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)

                Spacer()

                // Buttons
                VStack(spacing: 16) {
                    Button {
                        requestTrackingAndContinue()
                    } label: {
                        Text("Continue")
                            .primaryButton()
                    }

                    Button {
                        requestTrackingAndContinue()
                    } label: {
                        Text("Not Now")
                            .font(isRegular ? .title3 : .body)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: isRegular ? 800 : 500)
        }
    }

    private func requestTrackingAndContinue() {
        guard !hasRequestedPermission else { return }
        hasRequestedPermission = true

        Task {
            // Show the system ATT prompt
            if #available(iOS 14, *) {
                await ATTrackingManager.requestTrackingAuthorization()
            }
            // Enable analytics and start AppsFlyer after ATT resolves
            FirebaseService.shared.enableAnalyticsCollection()
            #if canImport(AppsFlyerLib)
            AppsFlyerLib.shared().start()
            #endif
            onContinue()
        }
    }
}

private struct ExplainerRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Theme.profileAccent)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

#Preview {
    OnboardingTrackingPermissionView(
        onContinue: {},
        onBack: {}
    )
}
