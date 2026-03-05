//
//  SleepView.swift
//  Meditation Sleep Mindset
//

import SwiftUI
import SwiftData

struct SleepView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(filter: #Predicate<Content> {
        $0.contentTypeRaw == "Sleep Story" ||
        $0.contentTypeRaw == "Soundscape" ||
        $0.contentTypeRaw == "Music" ||
        $0.contentTypeRaw == "ASMR"
    })
    private var sleepContent: [Content]
    @Query private var favorites: [FavoriteContent]

    @State private var selectedTab = 0
    @State private var showScrollToTop = false
    @State private var activeSleepSheet: SleepSheetType?
    @State private var durationFilter: DurationFilter = .all
    @State private var showSleepPreparation = false

    // MARK: - Memoized derived state
    @State private var contentByCategory: [ContentType: [Content]] = [:]
    @State private var cachedFavoriteIDSet: Set<UUID> = []
    @State private var cachedFavoriteVideoIDSet: Set<String> = []

    enum SleepSheetType: Identifiable {
        case sleepTimer, alarm, analytics, soundMixer, sessionLimit
        case addToPlaylist(Content)
        var id: String {
            switch self {
            case .sleepTimer: return "sleepTimer"
            case .alarm: return "alarm"
            case .analytics: return "analytics"
            case .soundMixer: return "soundMixer"
            case .sessionLimit: return "sessionLimit"
            case .addToPlaylist(let c): return "playlist-\(c.youtubeVideoID)"
            }
        }
    }
    @StateObject private var playerManager = AudioPlayerManager.shared
    @StateObject private var notificationService = NotificationService.shared
    @AppStorage("dismissedBedtimePrompt") private var dismissedBedtimePrompt = false

    // MARK: - Duration Filter
    enum DurationFilter: String, CaseIterable {
        case all = "All"
        case short = "Under 30m"
        case medium = "30-60m"
        case long = "1hr+"

        var displayName: String {
            switch self {
            case .all: return String(localized: "All")
            case .short: return String(localized: "Under 30m")
            case .medium: return String(localized: "30-60m")
            case .long: return String(localized: "1hr+")
            }
        }
    }

    private var sleepStories: [Content] { contentByCategory[.sleepStory] ?? [] }
    private var soundscapes: [Content] { contentByCategory[.soundscape] ?? [] }
    private var music: [Content] { contentByCategory[.music] ?? [] }
    private var asmr: [Content] { contentByCategory[.asmr] ?? [] }

    private func rebuildContentCategories() {
        contentByCategory = Dictionary(grouping: sleepContent, by: \.contentType)
        cachedFavoriteIDSet = Set(favorites.map { $0.contentID })
        cachedFavoriteVideoIDSet = Set(favorites.compactMap { $0.youtubeVideoID })
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
        let index = dayOfYear % allSleep.count
        return allSleep[safe: index]
    }

    // MARK: - Sleep Pills
    private var sleepPillsRow: some View {
        HStack(spacing: sizeClass == .regular ? 12 : 8) {
            SleepActionPill(
                title: playerManager.sleepTimerRemaining.map { timerFormatted($0) } ?? "Timer",
                icon: "moon.zzz.fill",
                isActive: playerManager.sleepTimerRemaining != nil
            ) {
                activeSleepSheet = .sleepTimer
            }

            SleepActionPill(
                title: AlarmService.shared.isEnabled ? AlarmService.shared.formattedAlarmTime : "Alarm",
                icon: "alarm.fill",
                isActive: AlarmService.shared.isEnabled
            ) {
                activeSleepSheet = .alarm
            }

            SleepActionPill(
                title: "Analytics",
                icon: "chart.bar.fill",
                isActive: false
            ) {
                activeSleepSheet = .analytics
            }

            if sizeClass != .regular {
                Spacer()
            }
        }
    }

    var body: some View {
        ZStack {
            Theme.sleepBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Fixed header — outside ScrollView for reliable iPad touch handling
                VStack(alignment: .leading, spacing: sizeClass == .regular ? 14 : 8) {
                    HStack {
                        Text("Sleep")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(Theme.sleepTextPrimary)
                        Spacer()
                    }

                    sleepPillsRow
                }
                .padding(.horizontal)
                .padding(.top, sizeClass == .regular ? 12 : 8)
                .padding(.bottom, sizeClass == .regular ? 14 : 8)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 24) {
                            Color.clear.frame(height: 0).id("sleepTop")

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

                            // Sleep Preparation Card
                            SleepPreparationCard {
                                showSleepPreparation = true
                            }
                            .padding(.horizontal)

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
                                        Text(filter.displayName)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundStyle(durationFilter == filter ? .white : Theme.sleepTextSecondary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 7)
                                            .background(durationFilter == filter ? Color.white.opacity(0.2) : Theme.sleepCardBackground)
                                            .clipShape(Capsule())
                                            .contentShape(Capsule())
                                            .onTapGesture {
                                                HapticManager.selection()
                                                withAnimation { durationFilter = filter }
                                            }
                                    }
                                }
                                .padding(.horizontal)
                            }

                            // Sound Mixer Card (only shown in Soundscapes tab)
                            if selectedTab == 1 {
                                SoundMixerCard {
                                    activeSleepSheet = .soundMixer
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
                                        onAddToPlaylist: { activeSleepSheet = .addToPlaylist(content) },
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
        }
        .onChange(of: selectedTab) { _, _ in
            showScrollToTop = false
            prefetchCurrentContent()
        }
        .onAppear {
            rebuildContentCategories()
            prefetchCurrentContent()
        }
        .onChange(of: sleepContent.count) { _, _ in
            rebuildContentCategories()
        }
        .onChange(of: favorites.count) { _, _ in
            cachedFavoriteIDSet = Set(favorites.map { $0.contentID })
            cachedFavoriteVideoIDSet = Set(favorites.compactMap { $0.youtubeVideoID })
        }
        .sheet(item: $activeSleepSheet) { sheet in
            switch sheet {
            case .sleepTimer:
                SleepTimerView()
            case .alarm:
                AlarmSettingsView()
            case .analytics:
                SleepAnalyticsDashboard()
            case .soundMixer:
                SoundMixerView()
            case .sessionLimit:
                PremiumPaywallView(
                    storeManager: StoreManager.shared,
                    sessionLimitMessage: "This is a premium meditation. Subscribe to unlock the full library.",
                    onSubscribed: { activeSleepSheet = nil }
                )
            case .addToPlaylist(let content):
                AddToPlaylistSheet(content: content)
            }
        }
        .sheet(isPresented: $showSleepPreparation) {
            SleepPreparationView()
        }
    }

    private func timerFormatted(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func isFavorite(_ content: Content) -> Bool {
        cachedFavoriteIDSet.contains(content.id) || cachedFavoriteVideoIDSet.contains(content.youtubeVideoID)
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
            onAddToPlaylist: { activeSleepSheet = .addToPlaylist(content) },
            onShare: { shareContent(content) }
        )
    }

    /// Play content with the current tab's queue for auto-play
    private func playContent(_ content: Content, from queue: [Content]) {
        if !StoreManager.shared.isSubscribed && AppStateManager.shared.hasReachedFreeSessionLimit {
            activeSleepSheet = .sessionLimit
            return
        }
        let startIndex = queue.firstIndex(where: { $0.id == content.id }) ?? 0
        let manager = AudioPlayerManager.shared
        manager.queue = queue
        manager.currentIndex = startIndex
        manager.currentContent = content
        manager.shouldPresentPlayer = true
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
        Text(title)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(isSelected ? .white : Theme.sleepTextSecondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(isSelected ? Color.white.opacity(0.2) : Theme.sleepCardBackground)
            .clipShape(Capsule())
            .contentShape(Capsule())
            .onTapGesture { action() }
    }
}

struct SleepActionPill: View {
    let title: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Button {
            HapticManager.selection()
            action()
        } label: {
            Group {
                if sizeClass == .regular {
                    // iPad: vertical card layout
                    VStack(spacing: 8) {
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundStyle(isActive ? .white : Theme.sleepTextSecondary)

                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .monospacedDigit()
                            .foregroundStyle(isActive ? .white : Theme.sleepTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isActive ? Theme.sleepPrimary.opacity(0.25) : Theme.sleepCardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isActive ? Theme.sleepPrimary.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    // iPhone: compact capsule
                    Label(title, systemImage: icon)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(isActive ? .white : Theme.sleepTextSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(minHeight: 44)
                        .background(Theme.sleepCardBackground)
                        .clipShape(Capsule())
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
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

    @Environment(\.horizontalSizeClass) private var sizeClass

    // Adaptive height for iPad
    private var cardImageHeight: CGFloat { sizeClass == .regular ? 160 : 120 }

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
            .frame(height: cardImageHeight)
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
                        if let narrator = content.narrator {
                            Text("·")
                            Text(narrator)
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
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var playerManager = AudioPlayerManager.shared
    @State private var selectedMinutes = 30

    let timerOptions = [15, 30, 45, 60, 90, 120]

    private var isTimerActive: Bool {
        playerManager.sleepTimerRemaining != nil
    }

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        ZStack {
            Theme.profileGradient.ignoresSafeArea()

            VStack(spacing: isRegular ? 28 : 20) {
                Spacer(minLength: isRegular ? 48 : 32)

                // Icon
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: isRegular ? 64 : 50))
                    .foregroundStyle(.white.opacity(0.9))

                // Title
                Text("Sleep Timer")
                    .font(isRegular ? .title : .title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.textPrimary)

                if isTimerActive, let remaining = playerManager.sleepTimerRemaining {
                    // Active timer state
                    Text(timerFormattedLong(remaining))
                        .font(.system(size: isRegular ? 64 : 48, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.vertical, isRegular ? 16 : 8)

                    Text("Audio will fade out and stop")
                        .font(isRegular ? .body : .subheadline)
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
                            .padding(isRegular ? 18 : 16)
                            .background(Color.red.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: isRegular ? 14 : 12))
                    }
                    .padding(.horizontal, isRegular ? 40 : 16)

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
                        .font(isRegular ? .body : .subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Timer Options Grid — iPad: larger cards with duration labels
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: isRegular ? 16 : 12) {
                        ForEach(timerOptions, id: \.self) { minutes in
                            Button {
                                HapticManager.selection()
                                selectedMinutes = minutes
                            } label: {
                                VStack(spacing: isRegular ? 6 : 0) {
                                    if isRegular {
                                        Text("\(minutes)")
                                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                                            .foregroundStyle(selectedMinutes == minutes ? .white : Theme.textPrimary)

                                        Text("minutes")
                                            .font(.caption)
                                            .foregroundStyle(selectedMinutes == minutes ? .white.opacity(0.7) : Theme.textSecondary)
                                    } else {
                                        Text("\(minutes) min")
                                            .font(.headline)
                                            .foregroundStyle(selectedMinutes == minutes ? .white : Theme.textPrimary)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, isRegular ? 24 : 14)
                                .background(
                                    selectedMinutes == minutes
                                        ? Color.white.opacity(0.25)
                                        : Theme.cardBackground
                                )
                                .overlay(
                                    isRegular ?
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(selectedMinutes == minutes ? Color.white.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
                                        : nil
                                )
                                .clipShape(RoundedRectangle(cornerRadius: isRegular ? 14 : 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, isRegular ? 32 : 16)

                    Spacer(minLength: isRegular ? 24 : 16)

                    // Start Timer Button
                    Button {
                        HapticManager.success()
                        AudioPlayerManager.shared.setSleepTimer(minutes: selectedMinutes)
                        dismiss()
                    } label: {
                        Text("Start Timer")
                            .font(isRegular ? .title3.weight(.semibold) : .headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(isRegular ? 18 : 16)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: isRegular ? 14 : 12))
                    }
                    .padding(.horizontal, isRegular ? 32 : 16)

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
            .frame(maxWidth: isRegular ? 520 : 500)
            .frame(maxWidth: .infinity)
        }
        .presentationDetents(isRegular ? [.medium] : [.medium, .large])
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
    @Environment(\.horizontalSizeClass) private var sizeClass
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
                .frame(maxWidth: sizeClass == .regular ? 700 : 600)
                .frame(maxWidth: .infinity)
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

    @Environment(\.horizontalSizeClass) private var sizeClass

    // Adaptive height for iPad
    private var pickCardHeight: CGFloat { sizeClass == .regular ? 240 : 180 }

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
                            .frame(height: pickCardHeight)
                            .scaleEffect(1.15)
                            .clipped()
                    },
                    placeholder: {
                        Rectangle()
                            .fill(Theme.sleepCardBackground)
                            .frame(height: pickCardHeight)
                            .overlay(ProgressView().tint(.white.opacity(0.5)))
                    }
                )
                .frame(height: pickCardHeight)
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

// MARK: - Sleep Preparation Card

struct SleepPreparationCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.sleepPrimary.opacity(0.3), Color.indigo.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: "moon.stars.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.sleepPrimary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Sleep Preparation")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Guided bedtime routine")
                        .font(.caption)
                        .foregroundStyle(Theme.sleepTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.sleepTextSecondary)
            }
            .padding(14)
            .background(
                LinearGradient(
                    colors: [
                        Color.indigo.opacity(0.2),
                        Theme.sleepPrimary.opacity(0.15)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.sleepPrimary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SleepView()
        .modelContainer(for: Content.self, inMemory: true)
        .preferredColorScheme(.dark)
}
