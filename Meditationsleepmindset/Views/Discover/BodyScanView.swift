//
//  BodyScanView.swift
//  Meditation Sleep Mindset
//

import SwiftUI
import SwiftData

struct BodyScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isRegular: Bool { sizeClass == .regular }

    @State private var currentRegion: Int = -1 // -1 = intro
    @State private var timer: Timer?
    @State private var phaseTimer: Timer?
    @State private var countdown: Int = 30
    @State private var isComplete = false
    @State private var startTime = Date()
    @State private var glowOpacity: Double = 0.3

    private let regions = [
        BodyRegion(name: "Head & Face", instruction: "Release tension in your forehead, jaw, and temples", icon: "brain.head.profile", yPosition: 0.12),
        BodyRegion(name: "Neck & Shoulders", instruction: "Let your shoulders drop, release neck tension", icon: "figure.arms.open", yPosition: 0.22),
        BodyRegion(name: "Arms & Hands", instruction: "Feel warmth flowing through your arms to fingertips", icon: "hand.raised.fill", yPosition: 0.35),
        BodyRegion(name: "Chest & Heart", instruction: "Notice your breath, feel your heartbeat", icon: "heart.fill", yPosition: 0.42),
        BodyRegion(name: "Abdomen", instruction: "Soften your belly, let it rise and fall naturally", icon: "circle.fill", yPosition: 0.52),
        BodyRegion(name: "Lower Back & Hips", instruction: "Release any tightness in your lower back", icon: "figure.seated.side.left", yPosition: 0.62),
        BodyRegion(name: "Legs & Feet", instruction: "Feel grounded, let heaviness flow to the earth", icon: "figure.stand", yPosition: 0.78),
    ]

    var body: some View {
        ZStack {
            Theme.profileGradient.ignoresSafeArea()

            // Ambient particles
            GeometryReader { geometry in
                ForEach(0..<12, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.03...0.1)))
                        .frame(width: CGFloat.random(in: 2...6))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                        .blur(radius: 2)
                }
            }

            if isComplete {
                completionView
            } else if currentRegion < 0 {
                introView
            } else {
                scanView
            }

            // Top bar
            VStack {
                HStack {
                    Button {
                        stopTimers()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }

                    Spacer()

                    if currentRegion >= 0 && !isComplete {
                        Text("\(currentRegion + 1) / \(regions.count)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()
            }
        }
        .onDisappear {
            stopTimers()
        }
    }

    // MARK: - Intro

    private var introView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "figure.mind.and.body")
                .font(.system(size: 64))
                .foregroundStyle(.purple)

            Text("Body Scan")
                .font(.title.bold())
                .foregroundStyle(.white)

            Text("Bring awareness to each part of your body,\nreleasing tension as you go.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            Text("~3.5 minutes")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)

            Spacer()

            Button {
                startScan()
            } label: {
                Text("Begin Scan")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Scan View

    private var scanView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Body outline with highlighted region
            ZStack {
                // Body silhouette - adaptive sizing for iPad
                let bodyWidth: CGFloat = isRegular ? 180 : 120
                let bodyHeight: CGFloat = isRegular ? 500 : 350

                bodyOutline
                    .frame(width: bodyWidth, height: bodyHeight)

                // Glow on current region
                if currentRegion < regions.count {
                    let region = regions[currentRegion]
                    let glowSize: CGFloat = isRegular ? 160 : 120
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.purple.opacity(0.5),
                                    Color.purple.opacity(0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 5,
                                endRadius: isRegular ? 80 : 60
                            )
                        )
                        .frame(width: glowSize, height: glowSize)
                        .offset(y: CGFloat(region.yPosition - 0.5) * bodyHeight)
                        .opacity(glowOpacity)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: glowOpacity)
                }
            }

            Spacer().frame(height: 40)

            // Region info
            if currentRegion < regions.count {
                let region = regions[currentRegion]

                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: region.icon)
                            .foregroundStyle(.purple)
                        Text(region.name)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                    }

                    Text(region.instruction)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)

                    Text("\(countdown)")
                        .font(.system(size: 36, weight: .light, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .monospacedDigit()
                }
                .padding(.horizontal, 32)
            }

            Spacer()

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)

                    Rectangle()
                        .fill(Color.purple)
                        .frame(width: geo.size.width * CGFloat(currentRegion + 1) / CGFloat(regions.count), height: 4)
                        .animation(.easeInOut, value: currentRegion)
                }
            }
            .frame(height: 4)
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Body Outline

    private var bodyOutline: some View {
        ZStack {
            // Head
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                .frame(width: 30, height: 30)
                .offset(y: -140)

            // Neck
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 8, height: 15)
                .offset(y: -120)

            // Torso
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                .frame(width: 50, height: 100)
                .offset(y: -55)

            // Arms (left)
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                .frame(width: 12, height: 90)
                .rotationEffect(.degrees(10))
                .offset(x: -40, y: -45)

            // Arms (right)
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                .frame(width: 12, height: 90)
                .rotationEffect(.degrees(-10))
                .offset(x: 40, y: -45)

            // Legs (left)
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                .frame(width: 16, height: 110)
                .rotationEffect(.degrees(3))
                .offset(x: -15, y: 65)

            // Legs (right)
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                .frame(width: 16, height: 110)
                .rotationEffect(.degrees(-3))
                .offset(x: 15, y: 65)
        }
    }

    // MARK: - Completion

    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Scan Complete")
                .font(.title.bold())
                .foregroundStyle(.white)

            Text("You've brought awareness to your entire body.\nTake a moment to notice how you feel.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Logic

    private func startScan() {
        startTime = Date()
        currentRegion = 0
        countdown = 30
        glowOpacity = 0.8
        startRegionTimer()
    }

    private func startRegionTimer() {
        countdown = 30
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if countdown > 1 {
                    countdown -= 1
                } else {
                    timer?.invalidate()
                    timer = nil
                    advanceRegion()
                }
            }
        }
    }

    private func advanceRegion() {
        if currentRegion + 1 < regions.count {
            HapticManager.medium()
            withAnimation(.easeInOut(duration: 0.5)) {
                currentRegion += 1
            }
            startRegionTimer()
        } else {
            completeScan()
        }
    }

    private func completeScan() {
        stopTimers()
        HapticManager.success()
        withAnimation {
            isComplete = true
        }

        let duration = Int(Date().timeIntervalSince(startTime))
        let session = MeditationSession(
            contentTitle: "Body Scan",
            durationSeconds: duration,
            listenedSeconds: duration,
            wasCompleted: true,
            sessionType: "bodyScan",
            completedAt: Date()
        )
        modelContext.insert(session)
        try? modelContext.save()
        StreakService.shared.recordSession(durationMinutes: max(1, duration / 60), context: modelContext)
        AppStateManager.shared.onSessionCompleted()
    }

    private func stopTimers() {
        timer?.invalidate()
        timer = nil
        phaseTimer?.invalidate()
        phaseTimer = nil
    }
}

// MARK: - Body Region

struct BodyRegion {
    let name: String
    let instruction: String
    let icon: String
    let yPosition: Double // 0 = top, 1 = bottom
}
