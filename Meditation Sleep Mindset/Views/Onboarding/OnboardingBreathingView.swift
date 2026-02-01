//
//  OnboardingBreathingView.swift
//  Meditation Sleep Mindset
//

import SwiftUI

// MARK: - Breathing Techniques

enum BreathingTechnique: String, CaseIterable, Identifiable {
    case boxBreathing = "Box Breathing"
    case relaxing = "4-7-8 Relaxing"
    case wimHof = "Wim Hof"
    case alternateNostril = "Alternate Nostril"
    case energizing = "Energizing Breath"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .boxBreathing: return "Equal rhythm for focus & calm"
        case .relaxing: return "Long exhale to slow your heart rate"
        case .wimHof: return "Rapid breaths to energize & reset"
        case .alternateNostril: return "Balanced breathing for harmony"
        case .energizing: return "Quick bursts to boost energy"
        }
    }

    var icon: String {
        switch self {
        case .boxBreathing: return "square"
        case .relaxing: return "wind"
        case .wimHof: return "snowflake"
        case .alternateNostril: return "arrow.left.arrow.right"
        case .energizing: return "bolt.fill"
        }
    }

    var description: String {
        switch self {
        case .boxBreathing: return "Inhale, hold, exhale, and hold — each for 4 seconds. Used by Navy SEALs to stay calm under pressure."
        case .relaxing: return "Inhale for 4, hold for 7, exhale for 8. Activates your parasympathetic nervous system for deep relaxation."
        case .wimHof: return "30 rapid deep breaths followed by a breath hold. Increases oxygen levels and mental clarity."
        case .alternateNostril: return "Breathe in through one nostril, out through the other. Balances left and right brain hemispheres."
        case .energizing: return "Short, powerful exhales with passive inhales. Clears the mind and boosts energy quickly."
        }
    }

    /// Techniques shown during onboarding (subset)
    static var onboardingTechniques: [BreathingTechnique] {
        [.boxBreathing, .relaxing]
    }

    var phases: [BreathPhase] {
        switch self {
        case .boxBreathing:
            return [
                BreathPhase(name: "Breathe in", duration: 4, scale: 1.2),
                BreathPhase(name: "Hold", duration: 4, scale: 1.2),
                BreathPhase(name: "Breathe out", duration: 4, scale: 0.4),
                BreathPhase(name: "Hold", duration: 4, scale: 0.4)
            ]
        case .relaxing:
            return [
                BreathPhase(name: "Breathe in", duration: 4, scale: 1.2),
                BreathPhase(name: "Hold", duration: 7, scale: 1.2),
                BreathPhase(name: "Breathe out", duration: 8, scale: 0.4)
            ]
        case .wimHof:
            return [
                BreathPhase(name: "Breathe in deeply", duration: 2, scale: 1.2),
                BreathPhase(name: "Breathe out", duration: 1, scale: 0.5),
                BreathPhase(name: "Breathe in deeply", duration: 2, scale: 1.2),
                BreathPhase(name: "Breathe out", duration: 1, scale: 0.5),
                BreathPhase(name: "Breathe in deeply", duration: 2, scale: 1.2),
                BreathPhase(name: "Breathe out", duration: 1, scale: 0.5),
                BreathPhase(name: "Hold", duration: 10, scale: 0.3)
            ]
        case .alternateNostril:
            return [
                BreathPhase(name: "Left nostril in", duration: 4, scale: 1.2),
                BreathPhase(name: "Hold", duration: 4, scale: 1.2),
                BreathPhase(name: "Right nostril out", duration: 4, scale: 0.4),
                BreathPhase(name: "Right nostril in", duration: 4, scale: 1.2),
                BreathPhase(name: "Hold", duration: 4, scale: 1.2),
                BreathPhase(name: "Left nostril out", duration: 4, scale: 0.4)
            ]
        case .energizing:
            return [
                BreathPhase(name: "Sharp exhale", duration: 1, scale: 0.4),
                BreathPhase(name: "Passive inhale", duration: 1, scale: 1.0),
                BreathPhase(name: "Sharp exhale", duration: 1, scale: 0.4),
                BreathPhase(name: "Passive inhale", duration: 1, scale: 1.0),
                BreathPhase(name: "Sharp exhale", duration: 1, scale: 0.4),
                BreathPhase(name: "Passive inhale", duration: 1, scale: 1.0),
                BreathPhase(name: "Deep breath in", duration: 3, scale: 1.2),
                BreathPhase(name: "Slow exhale", duration: 4, scale: 0.4)
            ]
        }
    }
}

struct BreathPhase {
    let name: String
    let duration: Double
    let scale: CGFloat
}

// MARK: - Mood Rating

struct OnboardingMoodOption: Identifiable {
    let id = UUID()
    let emoji: String
    let label: String
    let value: Int
}

// MARK: - View

struct OnboardingBreathingView: View {
    let onComplete: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void

    // Stage: 0 = pick technique, 1 = breathing, 2 = mood capture
    @State private var stage = 0
    @State private var selectedTechnique: BreathingTechnique = .boxBreathing

    // Breathing state
    @State private var currentPhaseIndex = 0
    @State private var countdown: Int = 4
    @State private var circleScale: CGFloat = 0.4
    @State private var timer: Timer?
    @State private var glowPulse: Double = 0.3
    @State private var ringRotation: Double = 0

    // Mood capture
    @State private var selectedMood: Int? = nil

    private let moodOptions: [OnboardingMoodOption] = [
        .init(emoji: "😐", label: "Same", value: 1),
        .init(emoji: "🙂", label: "A bit better", value: 2),
        .init(emoji: "😌", label: "Calmer", value: 3),
        .init(emoji: "✨", label: "Refreshed", value: 4),
        .init(emoji: "🧘", label: "Peaceful", value: 5)
    ]

    private var currentPhase: BreathPhase? {
        let phases = selectedTechnique.phases
        guard currentPhaseIndex < phases.count else { return nil }
        return phases[currentPhaseIndex]
    }

    var body: some View {
        ZStack {
            Theme.profileGradient
                .ignoresSafeArea()

            // Ambient floating particles
            GeometryReader { geometry in
                ForEach(0..<8, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.05...0.15)))
                        .frame(width: CGFloat.random(in: 3...8))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                        .blur(radius: 2)
                }
            }

            // Navigation overlay at top
            VStack {
                VStack(spacing: 24) {
                    HStack {
                        Button {
                            if stage == 0 {
                                stopTimer()
                                onBack()
                            } else {
                                withAnimation { stage = 0 }
                                stopTimer()
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                        }

                        Spacer()

                        Button("Skip") {
                            stopTimer()
                            onSkip()
                        }
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 16)

                    // Progress indicator
                    OnboardingProgressDotsView(current: 2, total: 6)
                }

                Spacer()
            }
            .frame(maxWidth: 500)

            // Stage content
            Group {
                switch stage {
                case 0:
                    techniquePickerView
                case 1:
                    breathingView
                default:
                    moodCaptureView
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
        .onDisappear {
            stopTimer()
        }
    }

    // MARK: - Technique Picker (Stage 0)

    private var techniquePickerView: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Choose a technique")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text("We'll guide you through one cycle")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
            }

            VStack(spacing: 12) {
                ForEach(BreathingTechnique.onboardingTechniques) { technique in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTechnique = technique
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: technique.icon)
                                .font(.title2)
                                .foregroundStyle(selectedTechnique == technique ? .white : .white.opacity(0.6))
                                .frame(width: 44)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(technique.rawValue)
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)

                                Text(technique.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }

                            Spacer()

                            Image(systemName: selectedTechnique == technique ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedTechnique == technique ? .white : .white.opacity(0.4))
                                .font(.title3)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedTechnique == technique ? Color.white.opacity(0.15) : Theme.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedTechnique == technique ? Color.white.opacity(0.5) : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Button {
                withAnimation {
                    stage = 1
                }
                startBreathingCycle()
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    glowPulse = 0.6
                }
                withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                    ringRotation = 360
                }
            } label: {
                HStack {
                    Text("Begin")
                    Image(systemName: "arrow.right")
                }
                .primaryButton()
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: 500)
    }

    // MARK: - Breathing View (Stage 1)

    private var breathingView: some View {
        VStack(spacing: 32) {
            // Intro text
            VStack(spacing: 8) {
                Text("Let's take a moment")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text("to breathe together")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.7))
            }

            // Premium breathing circle
            ZStack {
                // Outermost ambient glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Theme.profileAccent.opacity(0.2),
                                Theme.profileAccent.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 80,
                            endRadius: 180
                        )
                    )
                    .frame(width: 360, height: 360)
                    .scaleEffect(circleScale)
                    .opacity(glowPulse)

                // Rotating outer ring
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
                    .frame(width: 240, height: 240)
                    .scaleEffect(circleScale * 1.1)
                    .rotationEffect(.degrees(ringRotation))

                // Middle ring with glow
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    .frame(width: 210, height: 210)
                    .scaleEffect(circleScale * 1.05)

                // Main breathing circle with gradient
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
                            endRadius: 100
                        )
                    )
                    .frame(width: 180, height: 180)
                    .scaleEffect(circleScale)
                    .shadow(color: Theme.profileAccent.opacity(0.3), radius: 30)

                // Inner glowing ring
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
                    .frame(width: 180, height: 180)
                    .scaleEffect(circleScale)

                // Inner circle with text
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
        .frame(maxWidth: 500)
    }

    // MARK: - Mood Capture (Stage 2)

    private var moodCaptureView: some View {
        VStack {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)

                Text("How do you feel?")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("That was just a few seconds.\nImagine what a few minutes could do.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)

                // Mood selector row
                HStack(spacing: 16) {
                    ForEach(moodOptions) { mood in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                selectedMood = mood.value
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Text(mood.emoji)
                                    .font(.system(size: 36))

                                Text(mood.label)
                                    .font(.caption2)
                                    .foregroundStyle(selectedMood == mood.value ? .white : .white.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedMood == mood.value ? Color.white.opacity(0.15) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedMood == mood.value ? Color.white.opacity(0.5) : Color.clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            Spacer()

            Button {
                // Save mood for potential use in personalized summary
                if let mood = selectedMood {
                    UserDefaults.standard.set(mood, forKey: "onboardingPostBreathMood")
                }
                onComplete()
            } label: {
                HStack {
                    Text("Continue")
                    Image(systemName: "arrow.right")
                }
                .primaryButton()
            }
            .disabled(selectedMood == nil)
            .opacity(selectedMood == nil ? 0.5 : 1)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: 500)
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
        let phases = selectedTechnique.phases
        guard currentPhaseIndex < phases.count else {
            // Cycle done — go to mood capture
            withAnimation(.spring()) {
                stage = 2
            }
            return
        }

        let phase = phases[currentPhaseIndex]
        countdown = Int(phase.duration)

        withAnimation(.easeInOut(duration: phase.duration)) {
            circleScale = phase.scale
        }

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            if countdown > 1 {
                countdown -= 1
            } else {
                t.invalidate()
                currentPhaseIndex += 1
                runPhase()
            }
        }
    }
}

#Preview {
    OnboardingBreathingView(
        onComplete: {},
        onBack: {},
        onSkip: {}
    )
}
