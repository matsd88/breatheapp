//
//  HapticBreathingView.swift
//  Meditation Sleep Mindset
//
//  Immersive, haptic-guided breathing. A calming orb expands and contracts in sync
//  with rich haptic pulses so you can breathe with your eyes closed — inspired by
//  multisensory "immersive" meditations.
//

import SwiftUI
import CoreHaptics

// MARK: - Breathing Pattern

struct BreathingPattern: Identifiable, Equatable {
    let id: String
    let name: String
    let inhale: Double
    let holdFull: Double
    let exhale: Double
    let holdEmpty: Double

    static let box = BreathingPattern(id: "box", name: "Box (4-4-4-4)", inhale: 4, holdFull: 4, exhale: 4, holdEmpty: 4)
    static let relaxing = BreathingPattern(id: "478", name: "Relaxing (4-7-8)", inhale: 4, holdFull: 7, exhale: 8, holdEmpty: 0)
    static let calm = BreathingPattern(id: "calm", name: "Calm (4-2-6)", inhale: 4, holdFull: 2, exhale: 6, holdEmpty: 0)

    static let all: [BreathingPattern] = [.calm, .box, .relaxing]
}

enum HapticBreathPhase: Equatable {
    case inhale, holdFull, exhale, holdEmpty

    var label: String {
        switch self {
        case .inhale: return "Breathe in"
        case .holdFull: return "Hold"
        case .exhale: return "Breathe out"
        case .holdEmpty: return "Rest"
        }
    }
}

// MARK: - Haptic Breathing Engine

@MainActor
final class HapticBreathingEngine: ObservableObject {
    @Published var phase: HapticBreathPhase = .inhale
    @Published var phaseDuration: Double = 4
    @Published var isRunning = false
    @Published var cyclesCompleted = 0

    var pattern: BreathingPattern = .calm

    private var engine: CHHapticEngine?
    private var phaseTask: Task<Void, Never>?

    func start() {
        guard !isRunning else { return }
        isRunning = true
        cyclesCompleted = 0
        prepareHaptics()
        runLoop()
    }

    func stop() {
        isRunning = false
        phaseTask?.cancel()
        phaseTask = nil
        engine?.stop()
    }

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            engine?.isAutoShutdownEnabled = true
            try engine?.start()
        } catch {
            engine = nil
        }
    }

    private func runLoop() {
        phaseTask?.cancel()
        phaseTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled, self.isRunning {
                await self.runPhase(.inhale, duration: self.pattern.inhale)
                if self.pattern.holdFull > 0 { await self.runPhase(.holdFull, duration: self.pattern.holdFull) }
                await self.runPhase(.exhale, duration: self.pattern.exhale)
                if self.pattern.holdEmpty > 0 { await self.runPhase(.holdEmpty, duration: self.pattern.holdEmpty) }
                if !Task.isCancelled, self.isRunning { self.cyclesCompleted += 1 }
            }
        }
    }

    private func runPhase(_ phase: HapticBreathPhase, duration: Double) async {
        guard duration > 0, isRunning else { return }
        self.phase = phase
        self.phaseDuration = duration
        playHaptic(for: phase, duration: duration)
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    }

    // MARK: - Haptics

    private func playHaptic(for phase: HapticBreathPhase, duration: Double) {
        // Respect the user's global haptics setting.
        guard HapticManager.isEnabled else { return }
        guard let engine else {
            // Fallback: simple transition tap.
            HapticManager.light()
            return
        }

        var events: [CHHapticEvent] = []
        switch phase {
        case .inhale:
            // Rising intensity over the inhale.
            for i in stride(from: 0.0, to: duration, by: 0.2) {
                let intensity = Float(0.2 + 0.6 * (i / duration))
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                    ],
                    relativeTime: i
                ))
            }
        case .exhale:
            // Falling intensity over the exhale.
            for i in stride(from: 0.0, to: duration, by: 0.2) {
                let intensity = Float(0.8 - 0.6 * (i / duration))
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: max(0.15, intensity)),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                    ],
                    relativeTime: i
                ))
            }
        case .holdFull, .holdEmpty:
            // Single soft marker at the start of the hold.
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0
            ))
        }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // Ignore haptic failures — the visual guide still works.
        }
    }
}

// MARK: - View

struct HapticBreathingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var engine = HapticBreathingEngine()
    @State private var selectedPattern: BreathingPattern = .calm
    @State private var orbScale: CGFloat = 0.6

    private var isRegular: Bool { sizeClass == .regular }
    private var orbOuter: CGFloat { isRegular ? 440 : 300 }
    private var orbInner: CGFloat { isRegular ? 300 : 200 }

    var body: some View {
        ZStack {
            Theme.profileGradient.ignoresSafeArea()

            VStack(spacing: 32) {
                // Close
                HStack {
                    Spacer()
                    Button {
                        engine.stop()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                // Breathing orb
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Theme.profileAccent.opacity(0.5), Theme.profileAccent.opacity(0.05)],
                                center: .center, startRadius: 10, endRadius: isRegular ? 230 : 160
                            )
                        )
                        .frame(width: orbOuter, height: orbOuter)
                        .scaleEffect(orbScale)
                        .blur(radius: 8)

                    Circle()
                        .fill(Theme.profileAccent.opacity(0.25))
                        .frame(width: orbInner, height: orbInner)
                        .scaleEffect(orbScale)

                    Text(engine.isRunning ? engine.phase.label : "Ready")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .animation(.easeInOut(duration: engine.phaseDuration), value: orbScale)

                Spacer()

                if engine.isRunning {
                    Text("\(engine.cyclesCompleted) breath\(engine.cyclesCompleted == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                } else {
                    // Pattern picker (only before starting) — scrollable so long labels never clip on narrow phones.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(BreathingPattern.all) { pattern in
                                Button {
                                    HapticManager.selection()
                                    selectedPattern = pattern
                                } label: {
                                    Text(pattern.name)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(selectedPattern == pattern ? .white : .white.opacity(0.6))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule().fill(selectedPattern == pattern ? Theme.profileAccent.opacity(0.8) : Color.white.opacity(0.08))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Start / stop
                Button {
                    if engine.isRunning {
                        engine.stop()
                    } else {
                        engine.pattern = selectedPattern
                        engine.start()
                    }
                } label: {
                    Text(engine.isRunning ? "End Session" : "Begin")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .frame(maxWidth: 460)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: isRegular ? 600 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: engine.phase) { _, phase in
            withAnimation(.easeInOut(duration: engine.phaseDuration)) {
                switch phase {
                case .inhale, .holdFull: orbScale = 1.15
                case .exhale, .holdEmpty: orbScale = 0.6
                }
            }
        }
        .onDisappear { engine.stop() }
    }
}

#Preview {
    HapticBreathingView()
}
