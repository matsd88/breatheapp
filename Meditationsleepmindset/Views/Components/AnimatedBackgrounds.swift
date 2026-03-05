//
//  AnimatedBackgrounds.swift
//  Meditation Sleep Mindset
//

import SwiftUI

// MARK: - Animated Background Container

struct AnimatedBackgroundView: View {
    let backgroundID: AnimatedBackgroundID
    let accentColor: Color

    var body: some View {
        switch backgroundID {
        case .none:
            EmptyView()
        case .rain:
            RainBackgroundView()
        case .water:
            WaterBackgroundView(accentColor: accentColor)
        case .aurora:
            AuroraBackgroundView(accentColor: accentColor)
        case .stars:
            StarsBackgroundView()
        case .pulse:
            PulseBackgroundView(accentColor: accentColor)
        }
    }
}

// MARK: - Rain Background

struct RainBackgroundView: View {
    // Store drop data as simple arrays for Canvas — no @State mutation needed per frame
    @State private var dropData: [(x: CGFloat, baseY: CGFloat, speed: Double, opacity: Double)] = []
    @State private var startTime: Date = .now

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 0.05)) { timeline in
                let elapsed = timeline.date.timeIntervalSince(startTime)

                Canvas { context, size in
                    for drop in dropData {
                        // Compute position from elapsed time — no @State mutation needed
                        let totalTravel = size.height + 20
                        let y = ((drop.baseY + elapsed * drop.speed * 60).truncatingRemainder(dividingBy: totalTravel)) - 20
                        let rect = CGRect(x: drop.x, y: y, width: 1.5, height: 15)
                        context.opacity = drop.opacity
                        context.fill(
                            Path(roundedRect: rect, cornerRadius: 1),
                            with: .color(.white.opacity(0.3))
                        )
                    }
                }
            }
            .onAppear {
                guard dropData.isEmpty else { return }
                startTime = .now
                let height = geo.size.height
                let width = geo.size.width
                dropData = (0..<50).map { _ in
                    (
                        x: CGFloat.random(in: 0...width),
                        baseY: CGFloat.random(in: 0...(height + 20)),
                        speed: Double.random(in: 3...8),
                        opacity: Double.random(in: 0.1...0.3)
                    )
                }
            }
        }
    }
}

// MARK: - Water/Wave Background

struct WaterBackgroundView: View {
    let accentColor: Color
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let waveHeight: CGFloat = 20
                let baseY = size.height * 0.7
                let currentPhase = timeline.date.timeIntervalSinceReferenceDate * 0.5

                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height))

                for x in stride(from: 0, through: size.width, by: 5) {
                    let y = baseY + sin((x / 50) + currentPhase) * waveHeight
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()

                context.opacity = 0.15
                context.fill(path, with: .color(accentColor))
            }
        }
    }
}

// MARK: - Drifting Mist Background

struct AuroraBackgroundView: View {
    let accentColor: Color

    var body: some View {
        GeometryReader { _ in
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate

                Canvas { context, size in
                    let blobs: [(xPhase: Double, yPhase: Double, xSpeed: Double, ySpeed: Double, radiusFraction: CGFloat, opacity: Double)] = [
                        (0, 0, 0.15, 0.1, 0.45, 0.30),
                        (2.0, 1.5, 0.1, 0.12, 0.35, 0.25),
                        (4.0, 3.0, 0.08, 0.14, 0.4, 0.20),
                        (1.0, 4.5, 0.12, 0.08, 0.3, 0.25),
                    ]

                    for blob in blobs {
                        let cx = size.width * 0.5 + CGFloat(sin(t * blob.xSpeed + blob.xPhase)) * size.width * 0.35
                        let cy = size.height * 0.4 + CGFloat(cos(t * blob.ySpeed + blob.yPhase)) * size.height * 0.25
                        let r = size.width * blob.radiusFraction

                        let gradient = Gradient(colors: [
                            accentColor.opacity(blob.opacity),
                            accentColor.opacity(blob.opacity * 0.3),
                            accentColor.opacity(0)
                        ])

                        context.drawLayer { ctx in
                            ctx.addFilter(.blur(radius: 25))
                            let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                            ctx.fill(
                                Ellipse().path(in: rect),
                                with: .radialGradient(
                                    gradient,
                                    center: CGPoint(x: cx, y: cy),
                                    startRadius: 0,
                                    endRadius: r
                                )
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Stars Background

struct StarsBackgroundView: View {
    // Store star data as simple arrays — twinkle driven by TimelineView + sin(), no Timer needed
    @State private var starData: [(x: CGFloat, y: CGFloat, size: CGFloat, baseOpacity: Double, twinkleSpeed: Double, phase: Double)] = []

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 0.1)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate

                Canvas { context, size in
                    for star in starData {
                        let opacity = star.baseOpacity + 0.15 * sin(t * star.twinkleSpeed + star.phase)
                        let rect = CGRect(
                            x: star.x - star.size / 2,
                            y: star.y - star.size / 2,
                            width: star.size,
                            height: star.size
                        )
                        context.opacity = max(0.1, min(0.7, opacity))
                        context.fill(Circle().path(in: rect), with: .color(.white))
                    }
                }
            }
            .onAppear {
                guard starData.isEmpty else { return }
                starData = (0..<80).map { _ in
                    (
                        x: CGFloat.random(in: 0...geo.size.width),
                        y: CGFloat.random(in: 0...geo.size.height),
                        size: CGFloat.random(in: 1...3),
                        baseOpacity: Double.random(in: 0.2...0.6),
                        twinkleSpeed: Double.random(in: 1...3),
                        phase: Double.random(in: 0...(2 * .pi))
                    )
                }
            }
        }
    }
}

// MARK: - Breathing Pulse Background

struct PulseBackgroundView: View {
    let accentColor: Color

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate
                let scale = 0.8 + 0.4 * sin(phase * 0.4) // 4 second cycle

                Canvas { context, size in
                    let centerX = size.width / 2
                    let centerY = size.height / 2
                    let radius = size.width * 0.4 * scale

                    let gradient = Gradient(colors: [
                        accentColor.opacity(0.15),
                        accentColor.opacity(0)
                    ])

                    context.drawLayer { ctx in
                        ctx.addFilter(.blur(radius: 30))
                        let rect = CGRect(
                            x: centerX - radius,
                            y: centerY - radius,
                            width: radius * 2,
                            height: radius * 2
                        )
                        ctx.fill(
                            Circle().path(in: rect),
                            with: .radialGradient(
                                gradient,
                                center: CGPoint(x: centerX, y: centerY),
                                startRadius: 0,
                                endRadius: radius
                            )
                        )
                    }
                }
            }
        }
    }
}
