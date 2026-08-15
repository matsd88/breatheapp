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

    @State private var selectedCategory: SleepCategory = .sleepStories
    @State private var showScrollToTop = false
    @State private var activeSleepSheet: SleepSheetType?
    @State private var durationFilter: DurationFilter = .all
    @State private var showSleepPreparation = false

    // MARK: - Memoized derived state
    @State private var contentByCategory: [ContentType: [Content]] = [:]
    @State private var cachedFavoriteIDSet: Set<UUID> = []
    @State private var cachedFavoriteVideoIDSet: Set<String> = []

    // MARK: - Sleep Categories
    private enum SleepCategory: CaseIterable {
        case sleepStories, soundscapes, music, asmr

        var title: String {
            switch self {
            case .sleepStories: return "Sleep Stories"
            case .soundscapes: return "Soundscapes"
            case .music: return "Music"
            case .asmr: return "ASMR"
            }
        }

        var icon: String { contentType.iconName }

        var contentType: ContentType {
            switch self {
            case .sleepStories: return .sleepStory
            case .soundscapes: return .soundscape
            case .music: return .music
            case .asmr: return .asmr
            }
        }
    }

    enum SleepSheetType: Identifiable {
        case sleepTimer, alarm, analytics, soundMixer, premium
        case addToPlaylist(Content)
        var id: String {
            switch self {
            case .sleepTimer: return "sleepTimer"
            case .alarm: return "alarm"
            case .analytics: return "analytics"
            case .soundMixer: return "soundMixer"
            case .premium: return "premium"
            case .addToPlaylist(let c): return "playlist-\(c.youtubeVideoID)"
            }
        }
    }
    @StateObject private var playerManager = AudioPlayerManager.shared
    /// Observed so the sleep-timer tile's countdown stays live (fast time
    /// state moved off AudioPlayerManager's published properties). Ticks at
    /// most 1 Hz, and only while a sleep timer is active.
    @ObservedObject private var sleepTimerClock = AudioPlayerManager.shared.sleepTimerClock
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var circadian = CircadianService.shared
    @StateObject private var health = HealthKitService.shared
    @Query(sort: \MeditationSession.startedAt, order: .reverse) private var sessions: [MeditationSession]
    @AppStorage("dismissedBedtimePrompt") private var dismissedBedtimePrompt = false

    private let sleepTimeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()

    /// Whether the user is inside tonight's wind-down window, using the same
    /// circadian schedule the wind-down banner above already renders from.
    private var isInWindDownWindow: Bool {
        guard let windDown = circadian.schedule().windows.first(where: {
            if case .windDown = $0.type { return true } else { return false }
        }) else { return false }
        let now = Date()
        return now >= windDown.start && now <= windDown.end
    }

    /// Leads with the moment the user is actually in — inside their wind-down
    /// window the pitch is tonight, otherwise it's the tool they're browsing.
    private var sleepPremiumHook: String? {
        if isInWindDownWindow {
            return String(localized: "Drift off tonight to any of 100+ sleep stories")
        }
        switch selectedCategory {
        case .soundscapes:
            return String(localized: "Every soundscape, layered your way")
        case .asmr:
            return String(localized: "The full ASMR collection, unlocked")
        default:
            return String(localized: "100+ sleep stories, and downloads for offline nights")
        }
    }

    // MARK: - Wind-down window banner (circadian)
    @ViewBuilder
    private var windDownBanner: some View {
        let schedule = circadian.schedule()
        if let windDown = schedule.windows.first(where: {
            if case .windDown = $0.type { return true } else { return false }
        }) {
            let now = Date()
            let active = now >= windDown.start && now <= windDown.end
            Button {
                HapticManager.light()
                showSleepPreparation = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "moon.stars.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.sleepPrimary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(active ? "It's your wind-down window" : "Wind-down window")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.sleepTextPrimary)
                        Text(active
                             ? "Now's the ideal time to start a sleep story or breathing."
                             : "Best time to wind down: \(sleepTimeFormatter.string(from: windDown.start))")
                            .font(.caption)
                            .foregroundStyle(Theme.sleepTextSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.sleepTextSecondary.opacity(0.6))
                }
                .padding(16)
                .background(active ? Theme.sleepPrimary.opacity(0.15) : Theme.sleepCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        }
    }

    // MARK: - Last night's sleep snapshot
    @ViewBuilder
    private var lastNightStrip: some View {
        let score = SleepAnalyticsService.shared.calculateSleepScore(from: sessions)
        if score.overall > 0 || health.sleepHoursToday > 0 {
            Button {
                HapticManager.light()
                activeSleepSheet = .analytics
            } label: {
                HStack(spacing: 16) {
                    if score.overall > 0 {
                        lastNightMetric(value: "\(score.overall)", label: "Sleep Score", tint: score.color)
                    }
                    if health.sleepHoursToday > 0 {
                        Divider().frame(height: 32).overlay(Color.white.opacity(0.1))
                        lastNightMetric(value: String(format: "%.1fh", health.sleepHoursToday), label: "Last night", tint: Theme.sleepPrimary)
                    }
                    Spacer(minLength: 0)
                    Text("Details")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.sleepTextSecondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.sleepTextSecondary.opacity(0.6))
                }
                .padding(16)
                .background(Theme.sleepCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        }
    }

    private func lastNightMetric(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title2.weight(.bold)).foregroundStyle(tint)
            Text(label).font(.caption2).foregroundStyle(Theme.sleepTextSecondary)
        }
    }

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
        contentByCategory[selectedCategory.contentType] ?? []
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
                .frame(maxWidth: sizeClass == .regular ? 1100 : 700)
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

                            // Wind-down window (circadian) + last night's sleep snapshot
                            windDownBanner
                            lastNightStrip

                            // Category picker, with duration folded into a trailing
                            // menu. These were two stacked full-width scrollers,
                            // which — on top of the tools row and the wind-down
                            // banner — put four bands of chrome above any content.
                            // Category is the primary axis and stays visible;
                            // duration is a refinement and now costs no vertical space.
                            HStack(spacing: 8) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(SleepCategory.allCases, id: \.self) { category in
                                            SleepCategoryPill(title: category.title, isSelected: selectedCategory == category) {
                                                HapticManager.selection()
                                                withAnimation { selectedCategory = category }
                                            }
                                        }
                                    }
                                    .padding(.leading)
                                    .padding(.trailing, 4)
                                }

                                Menu {
                                    ForEach(DurationFilter.allCases, id: \.rawValue) { filter in
                                        Button {
                                            HapticManager.selection()
                                            withAnimation { durationFilter = filter }
                                        } label: {
                                            if durationFilter == filter {
                                                Label(filter.displayName, systemImage: "checkmark")
                                            } else {
                                                Text(filter.displayName)
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "clock")
                                            .font(.caption2)
                                        Text(durationFilter == .all
                                             ? String(localized: "Any length")
                                             : durationFilter.displayName)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                    }
                                    .foregroundStyle(durationFilter == .all ? Theme.sleepTextSecondary : .white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(durationFilter == .all
                                                ? Theme.sleepCardBackground
                                                : Color.white.opacity(0.2))
                                    .clipShape(Capsule())
                                }
                                .padding(.trailing)
                                .accessibilityLabel(String(localized: "Filter by length"))
                                .accessibilityValue(durationFilter == .all
                                                    ? String(localized: "Any length")
                                                    : durationFilter.displayName)
                            }

                            // Sound Mixer Card (only shown in Soundscapes tab)
                            if selectedCategory == .soundscapes {
                                SoundMixerCard {
                                    activeSleepSheet = .soundMixer
                                }
                                .padding(.horizontal)
                            }

                            // Content Grid - Adaptive for iPad
                            LazyVGrid(
                                columns: [
                                    GridItem(.adaptive(minimum: 160, maximum: sizeClass == .regular ? 220 : 200), spacing: 16, alignment: .top)
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

                            // Sleep Lab tools (moved below the content shelves)
                            SleepToolsSection()

                            // The Sleep tab had no upsell at all, even though
                            // most of what it shows — stories, soundscapes,
                            // offline downloads — is the premium pitch.
                            if !storeManager.isSubscribed {
                                Button {
                                    HapticManager.light()
                                    activeSleepSheet = .premium
                                } label: {
                                    PremiumUpsellBanner(hook: sleepPremiumHook)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }

                            // Sleep Preparation + bedtime nudge (secondary, near the bottom)
                            SleepPreparationCard {
                                showSleepPreparation = true
                            }
                            .padding(.horizontal)

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

                            Spacer(minLength: 100)
                        }
                        .frame(maxWidth: sizeClass == .regular ? 1100 : 700)
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
                            .accessibilityLabel("Scroll to top")
                        }
                    }
                }
            }
        }
        .onChange(of: selectedCategory) { _, _ in
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
            case .premium:
                PremiumPaywallView(
                    storeManager: storeManager,
                    context: .sleepBanner,
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
            .accessibilityLabel(title)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
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
            .accessibilityLabel(content.title)
            .accessibilityHint("Plays this content")
            .accessibilityAddTraits(.isButton)

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
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel("More options")
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
    /// Live countdown display (sleep-timer state lives on its own clock).
    @ObservedObject private var sleepTimerClock = AudioPlayerManager.shared.sleepTimerClock
    @State private var selectedMinutes = 30

    let timerOptions = [15, 30, 45, 60, 90, 120]

    private var isTimerActive: Bool {
        playerManager.sleepTimerActive
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

                if isTimerActive {
                    // Active timer state — countdown or stop mode
                    if let remaining = playerManager.sleepTimerRemaining {
                        Text(timerFormattedLong(remaining))
                            .font(.system(size: isRegular ? 64 : 48, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.vertical, isRegular ? 16 : 8)

                        Text("Audio will fade out and stop")
                            .font(isRegular ? .body : .subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    } else if let mode = playerManager.sleepStopMode {
                        Image(systemName: mode == .endOfTrack ? "stop.circle" : "list.bullet.circle")
                            .font(.system(size: isRegular ? 56 : 44, weight: .light))
                            .foregroundStyle(.white)
                            .padding(.vertical, isRegular ? 16 : 8)

                        Text(mode == .endOfTrack
                             ? "Audio will stop when this session ends"
                             : "Audio will stop when the queue finishes")
                            .font(isRegular ? .body : .subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

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

                    // Stop-at options — no countdown, just a natural end point
                    HStack(spacing: 12) {
                        sleepStopModeButton(.endOfTrack, icon: "stop.circle")
                        if playerManager.queue.count > 1 {
                            sleepStopModeButton(.endOfQueue, icon: "list.bullet.circle")
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
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func timerFormattedLong(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    /// "End of session" / "End of queue" option — stops playback at a natural
    /// end point instead of a fixed countdown.
    private func sleepStopModeButton(_ mode: AudioPlayerManager.SleepStopMode, icon: String) -> some View {
        Button {
            HapticManager.success()
            playerManager.setSleepStopMode(mode)
            dismiss()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(mode.label)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.cardBackground)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Stops playback at the \(mode == .endOfTrack ? "end of this session" : "end of the queue")")
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
                .accessibilityLabel(sound.name)
            }

            if isActive {
                Slider(value: Binding(
                    get: { volume },
                    set: { onVolumeChange($0) }
                ), in: 0...1)
                .tint(.white)
                .accessibilityLabel("\(sound.name) volume")
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
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Dismiss")
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
