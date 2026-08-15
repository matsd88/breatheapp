//
//  DiscoverView.swift
//  Meditation Sleep Mindset
//

import SwiftUI
import SwiftData

enum DiscoverSheetType: Identifiable {
    case programs
    case premium
    case addToPlaylist(Content)
    var id: String {
        switch self {
        case .programs: return "programs"
        case .premium: return "premium"
        case .addToPlaylist(let c): return "playlist-\(c.youtubeVideoID)"
        }
    }
}

struct DiscoverView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \Content.title) private var allContent: [Content]
    @Query private var favorites: [FavoriteContent]
    @Binding var initialCategory: ContentType?
    @State private var searchText = ""
    @State private var selectedContent: Content?
    @State private var selectedCategory: ContentType?
    @State private var isSearchActive = false
    @State private var showScrollToTop = false
    @State private var activeDiscoverSheet: DiscoverSheetType?
    @State private var showBreathingExercises = false
    @State private var showBodyScan = false
    @State private var showFocusTimer = false
    @State private var showYouTubeSearch = false
    @State private var showAIMeditation = false
    @State private var showMicroMoments = false
    @StateObject private var storeManager = StoreManager.shared

    init(initialCategory: Binding<ContentType?> = .constant(nil)) {
        self._initialCategory = initialCategory
    }

    private var filteredContent: [Content] {
        if searchText.isEmpty {
            return allContent
        }
        return allContent.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.narrator?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var contentByType: [ContentType: [Content]] {
        Dictionary(grouping: filteredContent, by: { $0.contentType })
    }

    /// Names what the user is actually looking at — the count of locked
    /// sessions in the category they've filtered to — instead of a generic
    /// pitch they've already scrolled past on Home.
    private var discoverPremiumHook: String? {
        if let category = selectedCategory,
           let contents = contentByType[category] {
            let locked = contents.filter(\.isPremium).count
            if locked > 0 {
                return String(localized: "\(locked) more \(category.displayName.lowercased()) sessions with Premium")
            }
        }
        return String(localized: "Unlock every session, program and AI meditation")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 28) {
                            // Title
                            Text("Discover")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                                .id("discoverTop")

                            // Search bar — primary discovery action
                            SearchBarView(searchText: $searchText, isActive: $isSearchActive)

                            if isSearchActive {
                                // While searching, render a light hierarchy so the keyboard
                                // appears instantly (the full browse grid below is what stalled it).
                                if searchText.isEmpty {
                                    VStack(spacing: 12) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 40))
                                            .foregroundStyle(Theme.textSecondary)
                                        Text("Search meditations, sleep stories, sounds, and more")
                                            .font(.subheadline)
                                            .multilineTextAlignment(.center)
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 60)
                                } else {
                                    SearchResultsView(
                                        results: filteredContent,
                                        onContentTap: { content in
                                            playContent(content, from: filteredContent)
                                        },
                                        onAddToPlaylist: { content in
                                            activeDiscoverSheet = .addToPlaylist(content)
                                        },
                                        isFavorite: { content in isFavorite(content) },
                                        onFavorite: { content in toggleFavorite(content) },
                                        onShare: { content in shareContent(content) }
                                    )
                                }
                            } else {
                                // Micro Moments Banner
                                MicroMomentsBanner {
                                    showMicroMoments = true
                                }

                                // Tools Section
                                DiscoverToolsSection(
                                    onBreathing: { showBreathingExercises = true },
                                    onBodyScan: { showBodyScan = true },
                                    onFocusTimer: { showFocusTimer = true },
                                    onAIMeditation: { showAIMeditation = true },
                                    onYouTubeSearch: Constants.isCuratorMode ? { showYouTubeSearch = true } : nil
                                )

                                // Quick Categories
                                QuickCategoriesView(
                                    selectedCategory: $selectedCategory,
                                    contentByType: contentByType
                                )

                                // Discover is where free users meet locked
                                // sessions, but it had no upsell of its own —
                                // only per-card locks with nowhere to go.
                                if !storeManager.isSubscribed {
                                    Button {
                                        HapticManager.light()
                                        activeDiscoverSheet = .premium
                                    } label: {
                                        PremiumUpsellBanner(hook: discoverPremiumHook)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal)
                                }

                                // Browse by Category
                                if let category = selectedCategory {
                                    // Show single category
                                    if let contents = contentByType[category], !contents.isEmpty {
                                        ContentCategorySection(
                                            type: category,
                                            contents: contents,
                                            onContentTap: { content in
                                                playContent(content, from: contents)
                                            },
                                            expanded: true,
                                            onScrollThresholdReached: { reached in
                                                withAnimation { showScrollToTop = reached }
                                            },
                                            onAddToPlaylist: { content in
                                                activeDiscoverSheet = .addToPlaylist(content)
                                            },
                                            isFavorite: isFavorite,
                                            onFavorite: toggleFavorite,
                                            onShare: shareContent,
                                            onMore: { content in
                                                showActionSheet(for: content)
                                            }
                                        )
                                    }
                                } else {
                                    // Show all categories
                                    ForEach(ContentType.allCases) { type in
                                        if let contents = contentByType[type], !contents.isEmpty {
                                            ContentCategorySection(
                                                type: type,
                                                contents: contents,
                                                onContentTap: { content in
                                                    playContent(content, from: contents)
                                                },
                                                expanded: false,
                                                onAddToPlaylist: { content in
                                                    activeDiscoverSheet = .addToPlaylist(content)
                                                },
                                                isFavorite: isFavorite,
                                                onFavorite: toggleFavorite,
                                                onShare: shareContent,
                                                onMore: { content in
                                                    showActionSheet(for: content)
                                                }
                                            )
                                        }
                                    }
                                }

                                Spacer(minLength: 100)
                            } // end of else for search
                        }
                        .frame(maxWidth: sizeClass == .regular ? 1100 : 700)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 0)
                        .padding(.bottom)
                    }
                    .refreshable {
                        HapticManager.light()
                        // Re-prefetch visible content stream URLs
                        let videoIDs = allContent.prefix(10).map { $0.youtubeVideoID }
                        await YouTubeService.shared.prefetchStreamURLs(for: videoIDs)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if showScrollToTop {
                            ScrollToTopButton(
                                scrollProxy: proxy,
                                targetID: "discoverTop",
                                isVisible: $showScrollToTop
                            )
                            .accessibilityLabel("Scroll to top")
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $activeDiscoverSheet) { sheet in
                switch sheet {
                case .programs:
                    ProgramsListView()
                case .premium:
                    PremiumPaywallView(
                        storeManager: storeManager,
                        context: .discoverBanner,
                        onSubscribed: { activeDiscoverSheet = nil }
                    )
                case .addToPlaylist(let content):
                    AddToPlaylistSheet(content: content)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dismissAllSheetsAndPlay)) { _ in
                activeDiscoverSheet = nil
            }
            .fullScreenCover(isPresented: $showBreathingExercises) {
                BreathingExercisesListView()
            }
            .fullScreenCover(isPresented: $showBodyScan) {
                BodyScanView()
            }
            .fullScreenCover(isPresented: $showFocusTimer) {
                FocusTimerView()
            }
            .fullScreenCover(isPresented: $showAIMeditation) {
                AIGeneratedMeditationView()
            }
            .fullScreenCover(isPresented: $showMicroMoments) {
                MicroMomentsView()
            }
            // YouTube search — commented out for App Store release
            // .sheet(isPresented: $showYouTubeSearch) {
            //     YouTubeSearchView()
            // }
            .onChange(of: selectedCategory) { _, _ in
                showScrollToTop = false
            }
            .onAppear {
                // Apply initial category from quick action if provided
                if let category = initialCategory {
                    selectedCategory = category
                    initialCategory = nil  // Clear after consuming
                }
            }
        }
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
            onAddToPlaylist: { activeDiscoverSheet = .addToPlaylist(content) },
            onShare: { shareContent(content) }
        )
    }

    /// Play content with a queue for auto-play
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
}

// MARK: - Search Bar
struct SearchBarView: View {
    @Binding var searchText: String
    @Binding var isActive: Bool
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.textSecondary)

                TextField("Start your search", text: $searchText)
                    .foregroundStyle(Theme.textPrimary)
                    .focused($isFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(12)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if isActive {
                Button("Cancel") {
                    searchText = ""
                    isActive = false
                    isFocused = false
                }
                .foregroundStyle(.white)
            }
        }
        .padding(.horizontal)
        // Drive `isActive` from focus so the keyboard appears immediately on tap,
        // and dismiss the field when search is cancelled.
        .onChange(of: isFocused) { _, focused in
            if focused { isActive = true }
        }
        .onChange(of: isActive) { _, active in
            if !active { isFocused = false }
        }
    }
}

// MARK: - Search Results
struct SearchResultsView: View {
    let results: [Content]
    let onContentTap: (Content) -> Void
    var onAddToPlaylist: ((Content) -> Void)? = nil
    var isFavorite: ((Content) -> Bool)? = nil
    var onFavorite: ((Content) -> Void)? = nil
    var onShare: ((Content) -> Void)? = nil
    @Environment(\.horizontalSizeClass) private var sizeClass

    @ViewBuilder
    private func resultRow(_ content: Content) -> some View {
        SearchResultRow(
            content: content,
            onTap: { onContentTap(content) },
            onAddToPlaylist: onAddToPlaylist != nil ? { onAddToPlaylist?(content) } : nil,
            isFavorite: isFavorite?(content) ?? false,
            onFavorite: onFavorite != nil ? { onFavorite?(content) } : nil,
            onShare: onShare != nil ? { onShare?(content) } : nil
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if results.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.textSecondary)

                    Text("No results found")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)

                    Text("Try a different search term")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                Text("\(results.count) results")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal)

                if sizeClass == .regular {
                    // iPad: two-column grid makes use of the wide screen
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 12) {
                        ForEach(results) { content in
                            resultRow(content)
                        }
                    }
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(results) { content in
                            resultRow(content)
                        }
                    }
                }
            }
        }
    }
}

struct SearchResultRow: View {
    let content: Content
    let onTap: () -> Void
    var onAddToPlaylist: (() -> Void)? = nil
    var isFavorite: Bool = false
    var onFavorite: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil
    var onMore: () -> Void = {}

    @ObservedObject private var storeManager = StoreManager.shared

    private var showsPremiumLock: Bool {
        content.isPremium && !storeManager.isSubscribed
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
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
                .frame(width: 100, height: 68)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .topTrailing) {
                    if showsPremiumLock {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.yellow)
                            .padding(5)
                            .background(.black.opacity(0.55))
                            .clipShape(Circle())
                            .padding(4)
                            .accessibilityLabel("Premium")
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(content.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        Text(content.contentType.displayName)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))

                        if !content.durationFormatted.isEmpty {
                            Text("•")
                                .foregroundStyle(Theme.textTertiary)

                            Text(content.durationFormatted)
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    if let narrator = content.narrator {
                        Text(narrator)
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .contentShape(Rectangle())

            // More button
            Image(systemName: "ellipsis")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .rotationEffect(.degrees(90))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .accessibilityLabel("More options")
                .accessibilityAddTraits(.isButton)
                .highPriorityGesture(
                    TapGesture().onEnded {
                        ActionSheetManager.shared.show(
                            content: content,
                            isFavorite: isFavorite,
                            onToggleFavorite: { onFavorite?() },
                            onAddToPlaylist: onAddToPlaylist,
                            onShare: { onShare?() }
                        )
                    }
                )
        }
        .padding(12)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Quick Categories
struct QuickCategoriesView: View {
    @Binding var selectedCategory: ContentType?
    let contentByType: [ContentType: [Content]]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All Button
                CategoryPill(
                    title: "All",
                    icon: "square.grid.2x2.fill",
                    isSelected: selectedCategory == nil,
                    count: contentByType.values.flatMap { $0 }.count
                ) {
                    HapticManager.selection()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = nil
                    }
                }

                ForEach(ContentType.allCases) { type in
                    CategoryPill(
                        title: type.displayName,
                        icon: type.iconName,
                        isSelected: selectedCategory == type,
                        count: contentByType[type]?.count ?? 0
                    ) {
                        HapticManager.selection()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = selectedCategory == type ? nil : type
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct CategoryPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)

                // Inventory counts ("All 1,693") are noise — nobody chooses a
                // meditation because a category has more items, and four-digit
                // numbers make the pill row read as a database. Kept only where
                // the number is small enough to be a genuine signal of scope.
                if count > 0 && count < 100 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : Theme.textSecondary.opacity(0.7))
                }
            }
            .foregroundStyle(isSelected ? .white : Theme.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color.white.opacity(0.25) : Theme.cardBackground)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Unguided Timer Card
struct UnguidedTimerCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 54, height: 54)

                    Image(systemName: "timer")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Unguided Timer")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.textPrimary)

                    Text("Meditate in silence or with sound")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()
            }
            .padding(16)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Content Category Section
struct ContentCategorySection: View {
    let type: ContentType
    let contents: [Content]
    let onContentTap: (Content) -> Void
    var expanded: Bool = false
    var onScrollThresholdReached: ((Bool) -> Void)? = nil
    var onAddToPlaylist: ((Content) -> Void)? = nil
    var isFavorite: ((Content) -> Bool)? = nil
    var onFavorite: ((Content) -> Void)? = nil
    var onShare: ((Content) -> Void)? = nil
    var onMore: ((Content) -> Void)? = nil
    @State private var sortOption: SortOption = .defaultOrder

    private var sortedContents: [Content] {
        switch sortOption {
        case .defaultOrder:
            return contents
        case .shortest:
            return contents.sorted { $0.durationSeconds < $1.durationSeconds }
        case .longest:
            return contents.sorted { $0.durationSeconds > $1.durationSeconds }
        case .alphabetical:
            return contents.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    private var sortIconName: String {
        switch sortOption {
        case .defaultOrder: return "arrow.up.arrow.down"
        case .shortest: return "clock"
        case .longest: return "clock.fill"
        case .alphabetical: return "textformat.abc"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: type.iconName)
                    .foregroundStyle(.white)

                Text(type.displayName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                if expanded {
                    // Sort menu (only in expanded/See All view)
                    Menu {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    sortOption = option
                                }
                            } label: {
                                Label(option.displayName, systemImage: sortOption == option ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Image(systemName: sortIconName)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Sort")
                    .accessibilityHint("Changes the order of the list")
                }

                if !expanded {
                    NavigationLink {
                        DiscoverContentListView(contentType: type)
                    } label: {
                        Text("See All")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal)

            if expanded {
                // Show as lazy list so onAppear fires based on scroll position
                LazyVStack(spacing: 12) {
                    ForEach(Array(sortedContents.enumerated()), id: \.element.id) { index, content in
                        SearchResultRow(
                            content: content,
                            onTap: { onContentTap(content) },
                            onAddToPlaylist: onAddToPlaylist != nil ? { onAddToPlaylist?(content) } : nil,
                            isFavorite: isFavorite?(content) ?? false,
                            onFavorite: onFavorite != nil ? { onFavorite?(content) } : nil,
                            onShare: onShare != nil ? { onShare?(content) } : nil,
                            onMore: { onMore?(content) }
                        )
                        .onAppear {
                            if index >= Constants.UI.scrollToTopThreshold {
                                onScrollThresholdReached?(true)
                            }
                            if index == 0 {
                                onScrollThresholdReached?(false)
                            }
                        }
                    }
                }
            } else {
                // Show as horizontal scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(sortedContents.prefix(10)) { content in
                            DiscoverContentCard(
                                content: content,
                                isFavorite: isFavorite?(content) ?? false,
                                onTap: { onContentTap(content) },
                                onAddToPlaylist: onAddToPlaylist != nil ? { onAddToPlaylist?(content) } : nil,
                                onFavorite: onFavorite != nil ? { onFavorite?(content) } : nil,
                                onShare: onShare != nil ? { onShare?(content) } : nil,
                                onMore: { onMore?(content) }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .onAppear {
            // Prefetch stream URLs for visible content to speed up playback
            let videoIDs = contents.prefix(5).map { $0.youtubeVideoID }
            Task {
                await YouTubeService.shared.prefetchStreamURLs(for: videoIDs)
            }
        }
    }
}

// MARK: - Discover Content Card
struct DiscoverContentCard: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    let content: Content
    var isFavorite: Bool = false
    let onTap: () -> Void
    var onAddToPlaylist: (() -> Void)? = nil
    var onFavorite: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil
    var onMore: () -> Void = {}

    private var cardWidth: CGFloat { sizeClass == .regular ? 200 : 160 }
    private var cardHeight: CGFloat { sizeClass == .regular ? 125 : 100 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                        .fill(Theme.cardGradient)
                        .overlay(
                            Image(systemName: content.contentType.iconName)
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.3))
                        )
                }
            )
            .frame(width: cardWidth, height: cardHeight)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture { onTap() }
            .accessibilityLabel(content.title)
            .accessibilityHint("Plays this content")
            .accessibilityAddTraits(.isButton)
            // The menu used to sit beside the title in a 44pt-tall HStack, which
            // set the row's height and left the duration floating well below the
            // title it belongs to. It also took 44 of the card's 160pt, so every
            // title truncated after a word or two. On the artwork it costs the
            // text nothing.
            .overlay(alignment: .topTrailing) { moreButton }

            VStack(alignment: .leading, spacing: 2) {
                Text(content.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)

                Text(content.durationFormatted)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
        }
        .frame(width: cardWidth, alignment: .top)
    }

    /// Sits on the artwork, so it needs its own scrim to stay legible against
    /// the bright thumbnails in the library.
    private var moreButton: some View {
        Image(systemName: "ellipsis")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .rotationEffect(.degrees(90))
            .frame(width: 26, height: 26)
            .background(.black.opacity(0.45), in: Circle())
            .padding(6)
            .frame(width: 44, height: 44, alignment: .topTrailing)
            .contentShape(Rectangle())
            .accessibilityLabel("More options")
            .accessibilityAddTraits(.isButton)
            .highPriorityGesture(
                TapGesture().onEnded {
                    ActionSheetManager.shared.show(
                        content: content,
                        isFavorite: isFavorite,
                        onToggleFavorite: { onFavorite?() },
                        onAddToPlaylist: onAddToPlaylist,
                        onShare: { onShare?() }
                    )
                }
            )
    }
}

// MARK: - Discover Content List View
enum SortOption: String, CaseIterable {
    case defaultOrder = "Default"
    case shortest = "Shortest First"
    case longest = "Longest First"
    case alphabetical = "A – Z"

    var displayName: String {
        switch self {
        case .defaultOrder: return String(localized: "Default")
        case .shortest: return String(localized: "Shortest First")
        case .longest: return String(localized: "Longest First")
        case .alphabetical: return String(localized: "A – Z")
        }
    }
}

struct DiscoverContentListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allContent: [Content]
    @Query private var favorites: [FavoriteContent]
    let contentType: ContentType
    @State private var selectedContent: Content?
    @State private var activeListSheet: DiscoverSheetType?
    @State private var displayedCount: Int = 15  // Start with 15 items
    @State private var isLoadingMore: Bool = false
    @State private var showScrollToTop = false
    @State private var isScrollingToTop = false
    @State private var sortOption: SortOption = .defaultOrder
    @Environment(\.horizontalSizeClass) private var sizeClass

    // iPad: lay results out in two columns to use the wide screen
    private var listColumns: [GridItem] {
        sizeClass == .regular
            ? [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
            : [GridItem(.flexible())]
    }

    private let batchSize: Int = 10  // Load 10 more at a time

    private var filteredContent: [Content] {
        let filtered = allContent.filter { $0.contentType == contentType }
        switch sortOption {
        case .defaultOrder:
            return filtered
        case .shortest:
            return filtered.sorted { $0.durationSeconds < $1.durationSeconds }
        case .longest:
            return filtered.sorted { $0.durationSeconds > $1.durationSeconds }
        case .alphabetical:
            return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    private var displayedContent: [Content] {
        Array(filteredContent.prefix(displayedCount))
    }

    private var hasMoreContent: Bool {
        displayedCount < filteredContent.count
    }

    private var sortIconName: String {
        switch sortOption {
        case .defaultOrder: return "arrow.up.arrow.down"
        case .shortest: return "clock"
        case .longest: return "clock.fill"
        case .alphabetical: return "textformat.abc"
        }
    }

    var body: some View {
        ZStack {
            Theme.profileGradient.ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Category header matching Discover style
                        HStack {
                            Image(systemName: contentType.iconName)
                                .foregroundStyle(.white)

                            Text(contentType.displayName)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(Theme.textPrimary)

                            Spacer()

                            // Sort menu
                            Menu {
                                ForEach(SortOption.allCases, id: \.self) { option in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            sortOption = option
                                        }
                                    } label: {
                                        Label(option.displayName, systemImage: sortOption == option ? "checkmark" : "")
                                    }
                                }
                            } label: {
                                Image(systemName: sortIconName)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("Sort")
                            .accessibilityHint("Changes the order of the list")
                        }
                        .padding(.horizontal)

                        LazyVGrid(columns: listColumns, spacing: 12) {
                            ForEach(Array(displayedContent.enumerated()), id: \.element.id) { index, content in
                                SearchResultRow(
                                    content: content,
                                    onTap: { playContent(content, from: filteredContent) },
                                    onAddToPlaylist: { activeListSheet = .addToPlaylist(content) },
                                    isFavorite: isFavorite(content),
                                    onFavorite: { toggleFavorite(content) },
                                    onShare: { shareContent(content) },
                                    onMore: { showActionSheet(for: content) }
                                )
                                .id(index == 0 ? "listTop" : content.youtubeVideoID)
                                .onAppear {
                                    // Load more when approaching the end
                                    if content.id == displayedContent.last?.id && hasMoreContent {
                                        loadMoreContent()
                                    }
                                    if index >= Constants.UI.scrollToTopThreshold {
                                        if !isScrollingToTop {
                                            withAnimation { showScrollToTop = true }
                                        }
                                    }
                                    if index == 0 && !isScrollingToTop {
                                        withAnimation { showScrollToTop = false }
                                    }
                                }
                            }

                            // Loading indicator at the bottom
                            if hasMoreContent {
                                HStack {
                                    Spacer()
                                    if isLoadingMore {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Button {
                                            loadMoreContent()
                                        } label: {
                                            Text("Load More")
                                                .font(.subheadline)
                                                .foregroundStyle(.white.opacity(0.7))
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 20)
                            }

                            // Bottom padding for tab bar
                            Spacer(minLength: 100)
                        }
                    }
                    .padding(.vertical)
                }
                .overlay(alignment: .bottomTrailing) {
                    if showScrollToTop {
                        ScrollToTopButton(
                            scrollProxy: proxy,
                            targetID: "listTop",
                            isVisible: $showScrollToTop
                        )
                        .accessibilityLabel("Scroll to top")
                        .onTapGesture {
                            isScrollingToTop = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                isScrollingToTop = false
                            }
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(item: $activeListSheet) { sheet in
            switch sheet {
            case .programs:
                ProgramsListView()
            case .premium:
                PremiumPaywallView(
                    storeManager: StoreManager.shared,
                    context: .discoverBanner,
                    onSubscribed: { activeListSheet = nil }
                )
            case .addToPlaylist(let content):
                AddToPlaylistSheet(content: content)
            }
        }
    }

    private func loadMoreContent() {
        guard !isLoadingMore && hasMoreContent else { return }

        isLoadingMore = true

        // Simulate brief loading delay for smooth UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.2)) {
                displayedCount = min(displayedCount + batchSize, filteredContent.count)
            }
            isLoadingMore = false
        }
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
            onAddToPlaylist: { activeListSheet = .addToPlaylist(content) },
            onShare: { shareContent(content) }
        )
    }

    /// Play content with a queue for auto-play
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
}

// MARK: - Unguided Timer View
struct UnguidedTimerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @StateObject private var streakService = StreakService.shared
    @StateObject private var ambientSoundService = AmbientSoundService.shared
    @State private var selectedDuration = 10
    @State private var isTimerRunning = false
    @State private var timeRemaining = 0
    @State private var selectedSound: TimerAmbientSound? = nil
    @State private var timer: Timer?
    @State private var sessionStartTime: Date?

    let durations = [5, 10, 15, 20, 30, 45, 60]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                VStack(spacing: 24) {
                    if isTimerRunning {
                        // Timer Running View
                        timerRunningView
                    } else {
                        // Setup View
                        timerSetupView
                    }
                }
                .padding(.horizontal)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        stopTimer()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .presentationDetents(isTimerRunning ? [.large] : [.medium])
        .presentationDragIndicator(.visible)
        .onDisappear {
            stopTimer()
        }
    }

    private var timerRunningView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Theme.cardBackground, lineWidth: 8)
                    .frame(width: 250, height: 250)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 250, height: 250)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                VStack(spacing: 8) {
                    Text(timeFormatted)
                        .font(.system(size: 48, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)

                    Text("remaining")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            if let sound = selectedSound, sound != .silence {
                HStack(spacing: 8) {
                    Image(systemName: sound.iconName)
                    Text(sound.displayName)
                }
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            HStack(spacing: 32) {
                Button {
                    stopTimer()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(.red)
                        .clipShape(Circle())
                }

                Button {
                    togglePause()
                } label: {
                    Image(systemName: timer != nil ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundStyle(.black)
                        .frame(width: 80, height: 80)
                        .background(.white)
                        .clipShape(Circle())
                }
            }
            .padding(.bottom, 32)
        }
    }

    private var timerSetupView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Text("Choose Duration")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(durations, id: \.self) { duration in
                            Button {
                                selectedDuration = duration
                            } label: {
                                Text("\(duration)")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(selectedDuration == duration ? .white : Theme.textPrimary)
                                    .frame(width: 48, height: 48)
                                    .background(
                                        selectedDuration == duration
                                            ? Color.white.opacity(0.25)
                                            : Theme.cardBackground
                                    )
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Text("minutes")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Divider()
                .background(Theme.textTertiary)

            VStack(spacing: 12) {
                Text("Background Sound")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)

                HStack(spacing: 10) {
                    ForEach(TimerAmbientSound.allCases, id: \.self) { sound in
                        Button {
                            if selectedSound == sound {
                                selectedSound = nil
                            } else {
                                selectedSound = sound
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: sound.iconName)
                                    .font(.body)
                                Text(sound.displayName)
                                    .font(.caption2)
                            }
                            .foregroundStyle(selectedSound == sound ? .white : Theme.textPrimary)
                            .frame(width: 64, height: 52)
                            .background(
                                selectedSound == sound
                                    ? Color.white.opacity(0.25)
                                    : Theme.cardBackground
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }

            Button {
                HapticManager.success()
                startTimer()
            } label: {
                Text("Begin Session")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
            }
            .padding(.top, 8)
        }
    }

    private var progress: Double {
        guard selectedDuration > 0 else { return 0 }
        return Double(timeRemaining) / Double(selectedDuration * 60)
    }

    private var timeFormatted: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func startTimer() {
        timeRemaining = selectedDuration * 60
        isTimerRunning = true
        sessionStartTime = Date()

        // Start ambient sound if selected
        if let sound = selectedSound {
            ambientSoundService.play(sound: sound)
        }

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    completeSession()
                }
            }
        }
    }

    private func togglePause() {
        if timer != nil {
            // Pause: stop the countdown AND the ambient sound.
            timer?.invalidate()
            timer = nil
            ambientSoundService.pause()
        } else {
            // Resume: restart the countdown AND the ambient sound.
            ambientSoundService.resume()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                Task { @MainActor in
                    if timeRemaining > 0 {
                        timeRemaining -= 1
                    } else {
                        completeSession()
                    }
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil

        // Stop ambient sound
        ambientSoundService.stop()

        // Record partial session if timer was started
        if isTimerRunning, let startTime = sessionStartTime {
            let actualDuration = Int(Date().timeIntervalSince(startTime))
            if actualDuration > 60 { // Only record if at least 1 minute
                recordSession(durationSeconds: actualDuration)
            }
        }

        isTimerRunning = false
        sessionStartTime = nil
    }

    private func completeSession() {
        timer?.invalidate()
        timer = nil
        HapticManager.success()

        // Fade out ambient sound
        ambientSoundService.fadeOut(duration: 2.0)

        // Record completed session
        recordSession(durationSeconds: selectedDuration * 60)

        // Count toward rating prompt
        AppStateManager.shared.onSessionCompleted()

        isTimerRunning = false
        sessionStartTime = nil
    }

    private func recordSession(durationSeconds: Int) {
        let session = MeditationSession(
            contentID: nil,
            durationSeconds: durationSeconds,
            completedAt: Date()
        )
        modelContext.insert(session)

        // Update streak
        streakService.recordSession(durationMinutes: durationSeconds / 60, context: modelContext)
    }
}

// MARK: - Discover Programs Preview
struct DiscoverProgramsPreview: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \Program.name) private var programs: [Program]
    @Query private var progress: [ProgramProgress]
    let onSeeAll: () -> Void
    @State private var selectedProgram: Program?

    var body: some View {
        if !programs.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "book.closed.fill")
                        .foregroundStyle(.white)
                    Text("Programs")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    Button("See All", action: onSeeAll)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(programs) { program in
                            let prog = progress.first { $0.programID == program.id }
                            Button {
                                selectedProgram = program
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(program.contentType == .sleepStory
                                                ? Color.indigo.opacity(0.3)
                                                : Color.cyan.opacity(0.2))
                                            .frame(height: 80)

                                        Image(systemName: program.iconName)
                                            .font(.largeTitle)
                                            .foregroundStyle(program.contentType == .sleepStory ? .indigo : .cyan)
                                    }

                                    Text(program.name)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)
                                        .lineLimit(1)

                                    if let p = prog {
                                        Text("\(p.completedDays.count)/\(program.totalDays) days")
                                            .font(.caption)
                                            .foregroundStyle(.cyan)
                                    } else {
                                        Text("\(program.totalDays) days")
                                            .font(.caption)
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                }
                                .frame(width: sizeClass == .regular ? 180 : 140)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .sheet(item: $selectedProgram) { program in
                ProgramDetailView(program: program)
            }
            .onReceive(NotificationCenter.default.publisher(for: .dismissAllSheetsAndPlay)) { _ in
                selectedProgram = nil
            }
        }
    }
}

// MARK: - Discover Tools Section
struct DiscoverToolsSection: View {
    let onBreathing: () -> Void
    let onBodyScan: () -> Void
    let onFocusTimer: () -> Void
    var onAIMeditation: (() -> Void)? = nil
    var onYouTubeSearch: (() -> Void)? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if let onYouTubeSearch {
                    DiscoverToolCard(
                        icon: "play.rectangle.on.rectangle",
                        title: "Add Content",
                        subtitle: "Search YouTube",
                        color: .red,
                        action: onYouTubeSearch
                    )
                }

                // AI-Generated Meditation - Premium feature
                if let onAIMeditation {
                    DiscoverToolCard(
                        icon: "wand.and.stars",
                        title: "Create Your Own",
                        subtitle: "AI meditation",
                        color: Theme.profileAccent,
                        isPremiumFeature: true,
                        action: onAIMeditation
                    )
                }

                DiscoverToolCard(
                    icon: "wind",
                    title: "Breathing",
                    subtitle: "5 techniques",
                    color: .cyan,
                    action: onBreathing
                )

                DiscoverToolCard(
                    icon: "figure.mind.and.body",
                    title: "Body Scan",
                    subtitle: "Guided relaxation",
                    color: .purple,
                    action: onBodyScan
                )

                DiscoverToolCard(
                    icon: "timer",
                    title: "Focus Timer",
                    subtitle: "Pomodoro mode",
                    color: .orange,
                    action: onFocusTimer
                )
            }
            .padding(.horizontal)
        }
    }
}

struct DiscoverToolCard: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var isPremiumFeature: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.2))
                            .frame(width: 44, height: 44)

                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundStyle(color)
                    }

                    Spacer()

                    if isPremiumFeature {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }

                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: sizeClass == .regular ? 150 : 120, height: sizeClass == .regular ? 110 : 95, alignment: .leading)
            .padding(14)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                isPremiumFeature ?
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [color.opacity(0.5), color.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    : nil
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DiscoverView(initialCategory: .constant(nil))
        .modelContainer(for: Content.self, inMemory: true)
}
