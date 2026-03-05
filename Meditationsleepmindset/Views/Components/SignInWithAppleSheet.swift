//
//  SignInWithAppleSheet.swift
//  Meditation Sleep Mindset
//

import SwiftUI
import AuthenticationServices

struct SignInWithAppleSheet: View {
    @ObservedObject var accountService: AccountService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Theme.profileGradient.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: accountService.signInReason.iconName)
                        .font(.system(size: 44))
                        .foregroundStyle(iconColor)
                }

                // Title & Subtitle
                VStack(spacing: 10) {
                    Text(accountService.signInReason.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(accountService.signInReason.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Benefits
                VStack(alignment: .leading, spacing: 12) {
                    BenefitItem(icon: "arrow.triangle.2.circlepath", text: String(localized: "Sync across all your devices"))
                    BenefitItem(icon: "shield.checkered", text: String(localized: "Never lose your progress"))
                    BenefitItem(icon: "lock.fill", text: String(localized: "Private & secure with iCloud"))
                }
                .padding(20)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)

                Spacer()

                // Sign In with Apple Button
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        accountService.handleSignIn(result: authorization)
                        dismiss()
                    case .failure:
                        // User cancelled or sign-in failed
                        break
                    }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)

                // Not Now
                Button {
                    accountService.recordPromptDismissed()
                    dismiss()
                } label: {
                    Text(String(localized: "Not Now"))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }

                // Privacy note
                Text("Your data stays private in your personal iCloud")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: sizeClass == .regular ? 500 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.profileGradient)
    }

    private var iconColor: Color {
        switch accountService.signInReason {
        case .streak: return .orange
        case .sessions: return .green
        case .multiDevice: return .blue
        case .favorites: return .pink
        case .manual: return Theme.profileAccent
        }
    }
}

// MARK: - Benefit Item
private struct BenefitItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            Spacer()
        }
    }
}
