//
//  PremiumUpsellBanner.swift
//  Meditation Sleep Mindset
//
//  Shared premium upsell banner (Home + You tab + Settings). A rich but calm
//  gradient card: crown badge, personalized hook line, four feature
//  glances, and a single clear CTA. Purely a label — callers decide how
//  it presents the paywall (NavigationLink, sheet, …).
//

import SwiftUI

struct PremiumUpsellBanner: View {
    /// Optional personalized hook ("Keep your 6-day streak growing").
    /// Falls back to a calm default.
    var hook: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: crown badge + title + hook
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.16))
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.85, blue: 0.4), Color(red: 0.98, green: 0.68, blue: 0.25)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Breathe Premium")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)

                    Text(hook ?? String(localized: "Everything unlocked. Calm on tap."))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            // Feature glances
            HStack(spacing: 0) {
                featureGlance(icon: "sparkles", label: String(localized: "AI Studio"))
                featureGlance(icon: "books.vertical.fill", label: String(localized: "Full library"))
                featureGlance(icon: "arrow.down.circle.fill", label: String(localized: "Offline"))
                featureGlance(icon: "waveform", label: String(localized: "Real voices"))
            }
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // CTA
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Text("Try 7 Days Free")
                        .font(.subheadline.weight(.bold))
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(Color(red: 0.2, green: 0.13, blue: 0.45))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(.white)
                .clipShape(Capsule())

                Text("Cancel anytime in the App Store")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(18)
        .background(
            ZStack {
                // Base gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.38, green: 0.27, blue: 0.78),
                        Color(red: 0.24, green: 0.17, blue: 0.55)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Static soft glows for depth (rendered once — no animation cost)
                Circle()
                    .fill(Color(red: 0.55, green: 0.45, blue: 1.0).opacity(0.35))
                    .frame(width: 180, height: 180)
                    .blur(radius: 40)
                    .offset(x: 120, y: -70)

                Circle()
                    .fill(Color(red: 0.2, green: 0.6, blue: 0.9).opacity(0.25))
                    .frame(width: 160, height: 160)
                    .blur(radius: 45)
                    .offset(x: -130, y: 80)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color(red: 0.3, green: 0.2, blue: 0.7).opacity(0.35), radius: 16, x: 0, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Breathe Premium. \(hook ?? "Everything unlocked."). Try 7 days free.")
        .accessibilityAddTraits(.isButton)
    }

    private func featureGlance(icon: String, label: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ZStack {
        Theme.profileGradient.ignoresSafeArea()
        VStack(spacing: 20) {
            PremiumUpsellBanner()
            PremiumUpsellBanner(hook: "Keep your 6-day streak growing")
        }
        .padding()
    }
}
