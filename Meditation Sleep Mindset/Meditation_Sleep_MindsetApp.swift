//
//  Meditation_Sleep_MindsetApp.swift
//  Meditation Sleep Mindset
//
//  Created by Gigabyte LLC on 1/23/26.
//

import SwiftUI
import SwiftData
import CoreSpotlight

@main
struct Meditation_Sleep_MindsetApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppStateManager.shared
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var streakService = StreakService.shared
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            Content.self,
            FavoriteContent.self,
            MeditationSession.self,
            Playlist.self,
            PlaylistItem.self,
            ChatSession.self,
            ChatMessage.self,
            Program.self,
            ProgramDay.self,
            ProgramProgress.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Schema migration failed — delete old store and retry
            #if DEBUG
            print("ModelContainer migration failed: \(error). Deleting old store and retrying.")
            #endif
            let url = modelConfiguration.url
            let fileManager = FileManager.default
            for suffix in ["", "-wal", "-shm"] {
                let fileURL = suffix.isEmpty ? url : URL(fileURLWithPath: url.path + suffix)
                try? fileManager.removeItem(at: fileURL)
            }
            // Reset content version so seeding re-runs
            UserDefaults.standard.removeObject(forKey: "ContentRepositoryVersion")
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer after reset: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .statusBarHidden()
                .environmentObject(appState)
                .onAppear {
                    // Seed content on first launch
                    ContentRepository.shared.seedContentIfNeeded(in: sharedModelContainer.mainContext)

                    // Seed programs
                    ProgramRepository.shared.seedIfNeeded(in: sharedModelContainer.mainContext)

                    // Restore data from iCloud after reinstall
                    let syncService = iCloudSyncService.shared
                    syncService.restoreFavoritesIfNeeded(in: sharedModelContainer.mainContext)
                    syncService.restorePlaylistsIfNeeded(in: sharedModelContainer.mainContext)
                    syncService.restoreSessionsIfNeeded(in: sharedModelContainer.mainContext)

                    // Fetch real video durations from YouTube Data API
                    Task {
                        await YouTubeDurationService.shared.fetchAndUpdateDurations(in: sharedModelContainer.mainContext)
                    }

                    // Fetch remote video health manifest and apply replacements for dead videos
                    Task {
                        await ContentHealthService.shared.fetchManifestAndApplyReplacements(in: sharedModelContainer.mainContext)
                    }

                    // Index content for Spotlight search
                    Task {
                        let descriptor = FetchDescriptor<Content>()
                        if let allContent = try? sharedModelContainer.mainContext.fetch(descriptor) {
                            SpotlightService.shared.indexAllContent(allContent)
                        }
                    }

                    // Preload thumbnails and videos in background
                    Task {
                        await preloadAllContent()
                    }
                }
                .onOpenURL { url in
                    // Handle deep links
                    appState.handleDeepLink(url)
                }
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    // Handle Spotlight search result taps
                    if let videoID = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                        appState.handleDeepLink(URL(string: "meditation://content/\(videoID)")!)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                appState.handleAppOpen()
                // Update quick actions when app becomes active
                appDelegate.updateQuickActions()
                // Reset re-engagement notifications and clear badge
                notificationService.resetReengagementOnAppOpen()
                notificationService.clearBadge()
            }
            if newPhase == .background {
                // Sync all user data to iCloud when app backgrounds
                let syncService = iCloudSyncService.shared
                let context = sharedModelContainer.mainContext
                syncService.syncFavorites(from: context)
                syncService.syncPlaylists(from: context)
                syncService.syncSessions(from: context)
            }
        }
    }

    /// Preload thumbnails and videos for all content
    private func preloadAllContent() async {
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<Content>()

        guard let allContent = try? context.fetch(descriptor) else { return }

        // Preload all thumbnails first (fast, small files)
        await CacheManager.shared.preloadThumbnails(for: allContent)

        // Preload featured content videos (limit to save storage)
        let featured = allContent.filter { $0.isFeatured }
        if !featured.isEmpty {
            await CacheManager.shared.preloadVideos(for: featured, limit: 10)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var selectedTab: AppTab = .home
    @State private var showingTimer = false
    @State private var showingPaywall = false
    @State private var initialDiscoverCategory: ContentType?

    var body: some View {
        Group {
            // Skip onboarding if there's a pending deep link - let user see shared content immediately
            if !appState.hasCompletedOnboarding && appState.pendingDeepLinkVideoID == nil {
                OnboardingView()
            } else {
                MainTabViewWithQuickActions(
                    selectedTab: $selectedTab,
                    showingTimer: $showingTimer,
                    showingPaywall: $showingPaywall,
                    initialDiscoverCategory: $initialDiscoverCategory
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickActionTriggered)) { notification in
            guard let action = notification.userInfo?["action"] as? AppDelegate.QuickAction else { return }
            handleQuickAction(action)
        }
        .onAppear {
            // Handle pending quick action if app was launched from one
            if let action = AppDelegate.pendingQuickAction {
                handleQuickAction(action)
                AppDelegate.pendingQuickAction = nil
            }
        }
    }

    private func handleQuickAction(_ action: AppDelegate.QuickAction) {
        switch action {
        case .browseMeditation:
            initialDiscoverCategory = .meditation
            selectedTab = .discover
        case .unguidedTimer:
            selectedTab = .home
            showingTimer = true
        case .openSleep:
            selectedTab = .sleep
        case .openDiscover:
            initialDiscoverCategory = nil
            selectedTab = .discover
        case .openChat:
            selectedTab = .chat
        }
    }
}

struct MainTabViewWithQuickActions: View {
    @Binding var selectedTab: AppTab
    @Binding var showingTimer: Bool
    @Binding var showingPaywall: Bool
    @Binding var initialDiscoverCategory: ContentType?
    @EnvironmentObject var appState: AppStateManager
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var playerManager = AudioPlayerManager.shared
    @State private var showFullPlayer = false
    @State private var deepLinkContent: Content?
    @State private var isKeyboardVisible = false
    @State private var actionSheetData: ActionSheetManager.SheetData?
    @Environment(\.modelContext) private var modelContext

    private var shouldHideTabBar: Bool {
        isKeyboardVisible && selectedTab == .chat
    }

    init(selectedTab: Binding<AppTab>, showingTimer: Binding<Bool>, showingPaywall: Binding<Bool>, initialDiscoverCategory: Binding<ContentType?>) {
        self._selectedTab = selectedTab
        self._showingTimer = showingTimer
        self._showingPaywall = showingPaywall
        self._initialDiscoverCategory = initialDiscoverCategory

        // Hide native tab bar
        UITabBar.appearance().isHidden = true
    }

    private var availableTabs: [AppTab] {
        [.home, .sleep, .discover, .chat, .profile]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content views based on selected tab
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .sleep:
                    SleepView()
                case .discover:
                    DiscoverView(initialCategory: $initialDiscoverCategory)
                case .profile:
                    ProfileView()
                case .chat:
                    ChatView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !shouldHideTabBar {
                // Bottom fade gradient to hide content behind tab bar
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color(red: 0.1, green: 0.2, blue: 0.35).opacity(0.8),
                            Color(red: 0.1, green: 0.2, blue: 0.35)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 160)
                    .allowsHitTesting(false)
                }
                .ignoresSafeArea()

                // Solid background color below tab bar to match app theme
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(Color(red: 0.1, green: 0.2, blue: 0.35))
                        .frame(height: 50)
                }
                .ignoresSafeArea(.all, edges: .bottom)
                .allowsHitTesting(false)

                // Bottom bar stack
                VStack(spacing: 7) {
                    // Mini player - shows when content is playing and full player is closed
                    if playerManager.currentContent != nil && !showFullPlayer {
                        MiniPlayerView(
                            playerManager: playerManager,
                            showFullPlayer: $showFullPlayer
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.3), value: playerManager.currentContent != nil)
                    }

                    // Custom tab bar
                    CustomTabBar(selectedTab: $selectedTab, tabs: availableTabs)
                        .padding(.bottom, -12)
                }
            }

            // Toast notification overlay
            ToastOverlay()
        }
        .sheet(isPresented: $appState.shouldShowNotificationPrompt, onDismiss: {
            appState.markNotificationPromptHandled()
        }) {
            NotificationPromptSheet()
        }
        .sheet(isPresented: $showingTimer) {
            UnguidedTimerView()
        }
        .sheet(isPresented: $showingPaywall) {
            DiscountedPaywallView()
        }
        .fullScreenCover(isPresented: $showFullPlayer) {
            if let content = playerManager.currentContent {
                MeditationPlayerView(content: content)
            } else {
                // Fallback - prevents white screen
                Color.clear.onAppear { showFullPlayer = false }
            }
        }
        .fullScreenCover(item: $deepLinkContent) { content in
            MeditationPlayerView(content: content)
        }
        .onChange(of: appState.pendingDeepLinkVideoID) { _, videoID in
            handleDeepLink(videoID: videoID)
        }
        .onAppear {
            // Handle any pending deep link when view appears
            if let videoID = appState.pendingDeepLinkVideoID {
                handleDeepLink(videoID: videoID)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .onReceive(NotificationCenter.default.publisher(for: ActionSheetManager.didChangeNotification)) { _ in
            actionSheetData = ActionSheetManager.shared.sheetData
        }
        .overlay {
            if let data = actionSheetData {
                ContentActionSheet(
                    content: data.content,
                    isFavorite: data.isFavorite,
                    onToggleFavorite: data.onToggleFavorite,
                    onAddToPlaylist: data.onAddToPlaylist,
                    onShare: data.onShare,
                    isPresented: Binding(
                        get: { actionSheetData != nil },
                        set: { if !$0 {
                            actionSheetData = nil
                            ActionSheetManager.shared.dismiss()
                        }}
                    )
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: actionSheetData?.id)
    }

    private func handleDeepLink(videoID: String?) {
        guard let videoID = videoID else { return }

        // Find content with matching YouTube video ID
        let descriptor = FetchDescriptor<Content>(
            predicate: #Predicate { $0.youtubeVideoID == videoID }
        )

        if let content = try? modelContext.fetch(descriptor).first {
            // Open the player with this content
            deepLinkContent = content
            appState.clearPendingDeepLink()
        } else {
            #if DEBUG
            print("[DeepLink] Content not found for video ID: \(videoID)")
            #endif
            appState.clearPendingDeepLink()
        }
    }
}

struct DiscountedPaywallView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var storeManager = StoreManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.3),
                        Color(red: 0.2, green: 0.1, blue: 0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Free Trial Badge
                        HStack {
                            Image(systemName: "star.fill")
                            Text("Exclusive Offer")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.yellow)
                        .clipShape(Capsule())

                        Text("Try Premium Free")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        // Free Trial Details
                        VStack(spacing: 8) {
                            Text("3 Days Free")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundStyle(.white)

                            Text("Then $49.99/year")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.7))

                            Text("Cancel anytime during trial")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                        }

                        // Benefits
                        VStack(alignment: .leading, spacing: 12) {
                            BenefitRow(icon: "infinity", text: "Unlimited access to all content")
                            BenefitRow(icon: "moon.stars.fill", text: "100+ sleep stories")
                            BenefitRow(icon: "arrow.down.circle.fill", text: "Offline downloads")
                            BenefitRow(icon: "sparkles", text: "Exclusive premium programs")
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                        // CTA Button
                        Button {
                            // Purchase annual with free trial
                            Task {
                                if let annualProduct = storeManager.subscriptions.first(where: { $0.subscription?.subscriptionPeriod.unit == .year }) {
                                    await storeManager.purchase(annualProduct)
                                }
                                dismiss()
                            }
                        } label: {
                            Text("Start Free Trial")
                                .font(.headline)
                                .foregroundStyle(Color(red: 0.2, green: 0.1, blue: 0.4))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)

                        Button("No thanks") {
                            dismiss()
                        }
                        .foregroundStyle(.white.opacity(0.6))

                        // Fine print
                        Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless it is canceled at least 24 hours before the end of the current period.")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.vertical, 40)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .alert("Purchase Failed", isPresented: $storeManager.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(storeManager.error ?? "Something went wrong. Please try again.")
            }
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Theme.profileAccent)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }
}

struct NotificationPromptSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppStateManager
    @StateObject private var notificationService = NotificationService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    // Icon
                    ZStack {
                        Circle()
                            .fill(Theme.profileAccent.opacity(0.2))
                            .frame(width: 100, height: 100)

                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.profileAccent)
                    }

                    // Content
                    VStack(spacing: 12) {
                        Text("Don't Miss Your Calm")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        Text("A gentle daily reminder helps you\nbuild a lasting meditation habit.")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }

                    // Stats
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundStyle(Theme.profileAccent)
                        (Text("Users with reminders are ")
                            .foregroundStyle(.white.opacity(0.7))
                        + Text("3x more likely ")
                            .fontWeight(.bold)
                            .foregroundStyle(Theme.profileAccent)
                        + Text("to build a lasting habit")
                            .foregroundStyle(.white.opacity(0.7)))
                        .multilineTextAlignment(.center)
                    }
                    .font(.caption)
                    .padding()
                    .background(Theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 24)

                    Spacer()

                    // Buttons
                    VStack(spacing: 16) {
                        Button {
                            Task {
                                let granted = await notificationService.requestAuthorization()
                                if granted {
                                    notificationService.setDailyReminder(enabled: true)
                                }
                                appState.markNotificationPromptHandled()
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Text("Enable Reminders")
                                Image(systemName: "bell.fill")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.profileAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button {
                            appState.markNotificationPromptHandled()
                            dismiss()
                        } label: {
                            Text("Not Now")
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appState.markNotificationPromptHandled()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
