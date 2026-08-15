//
//  BreathGuideOverlay.swift
//  Meditation Sleep Mindset
//
//  "Breathe with me" overlay shown on top of the player while a
//  session plays. Guides a calm 4-1-6 breathing cycle with a softly
//  glowing orb. Audio keeps playing underneath.
//

import SwiftUI

struct BreathGuideOverlay: View {
    let accentColor: Color
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum BreathPhase {
        case breatheIn
        case hold
        case breatheOut

        var label: String {
            switch self {
            case .breatheIn: return "Breathe in"
            case .hold: return "Hold"
            case .breatheOut: return "Breathe out"
            }
        }

        var duration: TimeInterval {
            switch self {
            case .breatheIn: return 4
            case .hold: return 1
            case .breatheOut: return 6
            }
        }

        var next: BreathPhase {
            switch self {
            case .breatheIn: return .hold
            case .hold: return .breatheOut
            case .breatheOut: return .breatheIn
            }
        }
    }

    @State private var phase: BreathPhase = .breatheIn
    @State private var orbScale: CGFloat = 0.62
    @State private var breathTask: Task<Void, Never>?

    private let expandedScale: CGFloat = 1.0
    private let contractedScale: CGFloat = 0.62

    var body: some View {
        ZStack {
            // Dark scrim; tapping anywhere closes
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticManager.light()
                    onClose()
                }
                .accessibilityLabel("Close breathing guide")
                .accessibilityAddTraits(.isButton)

            VStack(spacing: 40) {
                Spacer()

                orb

                Text(phase.label)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.5), value: phase)
                    .accessibilityLabel(phase.label)

                Spacer()

                Text("Audio keeps playing")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 28)
            }
            // Let taps pass through the VStack's clear areas to the scrim,
            // but keep the orb/labels non-interactive so taps close.
            .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                HapticManager.light()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Close breathing guide")
            .padding(.trailing, 20)
            // The player ZStack ignores safe areas — align with the player's
            // own nav bar so the button clears the Dynamic Island/status bar.
            .padding(.top, 62)
        }
        .onAppear { startBreathing() }
        .onDisappear { stopBreathing() }
    }

    // MARK: - Orb

    private var orb: some View {
        ZStack {
            // Outer soft glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accentColor.opacity(0.35), .clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)

            // Middle ring
            Circle()
                .strokeBorder(accentColor.opacity(0.35), lineWidth: 1.5)
                .frame(width: 220, height: 220)

            // Core orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accentColor.opacity(0.9),
                            accentColor.opacity(0.45),
                            accentColor.opacity(0.12),
                        ],
                        center: .center,
                        startRadius: 6,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .shadow(color: accentColor.opacity(0.5), radius: 30)
        }
        .scaleEffect(reduceMotion ? 0.85 : orbScale)
        .accessibilityHidden(true)
    }

    // MARK: - Breathing Loop

    private func startBreathing() {
        stopBreathing()
        breathTask = Task {
            while !Task.isCancelled {
                // Animate the orb for the current phase (labels crossfade
                // via the phase change; orb stays static under reduce motion).
                applyOrbAnimation(for: phase)

                let nanoseconds = UInt64(phase.duration * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                if Task.isCancelled { return }

                phase = phase.next
                HapticManager.light()
            }
        }
    }

    private func stopBreathing() {
        breathTask?.cancel()
        breathTask = nil
    }

    private func applyOrbAnimation(for phase: BreathPhase) {
        guard !reduceMotion else { return }
        switch phase {
        case .breatheIn:
            withAnimation(.easeInOut(duration: phase.duration)) {
                orbScale = expandedScale
            }
        case .hold:
            break // Stay expanded
        case .breatheOut:
            withAnimation(.easeInOut(duration: phase.duration)) {
                orbScale = contractedScale
            }
        }
    }
}
