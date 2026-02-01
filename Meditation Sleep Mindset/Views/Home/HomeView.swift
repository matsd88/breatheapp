//
//  HomeView.swift
//  Meditation Sleep Mindset
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userProfiles: [UserProfile]
    @Query(sort: \Content.title) private var allContent: [Content]
    @Query private var favorites: [FavoriteContent]
    @Query(sort: \Playlist.updatedAt, order: .reverse) private var playlists: [Playlist]
    @Query private var playlistItems: [PlaylistItem]
    @Query(sort: \MeditationSession.startedAt, order: .reverse) private var sessions: [MeditationSession]

    @State private var selectedMood: Mood?
    @State private var selectedContent: Content?
    @State private var selectedPlaylist: Playlist?
    @State private var showingTimer = false
    @State private var showingRecentlyPlayedList = false
    @State private var contentForPlaylistAdd: Content?
    @State private var cachedRecommendations: [Content] = HomeView.savedRecommendations
    @State private var lastRecommendationSeed: Int = 0
    @State private var isLoadingRecommendations = false
    @State private var recommendationTask: Task<Void, Never>?
    @StateObject private var streakService = StreakService.shared

    // Static cache so recommendations persist across tab switches
    private static var savedRecommendations: [Content] = []

    // Pre-computed index for faster tag lookups
    @State private var tagToContentIndex: [String: Set<UUID>] = [:]
    @State private var contentTypeIndex: [ContentType: Set<UUID>] = [:]

    private var userProfile: UserProfile? {
        userProfiles.first
    }

    /// Get user's onboarding pain point from UserDefaults (screen 1)
    private var userPainPoint: String? {
        UserDefaults.standard.string(forKey: "userPainPoint")
    }

    /// Get user's onboarding goals from UserDefaults (screen 2)
    private var userOnboardingGoals: [String] {
        UserDefaults.standard.stringArray(forKey: "userOnboardingGoals") ?? []
    }

    /// Map pain point to content tags for recommendation scoring
    private func tagsForPainPoint(_ painPoint: String) -> [String] {
        switch painPoint {
        case PainPoint.sleep.rawValue:
            return ["Sleep", "Relax", "Calm"]
        case PainPoint.anxiety.rawValue:
            return ["Anxiety", "Stress", "Calm", "Relax"]
        case PainPoint.racing.rawValue:
            return ["Focus", "Calm", "Anxiety", "Stress"]
        case PainPoint.calm.rawValue:
            return ["Calm", "Relax", "Gratitude", "Happiness"]
        default:
            return []
        }
    }

    /// Map pain point to preferred content types
    private var painPointContentTypes: [ContentType] {
        guard let painPoint = userPainPoint else { return [] }
        switch painPoint {
        case PainPoint.sleep.rawValue:
            return [.sleepStory, .asmr, .soundscape]
        case PainPoint.anxiety.rawValue:
            return [.meditation, .soundscape, .asmr]
        case PainPoint.racing.rawValue:
            return [.meditation, .soundscape, .mindset]
        case PainPoint.calm.rawValue:
            return [.meditation, .soundscape, .music]
        default:
            return []
        }
    }

    /// Map onboarding goals to content tags for recommendation scoring
    private func tagsForOnboardingGoal(_ goal: String) -> [String] {
        switch goal {
        case "Fall asleep faster":
            return ["Sleep", "Relax", "Calm"]
        case "Sleep through the night":
            return ["Sleep", "Calm"]
        case "Wake up refreshed":
            return ["Morning", "Energy", "Sleep"]
        case "Improve my mindset":
            return ["Self Esteem", "Happiness", "Gratitude", "Performance"]
        case "Reduce daily stress":
            return ["Stress", "Anxiety", "Relax", "Calm"]
        case "Build a meditation habit":
            return ["Focus", "Calm", "Morning"]
        default:
            return []
        }
    }

    /// Get content types preferred based on onboarding goals
    private var preferredContentTypes: [ContentType] {
        var types: Set<ContentType> = []

        for goal in userOnboardingGoals {
            switch goal {
            case "Fall asleep faster", "Sleep through the night":
                types.insert(.sleepStory)
                types.insert(.asmr)
                types.insert(.soundscape)
            case "Wake up refreshed":
                types.insert(.meditation)
                types.insert(.mindset)
            case "Improve my mindset":
                types.insert(.mindset)
                types.insert(.meditation)
            case "Reduce daily stress":
                types.insert(.meditation)
                types.insert(.soundscape)
                types.insert(.asmr)
            case "Build a meditation habit":
                types.insert(.meditation)
            default:
                break
            }
        }

        return Array(types)
    }

    // MARK: - Time of Day
    private enum TimeOfDay {
        case morning    // 5 AM - 11:59 AM
        case afternoon  // 12 PM - 4:59 PM
        case evening    // 5 PM - 8:59 PM
        case night      // 9 PM - 4:59 AM

        static var current: TimeOfDay {
            let hour = Calendar.current.component(.hour, from: Date())
            switch hour {
            case 5..<12:
                return .morning
            case 12..<17:
                return .afternoon
            case 17..<21:
                return .evening
            default:
                return .night
            }
        }

        var greeting: String {
            switch self {
            case .morning:
                return "Good Morning"
            case .afternoon:
                return "Good Afternoon"
            case .evening:
                return "Good Evening"
            case .night:
                return "Good Night"
            }
        }

        var contextualSuggestion: String {
            switch self {
            case .morning:
                return "Start your day with a mindful moment"
            case .afternoon:
                return "A short break can refresh your focus"
            case .evening:
                return "Wind down with a calming session"
            case .night:
                return "Relax into a peaceful sleep"
            }
        }

        var motivationalMessage: String {
            switch self {
            case .morning:
                return "Start your day with intention"
            case .afternoon:
                return "Take a moment for yourself"
            case .evening:
                return "Unwind and find your calm"
            case .night:
                return "Prepare for restful sleep"
            }
        }

        var recommendedContentTypes: [ContentType] {
            switch self {
            case .morning:
                return [.meditation, .mindset, .movement]
            case .afternoon:
                return [.meditation, .mindset, .soundscape]
            case .evening:
                return [.meditation, .soundscape, .asmr, .music]
            case .night:
                return [.sleepStory, .asmr, .soundscape, .music]
            }
        }

        var recommendedTags: [String] {
            switch self {
            case .morning:
                return ["Morning", "Energy", "Focus", "Performance", "Happiness"]
            case .afternoon:
                return ["Focus", "Stress", "Anxiety", "Performance"]
            case .evening:
                return ["Relax", "Stress", "Anxiety", "Calm"]
            case .night:
                return ["Sleep", "Relax", "Calm"]
            }
        }
    }

    private var timeOfDay: TimeOfDay {
        TimeOfDay.current
    }

    /// Next streak milestone and days remaining (e.g., "4 days" to reach 7-day milestone)
    private var nextStreakMilestone: String? {
        let streak = streakService.currentStreak
        let milestones = [7, 14, 30, 60, 100, 365]
        guard let next = milestones.first(where: { $0 > streak }) else { return nil }
        let remaining = next - streak
        return remaining <= 5 ? "\(remaining) day\(remaining == 1 ? "" : "s")" : nil
    }

    private var favoriteContents: [Content] {
        let idSet = favoriteIDSet
        let videoIDSet = favoriteVideoIDSet
        return allContent.filter { idSet.contains($0.id) || videoIDSet.contains($0.youtubeVideoID) }
    }

    /// Most recent unfinished session and its content — for the "Continue Listening" card
    private var continueListeningData: (content: Content, session: MeditationSession)? {
        // Find most recent incomplete session from the last 7 days
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        guard let unfinished = sessions.first(where: { !$0.wasCompleted && $0.startedAt >= cutoff }) else { return nil }

        // Match to content
        var content: Content?
        if let videoID = unfinished.youtubeVideoID {
            content = allContent.first { $0.youtubeVideoID == videoID }
        } else if let contentID = unfinished.contentID {
            content = allContent.first { $0.id == contentID }
        }

        guard let matched = content else { return nil }
        return (matched, unfinished)
    }

    private var recentlyPlayedContent: [Content] {
        // Build lookup dictionaries for O(1) matching
        let contentByVideoID = Dictionary(allContent.map { ($0.youtubeVideoID, $0) }, uniquingKeysWith: { first, _ in first })
        let contentByID = Dictionary(allContent.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var seenVideoIDs = Set<String>()
        var uniqueContent: [Content] = []

        for session in sessions {
            if let videoID = session.youtubeVideoID {
                if seenVideoIDs.insert(videoID).inserted,
                   let content = contentByVideoID[videoID] {
                    uniqueContent.append(content)
                }
            } else if let contentID = session.contentID,
                      let content = contentByID[contentID] {
                if seenVideoIDs.insert(content.youtubeVideoID).inserted {
                    uniqueContent.append(content)
                }
            }
        }

        return uniqueContent
    }

    // Track the content count the index was built from
    @State private var lastIndexedContentCount: Int = 0

    /// Build indices for fast content lookup by tag and type
    private func buildContentIndices() {
        // Rebuild when content count changes (new content added/removed)
        guard tagToContentIndex.isEmpty || allContent.count != lastIndexedContentCount else { return }

        var tagIndex: [String: Set<UUID>] = [:]
        var typeIndex: [ContentType: Set<UUID>] = [:]

        for content in allContent {
            // Index by content type
            typeIndex[content.contentType, default: []].insert(content.id)

            // Index by tags (normalized to lowercase for matching)
            for tag in content.tags {
                let normalizedTag = tag.lowercased()
                tagIndex[normalizedTag, default: []].insert(content.id)
            }
        }

        tagToContentIndex = tagIndex
        contentTypeIndex = typeIndex
        lastIndexedContentCount = allContent.count
    }

    /// Fast lookup of content IDs matching any of the given tags
    private func contentIDsMatchingTags(_ searchTerms: [String]) -> Set<UUID> {
        var matches = Set<UUID>()
        for term in searchTerms {
            let lowercasedTerm = term.lowercased()
            for (tag, ids) in tagToContentIndex where tag.contains(lowercasedTerm) {
                matches.formUnion(ids)
            }
        }
        return matches
    }

    /// Fast lookup of content IDs matching any of the given content types
    private func contentIDsMatchingTypes(_ types: [ContentType]) -> Set<UUID> {
        var matches = Set<UUID>()
        for type in types {
            if let ids = contentTypeIndex[type] {
                matches.formUnion(ids)
            }
        }
        return matches
    }

    private func generateRecommendations() -> [Content] {
        // Ensure indices are built
        buildContentIndices()

        let currentTime = timeOfDay

        // If mood is selected, use fast indexed lookup
        if let mood = selectedMood {
            let moodTags: [String]
            let moodTypes: [ContentType]

            switch mood {
            case .anxious, .stressed:
                moodTags = ["Anxiety", "Stress"]
                moodTypes = [.asmr, .soundscape]
            case .tired:
                moodTags = ["Sleep"]
                moodTypes = [.sleepStory, .asmr]
            case .focused:
                moodTags = ["Focus", "Performance"]
                moodTypes = [.mindset]
            case .energetic:
                moodTags = ["Energy", "Happiness"]
                moodTypes = [.movement, .mindset]
            case .sad:
                moodTags = ["Happiness", "Gratitude"]
                moodTypes = [.mindset]
            case .calm:
                moodTags = []
                moodTypes = [.meditation, .soundscape, .asmr]
            case .happy:
                moodTags = ["Gratitude", "Happiness"]
                moodTypes = [.mindset, .music]
            case .grateful:
                moodTags = ["Gratitude"]
                moodTypes = [.mindset]
            }

            // Fast indexed lookup
            var matchingIDs = contentIDsMatchingTags(moodTags)
            matchingIDs.formUnion(contentIDsMatchingTypes(moodTypes))

            let filtered = allContent.filter { matchingIDs.contains($0.id) }
            if filtered.isEmpty {
                return deduplicateByNarrator(allContent.shuffled(), limit: Constants.Recommendations.maxResults)
            }
            return deduplicateByNarrator(filtered.shuffled(), limit: Constants.Recommendations.maxResults)
        }

        // Time-based recommendations when no mood is selected
        let recommendedTypes = currentTime.recommendedContentTypes
        let recommendedTags = currentTime.recommendedTags

        // Pre-compute pain point tags once (screen 1)
        let painPointTags: Set<String>
        let painPointTypes: [ContentType]
        if let painPoint = userPainPoint {
            painPointTags = Set(tagsForPainPoint(painPoint).map { $0.lowercased() })
            painPointTypes = painPointContentTypes
        } else {
            painPointTags = []
            painPointTypes = []
        }

        // Pre-compute user goal tags once (screen 2)
        let userGoalTags = userOnboardingGoals.flatMap { tagsForOnboardingGoal($0) }
        let userGoalTagsSet = Set(userGoalTags.map { $0.lowercased() })

        // Score content using indexed lookups where possible
        let scoredContent = allContent.map { content -> (Content, Int) in
            var score = 0

            // Highest priority: Pain point from onboarding screen 1
            if !painPointTags.isEmpty {
                if painPointTypes.contains(content.contentType) {
                    score += Constants.Recommendations.goalTypeScore
                }

                for tag in content.tags {
                    let lowercasedTag = tag.lowercased()
                    for painTag in painPointTags where lowercasedTag.contains(painTag) {
                        score += Constants.Recommendations.goalTagScore
                        break
                    }
                }
            }

            // High priority: User's onboarding goals (screen 2)
            if !userOnboardingGoals.isEmpty {
                // Bonus for content types matching user's goals
                if preferredContentTypes.contains(content.contentType) {
                    score += Constants.Recommendations.goalTypeScore
                }

                // Bonus for tags matching user's goals (using pre-computed set)
                for tag in content.tags {
                    let lowercasedTag = tag.lowercased()
                    for goalTag in userGoalTagsSet where lowercasedTag.contains(goalTag) {
                        score += Constants.Recommendations.goalTagScore
                        break // Only count once per content tag
                    }
                }
            }

            // Secondary: Time-appropriate content type
            if recommendedTypes.contains(content.contentType) {
                score += Constants.Recommendations.timeTypeScore
            }

            // Score for matching time-based tags
            for tag in content.tags {
                let lowercasedTag = tag.lowercased()
                if recommendedTags.contains(where: { lowercasedTag.contains($0.lowercased()) }) {
                    score += Constants.Recommendations.timeTagScore
                }
            }

            // Legacy: User profile goals if profile exists
            if let profile = userProfile {
                for goal in profile.selectedGoals where content.tags.contains(goal) {
                    score += Constants.Recommendations.profileGoalScore
                }
            }

            return (content, score)
        }

        // Sort by score (highest first) and take top results with some randomization
        let sorted = scoredContent.sorted { $0.1 > $1.1 }
        let topContent = sorted.prefix(Constants.Recommendations.poolSize).map { $0.0 }

        return deduplicateByNarrator(topContent.shuffled(), limit: Constants.Recommendations.maxResults)
    }

    /// Pick up to `limit` items, allowing at most one per narrator (YouTube channel)
    /// and at most two items per content category to ensure variety.
    /// Never allows more than 2 consecutive items of the same category.
    private func deduplicateByNarrator(_ items: [Content], limit: Int) -> [Content] {
        var result: [Content] = []
        var seenNarrators: Set<String> = []
        var categoryCounts: [ContentType: Int] = [:]
        let maxPerCategory = 2
        var resultIDs: Set<UUID> = []

        // Pass 1: unique narrators + category cap (max 2 per category)
        for item in items {
            guard result.count < limit else { break }
            if let narrator = item.narrator {
                guard seenNarrators.insert(narrator).inserted else { continue }
            }
            let count = categoryCounts[item.contentType, default: 0]
            if count >= maxPerCategory { continue }
            categoryCounts[item.contentType] = count + 1
            result.append(item)
            resultIDs.insert(item.id)
        }

        // Pass 2: if still under limit, allow duplicate narrators (still cap at 2 per category)
        if result.count < limit {
            for item in items {
                guard result.count < limit else { break }
                guard !resultIDs.contains(item.id) else { continue }
                let count = categoryCounts[item.contentType, default: 0]
                if count >= maxPerCategory { continue }
                categoryCounts[item.contentType] = count + 1
                result.append(item)
                resultIDs.insert(item.id)
            }
        }

        // Reorder to avoid consecutive same-category runs
        return spreadCategories(result)
    }

    /// Reorders items so no more than 2 consecutive items share the same category.
    private func spreadCategories(_ items: [Content]) -> [Content] {
        guard items.count > 2 else { return items }
        var result: [Content] = []
        var remaining = items

        while !remaining.isEmpty {
            // Find the first item that doesn't create a 3-in-a-row
            if let index = remaining.firstIndex(where: { item in
                guard result.count >= 2 else { return true }
                let last = result[result.count - 1].contentType
                let secondLast = result[result.count - 2].contentType
                return !(item.contentType == last && last == secondLast)
            }) {
                result.append(remaining.remove(at: index))
            } else {
                // No ideal candidate — just append the rest
                result.append(contentsOf: remaining)
                break
            }
        }

        return result
    }

    private func refreshRecommendations(showLoading: Bool = false) {
        // Cancel any in-flight recommendation task to prevent race conditions
        recommendationTask?.cancel()

        if showLoading {
            isLoadingRecommendations = true
        }
        recommendationTask = Task {
            if showLoading {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                cachedRecommendations = generateRecommendations()
                HomeView.savedRecommendations = cachedRecommendations
                isLoadingRecommendations = false
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Continue Listening (top priority)
                        if let data = continueListeningData {
                            ContinueListeningCard(
                                content: data.content,
                                session: data.session,
                                onTap: { selectedContent = data.content }
                            )
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }

                        // Greeting + Streak Banner
                        VStack(spacing: 8) {
                            VStack(spacing: 4) {
                                Text(timeOfDay.greeting)
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white.opacity(0.8))

                                Text(timeOfDay.contextualSuggestion)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity, alignment: .center)

                            if streakService.currentStreak > 0 {
                                HStack(spacing: 6) {
                                    Image(systemName: "flame.fill")
                                        .foregroundStyle(.orange)
                                    Text("\(streakService.currentStreak) day streak")
                                        .fontWeight(.semibold)
                                    if let milestone = nextStreakMilestone {
                                        Text("— \(milestone) to go!")
                                            .foregroundStyle(.white.opacity(0.6))
                                    } else {
                                        Text("— \(streakService.streakMessage)")
                                            .foregroundStyle(.white.opacity(0.6))
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, continueListeningData == nil ? 8 : 0)

                        // Mood Selector
                        MoodSelectorView(selectedMood: $selectedMood)

                    // Recommended Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recommended for you")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Theme.textPrimary)

                            Spacer()

                            Button {
                                refreshRecommendations(showLoading: true)
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.body)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .disabled(isLoadingRecommendations)
                            .padding(.trailing, 10)
                        }
                        .padding(.horizontal)

                        if isLoadingRecommendations {
                            // Loading skeleton
                            ForEach(0..<3, id: \.self) { _ in
                                RecommendationLoadingCard()
                            }
                        } else if cachedRecommendations.isEmpty {
                            // Empty state
                            VStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.largeTitle)
                                    .foregroundStyle(.white.opacity(0.5))
                                Text("Finding personalized content...")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            ForEach(cachedRecommendations) { content in
                                ContentCardView(
                                    content: content,
                                    isFavorite: isFavorite(content),
                                    onTap: { playContent(content, from: cachedRecommendations) },
                                    onFavorite: { toggleFavorite(content) },
                                    onAddToPlaylist: { contentForPlaylistAdd = content },
                                    onShare: { shareContent(content) },
                                    onMore: { showActionSheet(for: content) }
                                )
                            }
                        }
                    }

                    // Recently Played Section (only shows if user has played content)
                    if !recentlyPlayedContent.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Recently Played")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Theme.textPrimary)

                                Spacer()

                                if recentlyPlayedContent.count > 3 {
                                    Button {
                                        showingRecentlyPlayedList = true
                                    } label: {
                                        Text("See All (\(recentlyPlayedContent.count))")
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                }
                            }
                            .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: 16) {
                                    ForEach(recentlyPlayedContent.prefix(6)) { content in
                                        RecentlyPlayedCard(content: content) {
                                            playContent(content, from: Array(recentlyPlayedContent))
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Favorites Section (hidden if empty)
                    if !favoriteContents.isEmpty {
                        favoritesSection
                    }

                    // Playlists Section (hidden if no playlists have items)
                    if !playlistItems.isEmpty && playlists.contains(where: { playlistItemsByID[$0.id] != nil }) {
                        playlistsSection
                    }

                    // Unguided Timer Card
                    UnguidedTimerCard {
                        showingTimer = true
                    }
                    .padding(.horizontal)

                        Spacer(minLength: 100)
                    }
                    .frame(maxWidth: 700)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom)
                }
                .safeAreaPadding(.top)
            }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(item: $selectedContent) { content in
                MeditationPlayerView(content: content)
            }
            .refreshable {
                refreshRecommendations(showLoading: true)
                // Small delay so the pull indicator feels responsive
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            .sheet(isPresented: $showingTimer) {
                UnguidedTimerView()
            }
            .sheet(item: $selectedPlaylist) { playlist in
                PlaylistDetailView(playlist: playlist)
            }
            .sheet(isPresented: $showingRecentlyPlayedList) {
                RecentlyPlayedListView(
                    recentlyPlayed: recentlyPlayedContent,
                    onContentTap: { content in
                        showingRecentlyPlayedList = false
                        playContent(content, from: Array(recentlyPlayedContent))
                    }
                )
            }
            .sheet(item: $contentForPlaylistAdd) { content in
                AddToPlaylistSheet(content: content)
            }
            .onAppear {
                if cachedRecommendations.isEmpty {
                    refreshRecommendations()
                }
            }
            .onChange(of: selectedMood) { _, _ in
                refreshRecommendations(showLoading: true)
            }
            .onChange(of: allContent.count) { _, _ in
                // Refresh when content loads
                if cachedRecommendations.isEmpty {
                    refreshRecommendations()
                }
            }
        }
    }

    // MARK: - Favorites Section

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Favorites")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.textPrimary)

                Spacer()
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(favoriteContents.prefix(6)) { content in
                        RecentlyPlayedCard(content: content) {
                            playContent(content, from: Array(favoriteContents))
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                withAnimation {
                                    toggleFavorite(content)
                                }
                            } label: {
                                Label("Remove from Favorites", systemImage: "heart.slash")
                            }

                            Button {
                                contentForPlaylistAdd = content
                            } label: {
                                Label("Add to Playlist", systemImage: "text.badge.plus")
                            }

                            ShareLink(
                                item: URL(string: "meditation://content/\(content.youtubeVideoID)")!,
                                subject: Text(content.title),
                                message: Text("Check out '\(content.title)' on Meditation Sleep Mindset!")
                            ) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Playlists Section

    /// Pre-compute playlist items grouped by playlist ID to avoid repeated filtering
    private var playlistItemsByID: [UUID: [PlaylistItem]] {
        Dictionary(grouping: playlistItems, by: \.playlistID)
    }

    private var playlistsSection: some View {
        let itemsByID = playlistItemsByID
        return VStack(alignment: .leading, spacing: 12) {
            Text("Playlists")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(playlists.filter { itemsByID[$0.id] != nil }) { playlist in
                        let items = itemsByID[playlist.id] ?? []
                        PlaylistCardCompact(
                            playlist: playlist,
                            itemCount: items.count,
                            thumbnailURLs: items.prefix(4).map(\.thumbnailURL),
                            onTap: { selectedPlaylist = playlist },
                            onDelete: {
                                withAnimation {
                                    modelContext.delete(playlist)
                                    try? modelContext.save()
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    /// Pre-computed set of favorite IDs and video IDs for O(1) lookups
    private var favoriteIDSet: Set<UUID> {
        Set(favorites.map { $0.contentID })
    }
    private var favoriteVideoIDSet: Set<String> {
        Set(favorites.compactMap { $0.youtubeVideoID })
    }

    private func isFavorite(_ content: Content) -> Bool {
        favoriteIDSet.contains(content.id) || favoriteVideoIDSet.contains(content.youtubeVideoID)
    }

    private func toggleFavorite(_ content: Content) {
        // Check by both contentID and youtubeVideoID for robustness
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

    /// Play content with a queue context so auto-play works
    private func playContent(_ content: Content, from queue: [Content]) {
        let startIndex = queue.firstIndex(where: { $0.id == content.id }) ?? 0
        AudioPlayerManager.shared.queue = queue
        AudioPlayerManager.shared.currentIndex = startIndex
        selectedContent = content
    }

    private func shareContent(_ content: Content) {
        ContentSharingHelper.share(content)
    }
}

struct MoodSelectorView: View {
    @Binding var selectedMood: Mood?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How are you feeling?")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Mood.allCases) { mood in
                        Button {
                            HapticManager.selection()
                            withAnimation {
                                selectedMood = selectedMood == mood ? nil : mood
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Text(mood.emoji)
                                    .font(.title)

                                Text(mood.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(selectedMood == mood ? .white : Theme.textPrimary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                selectedMood == mood
                                    ? Color.white.opacity(0.25)
                                    : Theme.cardBackground
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct ContentCardView: View {
    let content: Content
    let isFavorite: Bool
    let onTap: () -> Void
    let onFavorite: () -> Void
    var onAddToPlaylist: (() -> Void)? = nil
    var onShare: () -> Void
    var onMore: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            // Tappable content area
            HStack(spacing: 12) {
                // Thumbnail
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
                            .overlay(
                                Image(systemName: content.contentType.iconName)
                                    .font(.title3)
                                    .foregroundStyle(.white.opacity(0.3))
                            )
                    }
                )
                .frame(width: 100, height: 70)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Content Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(content.contentType.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.7))

                        Text("•")
                            .foregroundStyle(Theme.textTertiary)

                        Text(content.durationFormatted)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Text(content.title)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)

                    if let narrator = content.narrator {
                        Text(narrator)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture { onTap() }

            // More Button — completely separate from content tap area
            Button {
                ActionSheetManager.shared.show(
                    content: content,
                    isFavorite: isFavorite,
                    onToggleFavorite: { onFavorite() },
                    onAddToPlaylist: onAddToPlaylist,
                    onShare: { onShare() }
                )
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .rotationEffect(.degrees(90))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Recently Played Card
struct RecentlyPlayedCard: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    let content: Content
    let onTap: () -> Void

    private var cardWidth: CGFloat { sizeClass == .regular ? 180 : 140 }
    private var thumbHeight: CGFloat { sizeClass == .regular ? 115 : 90 }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail with play overlay
                ZStack {
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
                                .overlay(
                                    Image(systemName: content.contentType.iconName)
                                        .font(.title2)
                                        .foregroundStyle(.white.opacity(0.3))
                                )
                        }
                    )
                    .frame(width: cardWidth, height: thumbHeight)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Play button overlay
                    Circle()
                        .fill(.black.opacity(0.5))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                        )
                }

                // Content info
                VStack(alignment: .leading, spacing: 2) {
                    Text(content.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)

                    Text(content.durationFormatted)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(width: cardWidth)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recently Played List View
struct RecentlyPlayedListView: View {
    @Environment(\.dismiss) var dismiss
    let recentlyPlayed: [Content]
    let onContentTap: (Content) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(recentlyPlayed) { content in
                            RecentlyPlayedListRow(content: content) {
                                onContentTap(content)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Recently Played")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }
}

struct RecentlyPlayedListRow: View {
    let content: Content
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail
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
                            .overlay(
                                Image(systemName: content.contentType.iconName)
                                    .font(.body)
                                    .foregroundStyle(.white.opacity(0.3))
                            )
                    }
                )
                .frame(width: 80, height: 55)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Content Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(content.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(content.contentType.displayName)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))

                        Text("•")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)

                        Text(content.durationFormatted)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            .padding()
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Loading Card (Skeleton)
struct RecommendationLoadingCard: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail skeleton
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.1))
                .frame(width: 100, height: 70)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.1), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: isAnimating ? 150 : -150)
                )
                .clipped()

            // Text skeleton
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 80, height: 12)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 150, height: 16)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 100, height: 12)
            }

            Spacer()
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Continue Listening Card
struct ContinueListeningCard: View {
    let content: Content
    let session: MeditationSession
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Thumbnail
                ZStack(alignment: .center) {
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
                            Rectangle().fill(Theme.cardBackground)
                        }
                    )
                    .frame(width: 72, height: 72)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .shadow(radius: 3)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Continue Listening")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.6))

                    Text(content.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.8))
                                .frame(width: geo.size.width * session.progress, height: 4)
                        }
                    }
                    .frame(height: 4)

                    Text(progressText)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(12)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var progressText: String {
        let listened = session.listenedSeconds
        let total = session.durationSeconds > 0 ? session.durationSeconds : content.durationSeconds
        guard total > 0 else { return "Ready to play" }
        let remaining = max(0, total - listened)
        let mins = remaining / 60
        let secs = remaining % 60
        if mins > 0 {
            return "\(mins):\(String(format: "%02d", secs)) remaining"
        } else {
            return "Less than a minute left"
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Content.self, UserProfile.self, FavoriteContent.self, Playlist.self], inMemory: true)
        .environmentObject(AppStateManager.shared)
}
