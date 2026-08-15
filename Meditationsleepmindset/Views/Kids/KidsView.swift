//
//  KidsView.swift
//  Meditation Sleep Mindset
//
//  Kids corner: personalized AI bedtime stories that weave the child's name
//  into a calming, age-appropriate narrative. Plus saved stories.
//

import SwiftUI
import SwiftData

struct KidsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var aiService = AIMeditationService.shared
    @StateObject private var storeManager = StoreManager.shared
    @Query(sort: \AIGeneratedMeditation.createdAt, order: .reverse) private var allGenerated: [AIGeneratedMeditation]

    @AppStorage(Constants.UserDefaultsKeys.childName) private var childName: String = ""
    @State private var selectedTheme: KidsStoryTheme = .sleepyForest
    @State private var selectedDuration: AIMeditationDuration = .ten
    @State private var selectedVoice: AIMeditationVoice = .calmFemale

    @State private var showingPaywall = false
    @State private var generatedStory: AIGeneratedMeditation?

    private var isRegular: Bool { sizeClass == .regular }

    private var savedStories: [AIGeneratedMeditation] {
        allGenerated.filter { $0.focus == "kids_story" }
    }

    // MARK: - Generation limits (shared counters with the AI meditation generator)

    private var hasReachedFreeLimit: Bool {
        if storeManager.isSubscribed { return false }
        let used = UserDefaults.standard.integer(forKey: "aiGenerationsUsed")
        return used >= Constants.AIMeditation.freeGenerationLimit
    }

    private static var todayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }

    private var todayGenerationCount: Int {
        let defaults = UserDefaults.standard
        let lastDate = defaults.string(forKey: "aiGenerationDate") ?? ""
        if lastDate != Self.todayString { return 0 }
        return defaults.integer(forKey: "aiGenerationsDailyCount")
    }

    private var hasReachedDailyLimit: Bool {
        guard storeManager.isSubscribed else { return false }
        return todayGenerationCount >= Constants.AIMeditation.premiumDailyGenerationLimit
    }

    private func recordGeneration() {
        let defaults = UserDefaults.standard
        let today = Self.todayString
        let lastDate = defaults.string(forKey: "aiGenerationDate") ?? ""
        if lastDate != today {
            defaults.set(today, forKey: "aiGenerationDate")
            defaults.set(1, forKey: "aiGenerationsDailyCount")
        } else {
            defaults.set(defaults.integer(forKey: "aiGenerationsDailyCount") + 1, forKey: "aiGenerationsDailyCount")
        }
        if !storeManager.isSubscribed {
            defaults.set(defaults.integer(forKey: "aiGenerationsUsed") + 1, forKey: "aiGenerationsUsed")
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
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Close")
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PremiumPaywallView(
                    storeManager: storeManager,
                    context: .kidsStories,
                    sessionLimitMessage: "Personalized bedtime stories are a premium feature. Subscribe to create unlimited stories for your little one.",
                    onSubscribed: { showingPaywall = false }
                )
            }
            .fullScreenCover(item: $generatedStory) { story in
                AIGeneratedPlayerView(meditation: story)
            }
            .alert("Story Creation Failed", isPresented: $aiService.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(aiService.error ?? "Something went wrong. Please try again.")
            }
        }
        .background(Theme.profileGradient)
    }

    // MARK: - Form

    private var formContent: some View {
        ScrollView {
            VStack(spacing: 28) {
                header

                // Child's name
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Who is this story for?", icon: "person.fill")
                    TextField("Child's first name", text: $childName)
                        .textInputAutocapitalization(.words)
                        .padding()
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                }

                // Theme
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Tonight's adventure", icon: "sparkles")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(KidsStoryTheme.allCases) { theme in
                            SelectableCard(icon: theme.icon, title: theme.displayName, isSelected: selectedTheme == theme) {
                                HapticManager.selection()
                                selectedTheme = theme
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Length
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Length", icon: "clock")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(AIMeditationDuration.allCases) { duration in
                                SelectableChip(title: duration.displayName, isSelected: selectedDuration == duration) {
                                    HapticManager.selection()
                                    selectedDuration = duration
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                // Voice
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Storyteller voice", icon: "waveform")
                    HStack(spacing: 12) {
                        ForEach(AIMeditationVoice.allCases) { voice in
                            SelectableCard(icon: voice.icon, title: voice.displayName, isSelected: selectedVoice == voice) {
                                HapticManager.selection()
                                selectedVoice = voice
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Generate
                VStack(spacing: 12) {
                    Button {
                        if hasReachedFreeLimit {
                            showingPaywall = true
                        } else if !hasReachedDailyLimit {
                            generateStory()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: hasReachedFreeLimit ? "lock.fill" : hasReachedDailyLimit ? "clock.fill" : "moon.stars.fill")
                            Text(hasReachedFreeLimit ? "Unlock Premium" : hasReachedDailyLimit ? "Daily Limit Reached" : "Create Bedtime Story")
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
                }
                .padding(.top, 8)

                // Saved stories
                if !savedStories.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Saved stories", icon: "books.vertical.fill")
                        ForEach(savedStories) { story in
                            MyCreationCard(meditation: story) {
                                generatedStory = story
                            } onDelete: {
                                AIMeditationService.shared.deleteMeditation(story, context: modelContext)
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.top, 8)
                }

                Spacer(minLength: 40)
            }
            .frame(maxWidth: isRegular ? 820 : 600)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Theme.profileAccent.opacity(0.2))
                    .frame(width: 80, height: 80)
                Image(systemName: "teddybear.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Theme.profileAccent)
            }
            Text("Kids Bedtime Stories")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Text("A soothing story made just for your child, with their name in it")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.top, 16)
    }

    private var generatingView: some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView()
                .scaleEffect(1.6)
                .tint(.white)
            Text(aiService.generationStatus)
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            ProgressView(value: aiService.generationProgress)
                .tint(Theme.profileAccent)
                .padding(.horizontal, 60)
            Text("This may take a minute...")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
            Spacer()
        }
        .padding()
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Theme.profileAccent)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    private func generateStory() {
        Task {
            do {
                let story = try await aiService.generateBedtimeStory(
                    childName: childName,
                    theme: selectedTheme,
                    duration: selectedDuration,
                    voice: selectedVoice,
                    context: modelContext
                )
                if !aiService.lastResultWasCached { recordGeneration() }
                HapticManager.success()
                generatedStory = story
            } catch {
                HapticManager.error()
            }
        }
    }
}

#Preview {
    KidsView()
        .modelContainer(for: [AIGeneratedMeditation.self], inMemory: true)
}
