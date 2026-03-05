//
//  ClipBreathingView.swift
//  MeditationClip
//
//  Standalone breathing exercise for the App Clip.
//  Adapted from BreathingExerciseView.swift — no SwiftData, no StreakService.
//

import SwiftUI

struct ClipBreathingView: View {
    let technique: BreathingTechnique
    var totalCycles: Int = 3

    @Environment(\.dismiss) private var dismiss

    @State private var currentPhaseIndex = 0
    @State private var currentCycle = 0
    @State private var countdown: Int = 4
    @State private var circleScale: CGFloat = 0.4
    @State private var timer: Timer?
    @State private var glowPulse: Double = 0.3
    @State private var ringRotation: Double = 0
    @State private var isComplete = false
    @State private var particlePositions: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = []

    private var currentPhase: BreathPhase? {
        let phases = technique.phases
        guard currentPhaseIndex < phases.count else { return nil }
        return phases[currentPhaseIndex]
    }

    var body: some View {
        ZStack {
            Theme.profileGradient
                .ignoresSafeArea()

            // Ambient particles
            GeometryReader { geometry in
                ForEach(Array(particlePositions.enumerated()), id: \.offset) { _, particle in
                    Circle()
                        .fill(Color.white.opacity(particle.opacity))
                        .frame(width: particle.size)
                        .position(x: particle.x, y: particle.y)
                        .blur(radius: 2)
                }
                .onAppear {
                    if particlePositions.isEmpty {
                        particlePositions = (0..<8).map { _ in
                            (
                                x: CGFloat.random(in: 0...geometry.size.width),
                                y: CGFloat.random(in: 0...geometry.size.height),
                                size: CGFloat.random(in: 3...8),
                                opacity: Double.random(in: 0.05...0.15)
                            )
                        }
                    }
                }
            }

            if isComplete {
                completionView
            } else {
                breathingView
            }

            // Top bar
            VStack {
                HStack {
                    Button {
                        stopTimer()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 30, height: 30)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Spacer()

                    if !isComplete {
                        Text("Cycle \(currentCycle + 1) of \(totalCycles)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()
            }
        }
        .onAppear {
            startBreathingCycle()
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                glowPulse = 0.6
            }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
        }
        .onDisappear {
            stopTimer()
        }
    }

    // MARK: - Breathing View

    private var breathingView: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text(technique.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text("Follow the circle")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
            }

            let baseSize: CGFloat = 360
            let ringSize: CGFloat = 240
            let innerRingSize: CGFloat = 210
            let coreSize: CGFloat = 180

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Theme.profileAccent.opacity(0.2),
                                Theme.profileAccent.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: baseSize * 0.22,
                            endRadius: baseSize * 0.5
                        )
                    )
                    .frame(width: baseSize, height: baseSize)
                    .scaleEffect(circleScale)
                    .opacity(glowPulse)

                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                Theme.profileAccent.opacity(0.5),
                                Theme.profileAccent.opacity(0.1),
                                Color.white.opacity(0.2),
                                Theme.profileAccent.opacity(0.1),
                                Theme.profileAccent.opacity(0.5)
                            ],
                            center: .center
                        ),
                        lineWidth: 2
                    )
                    .frame(width: ringSize, height: ringSize)
                    .scaleEffect(circleScale * 1.1)
                    .rotationEffect(.degrees(ringRotation))

                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    .frame(width: innerRingSize, height: innerRingSize)
                    .scaleEffect(circleScale * 1.05)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Theme.profileAccent.opacity(0.15),
                                Color.white.opacity(0.08)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: coreSize * 0.56
                        )
                    )
                    .frame(width: coreSize, height: coreSize)
                    .scaleEffect(circleScale)
                    .shadow(color: Theme.profileAccent.opacity(0.3), radius: 30)

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
                    .frame(width: coreSize, height: coreSize)
                    .scaleEffect(circleScale)

                VStack(spacing: 8) {
                    if let phase = currentPhase {
                        Text(phase.name)
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                    }

                    Text("\(countdown)")
                        .font(.system(size: 48, weight: .light, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Well done!")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Text("\(totalCycles) cycles of \(technique.displayName) complete")
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))

            Spacer()

            VStack(spacing: 12) {
                Button {
                    openAppStore()
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.app.fill")
                        Text("Get the Full App")
                    }
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    // Reset and try again
                    isComplete = false
                    currentCycle = 0
                    currentPhaseIndex = 0
                    startBreathingCycle()
                } label: {
                    Text("Try Again")
                        .font(.headline)
                        .foregroundStyle(Theme.profileAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Breathing Logic

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func startBreathingCycle() {
        currentPhaseIndex = 0
        runPhase()
    }

    private func runPhase() {
        let phases = technique.phases
        guard currentPhaseIndex < phases.count else {
            // Cycle complete
            currentCycle += 1
            if currentCycle < totalCycles {
                currentPhaseIndex = 0
                runPhase()
            } else {
                HapticManager.success()
                withAnimation(.spring()) {
                    isComplete = true
                }
            }
            return
        }

        guard let phase = phases[safe: currentPhaseIndex] else { return }
        countdown = Int(phase.duration)

        HapticManager.medium()

        withAnimation(.easeInOut(duration: phase.duration)) {
            circleScale = phase.scale
        }

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            Task { @MainActor in
                if countdown > 1 {
                    countdown -= 1
                } else {
                    t.invalidate()
                    timer = nil
                    currentPhaseIndex += 1
                    runPhase()
                }
            }
        }
    }

    private func openAppStore() {
        let appStoreURL = URL(string: "https://apps.apple.com/app/id6758229420")!
        UIApplication.shared.open(appStoreURL)
    }
}
