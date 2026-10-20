//
//  MicroMomentVisuals.swift
//  Meditation Sleep Mindset
//
//  Time-driven animations for Micro Moments. Every visual is a pure function
//  of elapsed seconds, so pause/resume and paging never desync the guide.
//

import SwiftUI

// MARK: - Breath Pattern

struct BreathPattern {
    enum Kind { case inhale, holdIn, exhale, holdOut }

    struct Phase {
        let kind: Kind
        let label: String
        let seconds: Double
    }

    let phases: [Phase]

    var cycleLength: Double { phases.reduce(0) { $0 + $1.seconds } }

    /// Phase at `elapsed`, plus progress (0...1) through it and a key that
    /// changes every time a new phase starts (used for haptics).
    func state(at elapsed: Double) -> (index: Int, phase: Phase, progress: Double, key: Int) {
        let cycle = Int(elapsed / cycleLength)
        var t = elapsed.truncatingRemainder(dividingBy: cycleLength)
        for (index, phase) in phases.enumerated() {
            if t < phase.seconds || index == phases.count - 1 {
                return (index, phase, min(1, t / phase.seconds), cycle * phases.count + index)
            }
            t -= phase.seconds
        }
        return (0, phases[0], 0, 0)
    }

    /// 0 = empty lungs, 1 = full lungs.
    func fullness(at elapsed: Double) -> Double {
        let s = state(at: elapsed)
        let eased = 0.5 - cos(s.progress * .pi) / 2
        switch s.phase.kind {
        case .inhale: return eased
        case .holdIn: return 1
        case .exhale: return 1 - eased
        case .holdOut: return 0
        }
    }

    /// Progress through the whole cycle (0...1).
    func cycleProgress(at elapsed: Double) -> Double {
        elapsed.truncatingRemainder(dividingBy: cycleLength) / cycleLength
    }

    static let reset44 = BreathPattern(phases: [
        Phase(kind: .inhale, label: "Breathe In", seconds: 4),
        Phase(kind: .exhale, label: "Breathe Out", seconds: 4),
    ])

    static let box = BreathPattern(phases: [
        Phase(kind: .inhale, label: "Inhale", seconds: 4),
        Phase(kind: .holdIn, label: "Hold", seconds: 4),
        Phase(kind: .exhale, label: "Exhale", seconds: 4),
        Phase(kind: .holdOut, label: "Hold", seconds: 4),
    ])

    static let calmingExhale = BreathPattern(phases: [
        Phase(kind: .inhale, label: "Breathe In", seconds: 4),
        Phase(kind: .exhale, label: "Breathe Out", seconds: 8),
    ])

    static let energy = BreathPattern(phases: [
        Phase(kind: .inhale, label: "In", seconds: 1),
        Phase(kind: .exhale, label: "Out", seconds: 1),
    ])

    static let gratitude = BreathPattern(phases: [
        Phase(kind: .inhale, label: "Breathe In", seconds: 4),
        Phase(kind: .exhale, label: "Thank you", seconds: 6),
    ])

    static let shoulderDrop = BreathPattern(phases: [
        Phase(kind: .inhale, label: "Lift your shoulders", seconds: 3),
        Phase(kind: .holdIn, label: "Hold", seconds: 1),
        Phase(kind: .exhale, label: "Let them drop", seconds: 4),
    ])

    static let jawRelease = BreathPattern(phases: [
        Phase(kind: .inhale, label: "Breathe In", seconds: 4),
        Phase(kind: .exhale, label: "Soften your jaw", seconds: 6),
    ])

    static let handStretch = BreathPattern(phases: [
        Phase(kind: .inhale, label: "Stretch wide", seconds: 3),
        Phase(kind: .holdIn, label: "Hold", seconds: 2),
        Phase(kind: .exhale, label: "Relax", seconds: 4),
    ])
}

// MARK: - Visual Kind

enum MomentVisual {
    /// Orb that grows and shrinks with the pattern.
    case pulse(BreathPattern)
    /// Dot tracing a square: inhale, hold, exhale, hold.
    case box
    /// 5-4-3-2-1 senses walkthrough.
    case senses
    /// Fill N steps one after another (e.g. three good things).
    case steps([String])
    /// Calm rings radiating from the icon, instruction shown below.
    case ripple

    /// Changes whenever a new phase or step begins.
    func phaseKey(elapsed: Double, duration: Int) -> Int {
        switch self {
        case .pulse(let pattern): return pattern.state(at: elapsed).key
        case .box: return BreathPattern.box.state(at: elapsed).key
        case .senses: return MomentVisual.stepIndex(elapsed: elapsed, duration: duration, count: 5)
        case .steps(let labels): return MomentVisual.stepIndex(elapsed: elapsed, duration: duration, count: labels.count)
        case .ripple: return 0
        }
    }

    /// The ripple has no instructions of its own, so the card shows the text.
    var showsInstructionWhilePlaying: Bool {
        if case .ripple = self { return true }
        return false
    }

    static func stepIndex(elapsed: Double, duration: Int, count: Int) -> Int {
        guard count > 0, duration > 0 else { return 0 }
        let stepLength = Double(duration) / Double(count)
        return min(count - 1, Int(elapsed / stepLength))
    }
}

// MARK: - Visual View

struct MomentVisualView: View {
    let visual: MomentVisual
    let iconName: String
    let elapsed: Double
    let duration: Int
    let isRegular: Bool

    var body: some View {
        switch visual {
        case .pulse(let pattern):
            PulseVisual(pattern: pattern, iconName: iconName, elapsed: elapsed, isRegular: isRegular)
        case .box:
            BoxBreathingVisual(elapsed: elapsed, isRegular: isRegular)
        case .senses:
            SensesVisual(elapsed: elapsed, duration: duration, isRegular: isRegular)
        case .steps(let labels):
            StepsVisual(labels: labels, iconName: iconName, elapsed: elapsed, duration: duration, isRegular: isRegular)
        case .ripple:
            RippleVisual(iconName: iconName, elapsed: elapsed, isRegular: isRegular)
        }
    }
}

// MARK: - Pulse

private struct PulseVisual: View {
    let pattern: BreathPattern
    let iconName: String
    let elapsed: Double
    let isRegular: Bool

    var body: some View {
        let state = pattern.state(at: elapsed)
        let fullness = pattern.fullness(at: elapsed)
        let size: CGFloat = isRegular ? 300 : 230
        let scale = 0.55 + 0.45 * fullness
        let count = Int(state.progress * state.phase.seconds) + 1

        VStack(spacing: isRegular ? 32 : 24) {
            ZStack {
                // Phase progress ring
                Circle()
                    .stroke(.white.opacity(0.15), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: state.progress)
                    .stroke(.white.opacity(0.8), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Circle()
                    .fill(.white.opacity(0.08))
                    .padding(size * 0.04)
                    .scaleEffect(0.75 + 0.25 * fullness)

                Circle()
                    .fill(.white.opacity(0.18))
                    .padding(size * 0.14)
                    .scaleEffect(scale)

                Circle()
                    .fill(.white.opacity(0.3))
                    .padding(size * 0.26)
                    .scaleEffect(scale)

                Image(systemName: iconName)
                    .font(.system(size: isRegular ? 44 : 34, weight: .medium))
                    .foregroundStyle(.white)
                    .scaleEffect(0.85 + 0.15 * fullness)
            }
            .frame(width: size, height: size)

            VStack(spacing: 6) {
                Text(state.phase.label)
                    .font(isRegular ? .title.weight(.semibold) : .title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: state.key)

                if state.phase.seconds >= 2 {
                    Text("\(count)")
                        .font(.system(size: isRegular ? 22 : 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .monospacedDigit()
                }
            }
            .frame(height: isRegular ? 80 : 64, alignment: .top)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.phase.label)
    }
}

// MARK: - Box Breathing

private struct BoxBreathingVisual: View {
    let elapsed: Double
    let isRegular: Bool

    private let pattern = BreathPattern.box

    var body: some View {
        let state = pattern.state(at: elapsed)
        let side: CGFloat = isRegular ? 260 : 200
        let progress = pattern.cycleProgress(at: elapsed)
        let fullness = pattern.fullness(at: elapsed)
        let count = Int(state.progress * state.phase.seconds) + 1

        VStack(spacing: isRegular ? 28 : 20) {
            sideLabel("Inhale", active: state.index == 0)

            HStack(spacing: isRegular ? 20 : 14) {
                sideLabel("Hold", active: state.index == 3)
                    .rotationEffect(.degrees(-90))
                    .fixedSize()
                    .frame(width: 24)

                ZStack {
                    // Track
                    BoxPath()
                        .stroke(.white.opacity(0.2), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    // Traced portion this cycle
                    BoxPath()
                        .trim(from: 0, to: progress)
                        .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

                    // Breath fill
                    RoundedRectangle(cornerRadius: side * 0.08)
                        .fill(.white.opacity(0.18))
                        .padding(side * 0.12)
                        .scaleEffect(0.5 + 0.5 * fullness)

                    // Dot
                    Circle()
                        .fill(.white)
                        .frame(width: 18, height: 18)
                        .shadow(color: .white.opacity(0.8), radius: 8)
                        .position(BoxPath.point(at: progress, in: CGSize(width: side, height: side)))

                    VStack(spacing: 4) {
                        Text(state.phase.label)
                            .font(isRegular ? .title2.weight(.semibold) : .title3.weight(.semibold))
                        Text("\(count)")
                            .font(.system(size: isRegular ? 40 : 32, weight: .light, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.white)
                }
                .frame(width: side, height: side)

                sideLabel("Hold", active: state.index == 1)
                    .rotationEffect(.degrees(90))
                    .fixedSize()
                    .frame(width: 24)
            }

            sideLabel("Exhale", active: state.index == 2)
        }
        .animation(.easeInOut(duration: 0.3), value: state.index)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Box breathing, \(state.phase.label)")
    }

    private func sideLabel(_ text: String, active: Bool) -> some View {
        Text(text)
            .font(.subheadline.weight(active ? .bold : .medium))
            .foregroundStyle(.white.opacity(active ? 1 : 0.45))
    }
}

/// Square starting at the top-left corner, traced clockwise:
/// top = inhale, right = hold, bottom = exhale, left = hold.
private struct BoxPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    static func point(at progress: Double, in size: CGSize) -> CGPoint {
        let p = progress * 4
        let t = CGFloat(p - floor(p))
        switch Int(p) % 4 {
        case 0: return CGPoint(x: size.width * t, y: 0)
        case 1: return CGPoint(x: size.width, y: size.height * t)
        case 2: return CGPoint(x: size.width * (1 - t), y: size.height)
        default: return CGPoint(x: 0, y: size.height * (1 - t))
        }
    }
}

// MARK: - 5-4-3-2-1 Senses

private struct SensesVisual: View {
    let elapsed: Double
    let duration: Int
    let isRegular: Bool

    private let senses: [(count: Int, label: String, icon: String)] = [
        (5, "things you can see", "eye"),
        (4, "things you can hear", "ear"),
        (3, "things you can feel", "hand.raised"),
        (2, "things you can smell", "nose"),
        (1, "thing you can taste", "mouth"),
    ]

    var body: some View {
        let index = MomentVisual.stepIndex(elapsed: elapsed, duration: duration, count: senses.count)
        let stepLength = Double(duration) / Double(senses.count)
        let stepProgress = min(1, (elapsed - Double(index) * stepLength) / stepLength)
        let sense = senses[index]
        let size: CGFloat = isRegular ? 260 : 200

        VStack(spacing: isRegular ? 32 : 24) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.12))
                Circle()
                    .stroke(.white.opacity(0.15), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: stepProgress)
                    .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 6) {
                    Image(systemName: sense.icon)
                        .font(.system(size: isRegular ? 34 : 28, weight: .medium))
                    Text("\(sense.count)")
                        .font(.system(size: isRegular ? 88 : 72, weight: .light, design: .rounded))
                        .contentTransition(.numericText(countsDown: true))
                }
                .foregroundStyle(.white)
            }
            .frame(width: size, height: size)

            Text(sense.label.capitalizedFirst)
                .font(isRegular ? .title2.weight(.semibold) : .title3.weight(.semibold))
                .foregroundStyle(.white)
                .contentTransition(.opacity)

            HStack(spacing: 10) {
                ForEach(senses.indices, id: \.self) { i in
                    Capsule()
                        .fill(.white.opacity(i <= index ? 0.95 : 0.3))
                        .frame(width: i == index ? 24 : 8, height: 8)
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: index)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(sense.count) \(sense.label)")
    }
}

// MARK: - Steps

private struct StepsVisual: View {
    let labels: [String]
    let iconName: String
    let elapsed: Double
    let duration: Int
    let isRegular: Bool

    var body: some View {
        let index = MomentVisual.stepIndex(elapsed: elapsed, duration: duration, count: labels.count)
        let stepLength = Double(duration) / Double(max(1, labels.count))
        let dot: CGFloat = isRegular ? 84 : 68
        let breathe = 1 + 0.06 * sin(elapsed * .pi / 2)

        VStack(spacing: isRegular ? 40 : 32) {
            HStack(spacing: isRegular ? 28 : 20) {
                ForEach(labels.indices, id: \.self) { i in
                    let fill = min(1, max(0, (elapsed - Double(i) * stepLength) / stepLength))
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.12))
                        Circle()
                            .trim(from: 0, to: fill)
                            .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: iconName)
                            .font(.system(size: dot * 0.36, weight: .medium))
                            .foregroundStyle(.white.opacity(i < index ? 1 : (i == index ? 0.9 : 0.35)))
                    }
                    .frame(width: dot, height: dot)
                    .scaleEffect(i == index ? breathe : (i < index ? 1 : 0.85))
                }
            }

            Text(labels[index])
                .font(isRegular ? .title2.weight(.semibold) : .title3.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: index)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(labels[index])
    }
}

// MARK: - Ripple

private struct RippleVisual: View {
    let iconName: String
    let elapsed: Double
    let isRegular: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let period = 6.0
    private let ringCount = 3

    var body: some View {
        let size: CGFloat = isRegular ? 280 : 220
        let core: CGFloat = isRegular ? 120 : 96
        let glow = 0.5 - cos(elapsed / period * 2 * .pi) / 2

        ZStack {
            if !reduceMotion {
                ForEach(0..<ringCount, id: \.self) { i in
                    let t = (elapsed / period + Double(i) / Double(ringCount)).truncatingRemainder(dividingBy: 1)
                    Circle()
                        .stroke(.white.opacity(0.5 * (1 - t)), lineWidth: 2)
                        .frame(width: core, height: core)
                        .scaleEffect(1 + t * (size / core - 1))
                }
            }

            Circle()
                .fill(.white.opacity(0.12 + 0.1 * glow))
                .frame(width: core * 1.35, height: core * 1.35)
                .blur(radius: 12)

            Circle()
                .fill(.white.opacity(0.22))
                .frame(width: core, height: core)
                .scaleEffect(0.96 + 0.06 * glow)

            Image(systemName: iconName)
                .font(.system(size: core * 0.4, weight: .medium))
                .foregroundStyle(.white)
                .scaleEffect(0.96 + 0.06 * glow)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
