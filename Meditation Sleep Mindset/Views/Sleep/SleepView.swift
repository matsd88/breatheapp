//
//  SleepView.swift
//  Meditation Sleep Mindset
//

import SwiftUI
import SwiftData

struct SleepView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Content> {
        $0.contentTypeRaw == "Sleep Story" ||
        $0.contentTypeRaw == "Soundscape" ||
        $0.contentTypeRaw == "Music" ||
        $0.contentTypeRaw == "ASMR"
    })
    private var sleepContent: [Content]
    @Query private var favorites: [FavoriteContent]

    @State private var selectedTab = 0
    @State private var showingSoundMixer = false
    @State private var selectedContent: Content?
    @State private var showScrollToTop = false
    @State private var contentForPlaylistAdd: Content?
    @State private var showSleepTimer = false
    @State private var showAlarmSettings = false
    @State private var durationFilter: DurationFilter = .all
    @StateObject private var playerManager = AudioPlayerManager.shared
    @StateObject private var notificationService = NotificationService.shared
    @AppStorage("dismissedBedtimePrompt") private var dismissedBedtimePrompt = false

    // MARK: - Duration Filter
    enum DurationFilter: String, CaseIterable {
        case all = "All"
        case short = "Under 30m"
        case medium = "30-60m"
        case long = "1hr+"
    }

    private var sleepStories: [Content] {
        sleepContent.filter { $0.contentType == .sleepStory }
    }

    private var soundscapes: [Content] {
        sleepContent.filter { $0.contentType == .soundscape }
    }

    private var music: [Content] {
        sleepContent.filter { $0.contentType == .music }
    }

    private var asmr: [Content] {
        sleepContent.filter { $0.contentType == .asmr }
    }

    private var currentContent: [Content] {
        switch selectedTab {
        case 0: return sleepStories
        case 1: return soundscapes
        case 2: return music
        case 3: return asmr
        default: return sleepStories
        }
    }

    private var filteredContent: [Content] {
        let base = currentContent
        switch durationFilter {
        case .all: return base
        case .short: return base.filter { $0.durationSeconds < 1800 }
        case .medium: return base.filter { $0.durationSeconds >= 1800 && $0.durationSeconds < 3600 }
        case .long: return base.filter { $0.durationSeconds >= 3600 }
        }
    }

    // Tonight's Pick — deterministic daily rotation
    private var tonightsPick: Content? {
        let allSleep = sleepStories + soundscapes + music + asmr
        guard !allSleep.isEmpty else { return nil }
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return allSleep[dayOfYear % allSleep.count]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.sleepBackground.ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header: Title + Timer Pill
                            HStack {
                                Text("Sleep")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Theme.sleepTextPrimary)

                                Spacer()

                                // Sleep Timer Pill
                                Button {
                                    showSleepTimer = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "moon.zzz.fill")
                                            .font(.caption)
                                        if let remaining = playerManager.sleepTimerRemaining {
                                            Text(timerFormatted(remaining))
                                                .font(.caption)
                                                .monospacedDigit()
                                        } else {
                                            Text("Timer")
                                                .font(.caption)
                                        }
                                    }
                                    .foregroundStyle(playerManager.sleepTimerRemaining != nil ? .white : Theme.sleepTextSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Theme.sleepCardBackground)
                                    .clipShape(Capsule())
                                }

                                // Alarm Pill
                                Button {
                                    showAlarmSettings = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "alarm.fill")
                                            .font(.caption)
                                        Text(AlarmService.shared.isEnabled ? AlarmService.shared.formattedAlarmTime : "Alarm")
                                            .font(.caption)
                                    }
                                    .foregroundStyle(AlarmService.shared.isEnabled ? .cyan : Theme.sleepTextSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Theme.sleepCardBackground)
                                    .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .id("sleepTop")

                            // Tonight's Pick
                            if let pick = tonightsPick {
                                TonightsPickCard(content: pick) {
                                    playContent(pick, from: [pick])
                                }
                                .padding(.horizontal)
                            }

                            // Bedtime Reminder Prompt
                            if !notificationService.bedtimeReminderEnabled && !dismissedBedtimePrompt {
                                BedtimeReminderPrompt(
                                    onEnable: {
                                        notificationService.setBedtimeReminder(enabled: true)
                                    },
                                    onDismiss: {
                                        dismissedBedtimePrompt = true
                                    }
                                )
                                .padding(.horizontal)
                            }

                            // Category Picker
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    SleepCategoryPill(title: "Sleep Stories", isSelected: selectedTab == 0) {
                                        HapticManager.selection()
                                        withAnimation { selectedTab = 0 }
                                    }
                                    SleepCategoryPill(title: "Soundscapes", isSelected: selectedTab == 1) {
                                        HapticManager.selection()
                                        withAnimation { selectedTab = 1 }
                                    }
                                    SleepCategoryPill(title: "Music", isSelected: selectedTab == 2) {
                                        HapticManager.selection()
                                        withAnimation { selectedTab = 2 }
                                    }
                                    SleepCategoryPill(title: "ASMR", isSelected: selectedTab == 3) {
                                        HapticManager.selection()
                                        withAnimation { selectedTab = 3 }
                                    }
                                }
                                .padding(.horizontal)
                            }

                            // Duration Filter Pills
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(DurationFilter.allCases, id: \.rawValue) { filter in
                                        Button {
                                            HapticManager.selection()
                                            withAnimation { durationFilter = filter }
                                        } label: {
                                            Text(filter.rawValue)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundStyle(durationFilter == filter ? .white : Theme.sleepTextSecondary)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 7)
                                                .background(durationFilter == filter ? Color.white.opacity(0.2) : Theme.sleepCardBackground)
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }

                            // Sound Mixer Card (only shown in Soundscapes tab)
                            if selectedTab == 1 {
                                SoundMixerCard {
                                    showingSoundMixer = true
                                }
                                .padding(.horizontal)
                            }

                            // Content Grid - Adaptive for iPad
                            LazyVGrid(
                                columns: [
                                    GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16, alignment: .top)
                                ],
                                alignment: .leading,
                                spacing: 24
                            ) {
                                ForEach(Array(filteredContent.enumerated()), id: \.element.id) { index, content in
                                    SleepContentCard(
                                        content: content,
                                        isFavorite: isFavorite(content),
                                        onTap: { playContent(content, from: filteredContent) },
                                        onFavorite: { toggleFavorite(content) },
                                        onAddToPlaylist: { contentForPlaylistAdd = content },
                                        onShare: { shareContent(content) },
                                        onMore: { showActionSheet(for: content) }
                                    )
                                    .onAppear {
                                        if index >= Constants.UI.scrollToTopThreshold {
                                            withAnimation { showScrollToTop = true }
                                        }
                                        if index == 0 {
                                            withAnimation { showScrollToTop = false }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)

                            if filteredContent.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "moon.zzz")
                                        .font(.system(size: 40))
                                        .foregroundStyle(Theme.sleepTextSecondary.opacity(0.5))

                                    if durationFilter != .all {
                                        Text("No content matches this duration")
                                            .font(.subheadline)
                                            .foregroundStyle(Theme.sleepTextSecondary)
                                        Button("Show All") {
                                            withAnimation { durationFilter = .all }
                                        }
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.sleepPrimary)
                                    } else {
                                        Text("No content yet")
                                            .font(.subheadline)
                                            .foregroundStyle(Theme.sleepTextSecondary)
                                        Text("Check back soon for new sleep content")
                                            .font(.caption)
                                            .foregroundStyle(Theme.sleepTextSecondary.opacity(0.7))
                                    }
                                }
                                .padding(.top, 40)
                            }

                            Spacer(minLength: 100)
                        }
                        .frame(maxWidth: 700)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom)
                    }
                    .refreshable {
                        prefetchCurrentContent()
                        HapticManager.light()
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if showScrollToTop {
                            ScrollToTopButton(
                                scrollProxy: proxy,
                                targetID: "sleepTop",
                                isVisible: $showScrollToTop
                            )
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showingSoundMixer) {
                SoundMixerView()
            }
            .sheet(isPresented: $showSleepTimer) {
                SleepTimerView()
            }
            .sheet(isPresented: $showAlarmSettings) {
                AlarmSettingsView()
            }
            .fullScreenCover(item: $selectedContent) { content in
                MeditationPlayerView(content: content)
            }
            .sheet(item: $contentForPlaylistAdd) { content in
                AddToPlaylistSheet(content: content)
            }
            .onChange(of: selectedTab) { _, _ in
                showScrollToTop = false
                prefetchCurrentContent()
            }
            .onAppear {
                prefetchCurrentContent()
            }
        }
    }

    private func timerFormatted(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func isFavorite(_ content: Content) -> Bool {
        favorites.contains { $0.contentID == content.id || $0.youtubeVideoID == content.youtubeVideoID }
    }

    private func toggleFavorite(_ content: Content) {
        let wasFavorite = isFavorite(content)
        if let existing = favorites.first(where: { $0.contentID == content.id || $0.youtubeVideoID == content.youtubeVideoID }) {
            modelContext.delete(existing)
        } else {
            let favorite = FavoriteContent(from: content)
            modelContext.insert(favorite)
            AppStateManager.shared.onContentFavorited()
        }
        do {
            try modelContext.save()
            ToastManager.shared.show(
                wasFavorite ? "Removed from Favorites" : "Added to Favorites",
                icon: wasFavorite ? "heart.slash" : "heart.fill",
                style: wasFavorite ? .standard : .success
            )
        } catch {
            #if DEBUG
            print("Failed to save favorite: \(error)")
            #endif
        }
    }

    private func showActionSheet(for content: Content) {
        ActionSheetManager.shared.show(
            content: content,
            isFavorite: isFavorite(content),
            onToggleFavorite: { toggleFavorite(content) },
            onAddToPlaylist: { contentForPlaylistAdd = content },
            onShare: { shareContent(content) }
        )
    }

    /// Play content with the current tab's queue for auto-play
    private func playContent(_ content: Content, from queue: [Content]) {
        let startIndex = queue.firstIndex(where: { $0.id == content.id }) ?? 0
        AudioPlayerManager.shared.queue = queue
        AudioPlayerManager.shared.currentIndex = startIndex
        selectedContent = content
    }

    private func shareContent(_ content: Content) {
        ContentSharingHelper.share(content)
    }

    private func prefetchCurrentContent() {
        // Prefetch stream URLs for first 5 visible items
        let videoIDs = currentContent.prefix(5).map { $0.youtubeVideoID }
        Task {
            await YouTubeService.shared.prefetchStreamURLs(for: videoIDs)
        }
    }
}

struct SleepCategoryPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : Theme.sleepTextSecondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(isSelected ? Color.white.opacity(0.2) : Theme.sleepCardBackground)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct SleepQuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)

                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(color.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
        }
    }
}

struct SoundMixerCard: View {
    let onTap: () -> Void
    @StateObject private var mixer = AmbientSoundManager.shared

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Soundscape Mixer")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text(mixer.activeSounds.isEmpty ? "Create your perfect soundscape" : "\(mixer.activeSounds.count) sound\(mixer.activeSounds.count == 1 ? "" : "s") playing")
                        .font(.subheadline)
                        .foregroundStyle(Theme.sleepTextSecondary)
                }

                Spacer()

                if !mixer.activeSounds.isEmpty {
                    // Show active indicator
                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                }

                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding()
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct SleepContentCard: View {
    let content: Content
    let isFavorite: Bool
    let onTap: () -> Void
    let onFavorite: () -> Void
    let onAddToPlaylist: () -> Void
    let onShare: () -> Void
    var onMore: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                CachedAsyncImage(
                    url: URL(string: content.thumbnailURLComputed),
                    failedIconName: content.contentType.iconName,
                    content: { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .scaleEffect(1.15)
                            .clipped()
                    },
                    placeholder: {
                        Rectangle()
                            .fill(Theme.cardBackground)
                            .overlay(
                                ProgressView()
                                    .tint(.white.opacity(0.5))
                            )
                    }
                )
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture { onTap() }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(content.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(spacing: 4) {
                        Text(content.durationFormatted)
                        if content.narrator != nil {
                            Text("·")
                            Text(content.narrator!)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onTapGesture { onTap() }

                // More button
                Image(systemName: "ellipsis")
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .rotationEffect(.degrees(90))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                        TapGesture().onEnded {
                            ActionSheetManager.shared.show(
                                content: content,
                                isFavorite: isFavorite,
                                onToggleFavorite: { onFavorite() },
                                onAddToPlaylist: { onAddToPlaylist() },
                                onShare: { onShare() }
                            )
                        }
                    )
            }
        }
    }
}

struct SleepTimerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var playerManager = AudioPlayerManager.shared
    @State private var selectedMinutes = 30

    let timerOptions = [15, 30, 45, 60, 90, 120]

    private var isTimerActive: Bool {
        playerManager.sleepTimerRemaining != nil
    }

    var body: some View {
        ZStack {
            Theme.profileGradient.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer(minLength: 32)

                // Icon
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.white.opacity(0.9))

                // Title
                Text("Sleep Timer")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.textPrimary)

                if isTimerActive, let remaining = playerManager.sleepTimerRemaining {
                    // Active timer state
                    Text(timerFormattedLong(remaining))
                        .font(.system(size: 48, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.vertical, 8)

                    Text("Audio will fade out and stop")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)

                    Spacer(minLength: 16)

                    // Turn Off Button
                    Button {
                        HapticManager.medium()
                        playerManager.cancelSleepTimer()
                        dismiss()
                    } label: {
                        Text("Turn Off Timer")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    // Done Button
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.bottom, 24)
                } else {
                    // Inactive — show options to set a timer
                    Text("Audio will fade out and stop after the selected time")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Timer Options Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(timerOptions, id: \.self) { minutes in
                            Button {
                                selectedMinutes = minutes
                            } label: {
                                Text("\(minutes) min")
                                    .font(.headline)
                                    .foregroundStyle(selectedMinutes == minutes ? .white : Theme.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        selectedMinutes == minutes
                                            ? Color.white.opacity(0.25)
                                            : Theme.cardBackground
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 16)

                    // Start Timer Button
                    Button {
                        HapticManager.success()
                        AudioPlayerManager.shared.setSleepTimer(minutes: selectedMinutes)
                        dismiss()
                    } label: {
                        Text("Start Timer")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    // Cancel Button
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func timerFormattedLong(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct SoundMixerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var mixer = AmbientSoundManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                VStack(spacing: 24) {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(mixer.availableSounds) { sound in
                                SoundMixerRow(
                                    sound: sound,
                                    isActive: mixer.isActive(sound),
                                    isLoading: mixer.isLoadingSound(sound),
                                    volume: mixer.volume(for: sound),
                                    onToggle: { mixer.toggleSound(sound) },
                                    onVolumeChange: { mixer.setVolume(for: sound, volume: $0) }
                                )
                            }
                        }
                        .padding()
                    }

                    Button {
                        mixer.resetAll()
                    } label: {
                        Text("Reset All")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Mix Your Perfect Soundscape")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Theme.cardBackground, for: .navigationBar)
        }
        .presentationDetents([.large])
    }
}

struct SoundMixerRow: View {
    let sound: AmbientSound
    let isActive: Bool
    let isLoading: Bool
    let volume: Double
    let onToggle: () -> Void
    let onVolumeChange: (Double) -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                ZStack {
                    Image(systemName: sound.iconName)
                        .font(.title2)
                        .foregroundStyle(isActive ? .white : Theme.textSecondary)
                        .frame(width: 40)
                        .opacity(isLoading ? 0.3 : 1)

                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                }

                Text(sound.name)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { isActive || isLoading },
                    set: { _ in onToggle() }
                ))
                .labelsHidden()
                .tint(.white)
                .disabled(isLoading)
            }

            if isActive {
                Slider(value: Binding(
                    get: { volume },
                    set: { onVolumeChange($0) }
                ), in: 0...1)
                .tint(.white)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Tonight's Pick Card

struct TonightsPickCard: View {
    let content: Content
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                // Thumbnail
                CachedAsyncImage(
                    url: URL(string: content.thumbnailURLComputed),
                    failedIconName: content.contentType.iconName,
                    content: { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .scaleEffect(1.15)
                            .clipped()
                    },
                    placeholder: {
                        Rectangle()
                            .fill(Theme.sleepCardBackground)
                            .frame(height: 180)
                            .overlay(ProgressView().tint(.white.opacity(0.5)))
                    }
                )
                .frame(height: 180)
                .clipped()

                // Gradient overlay
                LinearGradient(
                    colors: [.clear, .black.opacity(0.4), .black.opacity(0.85)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Text overlay
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.stars.fill")
                            .font(.caption)
                        Text("Tonight's Pick")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white.opacity(0.8))

                    Text(content.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    if let narrator = content.narrator {
                        Text("by \(narrator)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bedtime Reminder Prompt

struct BedtimeReminderPrompt: View {
    let onEnable: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.fill")
                .font(.body)
                .foregroundStyle(Theme.sleepPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Set a bedtime reminder?")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.sleepTextPrimary)
                Text("We'll remind you to wind down")
                    .font(.caption)
                    .foregroundStyle(Theme.sleepTextSecondary)
            }

            Spacer()

            Button("Enable") {
                onEnable()
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.sleepPrimary)
            .clipShape(Capsule())

            Button {
                withAnimation { onDismiss() }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(Theme.sleepTextSecondary)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(12)
        .background(Theme.sleepCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    SleepView()
        .modelContainer(for: Content.self, inMemory: true)
        .preferredColorScheme(.dark)
}
