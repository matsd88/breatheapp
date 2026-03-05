//
//  OnboardingWelcomeView.swift
//  Meditation Sleep Mindset
//

import SwiftUI

enum PainPoint: String, CaseIterable {
    case sleep = "I can't sleep"
    case anxiety = "I feel anxious"
    case racing = "My mind won't stop"
    case calm = "I want to feel calmer"
    case other = "Just exploring"

    var displayName: String {
        switch self {
        case .sleep: return String(localized: "I can't sleep")
        case .anxiety: return String(localized: "I feel anxious")
        case .racing: return String(localized: "My mind won't stop")
        case .calm: return String(localized: "I want to feel calmer")
        case .other: return String(localized: "Just exploring")
        }
    }

    var emoji: String {
        switch self {
        case .sleep: return "😴"
        case .anxiety: return "😰"
        case .racing: return "🧠"
        case .calm: return "✨"
        case .other: return "🌿"
        }
    }

    var headline: String {
        switch self {
        case .sleep: return String(localized: "Better sleep starts tonight")
        case .anxiety: return String(localized: "Find your calm in minutes")
        case .racing: return String(localized: "Quiet the mental chatter")
        case .calm: return String(localized: "Peace is closer than you think")
        case .other: return String(localized: "Discover what works for you")
        }
    }
}

struct OnboardingWelcomeView: View {
    @Binding var selectedPainPoint: PainPoint?
    let onContinue: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var breatheScale: CGFloat = 1.0
    @State private var showContent = false
    @State private var glowOpacity: Double = 0.3
    @State private var particleOffset: CGFloat = 0

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        ZStack {
            // Animated breathing background
            Theme.profileGradient
                .ignoresSafeArea()

            // Floating particles/stars in background
            GeometryReader { geometry in
                ForEach(0..<12, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.1...0.3)))
                        .frame(width: CGFloat.random(in: 2...6))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat(index) * 40 + particleOffset
                        )
                        .blur(radius: 1)
                }
            }
            .opacity(showContent ? 1 : 0)

            // Large breathing glow circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Theme.profileAccent.opacity(0.3),
                            Theme.profileAccent.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .scaleEffect(breatheScale)
                .opacity(glowOpacity)
                .offset(y: -100)

            VStack(spacing: isRegular ? 36 : 24) {
                Spacer()

                // Logo with glow effect
                ZStack {
                    // Outer glow rings
                    Circle()
                        .stroke(Theme.profileAccent.opacity(0.2), lineWidth: 2)
                        .frame(width: isRegular ? 180 : 140, height: isRegular ? 180 : 140)
                        .scaleEffect(breatheScale)

                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        .frame(width: isRegular ? 220 : 180, height: isRegular ? 220 : 180)
                        .scaleEffect(breatheScale * 0.95)

                    // Inner glowing circle
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
                                endRadius: isRegular ? 80 : 60
                            )
                        )
                        .frame(width: isRegular ? 160 : 120, height: isRegular ? 160 : 120)

                }
                .opacity(showContent ? 1 : 0)
                .scaleEffect(showContent ? 1 : 0.8)

                // Welcome text
                VStack(spacing: isRegular ? 8 : 4) {
                    Text("Welcome to")
                        .font(isRegular ? .title2 : .title3)
                        .foregroundStyle(.white.opacity(0.7))

                    Text("Breathe")
                        .font(.system(size: isRegular ? 54 : 42, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Take a deep breath....")
                        .font(isRegular ? .title3 : .body)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 2)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)

                // Pain point question
                VStack(spacing: isRegular ? 16 : 12) {
                    Text("What brings you here today?")
                        .font(isRegular ? .title3 : .headline)
                        .foregroundStyle(.white)
                        .padding(.bottom, 4)

                    ForEach(PainPoint.allCases, id: \.self) { painPoint in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                selectedPainPoint = painPoint
                            }
                            // Brief delay then continue
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onContinue()
                            }
                        } label: {
                            HStack(spacing: isRegular ? 16 : 12) {
                                Text(painPoint.emoji)
                                    .font(isRegular ? .title : .title2)

                                Text(painPoint.displayName)
                                    .font(isRegular ? .title3 : .body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)

                                Spacer()

                                if selectedPainPoint == painPoint {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.white)
                                        .font(isRegular ? .title2 : .body)
                                }
                            }
                            .padding(isRegular ? 18 : 16)
                            .background(
                                RoundedRectangle(cornerRadius: isRegular ? 16 : 12)
                                    .fill(selectedPainPoint == painPoint ?
                                          Color.white.opacity(0.15) :
                                          Theme.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: isRegular ? 16 : 12)
                                    .stroke(selectedPainPoint == painPoint ?
                                            Color.white.opacity(0.5) : Color.clear,
                                            lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, isRegular ? 32 : 24)
                .padding(.top, 15)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)

                Spacer()
            }
            .frame(maxWidth: isRegular ? 800 : 500)
        }
        .onAppear {
            // Start breathing animation
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                breatheScale = 1.15
            }
            // Glow pulsing animation
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                glowOpacity = 0.6
            }
            // Particle floating animation
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                particleOffset = 500
            }
            // Fade in content
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                showContent = true
            }
        }
    }
}

#Preview {
    OnboardingWelcomeView(
        selectedPainPoint: .constant(nil),
        onContinue: {}
    )
}
