//
//  WatchBreathingView.swift
//  MeditationWatch
//
//  Haptic-guided breathing exercise with visual circle animation
//

import SwiftUI
import WatchKit

struct WatchBreathingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sessionManager: WatchSessionManager

    @State private var selectedTechnique: WatchBreathingTechnique = .boxBreathing
    @State private var isExerciseActive = false
    @State private var isComplete = false
    @State private var isHapticOnlyMode = false // New: haptic-only mode

    var body: some View {
        Group {
            if isComplete {
                CompletionView(
                    technique: selectedTechnique,
                    duration: sessionManager.breathingSessionDuration,
                    onDone: {
                        dismiss()
                    }
                )
            } else if isExerciseActive {
                if isHapticOnlyMode {
                    HapticOnlyBreathingView(
                        technique: selectedTechnique,
                        onComplete: {
                            sessionManager.endBreathingSession()
                            isComplete = true
                        },
                        onCancel: {
                            sessionManager.cancelBreathingSession()
                            isExerciseActive = false
                        }
                    )
                } else {
                    BreathingExerciseView(
                        technique: selectedTechnique,
                        onComplete: {
                            sessionManager.endBreathingSession()
                            isComplete = true
                        },
                        onCancel: {
                            sessionManager.cancelBreathingSession()
                            isExerciseActive = false
                        }
                    )
                }
            } else {
                TechniquePickerView(
                    selectedTechnique: $selectedTechnique,
                    isHapticOnly: $isHapticOnlyMode,
                    onStart: {
                        sessionManager.startBreathingSession()
                        isExerciseActive = true
                    }
                )
            }
        }
        .navigationBarBackButtonHidden(isExerciseActive || isComplete)
    }
}

// MARK: - Technique Picker View

struct TechniquePickerView: View {
    @Binding var selectedTechnique: WatchBreathingTechnique
    @Binding var isHapticOnly: Bool
    let onStart: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Choose Technique")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(WatchBreathingTechnique.allCases) { technique in
                    TechniqueButton(
                        technique: technique,
                        isSelected: selectedTechnique == technique,
                        onTap: {
                            selectedTechnique = technique
                            WKInterfaceDevice.current().play(.click)
                        }
                    )
                }

                // Haptic-only mode toggle
                Button {
                    isHapticOnly.toggle()
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isHapticOnly ? "hand.tap.fill" : "hand.tap")
                            .font(.caption)
                            .foregroundStyle(isHapticOnly ? .cyan : .white.opacity(0.6))

                        Text("Haptic Only")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))

                        Spacer()

                        if isHapticOnly {
                            Image(systemName: "checkmark")
                                .font(.caption2)
                                .foregroundStyle(.cyan)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isHapticOnly ? Color.cyan.opacity(0.15) : Color.white.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)

                if isHapticOnly {
                    Text("Screen dims. Feel the taps.")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.4))
                }

                Button(action: onStart) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start")
                    }
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Breathe")
    }
}

struct TechniqueButton: View {
    let technique: WatchBreathingTechnique
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: technique.icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .cyan : .white.opacity(0.6))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(technique.displayName)
                        .font(.footnote.bold())
                        .foregroundStyle(.white)

                    Text("\(technique.totalDuration)s cycle")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.cyan)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.cyan.opacity(0.2) : Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.cyan.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Breathing Exercise View

struct BreathingExerciseView: View {
    let technique: WatchBreathingTechnique
    let onComplete: () -> Void
    let onCancel: () -> Void

    @State private var currentPhaseIndex = 0
    @State private var countdown: Int = 4
    @State private var circleScale: CGFloat = 0.4
    @State private var cycleCount = 0
    @State private var timer: Timer?
    @State private var glowOpacity: Double = 0.3

    private let totalCycles = 3

    private var currentPhase: WatchBreathPhase? {
        let phases = technique.phases
        guard currentPhaseIndex < phases.count else { return nil }
        return phases[currentPhaseIndex]
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height) - 20

            ZStack {
                // Background glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.cyan.opacity(0.15),
                                Color.cyan.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: size * 0.15,
                            endRadius: size * 0.5
                        )
                    )
                    .frame(width: size, height: size)
                    .scaleEffect(circleScale)
                    .opacity(glowOpacity)

                // Main breathing circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.cyan.opacity(0.15),
                                Color.white.opacity(0.08)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.35
                        )
                    )
                    .frame(width: size * 0.7, height: size * 0.7)
                    .scaleEffect(circleScale)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.cyan.opacity(0.2)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 2
                            )
                            .frame(width: size * 0.7, height: size * 0.7)
                            .scaleEffect(circleScale)
                    )

                // Phase and countdown
                VStack(spacing: 4) {
                    if let phase = currentPhase {
                        Text(phase.name)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Text("\(countdown)")
                        .font(.system(size: 36, weight: .light, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }

                // Cycle indicator
                VStack {
                    Spacer()
                    Text("Cycle \(cycleCount + 1)/\(totalCycles)")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.bottom, 4)
                }

                // Cancel button
                VStack {
                    HStack {
                        Button(action: {
                            stopTimer()
                            onCancel()
                        }) {
                            Image(systemName: "xmark")
                                .font(.caption2.bold())
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    Spacer()
                }
                .padding(8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            startBreathingCycle()
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowOpacity = 0.5
            }
        }
        .onDisappear {
            stopTimer()
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
            cycleCount += 1
            if cycleCount < totalCycles {
                currentPhaseIndex = 0
                runPhase()
            } else {
                // All cycles done
                stopTimer()
                onComplete()
            }
            return
        }

        let phase = phases[currentPhaseIndex]
        countdown = Int(phase.duration)

        // Play haptic for phase transition
        playHaptic(for: phase.hapticType)

        // Animate circle
        withAnimation(.easeInOut(duration: phase.duration)) {
            circleScale = phase.scale
        }

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            if countdown > 1 {
                countdown -= 1
                // Light haptic tick each second
                WKInterfaceDevice.current().play(.click)
            } else {
                t.invalidate()
                currentPhaseIndex += 1
                runPhase()
            }
        }
    }

    private func playHaptic(for type: WatchHapticType) {
        let device = WKInterfaceDevice.current()
        switch type {
        case .start:
            device.play(.start)
        case .stop:
            device.play(.stop)
        case .click:
            device.play(.click)
        case .directionUp:
            device.play(.directionUp)
        case .directionDown:
            device.play(.directionDown)
        case .success:
            device.play(.success)
        case .failure:
            device.play(.failure)
        case .retry:
            device.play(.retry)
        case .notification:
            device.play(.notification)
        }
    }
}

// MARK: - Completion View

struct CompletionView: View {
    let technique: WatchBreathingTechnique
    let duration: Int
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)

            Text("Well done!")
                .font(.headline)
                .foregroundStyle(.white)

            Text(formatDuration(duration) + " of \(technique.displayName)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            Button(action: onDone) {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding()
        .onAppear {
            WKInterfaceDevice.current().play(.success)
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        if seconds >= 60 {
            let minutes = seconds / 60
            let secs = seconds % 60
            if secs > 0 {
                return "\(minutes)m \(secs)s"
            }
            return "\(minutes) min"
        }
        return "\(seconds) sec"
    }
}

// MARK: - Haptic-Only Breathing View

/// A minimal visual interface that relies primarily on haptic feedback.
/// Perfect for meetings, discreet use, or when you want to close your eyes.
struct HapticOnlyBreathingView: View {
    let technique: WatchBreathingTechnique
    let onComplete: () -> Void
    let onCancel: () -> Void

    @State private var currentPhaseIndex = 0
    @State private var countdown: Int = 4
    @State private var cycleCount = 0
    @State private var timer: Timer?
    @State private var isDimmed = true

    private let totalCycles = 3

    private var currentPhase: WatchBreathPhase? {
        let phases = technique.phases
        guard currentPhaseIndex < phases.count else { return nil }
        return phases[currentPhaseIndex]
    }

    var body: some View {
        ZStack {
            // Very dark background
            Color.black.ignoresSafeArea()

            // Minimal info (only visible when tapped)
            VStack(spacing: 16) {
                if !isDimmed {
                    // Only show when tapped
                    if let phase = currentPhase {
                        Text(phase.name)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Text("\(countdown)")
                        .font(.system(size: 48, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .monospacedDigit()

                    Text("Cycle \(cycleCount + 1)/\(totalCycles)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.3))
                }

                // Always-visible subtle indicator
                Circle()
                    .fill(Color.cyan.opacity(isDimmed ? 0.05 : 0.15))
                    .frame(width: 20, height: 20)
                    .scaleEffect(currentPhase?.scale ?? 0.5)
                    .animation(.easeInOut(duration: currentPhase?.duration ?? 4), value: currentPhase?.scale)
            }

            // Cancel gesture area
            VStack {
                HStack {
                    Button(action: {
                        stopTimer()
                        onCancel()
                    }) {
                        Image(systemName: "xmark")
                            .font(.caption2.bold())
                            .foregroundStyle(.white.opacity(0.3))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .opacity(isDimmed ? 0.3 : 1)

                    Spacer()
                }
                Spacer()
            }
            .padding(8)
        }
        .onTapGesture {
            // Toggle visibility on tap
            withAnimation(.easeInOut(duration: 0.3)) {
                isDimmed.toggle()
            }
            // Auto-dim after 2 seconds
            if !isDimmed {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        isDimmed = true
                    }
                }
            }
        }
        .onAppear {
            startBreathingCycle()
        }
        .onDisappear {
            stopTimer()
        }
    }

    // MARK: - Breathing Logic (same as visual version but more haptic feedback)

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
            cycleCount += 1
            if cycleCount < totalCycles {
                currentPhaseIndex = 0
                // Double haptic for new cycle
                WKInterfaceDevice.current().play(.start)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    WKInterfaceDevice.current().play(.start)
                }
                runPhase()
            } else {
                // All cycles done
                stopTimer()
                // Triple haptic for completion
                WKInterfaceDevice.current().play(.success)
                onComplete()
            }
            return
        }

        let phase = phases[currentPhaseIndex]
        countdown = Int(phase.duration)

        // Strong haptic for phase transition
        playHaptic(for: phase.hapticType)

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            if countdown > 1 {
                countdown -= 1
                // Gentle haptic tick each second
                WKInterfaceDevice.current().play(.click)
            } else {
                t.invalidate()
                currentPhaseIndex += 1
                runPhase()
            }
        }
    }

    private func playHaptic(for type: WatchHapticType) {
        let device = WKInterfaceDevice.current()
        switch type {
        case .start:
            device.play(.start)
        case .stop:
            device.play(.stop)
        case .click:
            device.play(.click)
        case .directionUp:
            device.play(.directionUp)
        case .directionDown:
            device.play(.directionDown)
        case .success:
            device.play(.success)
        case .failure:
            device.play(.failure)
        case .retry:
            device.play(.retry)
        case .notification:
            device.play(.notification)
        }
    }
}

#Preview {
    WatchBreathingView()
        .environmentObject(WatchSessionManager.shared)
}
