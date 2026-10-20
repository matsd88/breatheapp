//
//  MicroMomentsView.swift
//  Meditation Sleep Mindset
//
//  TikTok-style vertical feed of 30-60 second micro-meditations.
//  Quick breathing resets, affirmations, and grounding exercises.
//

import SwiftUI
import SwiftData

struct MicroMomentsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = MicroMomentsViewModel()
    @State private var currentID: String?

    private var activeID: String? { currentID ?? viewModel.moments.first?.id }

    private var currentIndex: Int {
        viewModel.moments.firstIndex { $0.id == activeID } ?? 0
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                if viewModel.moments.isEmpty {
                    loadingView
                } else {
                    // Vertical paging feed (TikTok style)
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.moments) { moment in
                                MicroMomentCard(
                                    moment: moment,
                                    isActive: moment.id == activeID,
                                    safeArea: proxy.safeAreaInsets,
                                    onComplete: {
                                        viewModel.markCompleted(moment)
                                    }
                                )
                                .containerRelativeFrame([.horizontal, .vertical])
                                .id(moment.id)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $currentID)
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
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Close")

                        Spacer()

                        // Progress indicator
                        if !viewModel.moments.isEmpty {
                            Text("\(currentIndex + 1) / \(viewModel.moments.count)")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.8))
                                .monospacedDigit()
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial.opacity(0.5))
                                .clipShape(Capsule())
                                .contentTransition(.numericText())
                                .animation(.snappy, value: currentIndex)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    Spacer()
                }
            }
        }
        .statusBarHidden()
        .onAppear {
            if viewModel.moments.isEmpty {
                viewModel.loadMoments(context: modelContext)
            }
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

    private var todayKey: String {
        "microMomentsCompleted_\(Date().formatted(.dateTime.year().month().day()))"
    }

    func loadMoments(context: ModelContext) {
        // Load built-in micro moments
        var allMoments = MicroMoment.builtInMoments
        let builtInTitles = Set(allMoments.map { $0.title.lowercased() })

        // Also find short content from database (under 90 seconds)
        let descriptor = FetchDescriptor<Content>(
            predicate: #Predicate<Content> { content in
                content.durationSeconds <= 90 && content.durationSeconds >= 20
            },
            sortBy: [SortDescriptor(\.title)]
        )

        if let shortContent = try? context.fetch(descriptor) {
            // Skip catalog items that duplicate a built-in moment (e.g. "Box Breathing")
            let contentMoments = shortContent
                .filter { !builtInTitles.contains($0.title.lowercased()) }
                .prefix(10)
                .map { content in
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
        let key = todayKey
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: key) + 1, forKey: key)
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
    let visual: MomentVisual

    enum MomentType {
        case breathing
        case affirmation
        case grounding
        case bodyCheck
        case gratitude
        case audioGuided
    }

    init(id: String = UUID().uuidString, type: MomentType, title: String, subtitle: String, duration: Int, instruction: String, backgroundColor: [String], iconName: String, youtubeVideoID: String? = nil, visual: MomentVisual? = nil) {
        self.id = id
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.duration = duration
        self.instruction = instruction
        self.backgroundColor = backgroundColor
        self.iconName = iconName
        self.youtubeVideoID = youtubeVideoID
        self.visual = visual ?? MicroMoment.defaultVisual(type: type, title: title)
    }

    private static func defaultVisual(type: MomentType, title: String) -> MomentVisual {
        if title.localizedCaseInsensitiveContains("box breath") { return .box }
        if type == .breathing || title.localizedCaseInsensitiveContains("breath") {
            return .pulse(.reset44)
        }
        return .ripple
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
        ["#6a11cb", "#2575fc"], // Indigo-blue
        ["#b5446e", "#862e5e"], // Berry
    ]

    // Built-in micro moments
    static let builtInMoments: [MicroMoment] = [
        // Breathing exercises
        MicroMoment(
            type: .breathing,
            title: "4-4 Breath Reset",
            subtitle: "32 seconds",
            duration: 32,
            instruction: "Breathe in for 4 seconds, out for 4 seconds. Let each breath bring calm.",
            backgroundColor: ["#667eea", "#764ba2"],
            iconName: "wind",
            visual: .pulse(.reset44)
        ),
        MicroMoment(
            type: .breathing,
            title: "Box Breathing",
            subtitle: "64 seconds",
            duration: 64,
            instruction: "Inhale 4s → Hold 4s → Exhale 4s → Hold 4s. Repeat 4 times.",
            backgroundColor: ["#1e6fd9", "#0a7ea4"],
            iconName: "square",
            visual: .box
        ),
        MicroMoment(
            type: .breathing,
            title: "Calming Exhale",
            subtitle: "48 seconds",
            duration: 48,
            instruction: "Breathe in for 4 seconds, out for 8 seconds. Extended exhale activates calm.",
            backgroundColor: ["#1a936f", "#0f6e6e"],
            iconName: "leaf.fill",
            visual: .pulse(.calmingExhale)
        ),
        MicroMoment(
            type: .breathing,
            title: "Energy Breath",
            subtitle: "30 seconds",
            duration: 30,
            instruction: "Quick breaths in through nose, strong exhale through mouth. Energize!",
            backgroundColor: ["#e8505b", "#c2185b"],
            iconName: "bolt.fill",
            visual: .pulse(.energy)
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
            backgroundColor: ["#11998e", "#1f7a4d"],
            iconName: "hand.raised.fill",
            visual: .senses
        ),
        MicroMoment(
            type: .grounding,
            title: "Feet on Ground",
            subtitle: "30 seconds",
            duration: 30,
            instruction: "Feel your feet firmly on the ground. Press down. You are here, rooted.",
            backgroundColor: ["#834d9b", "#b03fb5"],
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
            subtitle: "24 seconds",
            duration: 24,
            instruction: "Notice your shoulders. Are they tense? Let them drop. Release.",
            backgroundColor: ["#c45ab3", "#d63c5e"],
            iconName: "figure.arms.open",
            visual: .pulse(.shoulderDrop)
        ),
        MicroMoment(
            type: .bodyCheck,
            title: "Jaw Release",
            subtitle: "20 seconds",
            duration: 20,
            instruction: "Unclench your jaw. Let your tongue rest. Soften your face.",
            backgroundColor: ["#9b4dca", "#c2489a"],
            iconName: "face.smiling",
            visual: .pulse(.jawRelease)
        ),
        MicroMoment(
            type: .bodyCheck,
            title: "Hand Awareness",
            subtitle: "27 seconds",
            duration: 27,
            instruction: "Look at your hands. Stretch fingers wide, then relax. Feel the sensation.",
            backgroundColor: ["#2f80b8", "#5468c4"],
            iconName: "hand.raised.fill",
            visual: .pulse(.handStretch)
        ),

        // Gratitude
        MicroMoment(
            type: .gratitude,
            title: "Three Good Things",
            subtitle: "45 seconds",
            duration: 45,
            instruction: "Think of 3 good things from today, no matter how small. Feel grateful.",
            backgroundColor: ["#c06014", "#8b3a0f"],
            iconName: "heart.fill",
            visual: .steps(["Think of one good thing", "Now another", "And one more"])
        ),
        MicroMoment(
            type: .gratitude,
            title: "Gratitude Breath",
            subtitle: "30 seconds",
            duration: 30,
            instruction: "With each exhale, silently say \"thank you\" for something in your life.",
            backgroundColor: ["#3a5ba0", "#1e3a6e"],
            iconName: "sparkles",
            visual: .pulse(.gratitude)
        ),
    ]
}

// MARK: - Micro Moment Card

struct MicroMomentCard: View {
    let moment: MicroMoment
    let isActive: Bool
    let safeArea: EdgeInsets
    let onComplete: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPlaying = false
    /// Seconds played before the current run (pauses bank time here).
    @State private var accumulated: Double = 0
    @State private var resumedAt: Date?
    @State private var ticker: Timer?
    @State private var lastPhaseKey = 0
    @State private var showCompletion = false
    @State private var particlePositions: [(x: CGFloat, y: CGFloat, size: CGFloat)] = []
    @State private var completionTask: Task<Void, Never>?

    private var isRegular: Bool { sizeClass == .regular }
    private var hasStarted: Bool { isPlaying || accumulated > 0 }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                moment.gradient
                    .ignoresSafeArea()

                TimelineView(.animation(paused: !isPlaying)) { context in
                    let elapsed = elapsed(at: context.date)

                    ZStack {
                        // Ambient particles (stable positions, slow drift while playing)
                        ForEach(Array(particlePositions.enumerated()), id: \.offset) { index, particle in
                            let drift = reduceMotion ? 0 : sin(elapsed * 0.3 + Double(index)) * 14
                            Circle()
                                .fill(.white.opacity(0.1))
                                .frame(width: particle.size)
                                .position(x: particle.x, y: particle.y + drift)
                                .blur(radius: 10)
                        }

                        VStack(spacing: 0) {
                            Spacer(minLength: 0)

                            Group {
                                if hasStarted {
                                    playingContent(elapsed: elapsed)
                                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                                } else {
                                    centralContent
                                        .transition(.opacity.combined(with: .scale(scale: 1.04)))
                                }
                            }

                            Spacer(minLength: 0)

                            bottomControls(elapsed: elapsed)
                        }
                        .padding(.top, safeArea.top + 64)
                        .padding(.bottom, safeArea.bottom + (isRegular ? 48 : 28))
                        .padding(.horizontal, isRegular ? 48 : 24)
                    }
                }

                // Completion overlay
                if showCompletion {
                    completionOverlay
                        .transition(.opacity)
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
            if !active { resetSession() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active && isPlaying { pauseSession() }
        }
        .onDisappear {
            // Clean up timer and tasks when view disappears
            resetSession()
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
                    .foregroundStyle(.white.opacity(0.75))
            }

            // Instruction
            Text(moment.instruction)
                .font(isRegular ? .title3 : .body)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, isRegular ? 60 : 8)
                .padding(.top, 8)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Playing Content

    private func playingContent(elapsed: Double) -> some View {
        VStack(spacing: isRegular ? 32 : 24) {
            Text(moment.title)
                .font(isRegular ? .title2.weight(.semibold) : .headline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)

            MomentVisualView(
                visual: moment.visual,
                iconName: moment.iconName,
                elapsed: elapsed,
                duration: moment.duration,
                isRegular: isRegular
            )

            if moment.visual.showsInstructionWhilePlaying {
                Text(moment.instruction)
                    .font(isRegular ? .title3.weight(.medium) : .body.weight(.medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, isRegular ? 60 : 8)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Bottom Controls

    private func bottomControls(elapsed: Double) -> some View {
        let remaining = max(0, moment.duration - Int(elapsed))
        let progress = moment.duration > 0 ? elapsed / Double(moment.duration) : 0
        let buttonSize: CGFloat = isRegular ? 96 : 72

        return VStack(spacing: isRegular ? 24 : 18) {
            Text(formatTime(remaining))
                .font(.system(size: isRegular ? 26 : 20, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .monospacedDigit()
                .accessibilityLabel("\(remaining) seconds remaining")

            // Play/Pause button with session progress ring
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
                        .stroke(.white.opacity(0.25), lineWidth: 3)
                        .frame(width: buttonSize + 14, height: buttonSize + 14)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: buttonSize + 14, height: buttonSize + 14)

                    Circle()
                        .fill(.white)
                        .frame(width: buttonSize, height: buttonSize)

                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(isRegular ? .largeTitle : .title)
                        .foregroundStyle(.black)
                        .offset(x: isPlaying ? 0 : 2)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Pause" : (hasStarted ? "Resume" : "Start"))

            // Swipe hint (kept in layout so nothing jumps when it hides)
            HStack(spacing: 4) {
                Image(systemName: "chevron.up")
                Text("Swipe up for more")
            }
            .font(isRegular ? .body : .caption)
            .foregroundStyle(.white.opacity(0.6))
            .opacity(isPlaying ? 0 : 1)
            .accessibilityHidden(isPlaying)
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
                    .symbolEffect(.bounce, value: showCompletion)

                Text("Well done!")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("Moment completed")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Session Logic

    private func elapsed(at date: Date) -> Double {
        let running = resumedAt.map { date.timeIntervalSince($0) } ?? 0
        return min(Double(moment.duration), accumulated + running)
    }

    private func startSession() {
        guard !showCompletion else { return }
        lastPhaseKey = moment.visual.phaseKey(elapsed: accumulated, duration: moment.duration)
        withAnimation(.easeInOut(duration: 0.35)) {
            resumedAt = Date()
            isPlaying = true
        }

        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in tick() }
        }
    }

    private func tick() {
        guard isPlaying else { return }
        let elapsed = elapsed(at: Date())
        if elapsed >= Double(moment.duration) {
            completeSession()
            return
        }
        let key = moment.visual.phaseKey(elapsed: elapsed, duration: moment.duration)
        if key != lastPhaseKey {
            lastPhaseKey = key
            HapticManager.light()
        }
    }

    private func pauseSession() {
        accumulated = elapsed(at: Date())
        resumedAt = nil
        isPlaying = false
        ticker?.invalidate()
        ticker = nil
    }

    private func resetSession() {
        ticker?.invalidate()
        ticker = nil
        isPlaying = false
        resumedAt = nil
        accumulated = 0
    }

    private func completeSession() {
        pauseSession()
        withAnimation(.easeInOut(duration: 0.3)) {
            showCompletion = true
        }
        HapticManager.success()
        onComplete()

        // Hide completion after delay (cancellable)
        completionTask?.cancel()
        completionTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                showCompletion = false
                accumulated = 0
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
