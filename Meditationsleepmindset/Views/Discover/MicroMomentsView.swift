//
//  MicroMomentsView.swift
//  Meditation Sleep Mindset
//
//  TikTok-style vertical feed of 30-60 second micro-meditations.
//  Quick breathing resets, affirmations, and grounding exercises.
//

import SwiftUI
import SwiftData
import AVFoundation

struct MicroMomentsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = MicroMomentsViewModel()
    @State private var currentIndex = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.moments.isEmpty {
                loadingView
            } else {
                // Vertical paging TabView (TikTok style)
                TabView(selection: $currentIndex) {
                    ForEach(Array(viewModel.moments.enumerated()), id: \.element.id) { index, moment in
                        MicroMomentCard(
                            moment: moment,
                            isActive: index == currentIndex,
                            onComplete: {
                                viewModel.markCompleted(moment)
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
            }

            // Top bar overlay
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial.opacity(0.5))
                            .clipShape(Circle())
                    }

                    Spacer()

                    // Progress indicator
                    if !viewModel.moments.isEmpty {
                        Text("\(currentIndex + 1) / \(viewModel.moments.count)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial.opacity(0.5))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()
            }
        }
        .statusBarHidden()
        .onAppear {
            viewModel.loadMoments(context: modelContext)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
            Text("Loading moments...")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

// MARK: - View Model

@MainActor
class MicroMomentsViewModel: ObservableObject {
    @Published var moments: [MicroMoment] = []
    @Published var completedToday: Int = 0

    func loadMoments(context: ModelContext) {
        // Load built-in micro moments
        var allMoments = MicroMoment.builtInMoments

        // Also find short content from database (under 90 seconds)
        let descriptor = FetchDescriptor<Content>(
            predicate: #Predicate<Content> { content in
                content.durationSeconds <= 90 && content.durationSeconds >= 20
            },
            sortBy: [SortDescriptor(\.title)]
        )

        if let shortContent = try? context.fetch(descriptor) {
            let contentMoments = shortContent.prefix(10).map { content in
                MicroMoment(
                    id: content.id.uuidString,
                    type: .audioGuided,
                    title: content.title,
                    subtitle: content.narrator ?? "Guided",
                    duration: content.durationSeconds,
                    instruction: content.contentDescription ?? "Take a moment to breathe and relax.",
                    backgroundColor: MicroMoment.gradientColors.randomElement() ?? ["#1a1a2e", "#16213e"],
                    iconName: "headphones",
                    youtubeVideoID: content.youtubeVideoID
                )
            }
            allMoments.append(contentsOf: contentMoments)
        }

        // Shuffle for variety
        moments = allMoments.shuffled()
    }

    func markCompleted(_ moment: MicroMoment) {
        completedToday += 1
        // Could track in UserDefaults or SwiftData
        let key = "microMomentsCompleted_\(Date().formatted(.dateTime.year().month().day()))"
        UserDefaults.standard.set(completedToday, forKey: key)
    }
}

// MARK: - Micro Moment Model

struct MicroMoment: Identifiable {
    let id: String
    let type: MomentType
    let title: String
    let subtitle: String
    let duration: Int // seconds
    let instruction: String
    let backgroundColor: [String] // Gradient hex colors
    let iconName: String
    let youtubeVideoID: String?

    enum MomentType {
        case breathing
        case affirmation
        case grounding
        case bodyCheck
        case gratitude
        case audioGuided
    }

    init(id: String = UUID().uuidString, type: MomentType, title: String, subtitle: String, duration: Int, instruction: String, backgroundColor: [String], iconName: String, youtubeVideoID: String? = nil) {
        self.id = id
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.duration = duration
        self.instruction = instruction
        self.backgroundColor = backgroundColor
        self.iconName = iconName
        self.youtubeVideoID = youtubeVideoID
    }

    var gradient: LinearGradient {
        let colors = backgroundColor.compactMap { Color(hex: $0) }
        return LinearGradient(
            colors: colors.isEmpty ? [.purple, .blue] : colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Color palettes for moments (all dark enough for white text)
    static let gradientColors: [[String]] = [
        ["#667eea", "#764ba2"], // Purple-violet
        ["#c44dce", "#b8255f"], // Rich magenta-rose
        ["#2d7dd2", "#0077b6"], // Deep ocean blue
        ["#1a936f", "#114b5f"], // Forest-teal
        ["#c44536", "#9b2335"], // Deep crimson
        ["#5c4d9a", "#3a2d70"], // Muted violet
        ["#9b4dca", "#6a0572"], // Royal purple
        ["#667eea", "#764ba2"], // Deep purple
        ["#6a11cb", "#2575fc"], // Indigo-blue
        ["#b5446e", "#862e5e"], // Berry
    ]

    // Built-in micro moments
    static let builtInMoments: [MicroMoment] = [
        // Breathing exercises
        MicroMoment(
            type: .breathing,
            title: "4-4 Breath Reset",
            subtitle: "30 seconds",
            duration: 30,
            instruction: "Breathe in for 4 seconds, out for 4 seconds. Let each breath bring calm.",
            backgroundColor: ["#667eea", "#764ba2"],
            iconName: "wind"
        ),
        MicroMoment(
            type: .breathing,
            title: "Box Breathing",
            subtitle: "60 seconds",
            duration: 60,
            instruction: "Inhale 4s → Hold 4s → Exhale 4s → Hold 4s. Repeat 4 times.",
            backgroundColor: ["#4facfe", "#00f2fe"],
            iconName: "square"
        ),
        MicroMoment(
            type: .breathing,
            title: "Calming Exhale",
            subtitle: "45 seconds",
            duration: 45,
            instruction: "Breathe in for 4 seconds, out for 8 seconds. Extended exhale activates calm.",
            backgroundColor: ["#43e97b", "#38f9d7"],
            iconName: "leaf.fill"
        ),
        MicroMoment(
            type: .breathing,
            title: "Energy Breath",
            subtitle: "30 seconds",
            duration: 30,
            instruction: "Quick breaths in through nose, strong exhale through mouth. Energize!",
            backgroundColor: ["#f77062", "#fe5196"],
            iconName: "bolt.fill"
        ),

        // Affirmations
        MicroMoment(
            type: .affirmation,
            title: "I Am Capable",
            subtitle: "Affirmation",
            duration: 30,
            instruction: "Close your eyes. Repeat: \"I am capable. I am strong. I can handle this.\"",
            backgroundColor: ["#d63384", "#9b2335"],
            iconName: "star.fill"
        ),
        MicroMoment(
            type: .affirmation,
            title: "Self-Compassion",
            subtitle: "Affirmation",
            duration: 45,
            instruction: "Place a hand on your heart. Say: \"I am worthy of love and kindness.\"",
            backgroundColor: ["#c44dce", "#8b1a6b"],
            iconName: "heart.fill"
        ),
        MicroMoment(
            type: .affirmation,
            title: "Letting Go",
            subtitle: "Affirmation",
            duration: 30,
            instruction: "Breathe out and say: \"I release what I cannot control.\"",
            backgroundColor: ["#2d7dd2", "#1b4965"],
            iconName: "wind"
        ),
        MicroMoment(
            type: .affirmation,
            title: "Present Moment",
            subtitle: "Affirmation",
            duration: 30,
            instruction: "\"Right now, in this moment, I am okay. I am safe. I am here.\"",
            backgroundColor: ["#6a11cb", "#2575fc"],
            iconName: "sparkles"
        ),

        // Grounding
        MicroMoment(
            type: .grounding,
            title: "5-4-3-2-1 Grounding",
            subtitle: "60 seconds",
            duration: 60,
            instruction: "Notice: 5 things you see, 4 you hear, 3 you feel, 2 you smell, 1 you taste.",
            backgroundColor: ["#11998e", "#38ef7d"],
            iconName: "hand.raised.fill"
        ),
        MicroMoment(
            type: .grounding,
            title: "Feet on Ground",
            subtitle: "30 seconds",
            duration: 30,
            instruction: "Feel your feet firmly on the ground. Press down. You are here, rooted.",
            backgroundColor: ["#834d9b", "#d04ed6"],
            iconName: "figure.stand"
        ),
        MicroMoment(
            type: .grounding,
            title: "Body Anchor",
            subtitle: "45 seconds",
            duration: 45,
            instruction: "Notice where your body touches the chair or floor. Feel supported.",
            backgroundColor: ["#4568dc", "#b06ab3"],
            iconName: "figure.mind.and.body"
        ),

        // Body check
        MicroMoment(
            type: .bodyCheck,
            title: "Shoulder Drop",
            subtitle: "20 seconds",
            duration: 20,
            instruction: "Notice your shoulders. Are they tense? Let them drop. Release.",
            backgroundColor: ["#f093fb", "#f5576c"],
            iconName: "figure.arms.open"
        ),
        MicroMoment(
            type: .bodyCheck,
            title: "Jaw Release",
            subtitle: "20 seconds",
            duration: 20,
            instruction: "Unclench your jaw. Let your tongue rest. Soften your face.",
            backgroundColor: ["#c471f5", "#fa71cd"],
            iconName: "face.smiling"
        ),
        MicroMoment(
            type: .bodyCheck,
            title: "Hand Awareness",
            subtitle: "30 seconds",
            duration: 30,
            instruction: "Look at your hands. Stretch fingers wide, then relax. Feel the sensation.",
            backgroundColor: ["#48c6ef", "#6f86d6"],
            iconName: "hand.raised.fill"
        ),

        // Gratitude
        MicroMoment(
            type: .gratitude,
            title: "Three Good Things",
            subtitle: "45 seconds",
            duration: 45,
            instruction: "Think of 3 good things from today, no matter how small. Feel grateful.",
            backgroundColor: ["#c06014", "#8b3a0f"],
            iconName: "heart.circle.fill"
        ),
        MicroMoment(
            type: .gratitude,
            title: "Gratitude Breath",
            subtitle: "30 seconds",
            duration: 30,
            instruction: "With each exhale, silently say \"thank you\" for something in your life.",
            backgroundColor: ["#3a5ba0", "#1e3a6e"],
            iconName: "sparkles"
        ),
    ]
}

// MARK: - Micro Moment Card

struct MicroMomentCard: View {
    let moment: MicroMoment
    let isActive: Bool
    let onComplete: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var isPlaying = false
    @State private var timeRemaining: Int
    @State private var timer: Timer?
    @State private var breathPhase: BreathPhase = .inhale
    @State private var circleScale: CGFloat = 0.6
    @State private var showCompletion = false
    @State private var particlePositions: [(x: CGFloat, y: CGFloat, size: CGFloat)] = []
    @State private var completionTask: Task<Void, Never>?

    private var isRegular: Bool { sizeClass == .regular }

    enum BreathPhase {
        case inhale, hold, exhale, holdOut
    }

    init(moment: MicroMoment, isActive: Bool, onComplete: @escaping () -> Void) {
        self.moment = moment
        self.isActive = isActive
        self.onComplete = onComplete
        self._timeRemaining = State(initialValue: moment.duration)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                moment.gradient
                    .ignoresSafeArea()

                // Ambient particles (using stable positions)
                ForEach(Array(particlePositions.enumerated()), id: \.offset) { index, particle in
                    Circle()
                        .fill(.white.opacity(0.1))
                        .frame(width: particle.size)
                        .position(x: particle.x, y: particle.y)
                        .blur(radius: 10)
                }

                VStack(spacing: 0) {
                    Spacer()

                    // Central content
                    if moment.type == .breathing && isPlaying {
                        breathingAnimation
                    } else {
                        centralContent
                    }

                    Spacer()

                    // Bottom controls
                    bottomControls
                        .padding(.bottom, geometry.safeAreaInsets.bottom + (isRegular ? 60 : 40))
                }
                .padding(.horizontal, isRegular ? 48 : 24)

                // Completion overlay
                if showCompletion {
                    completionOverlay
                }
            }
            .onAppear {
                // Generate stable particle positions once
                if particlePositions.isEmpty {
                    particlePositions = (0..<8).map { _ in
                        (
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height),
                            size: CGFloat.random(in: 20...60)
                        )
                    }
                }
            }
        }
        .onChange(of: isActive) { _, active in
            if !active {
                stopTimer()
                isPlaying = false
            }
        }
        .onDisappear {
            // Clean up timer and tasks when view disappears
            stopTimer()
            isPlaying = false
            completionTask?.cancel()
        }
    }

    // MARK: - Central Content

    private var centralContent: some View {
        VStack(spacing: isRegular ? 32 : 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(.white.opacity(0.2))
                    .frame(width: isRegular ? 140 : 100, height: isRegular ? 140 : 100)

                Image(systemName: moment.iconName)
                    .font(.system(size: isRegular ? 60 : 44))
                    .foregroundStyle(.white)
            }

            // Title & subtitle
            VStack(spacing: 8) {
                Text(moment.title)
                    .font(isRegular ? .largeTitle.bold() : .title.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(moment.subtitle)
                    .font(isRegular ? .body : .subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            // Instruction
            Text(moment.instruction)
                .font(isRegular ? .title3 : .body)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, isRegular ? 60 : 20)
                .padding(.top, 8)
        }
    }

    // MARK: - Breathing Animation

    private var breathingAnimation: some View {
        let outerSize: CGFloat = isRegular ? 280 : 200
        let mainSize: CGFloat = isRegular ? 220 : 160
        let innerSize: CGFloat = isRegular ? 140 : 100

        return VStack(spacing: isRegular ? 48 : 32) {
            ZStack {
                // Outer glow
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: outerSize, height: outerSize)
                    .scaleEffect(circleScale * 1.3)

                // Main circle
                Circle()
                    .fill(.white.opacity(0.3))
                    .frame(width: mainSize, height: mainSize)
                    .scaleEffect(circleScale)

                // Inner circle
                Circle()
                    .fill(.white.opacity(0.5))
                    .frame(width: innerSize, height: innerSize)
                    .scaleEffect(circleScale * 0.8)

                // Phase text
                Text(phaseText)
                    .font(isRegular ? .title.weight(.medium) : .title3.weight(.medium))
                    .foregroundStyle(.white)
            }

            Text("\(timeRemaining)s")
                .font(.system(size: isRegular ? 64 : 48, weight: .light, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .monospacedDigit()
        }
    }

    private var phaseText: String {
        switch breathPhase {
        case .inhale: return "Breathe In"
        case .hold: return "Hold"
        case .exhale: return "Breathe Out"
        case .holdOut: return "Hold"
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: isRegular ? 28 : 20) {
            // Timer display (when not breathing type or not playing)
            if !isPlaying || moment.type != .breathing {
                Text(formatTime(timeRemaining))
                    .font(.system(size: isRegular ? 26 : 20, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .monospacedDigit()
            }

            // Play/Pause button
            Button {
                HapticManager.medium()
                if isPlaying {
                    pauseSession()
                } else {
                    startSession()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: isRegular ? 96 : 72, height: isRegular ? 96 : 72)

                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(isRegular ? .largeTitle : .title)
                        .foregroundStyle(.black)
                        .offset(x: isPlaying ? 0 : 2)
                }
            }

            // Swipe hint
            if !isPlaying {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.up")
                    Text("Swipe for more")
                }
                .font(isRegular ? .body : .caption)
                .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Completion Overlay

    private var completionOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)

                Text("Well done!")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("Moment completed")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .scaleEffect(showCompletion ? 1 : 0.8)
            .opacity(showCompletion ? 1 : 0)
            .animation(.spring(response: 0.5), value: showCompletion)
        }
    }

    // MARK: - Timer Logic

    private func startSession() {
        isPlaying = true

        // If it's audio guided, play the content
        if moment.type == .audioGuided, let videoID = moment.youtubeVideoID {
            // Would play audio here using playerManager
        }

        // Invalidate any existing timer before creating a new one
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                    updateBreathingAnimation()
                } else {
                    completeSession()
                }
            }
        }

        // Start breathing animation
        if moment.type == .breathing {
            startBreathingAnimation()
        }
    }

    private func pauseSession() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        timeRemaining = moment.duration
    }

    private func completeSession() {
        stopTimer()
        isPlaying = false
        showCompletion = true
        HapticManager.success()
        onComplete()

        // Hide completion after delay (cancellable)
        completionTask?.cancel()
        completionTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            showCompletion = false
            timeRemaining = moment.duration
        }
    }

    private func startBreathingAnimation() {
        breathPhase = .inhale
        animateBreath()
    }

    private func animateBreath() {
        // 4-4-4-4 box breathing pattern
        let phaseDuration = 4.0

        withAnimation(.easeInOut(duration: phaseDuration)) {
            circleScale = breathPhase == .inhale ? 1.0 : (breathPhase == .exhale ? 0.6 : circleScale)
        }
    }

    private func updateBreathingAnimation() {
        let elapsed = moment.duration - timeRemaining
        let cyclePosition = elapsed % 16 // 4+4+4+4 = 16 second cycle

        let newPhase: BreathPhase
        if cyclePosition < 4 {
            newPhase = .inhale
        } else if cyclePosition < 8 {
            newPhase = .hold
        } else if cyclePosition < 12 {
            newPhase = .exhale
        } else {
            newPhase = .holdOut
        }

        if newPhase != breathPhase {
            breathPhase = newPhase
            HapticManager.light()

            withAnimation(.easeInOut(duration: 4)) {
                switch breathPhase {
                case .inhale:
                    circleScale = 1.0
                case .hold:
                    break
                case .exhale:
                    circleScale = 0.6
                case .holdOut:
                    break
                }
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 {
            return "\(mins):\(String(format: "%02d", secs))"
        }
        return "\(secs)s"
    }
}

#Preview {
    MicroMomentsView()
}
