//
//  ProfileView.swift
//  Meditation Sleep Mindset
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query private var userProfiles: [UserProfile]
    @Query(sort: \MeditationSession.startedAt, order: .reverse) private var sessions: [MeditationSession]
    @Query private var favorites: [FavoriteContent]
    @Query private var allContent: [Content]
    @Query(sort: \Playlist.updatedAt, order: .reverse) private var playlists: [Playlist]
    @Query private var playlistItems: [PlaylistItem]
    @StateObject private var streakService = StreakService.shared
    @State private var showingSettings = false
    @State private var showingShareStats = false
    @State private var activeProfileSheet: ProfileSheetType?
    @State private var selectedContent: Content?
    @State private var newPlaylistName = ""
    @State private var showingMoodInsights = false

    enum ProfileSheetType: Identifiable {
        case recentlyPlayed
        case sessionLimit
        case playlist(Playlist)
        case addToPlaylist(Content)
        case createPlaylist
        var id: String {
            switch self {
            case .recentlyPlayed: return "recentlyPlayed"
            case .sessionLimit: return "sessionLimit"
            case .playlist(let p): return "playlist-\(p.id)"
            case .addToPlaylist(let c): return "playlist-\(c.youtubeVideoID)"
            case .createPlaylist: return "createPlaylist"
            }
        }
    }
    @State private var showingBadges = false
    @State private var showingChallenges = false
    @StateObject private var accountService = AccountService.shared
    @StateObject private var badgeService = BadgeService.shared
    @StateObject private var challengeService = ChallengeService.shared
    @StateObject private var healthKitService = HealthKitService.shared

    private var userProfile: UserProfile? {
        userProfiles.first
    }

    private var favoriteContents: [Content] {
        // Match by both contentID and youtubeVideoID for robustness
        let favoriteIDs = Set(favorites.map { $0.contentID })
        let favoriteVideoIDs = Set(favorites.compactMap { $0.youtubeVideoID })
        return allContent.filter { favoriteIDs.contains($0.id) || favoriteVideoIDs.contains($0.youtubeVideoID) }
    }

    private var recentlyPlayedContent: [Content] {
        // Get unique content from sessions, using youtubeVideoID as fallback for matching
        var seenVideoIDs = Set<String>()
        var uniqueContent: [Content] = []

        for session in sessions {
            // Try to match by youtubeVideoID first (more stable across app updates)
            if let videoID = session.youtubeVideoID {
                if !seenVideoIDs.contains(videoID) {
                    seenVideoIDs.insert(videoID)
                    if let content = allContent.first(where: { $0.youtubeVideoID == videoID }) {
                        uniqueContent.append(content)
                    }
                }
            } else if let contentID = session.contentID {
                // Fallback to contentID for older sessions
                if let content = allContent.first(where: { $0.id == contentID }) {
                    if !seenVideoIDs.contains(content.youtubeVideoID) {
                        seenVideoIDs.insert(content.youtubeVideoID)
                        uniqueContent.append(content)
                    }
                }
            }
        }

        return uniqueContent
    }

    private func contentFor(session: MeditationSession) -> Content? {
        guard let contentID = session.contentID else { return nil }
        return allContent.first { $0.id == contentID }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Streak Badge
                        if streakService.currentStreak > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .foregroundStyle(.orange)

                                Text("\(streakService.currentStreak) day streak")
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.2))
                            .clipShape(Capsule())
                        }

                        // Stats Overview with Share Button
                        StatsOverviewCard(profile: userProfile, streakService: streakService, onShareTap: {
                            HapticManager.medium()
                            showingShareStats = true
                        })

                        // Streak Card
                        StreakCard(streakService: streakService)

                        // Mood History
                        Button {
                            HapticManager.light()
                            showingMoodInsights = true
                        } label: {
                            MoodHistoryCard(moodHistory: ChatService.getMoodHistory(in: modelContext))
                        }
                        .buttonStyle(.plain)

                        // Badges/Achievements
                        Button {
                            HapticManager.light()
                            showingBadges = true
                        } label: {
                            BadgesPreviewCard(badgeService: badgeService)
                        }
                        .buttonStyle(.plain)

                        // Weekly Challenges
                        Button {
                            HapticManager.light()
                            showingChallenges = true
                        } label: {
                            ChallengesPreviewCard(challengeService: challengeService)
                        }
                        .buttonStyle(.plain)

                        // Apple Health - Mindful Minutes
                        MindfulMinutesCard(healthKitService: healthKitService)

                        // Visual separator between stats and content sections
                        HStack(spacing: 16) {
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 1)
                            Text("Your Library")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(Theme.textSecondary)
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 1)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // Recently Played Section (horizontal)
                        ProfileHorizontalSection(
                            title: "Recently Played\(recentlyPlayedContent.isEmpty ? "" : " (\(recentlyPlayedContent.count))")",
                            icon: "clock.arrow.circlepath",
                            isEmpty: recentlyPlayedContent.isEmpty,
                            emptyMessage: "Start listening to see your history here",
                            itemCount: recentlyPlayedContent.count,
                            onSeeAll: { activeProfileSheet = .recentlyPlayed }
                        ) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: 12) {
                                    ForEach(recentlyPlayedContent.prefix(6)) { content in
                                        RecentlyPlayedCardCompact(content: content) {
                                            playContent(content)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        // Favorites Section (horizontal)
                        ProfileHorizontalSection(
                            title: "Favorites\(favoriteContents.isEmpty ? "" : " (\(favoriteContents.count))")",
                            icon: "heart.fill",
                            isEmpty: favoriteContents.isEmpty,
                            emptyMessage: "Tap the heart on any content to save it here"
                        ) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: 12) {
                                    ForEach(favoriteContents.prefix(10)) { content in
                                        FavoriteCardCompact(
                                            content: content,
                                            onTap: { playContent(content) },
                                            onRemove: { removeFavorite(content) },
                                            onAddToPlaylist: { activeProfileSheet = .addToPlaylist(content) },
                                            onShare: { shareContent(content) }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        // Playlists Section (horizontal)
                        ProfileHorizontalSection(
                            title: "Playlists\(playlists.isEmpty ? "" : " (\(playlists.count))")",
                            icon: "rectangle.stack",
                            isEmpty: false,
                            emptyMessage: ""
                        ) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: 12) {
                                    // Create Playlist card (always visible)
                                    Button {
                                        HapticManager.medium()
                                        activeProfileSheet = .createPlaylist
                                    } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(Theme.cardBackground)
                                                    .frame(width: sizeClass == .regular ? 180 : 140, height: sizeClass == .regular ? 130 : 100)

                                                Image(systemName: "plus")
                                                    .font(.title)
                                                    .foregroundStyle(.white.opacity(0.6))
                                            }

                                            Text("Create Playlist")
                                                .font(sizeClass == .regular ? .subheadline : .caption)
                                                .fontWeight(.medium)
                                                .foregroundStyle(Theme.textPrimary)

                                            Text(" ")
                                                .font(sizeClass == .regular ? .caption : .caption2)
                                        }
                                        .frame(width: sizeClass == .regular ? 180 : 140)
                                    }
                                    .buttonStyle(.plain)

                                    // Existing playlists
                                    ForEach(playlists) { playlist in
                                        PlaylistCardCompact(
                                            playlist: playlist,
                                            itemCount: playlistItems.filter { $0.playlistID == playlist.id }.count,
                                            thumbnailURLs: playlistItems.filter { $0.playlistID == playlist.id }.prefix(4).map(\.thumbnailURL),
                                            onTap: {
                                                activeProfileSheet = .playlist(playlist)
                                            },
                                            onDelete: {
                                                deletePlaylist(playlist)
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        Spacer(minLength: 100)
                    }
                    .frame(maxWidth: 700)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom)
                }
                .refreshable {
                    HapticManager.light()
                    streakService.loadStreakData()
                    streakService.checkAndUpdateStreak()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                HStack {
                    // Invisible spacer to balance the settings button
                    Color.clear
                        .frame(width: 44, height: 44)

                    Spacer()

                    // Centered title
                    Text("You")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Spacer()

                    Button {
                        HapticManager.light()
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Theme.cardBackground)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(
                    Color(red: 0.08, green: 0.15, blue: 0.28)
                        .ignoresSafeArea(edges: .top)
                )
            }
            .fullScreenCover(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(AppStateManager.shared)
            }
            .fullScreenCover(isPresented: $showingShareStats) {
                ShareStatsView(streakService: streakService, sessions: sessions)
            }
            .sheet(item: $activeProfileSheet) { sheet in
                switch sheet {
                case .recentlyPlayed:
                    RecentlyPlayedListView(
                        recentlyPlayed: recentlyPlayedContent,
                        onContentTap: { content in
                            activeProfileSheet = nil
                            playContent(content)
                        }
                    )
                case .sessionLimit:
                    PremiumPaywallView(
                        storeManager: StoreManager.shared,
                        sessionLimitMessage: "This is a premium meditation. Subscribe to unlock the full library.",
                        onSubscribed: { activeProfileSheet = nil }
                    )
                case .playlist(let playlist):
                    PlaylistDetailView(playlist: playlist)
                case .addToPlaylist(let content):
                    AddToPlaylistSheet(content: content)
                case .createPlaylist:
                    CreatePlaylistSheet(
                        playlistName: $newPlaylistName,
                        onCreate: createPlaylist
                    )
                }
            }
            .sheet(isPresented: $accountService.shouldShowSignInSheet) {
                SignInWithAppleSheet(accountService: accountService)
            }
            .fullScreenCover(item: $selectedContent) { content in
                MeditationPlayerView(content: content)
            }
            .fullScreenCover(isPresented: $showingMoodInsights) {
                MoodInsightsView()
            }
            .fullScreenCover(isPresented: $showingBadges) {
                BadgesView()
            }
            .fullScreenCover(isPresented: $showingChallenges) {
                ChallengesView()
            }
        }
    }

    private func playContent(_ content: Content) {
        if !StoreManager.shared.isSubscribed && AppStateManager.shared.hasReachedFreeSessionLimit {
            activeProfileSheet = .sessionLimit
            return
        }
        selectedContent = content
    }

    private func removeFavorite(_ content: Content) {
        if let existing = favorites.first(where: { $0.contentID == content.id || $0.youtubeVideoID == content.youtubeVideoID }) {
            HapticManager.light()
            modelContext.delete(existing)
            ToastManager.shared.show("Removed from Favorites", icon: "heart.slash")
        }
    }

    private func createPlaylist() {
        let trimmed = newPlaylistName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let playlist = Playlist(name: trimmed)
        modelContext.insert(playlist)
        try? modelContext.save()
        newPlaylistName = ""
    }

    private func shareContent(_ content: Content) {
        ContentSharingHelper.share(content)
    }

    private func deletePlaylist(_ playlist: Playlist) {
        withAnimation {
            // Cascade delete all items in this playlist
            let itemsToDelete = playlistItems.filter { $0.playlistID == playlist.id }
            for item in itemsToDelete {
                modelContext.delete(item)
            }
            modelContext.delete(playlist)
            try? modelContext.save()
        }
    }
}

// MARK: - Horizontal Section Container
struct ProfileHorizontalSection<Content: View>: View {
    let title: String
    let icon: String
    let isEmpty: Bool
    let emptyMessage: String
    var itemCount: Int = 0
    var onSeeAll: (() -> Void)? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.white)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                if itemCount >= 6, let onSeeAll = onSeeAll {
                    Button(action: onSeeAll) {
                        Text("See All")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal)

            if isEmpty {
                HStack {
                    Spacer()
                    Text(emptyMessage)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.vertical, 24)
                .padding(.horizontal)
                .background(Theme.cardBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            } else {
                content
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Compact Favorite Card (for horizontal scroll)
struct FavoriteCardCompact: View {
    let content: Content
    let onTap: () -> Void
    let onRemove: () -> Void
    var onAddToPlaylist: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil

    @Environment(\.horizontalSizeClass) private var sizeClass

    // Adaptive sizes for iPad
    private var cardWidth: CGFloat { sizeClass == .regular ? 180 : 140 }
    private var cardHeight: CGFloat { sizeClass == .regular ? 130 : 100 }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    CachedAsyncImage(
                        url: URL(string: content.thumbnailURLComputed),
                        failedIconName: content.contentType.iconName,
                        content: { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .scaleEffect(1.15)
                        },
                        placeholder: {
                            Rectangle()
                                .fill(Theme.cardBackground)
                        }
                    )
                    .frame(width: cardWidth, height: cardHeight)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Image(systemName: "play.circle.fill")
                        .font(sizeClass == .regular ? .title : .title2)
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                        .padding(8)
                }

                Text(content.title)
                    .font(sizeClass == .regular ? .subheadline : .caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(content.durationFormatted)
                    .font(sizeClass == .regular ? .caption : .caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(width: cardWidth)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                withAnimation {
                    onRemove()
                }
            } label: {
                Label("Remove from Favorites", systemImage: "heart.slash")
            }

            if let onAddToPlaylist = onAddToPlaylist {
                Button {
                    onAddToPlaylist()
                } label: {
                    Label("Add to Playlist", systemImage: "text.badge.plus")
                }
            }

            if let onShare = onShare {
                Button {
                    onShare()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
    }
}

// MARK: - Compact History Card (for horizontal scroll)
struct HistoryCardCompact: View {
    let session: MeditationSession
    let content: Content?

    @Environment(\.horizontalSizeClass) private var sizeClass

    // Adaptive sizes for iPad
    private var cardWidth: CGFloat { sizeClass == .regular ? 180 : 140 }
    private var cardHeight: CGFloat { sizeClass == .regular ? 130 : 100 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let content = content {
                    CachedAsyncImage(
                        url: URL(string: content.thumbnailURLComputed),
                        failedIconName: content.contentType.iconName,
                        content: { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .scaleEffect(1.15)
                        },
                        placeholder: {
                            Rectangle()
                                .fill(Theme.cardBackground)
                        }
                    )
                } else {
                    Rectangle()
                        .fill(Theme.cardBackground)
                        .overlay {
                            Image(systemName: "timer")
                                .font(.title)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(content?.title ?? "Unguided Session")
                .font(sizeClass == .regular ? .subheadline : .caption)
                .fontWeight(.medium)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: 4) {
                Text(session.durationSeconds.formattedMinutes)
                Text("•")
                Text(session.startedAt.timeAgo)
            }
            .font(sizeClass == .regular ? .caption : .caption2)
            .foregroundStyle(Theme.textSecondary)
        }
        .frame(width: cardWidth)
    }
}

// MARK: - Compact Recently Played Card (for profile horizontal scroll)
struct RecentlyPlayedCardCompact: View {
    let content: Content
    let onTap: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    // Adaptive sizes for iPad
    private var cardWidth: CGFloat { sizeClass == .regular ? 180 : 140 }
    private var cardHeight: CGFloat { sizeClass == .regular ? 130 : 100 }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    CachedAsyncImage(
                        url: URL(string: content.thumbnailURLComputed),
                        failedIconName: content.contentType.iconName,
                        content: { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .scaleEffect(1.15)
                        },
                        placeholder: {
                            Rectangle()
                                .fill(Theme.cardBackground)
                        }
                    )
                    .frame(width: cardWidth, height: cardHeight)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Image(systemName: "play.circle.fill")
                        .font(sizeClass == .regular ? .title : .title2)
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                        .padding(8)
                }

                Text(content.title)
                    .font(sizeClass == .regular ? .subheadline : .caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(content.durationFormatted)
                    .font(sizeClass == .regular ? .caption : .caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(width: cardWidth)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stats Overview Card
struct StatsOverviewCard: View {
    let profile: UserProfile?
    let streakService: StreakService
    let onShareTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                StatItem(
                    value: streakService.totalTimeFormatted,
                    label: "Total Time",
                    icon: "clock.fill"
                )

                Rectangle()
                    .fill(Theme.textTertiary)
                    .frame(width: 1, height: 50)

                StatItem(
                    value: "\(streakService.totalSessions)",
                    label: "Sessions",
                    icon: "figure.mind.and.body"
                )

                Rectangle()
                    .fill(Theme.textTertiary)
                    .frame(width: 1, height: 50)

                StatItem(
                    value: "\(streakService.longestStreak)",
                    label: "Best Streak",
                    icon: "trophy.fill"
                )
            }
            .padding()

            Rectangle()
                .fill(Theme.textTertiary.opacity(0.5))
                .frame(height: 1)
                .padding(.horizontal)

            Button(action: onShareTap) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share My Stats")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

struct StatItem: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(.white)

                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.textPrimary)
            }

            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Streak Card
struct StreakCard: View {
    let streakService: StreakService
    @State private var flameScale: CGFloat = 1.0
    @State private var flameRotation: Double = 0

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: "flame.fill")
                    .font(.title)
                    .foregroundStyle(.orange)
                    .scaleEffect(flameScale)
                    .rotationEffect(.degrees(flameRotation))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(streakService.currentStreak) Day Streak!")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)

                Text(streakService.streakMessage)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .onAppear {
            // Animate the flame each time the card appears
            flameScale = 1.0
            flameRotation = 0

            // Delay slightly for better effect
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Bounce animation sequence
                withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                    flameScale = 1.3
                    flameRotation = -10
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                        flameRotation = 10
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                        flameScale = 1.0
                        flameRotation = 0
                    }
                }
            }
        }
    }
}

// MARK: - Mood History Card
struct MoodHistoryCard: View {
    let moodHistory: [ChatService.DayMood]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.white)
                Text("Mood History")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(.horizontal)

            if moodHistory.isEmpty || moodHistory.allSatisfy({ $0.mood == nil }) {
                HStack {
                    Spacer()
                    Text("Chat with Breathe AI to track your mood")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.vertical, 16)
            } else {
                HStack(spacing: 0) {
                    ForEach(moodHistory) { day in
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(day.mood?.color.opacity(0.2) ?? Color.white.opacity(0.06))
                                    .frame(width: 40, height: 40)

                                if let mood = day.mood {
                                    Text(mood.emoji)
                                        .font(.title3)
                                } else {
                                    Circle()
                                        .fill(Color.white.opacity(0.15))
                                        .frame(width: 8, height: 8)
                                }
                            }

                            Text(dayAbbreviation(for: day.date))
                                .font(.caption2)
                                .foregroundStyle(
                                    Calendar.current.isDateInToday(day.date)
                                        ? Theme.textPrimary
                                        : Theme.textTertiary
                                )
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 16)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private static let dayAbbrevFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    private func dayAbbreviation(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }
        return Self.dayAbbrevFormatter.string(from: date)
    }
}

// MARK: - Badges Preview Card
struct BadgesPreviewCard: View {
    @ObservedObject var badgeService: BadgeService

    private var earnedCount: Int {
        badgeService.earnedBadges.count
    }

    private var totalCount: Int {
        Badge.allBadges.count
    }

    /// Get a mix of earned and upcoming badges to display
    private var displayBadges: [Badge] {
        let allBadges = badgeService.allBadgesWithStatus

        // Start with recently earned badges
        var display: [Badge] = badgeService.recentlyEarnedBadges.prefix(3).map { $0 }

        // Add other earned badges
        let otherEarned = badgeService.earnedBadges
            .filter { earned in !display.contains { $0.id == earned.id } }
            .prefix(5 - display.count)
        display.append(contentsOf: otherEarned)

        // Fill remaining with unearned badges (sorted by progress)
        if display.count < 8 {
            let unearned = allBadges
                .filter { !$0.isEarned }
                .prefix(8 - display.count)
            display.append(contentsOf: unearned)
        }

        return Array(display.prefix(8))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
                Text("Badges")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                HStack(spacing: 4) {
                    Text("\(earnedCount)/\(totalCount)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(displayBadges) { badge in
                        BadgePreviewItem(badge: badge)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 16)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

struct BadgePreviewItem: View {
    let badge: Badge

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(badge.isEarned ? badge.color.opacity(0.2) : Color.white.opacity(0.06))
                    .frame(width: 56, height: 56)

                if badge.isEarned {
                    Image(systemName: badge.iconName)
                        .font(.title2)
                        .foregroundStyle(badge.color)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundStyle(Color.white.opacity(0.2))
                }
            }

            Text(badge.name)
                .font(.caption2)
                .foregroundStyle(badge.isEarned ? Theme.textSecondary : Theme.textTertiary)
                .multilineTextAlignment(.center)
                .frame(width: 64)
        }
    }
}

// MARK: - Challenges Preview Card
struct ChallengesPreviewCard: View {
    @ObservedObject var challengeService: ChallengeService

    private var activeChallenges: [Challenge] {
        challengeService.activeChallenges.filter { !$0.isCompleted }.prefix(4).map { $0 }
    }

    private var completedCount: Int {
        challengeService.activeChallenges.filter { $0.isCompleted }.count
    }

    private var totalCount: Int {
        challengeService.activeChallenges.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "flag.checkered")
                    .foregroundStyle(.green)
                Text("Weekly Challenges")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                HStack(spacing: 4) {
                    Text("\(completedCount)/\(totalCount)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(.horizontal)

            if challengeService.activeChallenges.isEmpty {
                HStack {
                    Spacer()
                    Text("Challenges reset every Monday")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.vertical, 16)
            } else {
                // Featured challenge or first active challenge
                if let featured = challengeService.featuredChallenge ?? activeChallenges.first {
                    HStack(spacing: 12) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(featured.color.opacity(0.2))
                                .frame(width: 44, height: 44)

                            Image(systemName: featured.iconName)
                                .font(.body)
                                .foregroundStyle(featured.color)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                if featured.isFeatured {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.yellow)
                                }
                                Text(featured.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                            }

                            // Progress bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(height: 6)

                                    Capsule()
                                        .fill(featured.color)
                                        .frame(width: geometry.size.width * featured.progressPercentage, height: 6)
                                }
                            }
                            .frame(height: 6)
                        }

                        Spacer()

                        // Progress text
                        Text("\(featured.progress)/\(featured.target)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal)
                }

                // Time remaining
                if let firstChallenge = challengeService.activeChallenges.first {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text(firstChallenge.timeRemaining)
                            .font(.caption)
                            .foregroundStyle(.orange)

                        Spacer()

                        // XP earned
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                            Text("\(challengeService.totalXPEarned) XP")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 16)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .onAppear {
            challengeService.checkAndRotateChallenges()
        }
    }
}

// MARK: - Settings Row (for ProfileView-specific settings)
struct ProfileSettingsRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 32)

            Text(title)
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding()
    }
}

// MARK: - Goal Settings View
struct GoalSettingsView: View {
    @Query private var userProfiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedGoals: Set<UserGoal> = []

    private var userProfile: UserProfile? {
        userProfiles.first
    }

    var body: some View {
        ZStack {
            Theme.profileGradient.ignoresSafeArea()

            List {
                Section {
                    ForEach(UserGoal.allCases) { goal in
                        Button {
                            if selectedGoals.contains(goal) {
                                selectedGoals.remove(goal)
                            } else {
                                selectedGoals.insert(goal)
                            }
                            saveGoals()
                        } label: {
                            HStack {
                                Image(systemName: goal.iconName)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .frame(width: 32)

                                Text(goal.displayName)
                                    .foregroundStyle(Theme.textPrimary)

                                Spacer()

                                if selectedGoals.contains(goal) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                } footer: {
                    Text("Select your meditation goals to get personalized recommendations.")
                        .foregroundStyle(Theme.textSecondary)
                }
                .listRowBackground(Theme.cardBackground)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let profile = userProfile {
                selectedGoals = Set(profile.goals)
            }
        }
    }

    private func saveGoals() {
        if let profile = userProfile {
            profile.selectedGoals = selectedGoals.map { $0.rawValue }
        }
    }
}

// MARK: - Share Stats View
struct ShareStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var streakService: StreakService
    let sessions: [MeditationSession]

    @State private var renderedImage: UIImage?

    private var totalMinutes: Int {
        sessions.reduce(0) { $0 + $1.durationSeconds / 60 }
    }

    private var formattedTime: String {
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours > 0 {
            return "\(hours) hr \(mins) min"
        }
        return "\(mins) min"
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.15, blue: 0.35),
                    Color(red: 0.15, green: 0.1, blue: 0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // X Dismiss Button
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .padding(.leading, 20)
                    .padding(.top, 16)

                    Spacer()
                }

                Spacer()

                // Stats Card (the shareable part)
                ShareableStatsCard(
                    mindfulDays: streakService.currentStreak,
                    totalSessions: sessions.count,
                    mindfulMinutes: formattedTime,
                    longestStreak: streakService.longestStreak
                )
                .padding(.horizontal, 40)

                Spacer()

                // Share Options
                VStack(spacing: 12) {
                    ShareOptionButton(
                        icon: "camera.fill",
                        title: "Instagram Stories",
                        action: { shareToInstagramStories() }
                    )

                    ShareOptionButton(
                        icon: "message.fill",
                        title: "Send Message",
                        action: { shareViaMessages() }
                    )

                    ShareOptionButton(
                        icon: "square.and.arrow.up",
                        title: "Share",
                        action: { shareGeneric() }
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            renderStatsCard()
        }
    }

    private func renderStatsCard() {
        let cardView = ShareableStatsCard(
            mindfulDays: streakService.currentStreak,
            totalSessions: sessions.count,
            mindfulMinutes: formattedTime,
            longestStreak: streakService.longestStreak
        )
        .frame(width: 300, height: 280)

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0
        renderedImage = renderer.uiImage
    }

    private func shareToInstagramStories() {
        guard let image = renderedImage,
              let imageData = image.pngData() else { return }

        let pasteboardItems: [[String: Any]] = [[
            "com.instagram.sharedSticker.backgroundImage": imageData,
            "com.instagram.sharedSticker.backgroundTopColor": "#1a1a3a",
            "com.instagram.sharedSticker.backgroundBottomColor": "#2a1a4a"
        ]]

        let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [
            .expirationDate: Date().addingTimeInterval(60 * 5)
        ]

        UIPasteboard.general.setItems(pasteboardItems, options: pasteboardOptions)

        if let url = URL(string: "instagram-stories://share?source_application=com.meditation.Meditation-Sleep-Mindset") {
            UIApplication.shared.open(url)
        }
    }

    private func shareViaMessages() {
        guard let image = renderedImage else { return }
        let activityVC = UIActivityViewController(
            activityItems: [image, "Check out my meditation progress!"],
            applicationActivities: nil
        )
        activityVC.excludedActivityTypes = [.addToReadingList, .assignToContact]

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func shareGeneric() {
        guard let image = renderedImage else { return }
        let activityVC = UIActivityViewController(
            activityItems: [image, "I've been meditating with Meditation Sleep Mindset!"],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Shareable Stats Card
struct ShareableStatsCard: View {
    let mindfulDays: Int
    let totalSessions: Int
    let mindfulMinutes: String
    let longestStreak: Int

    var body: some View {
        VStack(spacing: 20) {
            // Mindful Days Badge
            VStack(spacing: 8) {
                ZStack {
                    // Decorative circle
                    Circle()
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 2)
                        .frame(width: 100, height: 100)

                    Circle()
                        .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
                        .frame(width: 85, height: 85)

                    VStack(spacing: 2) {
                        Text("\(mindfulDays)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }

                Text("Mindful Days")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.9))
            }

            // Stats Row
            HStack(spacing: 24) {
                ShareStatItem(
                    icon: "calendar",
                    value: "\(totalSessions)",
                    label: "Total Sessions"
                )

                ShareStatItem(
                    icon: "clock",
                    value: mindfulMinutes,
                    label: "Mindful Minutes"
                )

                ShareStatItem(
                    icon: "flame",
                    value: "\(longestStreak) day",
                    label: "Longest Streak"
                )
            }

            // App Name
            Text("Meditation Sleep Mindset")
                .font(.caption)
                .italic()
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 8)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.2, blue: 0.4),
                            Color(red: 0.2, green: 0.15, blue: 0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct ShareStatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ShareOptionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.black)
                    .frame(width: 24)

                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.black)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Mindful Minutes Card (Apple Health)
struct MindfulMinutesCard: View {
    @ObservedObject var healthKitService: HealthKitService

    private var weekTotal: Int {
        healthKitService.weeklyMindfulMinutes.reduce(0) { $0 + $1.minutes }
    }

    private var maxDayMinutes: Int {
        max(healthKitService.weeklyMindfulMinutes.map(\.minutes).max() ?? 1, 1)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                Text("Apple Health")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                if healthKitService.isEnabled {
                    Text("\(weekTotal) min this week")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal)

            if !HealthKitService.isAvailable {
                // Device doesn't support HealthKit
                HStack {
                    Spacer()
                    Text("HealthKit is not available on this device")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                }
                .padding(.vertical, 16)
            } else if !healthKitService.isEnabled {
                // Not enabled — show enable prompt
                VStack(spacing: 12) {
                    Text("Sync your meditation sessions as Mindful Minutes in Apple Health")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)

                    Button {
                        HapticManager.medium()
                        healthKitService.isEnabled = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.circle.fill")
                            Text("Enable Apple Health")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.8))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            } else {
                // Enabled — show today + weekly chart
                VStack(spacing: 16) {
                    // Today's minutes highlight
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.2))
                                .frame(width: 48, height: 48)

                            Image(systemName: "figure.mind.and.body")
                                .font(.title3)
                                .foregroundStyle(.green)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(healthKitService.todayMindfulMinutes) min")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Theme.textPrimary)
                            Text("Mindful minutes today")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)

                    // Weekly bar chart
                    if !healthKitService.weeklyMindfulMinutes.isEmpty {
                        HStack(alignment: .bottom, spacing: 0) {
                            ForEach(healthKitService.weeklyMindfulMinutes) { day in
                                VStack(spacing: 4) {
                                    if day.minutes > 0 {
                                        Text("\(day.minutes)")
                                            .font(.system(size: 9))
                                            .foregroundStyle(Theme.textTertiary)
                                    }

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            Calendar.current.isDateInToday(day.date)
                                                ? Color.green
                                                : Color.green.opacity(0.4)
                                        )
                                        .frame(height: max(4, CGFloat(day.minutes) / CGFloat(maxDayMinutes) * 40))

                                    Text(dayLabel(for: day.date))
                                        .font(.caption2)
                                        .foregroundStyle(
                                            Calendar.current.isDateInToday(day.date)
                                                ? Theme.textPrimary
                                                : Theme.textTertiary
                                        )
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .onAppear {
            if healthKitService.isEnabled {
                Task { await healthKitService.loadWeeklyMindfulMinutes() }
            }
        }
    }

    private func dayLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }
        return Self.dayFormatter.string(from: date)
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [UserProfile.self, MeditationSession.self, FavoriteContent.self, Content.self, Playlist.self, PlaylistItem.self], inMemory: true)
}
