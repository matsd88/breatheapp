//
//  AIGeneratedMeditationView.swift
//  Meditation Sleep Mindset
//
//  View for creating personalized AI-generated meditations.
//  Allows users to customize duration, focus, voice, and background sounds.
//

import SwiftUI
import SwiftData
import AVFoundation

struct AIGeneratedMeditationView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var aiService = AIMeditationService.shared
    @StateObject private var storeManager = StoreManager.shared
    @Query private var generatedMeditations: [AIGeneratedMeditation]

    // Form state
    @State private var selectedDuration: AIMeditationDuration = .ten
    @State private var selectedFocus: AIMeditationFocus = .stress
    @State private var selectedVoice: AIMeditationVoice = .calmFemale
    @State private var selectedBackground: AIMeditationBackground = .nature
    @State private var personalNote: String = ""

    // UI state
    @State private var activeAISheet: AISheetType?
    @State private var showingPlayer = false
    @State private var generatedMeditation: AIGeneratedMeditation?

    enum AISheetType: String, Identifiable {
        case paywall, myCreations
        var id: String { rawValue }
    }

    private var isRegular: Bool { sizeClass == .regular }

    private var hasReachedFreeLimit: Bool {
        if storeManager.isSubscribed { return false }
        let generationsUsed = UserDefaults.standard.integer(forKey: "aiGenerationsUsed")
        return generationsUsed >= Constants.AIMeditation.freeGenerationLimit
    }

    private var hasReachedDailyLimit: Bool {
        guard storeManager.isSubscribed else { return false }
        return todayGenerationCount >= Constants.AIMeditation.premiumDailyGenerationLimit
    }

    private var todayGenerationCount: Int {
        let defaults = UserDefaults.standard
        let lastDate = defaults.string(forKey: "aiGenerationDate") ?? ""
        let today = Self.todayString
        if lastDate != today { return 0 }
        return defaults.integer(forKey: "aiGenerationsDailyCount")
    }

    private var freeGenerationsRemaining: Int {
        let used = UserDefaults.standard.integer(forKey: "aiGenerationsUsed")
        return max(0, Constants.AIMeditation.freeGenerationLimit - used)
    }

    private var remainingDailyGenerations: Int {
        Constants.AIMeditation.premiumDailyGenerationLimit - todayGenerationCount
    }

    private static var todayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }

    private var generateButtonIcon: String {
        if hasReachedFreeLimit { return "lock.fill" }
        if hasReachedDailyLimit { return "clock.fill" }
        return "sparkles"
    }

    private var generateButtonLabel: String {
        if hasReachedFreeLimit { return "Unlock Premium" }
        if hasReachedDailyLimit { return "Daily Limit Reached" }
        return "Generate Meditation"
    }

    @ViewBuilder
    private var generationLimitLabel: some View {
        if !storeManager.isSubscribed {
            HStack(spacing: 4) {
                Image(systemName: hasReachedFreeLimit ? "crown.fill" : "sparkles")
                    .font(.caption2)
                Text(hasReachedFreeLimit ? "Premium Feature" : "\(freeGenerationsRemaining) free creation\(freeGenerationsRemaining == 1 ? "" : "s") available")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.5))
        } else if hasReachedDailyLimit {
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.caption2)
                Text("Resets tomorrow — \(Constants.AIMeditation.premiumDailyGenerationLimit) per day")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.5))
        } else {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.caption2)
                Text("\(remainingDailyGenerations) of \(Constants.AIMeditation.premiumDailyGenerationLimit) creations remaining today")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func recordGeneration() {
        let defaults = UserDefaults.standard
        let today = Self.todayString
        let lastDate = defaults.string(forKey: "aiGenerationDate") ?? ""
        if lastDate != today {
            defaults.set(today, forKey: "aiGenerationDate")
            defaults.set(1, forKey: "aiGenerationsDailyCount")
        } else {
            let count = defaults.integer(forKey: "aiGenerationsDailyCount") + 1
            defaults.set(count, forKey: "aiGenerationsDailyCount")
        }
        if !storeManager.isSubscribed {
            let total = defaults.integer(forKey: "aiGenerationsUsed") + 1
            defaults.set(total, forKey: "aiGenerationsUsed")
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                if aiService.isGenerating {
                    generatingView
                } else {
                    formContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if !generatedMeditations.isEmpty {
                        Button {
                            activeAISheet = .myCreations
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "folder.fill")
                                Text("My Creations")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
            }
            .sheet(item: $activeAISheet) { sheet in
                switch sheet {
                case .paywall:
                    PremiumPaywallView(
                        storeManager: storeManager,
                        sessionLimitMessage: "AI Meditation is a premium feature. Subscribe to create personalized meditations.",
                        onSubscribed: { activeAISheet = nil }
                    )
                case .myCreations:
                    MyCreationsView()
                }
            }
            .fullScreenCover(item: $generatedMeditation) { meditation in
                AIGeneratedPlayerView(meditation: meditation)
            }
            .alert("Generation Failed", isPresented: $aiService.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(aiService.error ?? "Something went wrong. Please try again.")
            }
        }
        .background(Theme.profileGradient)
    }

    // MARK: - Form Content

    private var formContent: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Theme.profileAccent.opacity(0.2))
                            .frame(width: 80, height: 80)

                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 36))
                            .foregroundStyle(Theme.profileAccent)
                    }

                    Text("Create Your Meditation")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    Text("Personalized just for you using AI")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 16)

                // Duration Picker
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Duration", icon: "clock")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(AIMeditationDuration.allCases) { duration in
                                SelectableChip(
                                    title: duration.displayName,
                                    isSelected: selectedDuration == duration
                                ) {
                                    HapticManager.selection()
                                    selectedDuration = duration
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                // Focus Area
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Focus", icon: "brain.head.profile")

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(AIMeditationFocus.allCases) { focus in
                            SelectableCard(
                                icon: focus.icon,
                                title: focus.displayName,
                                isSelected: selectedFocus == focus
                            ) {
                                HapticManager.selection()
                                selectedFocus = focus
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Voice Style
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Voice", icon: "waveform")

                    HStack(spacing: 12) {
                        ForEach(AIMeditationVoice.allCases) { voice in
                            SelectableCard(
                                icon: voice.icon,
                                title: voice.displayName,
                                isSelected: selectedVoice == voice
                            ) {
                                HapticManager.selection()
                                selectedVoice = voice
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Background Sounds
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Background", icon: "speaker.wave.2")

                    HStack(spacing: 12) {
                        ForEach(AIMeditationBackground.allCases) { bg in
                            SelectableCard(
                                icon: bg.icon,
                                title: bg.displayName,
                                isSelected: selectedBackground == bg
                            ) {
                                HapticManager.selection()
                                selectedBackground = bg
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Personal Note (Optional)
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("What's on your mind?", icon: "text.bubble", optional: true)

                    TextField("Optional: Share what you'd like to focus on...", text: $personalNote, axis: .vertical)
                        .lineLimit(3...5)
                        .padding()
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                }

                // Generate Button
                VStack(spacing: 12) {
                    Button {
                        if hasReachedFreeLimit {
                            activeAISheet = .paywall
                        } else if hasReachedDailyLimit {
                            // Premium user hit daily cap — no action, button is disabled
                        } else {
                            generateMeditation()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: generateButtonIcon)
                            Text(generateButtonLabel)
                        }
                        .font(.headline)
                        .foregroundStyle(hasReachedFreeLimit ? .white : .black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(hasReachedFreeLimit ? Theme.profileAccent : hasReachedDailyLimit ? Color.white.opacity(0.3) : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(hasReachedDailyLimit)
                    .padding(.horizontal, 20)

                    generationLimitLabel
                }
                .padding(.top, 8)

                Spacer(minLength: 40)
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Generating View

    private var generatingView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated orb
            ZStack {
                // Outer glow - adaptive sizing for iPad
                let outerSize: CGFloat = isRegular ? 320 : 240
                let pulseSize: CGFloat = isRegular ? 220 : 160
                let innerSize: CGFloat = isRegular ? 140 : 100
                let iconSize: CGFloat = isRegular ? 56 : 40

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Theme.profileAccent.opacity(0.3), .clear],
                            center: .center,
                            startRadius: isRegular ? 60 : 40,
                            endRadius: isRegular ? 160 : 120
                        )
                    )
                    .frame(width: outerSize, height: outerSize)
                    .blur(radius: 20)

                // Pulsing circle
                Circle()
                    .fill(Theme.profileAccent.opacity(0.2))
                    .frame(width: pulseSize, height: pulseSize)
                    .scaleEffect(aiService.isGenerating ? 1.2 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: aiService.isGenerating
                    )

                // Inner circle
                Circle()
                    .fill(Theme.profileAccent.opacity(0.4))
                    .frame(width: innerSize, height: innerSize)

                // Icon
                Image(systemName: "wand.and.stars")
                    .font(.system(size: iconSize))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(aiService.isGenerating ? 360 : 0))
                    .animation(
                        .linear(duration: 4).repeatForever(autoreverses: false),
                        value: aiService.isGenerating
                    )
            }

            VStack(spacing: 16) {
                Text("Creating Your Meditation")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text(aiService.generationStatus)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut, value: aiService.generationStatus)
            }

            // Progress bar
            VStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 8)

                        Capsule()
                            .fill(Theme.profileAccent)
                            .frame(width: geo.size.width * aiService.generationProgress, height: 8)
                            .animation(.easeInOut, value: aiService.generationProgress)
                    }
                }
                .frame(height: 8)

                Text("\(Int(aiService.generationProgress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .monospacedDigit()
            }
            .padding(.horizontal, 60)

            Text("This may take a minute...")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))

            Spacer()
        }
        .padding()
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String, optional: Bool = false) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Theme.profileAccent)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            if optional {
                Text("(optional)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    private func generateMeditation() {
        let request = AIMeditationRequest(
            duration: selectedDuration,
            focus: selectedFocus,
            voice: selectedVoice,
            background: selectedBackground,
            personalNote: personalNote.isEmpty ? nil : personalNote
        )

        Task {
            do {
                let meditation = try await aiService.generateMeditation(request: request, context: modelContext)
                recordGeneration()
                HapticManager.success()
                generatedMeditation = meditation
            } catch {
                HapticManager.error()
            }
        }
    }
}

// MARK: - Selectable Chip

struct SelectableChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(isSelected ? Color.white.opacity(0.25) : Theme.cardBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Selectable Card

struct SelectableCard: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.6))

                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.white.opacity(0.2) : Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - My Creations View

struct MyCreationsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AIGeneratedMeditation.createdAt, order: .reverse) private var meditations: [AIGeneratedMeditation]
    @State private var selectedMeditation: AIGeneratedMeditation?
    @State private var meditationToDelete: AIGeneratedMeditation?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                if meditations.isEmpty {
                    emptyState
                } else {
                    meditationsList
                }
            }
            .navigationTitle("My Creations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .fullScreenCover(item: $selectedMeditation) { meditation in
                AIGeneratedPlayerView(meditation: meditation)
            }
            .alert("Delete Meditation?", isPresented: .constant(meditationToDelete != nil)) {
                Button("Cancel", role: .cancel) {
                    meditationToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let meditation = meditationToDelete {
                        AIMeditationService.shared.deleteMeditation(meditation, context: modelContext)
                        meditationToDelete = nil
                    }
                }
            } message: {
                Text("This will permanently delete this meditation.")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))

            Text("No Creations Yet")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Generate your first AI meditation to see it here.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var meditationsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(meditations) { meditation in
                    MyCreationCard(meditation: meditation) {
                        selectedMeditation = meditation
                    } onDelete: {
                        meditationToDelete = meditation
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - My Creation Card

struct MyCreationCard: View {
    let meditation: AIGeneratedMeditation
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(Theme.profileAccent.opacity(0.2))
                    .frame(width: 50, height: 50)

                if let focus = meditation.focusType {
                    Image(systemName: focus.icon)
                        .font(.title3)
                        .foregroundStyle(Theme.profileAccent)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(meditation.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(meditation.durationFormatted)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))

                    Text(meditation.createdAtRelative)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer()

            // Play button
            Button {
                onTap()
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white)
            }

            // Menu
            Menu {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 32, height: 32)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - AI Generated Player View

struct AIGeneratedPlayerView: View {
    let meditation: AIGeneratedMeditation

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var ambientSoundService = AmbientSoundService.shared
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var timeObserver: Any?
    @State private var endObserver: NSObjectProtocol?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                Theme.profileGradient.ignoresSafeArea()

                // Animated background
                if isPlaying {
                    AnimatedBackgroundView(
                        backgroundID: .water,
                        accentColor: Theme.profileAccent
                    )
                    .ignoresSafeArea()
                }

                VStack(spacing: 0) {
                    // Navigation bar
                    HStack {
                        Button {
                            stopPlayback()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }

                        Spacer()

                        Text("AI Meditation")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.6))

                        Spacer()

                        Color.clear.frame(width: 36, height: 36)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 60)

                    Spacer()

                    // Visualization
                    ZStack {
                        Circle()
                            .fill(Theme.profileAccent.opacity(0.15))
                            .frame(width: 200, height: 200)
                            .scaleEffect(isPlaying ? 1.1 : 1.0)
                            .animation(
                                .easeInOut(duration: 2).repeatForever(autoreverses: true),
                                value: isPlaying
                            )

                        Circle()
                            .fill(Theme.profileAccent.opacity(0.25))
                            .frame(width: 140, height: 140)

                        if let focus = meditation.focusType {
                            Image(systemName: focus.icon)
                                .font(.system(size: 50))
                                .foregroundStyle(.white)
                        }
                    }

                    Spacer()

                    // Content info
                    VStack(spacing: 8) {
                        Text(meditation.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 8) {
                            if let voice = meditation.voiceType {
                                Text(voice.displayName)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.6))
                            }

                            Text(meditation.durationFormatted)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    // Progress bar
                    VStack(spacing: 8) {
                        GeometryReader { geo in
                            let progress = duration > 0 ? currentTime / duration : 0

                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 4)

                                Capsule()
                                    .fill(Theme.profileAccent)
                                    .frame(width: max(0, geo.size.width * progress), height: 4)
                            }
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let progress = max(0, min(1, value.location.x / geo.size.width))
                                        seek(to: progress * duration)
                                    }
                            )
                        }
                        .frame(height: 20)

                        HStack {
                            Text(formatTime(currentTime))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                                .monospacedDigit()

                            Spacer()

                            Text(formatTime(duration))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                                .monospacedDigit()
                        }
                    }
                    .padding(.horizontal, 24)

                    // Playback controls
                    HStack(spacing: 40) {
                        Button {
                            skip(by: -15)
                        } label: {
                            Image(systemName: "gobackward.15")
                                .font(.title)
                                .foregroundStyle(.white.opacity(0.8))
                        }

                        Button {
                            togglePlayPause()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 72, height: 72)

                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title)
                                    .foregroundStyle(.black)
                                    .offset(x: isPlaying ? 0 : 2)
                            }
                        }

                        Button {
                            skip(by: 15)
                        } label: {
                            Image(systemName: "goforward.15")
                                .font(.title)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .padding(.top, 32)

                    Spacer().frame(height: 60)
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .onAppear {
            setupPlayer()
            startAmbientSound()
        }
        .onDisappear {
            stopPlayback()
        }
    }

    // MARK: - Player Methods

    private func setupPlayer() {
        let audioURL = AIMeditationService.shared.getAudioFileURL(for: meditation)

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            return
        }

        let playerItem = AVPlayerItem(url: audioURL)
        player = AVPlayer(playerItem: playerItem)

        // Observe duration
        Task {
            if let loadedDuration = try? await playerItem.asset.load(.duration) {
                duration = loadedDuration.seconds
            }
        }

        // Time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            currentTime = time.seconds
        }

        // End of playback notification
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            isPlaying = false
            seek(to: 0)
        }

        // Start playing
        player?.play()
        isPlaying = true

        // Increment play count
        meditation.incrementPlayCount()
        try? modelContext.save()
    }

    private func togglePlayPause() {
        HapticManager.light()
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
    }

    private func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: cmTime)
        currentTime = time
    }

    private func skip(by seconds: TimeInterval) {
        HapticManager.light()
        let newTime = max(0, min(duration, currentTime + seconds))
        seek(to: newTime)
    }

    private func stopPlayback() {
        player?.pause()
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        player = nil
        stopAmbientSound()
    }

    private func startAmbientSound() {
        guard let bg = meditation.backgroundType, bg != .silence else { return }

        // Map to existing ambient sounds if available
        switch bg {
        case .nature:
            if let sound = TimerAmbientSound.allCases.first(where: { $0.displayName.lowercased().contains("forest") }) {
                ambientSoundService.play(sound: sound)
            }
        case .rain:
            if let sound = TimerAmbientSound.allCases.first(where: { $0.displayName.lowercased().contains("rain") }) {
                ambientSoundService.play(sound: sound)
            }
        case .singingBowls:
            if let sound = TimerAmbientSound.allCases.first(where: { $0.displayName.lowercased().contains("bowl") }) {
                ambientSoundService.play(sound: sound)
            }
        case .silence:
            break
        }
    }

    private func stopAmbientSound() {
        ambientSoundService.stop()
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview {
    AIGeneratedMeditationView()
        .modelContainer(for: [AIGeneratedMeditation.self], inMemory: true)
}
