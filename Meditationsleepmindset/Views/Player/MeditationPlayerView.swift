//
//  MeditationPlayerView.swift
//  Meditation Sleep Mindset
//

import SwiftUI
import SwiftData
import AVKit
import StoreKit

struct MeditationPlayerView: View {
    let content: Content

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [FavoriteContent]
    @StateObject private var playerManager = AudioPlayerManager.shared
    @StateObject private var storeManager = StoreManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var appStateManager = AppStateManager.shared
    @State private var showSleepTimer = false
    @State private var showAddToPlaylist = false
    @State private var showSpeedSelector = false
    @State private var isVideoMode = true
    @State private var hasRecordedSession = false
    @State private var showPaywall = false
    @State private var hasCheckedSubscription = false
    @State private var showPostSessionReflection = false
    @State private var isPreviewMode = false
    @State private var previewTimer: Task<Void, Never>?

    // Session tracking - record based on actual listen time
    @State private var sessionStartTime: Date?
    @State private var accumulatedListenTime: TimeInterval = 0
    @Environment(\.scenePhase) private var scenePhase

    // Video controls visibility state
    @State private var showVideoControls = false
    @State private var controlsHideTask: Task<Void, Never>?

    // Orientation state for fullscreen
    @State private var isLandscape = false

    // Haptics
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let selectionFeedback = UISelectionFeedbackGenerator()

    // Swipe to dismiss state
    @State private var dragOffset: CGFloat = 0

    // Theme convenience
    private var theme: PlayerTheme { themeManager.currentTheme }

    /// Use the player manager's current content (which updates on queue advance) or fall back to the init content
    private var displayedContent: Content {
        playerManager.currentContent ?? content
    }

    private var isFavorite: Bool {
        let c = displayedContent
        return favorites.contains { $0.contentID == c.id || $0.youtubeVideoID == c.youtubeVideoID }
    }

    var body: some View {
        GeometryReader { geometry in
            let currentIsLandscape = geometry.size.width > geometry.size.height

            ZStack {
                // Themed background gradient
                theme.gradient
                    .ignoresSafeArea()

                // Animated background overlay (pauses when not playing to save energy)
                if playerManager.isPlaying || playerManager.isLoading {
                    AnimatedBackgroundView(
                        backgroundID: themeManager.currentBackground,
                        accentColor: theme.accentColor
                    )
                    .ignoresSafeArea()
                }

                if isLandscape && isVideoMode {
                    // Fullscreen landscape video mode
                    fullscreenVideoPlayer
                } else {
                    // Normal portrait mode
                    VStack(spacing: 0) {
                        // Navigation bar
                        navigationBar
                            .padding(.top, 50)

                        // Video player area
                        videoPlayerSection
                            .padding(.top, 30)

                        // Preview banner
                        if isPreviewMode {
                            HStack {
                                Image(systemName: "lock.fill")
                                Text("Preview — Subscribe for full access")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Theme.profileAccent.opacity(0.8))
                            .clipShape(Capsule())
                            .padding(.top, 8)
                        }

                        // Content info
                        contentInfoSection
                            .padding(.horizontal, 24)
                            .padding(.top, 28)

                        // Action buttons (favorite, sleep timer, share)
                        actionButtonsSection
                            .padding(.top, 28)

                        Spacer()

                        // Bottom controls (progress + play/pause)
                        bottomControlsSection
                            .padding(.horizontal, 24)
                            .offset(y: -5)

                        // Up Next indicator
                        if let nextTitle = playerManager.nextTrackTitle {
                            Text("Up next: \(nextTitle)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.45))
                                .lineLimit(1)
                                .padding(.horizontal, 24)
                                .padding(.top, 35)
                        }

                        Spacer().frame(height: 50)
                    }
                }
                // Toast overlay for fullScreenCover context
                ToastOverlay()
            }
            .offset(y: dragOffset)
            .scaleEffect(dragOffset > 0 ? 1 - (dragOffset / geometry.size.height) * 0.15 : 1)
            .clipShape(RoundedRectangle(cornerRadius: dragOffset > 0 ? 20 : 0))
            .animation(.interactiveSpring(), value: dragOffset)
            .gesture(
                !isLandscape ? DragGesture()
                    .onChanged { value in
                        // Only allow downward drag
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 150 || value.velocity.height > 1000 {
                            dismiss()
                        } else {
                            // Snap back
                            dragOffset = 0
                        }
                    } : nil
            )
            .onChange(of: currentIsLandscape) { _, newValue in
                withAnimation(.easeInOut(duration: 0.3)) {
                    isLandscape = newValue
                }
            }
            .onAppear {
                isLandscape = currentIsLandscape
            }
        }
        .ignoresSafeArea()
        .background(ClearFullScreenBackground())
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .sheet(isPresented: $showSleepTimer) {
            SleepTimerView()
        }
        .sheet(isPresented: $showAddToPlaylist) {
            AddToPlaylistSheet(content: displayedContent)
        }
        .sheet(isPresented: $showSpeedSelector) {
            SpeedSelectorView(
                currentSpeed: playerManager.playbackRate,
                onSelect: { speed in
                    playerManager.setPlaybackRate(speed)
                }
            )
        }
        .sheet(isPresented: $showPostSessionReflection) {
            PostSessionReflectionView(content: displayedContent)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            SessionPaywallView {
                // User dismissed paywall without subscribing - dismiss player
                dismiss()
            } onSubscribed: {
                // User subscribed - continue with session
                showPaywall = false
                loadContent()
            }
        }
        .onChange(of: showPaywall) { _, showing in
            AppDelegate.allowLandscape = !showing
        }
        .onAppear {
            AppDelegate.allowLandscape = true
            checkSubscriptionAndLoad()

            // Set up callback for auto-advance session recording
            playerManager.onTrackCompleted = { [weak modelContext] completedContent, completedDuration in
                guard let modelContext = modelContext else { return }
                // Mark recorded so recordSessionIfEligible() won't duplicate on dismiss
                hasRecordedSession = true
                // Record session for the track that just finished
                let actualDuration = Int(min(completedDuration, Double(completedContent.durationSeconds)))
                guard actualDuration >= Int(Constants.Session.minimumListenTimeForRecord) else { return }
                let isCompleted = Double(actualDuration) >= Double(completedContent.durationSeconds) * Constants.Session.completionThreshold
                let session = MeditationSession(
                    contentID: completedContent.id,
                    youtubeVideoID: completedContent.youtubeVideoID,
                    contentTitle: completedContent.title,
                    durationSeconds: completedContent.durationSeconds,
                    listenedSeconds: actualDuration,
                    wasCompleted: isCompleted,
                    sessionType: "guided",
                    completedAt: isCompleted ? Date() : nil
                )
                modelContext.insert(session)
                try? modelContext.save()
            }
        }
        .onDisappear {
            previewTimer?.cancel()
            AppDelegate.allowLandscape = false
            // Force back to portrait when leaving player
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            }
            // Record session when player closes (if user listened enough)
            recordSessionIfEligible()
            // Clear the callback
            playerManager.onTrackCompleted = nil
            // Keep audio playing so mini player can show — don't call playerManager.stop()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Track listen time when app goes to background
            if newPhase == .background {
                recordSessionIfEligible()
            }
        }
        .onChange(of: playerManager.isPlaying) { _, isPlaying in
            // Track when playback starts/stops to accumulate listen time
            if isPlaying {
                sessionStartTime = Date()
            } else if let startTime = sessionStartTime {
                accumulatedListenTime += Date().timeIntervalSince(startTime)
                sessionStartTime = nil
            }
        }
        .onChange(of: playerManager.currentContent?.id) { oldID, newID in
            // Queue auto-advanced to a new track — reset session tracking
            guard oldID != nil, newID != nil, oldID != newID else { return }
            accumulatedListenTime = 0
            sessionStartTime = Date()
            hasRecordedSession = false
        }
    }

    private func checkSubscriptionAndLoad() {
        guard !hasCheckedSubscription else { return }
        hasCheckedSubscription = true

        Task {
            let isPremium = await storeManager.isPremiumSubscriber()

            if isPremium {
                loadContent()
            } else if content.isPremium {
                // Free user tapped premium content — allow 30-second preview
                isPreviewMode = true
                loadContent()
                startPreviewTimer()
            } else if appStateManager.hasReachedFreeSessionLimit {
                showPaywall = true
            } else {
                appStateManager.recordFreeSessionUsed()
                loadContent()
            }
        }
    }

    // MARK: - Navigation Bar
    private var navigationBar: some View {
        HStack {
            // Minimize button
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }

            Spacer()

            // AirPlay
            AirPlayButton()
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Video Player Section
    private var videoPlayerSection: some View {
        ZStack {
            if isVideoMode, let player = playerManager.player {
                // Actual video player using AVKit
                VideoPlayer(player: player)
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .disabled(true) // Disable built-in controls, we use our own
                    .overlay {
                        // Tap to show/hide controls
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleVideoControls()
                            }
                    }

                // Loading indicator
                if playerManager.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }

                // Error overlay (when player exists but stream failed)
                if let error = playerManager.error {
                    streamErrorOverlay(error: error)
                }
            } else if isVideoMode {
                // Show thumbnail while loading video
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
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.08))
                            .aspectRatio(16/9, contentMode: .fit)
                    }
                )
                .aspectRatio(16/9, contentMode: .fit)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Loading indicator while fetching stream
                if playerManager.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }

                // Error overlay with retry button
                if let error = playerManager.error {
                    streamErrorOverlay(error: error)
                }
            } else {
                // Audio-only mode with artwork
                CachedAsyncImage(
                    url: URL(string: content.thumbnailURLComputed),
                    failedIconName: content.contentType.iconName,
                    content: { image in
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 8)
                    },
                    placeholder: {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.08))
                            .aspectRatio(1, contentMode: .fit)
                    }
                )
                .frame(maxWidth: 280)
                .padding(.vertical, 20)

                // Error overlay for audio-only mode
                if let error = playerManager.error {
                    streamErrorOverlay(error: error)
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Fullscreen Video Player (Landscape)
    private var fullscreenVideoPlayer: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = playerManager.player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .disabled(true)
                    .overlay {
                        // Tap to show/hide controls
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleVideoControls()
                            }
                    }

                // Controls overlay for fullscreen
                if showVideoControls || (!playerManager.isPlaying && !playerManager.isLoading) {
                    // Semi-transparent gradient at top and bottom
                    VStack {
                        // Top gradient with close button
                        HStack {
                            Spacer()
                            Text(content.title)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.black.opacity(0.7), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        Spacer()

                        // Bottom controls
                        VStack(spacing: 16) {
                            // Progress bar
                            HStack(spacing: 12) {
                                Text(formatTime(playerManager.currentTime))
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .monospacedDigit()

                                GeometryReader { geo in
                                    let progress = playerManager.duration > 0
                                        ? playerManager.currentTime / playerManager.duration
                                        : 0

                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.white.opacity(0.3))
                                            .frame(height: 4)

                                        Capsule()
                                            .fill(Color.white)
                                            .frame(width: max(0, geo.size.width * progress), height: 4)
                                    }
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                let progress = max(0, min(1, value.location.x / geo.size.width))
                                                let newTime = progress * playerManager.duration
                                                playerManager.seek(to: newTime)
                                            }
                                    )
                                }
                                .frame(height: 20)

                                Text(formatTime(playerManager.duration))
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .monospacedDigit()
                            }
                            .padding(.horizontal)

                            // Playback controls
                            HStack(spacing: 48) {
                                Button {
                                    playerManager.skipBackward(seconds: 15)
                                    scheduleControlsHide()
                                } label: {
                                    Image(systemName: "gobackward.15")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                }

                                Button {
                                    playerManager.togglePlayPause()
                                    scheduleControlsHide()
                                } label: {
                                    Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.largeTitle)
                                        .foregroundStyle(.white)
                                }

                                Button {
                                    playerManager.skipForward(seconds: 15)
                                    scheduleControlsHide()
                                } label: {
                                    Image(systemName: "goforward.15")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(.bottom, 8)
                        }
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: showVideoControls)
                }

                // Loading indicator
                if playerManager.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
            }
        }
    }

    // MARK: - Video Controls Helpers
    private func toggleVideoControls() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showVideoControls.toggle()
        }

        if showVideoControls {
            scheduleControlsHide()
        }
    }

    private func scheduleControlsHide() {
        // Cancel any existing hide task
        controlsHideTask?.cancel()

        // Schedule new hide task after 5 seconds
        controlsHideTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showVideoControls = false
                    }
                }
            }
        }
    }

    // MARK: - Content Info Section
    private var contentInfoSection: some View {
        VStack(spacing: 6) {
            // Title
            Text(displayedContent.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Narrator and duration
            HStack(spacing: 6) {
                if let narrator = displayedContent.narrator {
                    Text(narrator)
                        .foregroundStyle(.white.opacity(0.6))
                }
                if displayedContent.narrator != nil {
                    Text("·")
                        .foregroundStyle(.white.opacity(0.4))
                }
                Text(playerManager.duration > 0 ? formatDuration(playerManager.duration) : displayedContent.durationFormatted)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .font(.subheadline)

        }
    }

    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 8) {
            // Sleep timer countdown (visible when active)
            if let remaining = playerManager.sleepTimerRemaining {
                Text("Sleep in \(formatTime(remaining))")
                    .font(.caption)
                    .foregroundStyle(theme.accentColor)
                    .transition(.opacity)
            }

            HStack(spacing: 20) {
                // Favorite
                actionButton(icon: isFavorite ? "heart.fill" : "heart",
                             label: "Favorite",
                             active: isFavorite) {
                    impactMedium.impactOccurred()
                    toggleFavorite()
                }
                .animation(.spring(response: 0.3), value: isFavorite)

                // Sleep Timer
                actionButton(icon: "timer",
                             label: "Timer",
                             active: playerManager.sleepTimerRemaining != nil) {
                    impactLight.impactOccurred()
                    showSleepTimer = true
                }

                // Playback Speed
                actionButton(icon: "gauge.with.dots.needle.33percent",
                             label: playerManager.playbackRate != 1.0 ? String(format: "%.1fx", playerManager.playbackRate) : "Speed",
                             active: playerManager.playbackRate != 1.0) {
                    impactLight.impactOccurred()
                    showSpeedSelector = true
                }

                // Repeat
                actionButton(icon: playerManager.repeatMode.icon,
                             label: "Repeat",
                             active: playerManager.repeatMode != .off) {
                    selectionFeedback.selectionChanged()
                    withAnimation(.spring(response: 0.3)) {
                        playerManager.repeatMode = playerManager.repeatMode.next
                    }
                }

                // More (playlist + share)
                Menu {
                    Button {
                        showAddToPlaylist = true
                    } label: {
                        Label("Add to Playlist", systemImage: "text.badge.plus")
                    }
                    Button {
                        shareContent()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "ellipsis")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                        Text("More")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private func actionButton(icon: String, label: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(active ? theme.accentColor : .white.opacity(0.8))
                    .frame(width: 40, height: 40)
                    .background(active ? theme.accentColor.opacity(0.15) : Color.white.opacity(0.1))
                    .clipShape(Circle())

                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(active ? theme.accentColor : .white.opacity(0.5))
            }
        }
    }

    // MARK: - Bottom Controls Section (Progress + Play/Pause)
    private var bottomControlsSection: some View {
        VStack(spacing: 26) {
            // Progress bar - Custom styled to match reference
            VStack(spacing: 8) {
                // Custom progress bar with draggable thumb
                GeometryReader { geometry in
                    let trackWidth = geometry.size.width - 16 // inset for thumb radius
                    let progress = playerManager.duration > 0
                        ? playerManager.currentTime / playerManager.duration
                        : 0
                    let thumbX = 8 + trackWidth * progress // 8pt left margin to center of thumb

                    ZStack(alignment: .leading) {
                        // Background track
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 4)
                            .padding(.horizontal, 8)

                        // Progress fill with theme accent
                        Capsule()
                            .fill(theme.accentColor)
                            .frame(width: max(0, 8 + trackWidth * progress), height: 4)
                            .padding(.leading, 8)

                        // Thumb/knob
                        Circle()
                            .fill(.white)
                            .frame(width: 16, height: 16)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            .position(x: thumbX, y: 8)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let p = max(0, min(1, (value.location.x - 8) / trackWidth))
                                let newTime = p * playerManager.duration
                                playerManager.seek(to: newTime)
                            }
                    )
                }
                .frame(height: 16)

                // Time labels
                HStack {
                    Text(formatTime(playerManager.currentTime))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .monospacedDigit()

                    Spacer()

                    Text(formatTime(playerManager.duration))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .monospacedDigit()
                }
            }

            // Playback controls with skip and next/prev buttons
            HStack(spacing: 24) {
                // Previous track
                Button {
                    impactLight.impactOccurred()
                    playerManager.playPrevious()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 44, height: 44)
                }

                // Skip backward 15 seconds
                Button {
                    impactLight.impactOccurred()
                    playerManager.skipBackward(seconds: 15)
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 50, height: 50)
                }

                // Play/Pause button
                Button {
                    impactMedium.impactOccurred()
                    playerManager.togglePlayPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 72, height: 72)

                        if playerManager.isLoading {
                            VStack(spacing: 2) {
                                ProgressView()
                                    .tint(.black)
                                Text("Loading")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(.black.opacity(0.6))
                            }
                        } else if playerManager.isBuffering {
                            VStack(spacing: 2) {
                                ProgressView()
                                    .tint(.black)
                                Text("Buffering")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(.black.opacity(0.6))
                            }
                        } else {
                            Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title)
                                .foregroundStyle(.black)
                                .offset(x: playerManager.isPlaying ? 0 : 2)
                        }
                    }
                }

                // Skip forward 15 seconds
                Button {
                    impactLight.impactOccurred()
                    playerManager.skipForward(seconds: 15)
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 50, height: 50)
                }

                // Next track
                Button {
                    impactLight.impactOccurred()
                    playerManager.playNext()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 44, height: 44)
                }
            }
        }
    }

    // MARK: - Error Overlay
    private func streamErrorOverlay(error: String) -> some View {
        VStack(spacing: 16) {
            if playerManager.contentUnavailable {
                // Apology screen — both video and audio failed
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.8))

                Text("Content Unavailable")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Text("We're sorry, this content isn't available right now. Please try again later.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                HStack(spacing: 12) {
                    Button {
                        retryLoadContent()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.white)
                        .clipShape(Capsule())
                    }

                    Button {
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("Go Back")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                    }
                }
            } else {
                // Retryable error
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.8))

                Text("Unable to load content")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(error)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button {
                    retryLoadContent()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.white)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    private func retryLoadContent() {
        let retryContent = displayedContent
        // Clear stale stream cache for this video so we get a fresh extraction
        YouTubeService.shared.evictCacheEntry(for: retryContent.youtubeVideoID)
        playerManager.error = nil
        playerManager.contentUnavailable = false
        Task {
            await playerManager.loadContent(retryContent, videoMode: isVideoMode)
            playerManager.play()
        }
    }

    // MARK: - Helper Methods
    private func loadContent() {
        // Skip if same content is already loaded and ready, or currently loading
        if playerManager.currentContent?.id == content.id {
            if playerManager.isLoading { return }
            if playerManager.player != nil {
                if !playerManager.isPlaying { playerManager.play() }
                return
            }
        }

        // Reset session tracking for new content
        accumulatedListenTime = 0
        sessionStartTime = nil
        hasRecordedSession = false

        // Track that user has played a video (for share prompt gating)
        appStateManager.recordVideoPlayed()

        // If a queue was pre-set by the launching view, use it
        if playerManager.queue.count > 1,
           let idx = playerManager.queue.firstIndex(where: { $0.id == content.id }),
           idx == playerManager.currentIndex {
            // Queue already set and pointing at the right content — just load
            Task {
                await playerManager.loadContent(content, videoMode: isVideoMode)
                playerManager.play()
            }
        } else if playerManager.queue.isEmpty {
            // No queue set — single item playback
            playerManager.queue = [content]
            playerManager.currentIndex = 0
            Task {
                await playerManager.loadContent(content, videoMode: isVideoMode)
                playerManager.play()
            }
        } else {
            // Queue is set but content doesn't match index — just load normally
            Task {
                await playerManager.loadContent(content, videoMode: isVideoMode)
                playerManager.play()
            }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let mins = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        } else {
            return String(format: "%d:%02d", mins, secs)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let mins = (totalSeconds % 3600) / 60

        if hours > 0 {
            if mins > 0 {
                return "\(hours)h \(mins)m"
            }
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }

    /// Records session only if user listened for minimum required time
    private func recordSessionIfEligible() {
        guard !hasRecordedSession else { return }

        // Calculate total listen time including current playing session
        var totalListenTime = accumulatedListenTime
        if let startTime = sessionStartTime, playerManager.isPlaying {
            totalListenTime += Date().timeIntervalSince(startTime)
        }

        // Only record if user listened for at least the minimum time
        guard totalListenTime >= Constants.Session.minimumListenTimeForRecord else { return }

        hasRecordedSession = true

        let currentlyDisplayed = displayedContent

        // Record the actual time listened, not content duration
        let actualListenedSeconds = Int(min(totalListenTime, Double(currentlyDisplayed.durationSeconds)))
        let isCompleted = Double(actualListenedSeconds) >= Double(currentlyDisplayed.durationSeconds) * Constants.Session.completionThreshold

        Task { @MainActor in
            let session = MeditationSession(
                contentID: currentlyDisplayed.id,
                youtubeVideoID: currentlyDisplayed.youtubeVideoID,
                contentTitle: currentlyDisplayed.title,
                durationSeconds: currentlyDisplayed.durationSeconds,
                listenedSeconds: actualListenedSeconds,
                wasCompleted: isCompleted,
                sessionType: "guided",
                completedAt: isCompleted ? Date() : nil
            )
            modelContext.insert(session)
            do {
                try modelContext.save()
            } catch {
                #if DEBUG
                print("Failed to save session: \(error)")
                #endif
            }

            // Trigger review prompt after completed sessions
            if isCompleted {
                appStateManager.onSessionCompleted()
                // Show post-session reflection
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showPostSessionReflection = true
                }
            }

            // Write to Apple Health if enabled
            if HealthKitService.shared.isEnabled {
                let end = Date()
                let start = end.addingTimeInterval(-Double(actualListenedSeconds))
                Task {
                    await HealthKitService.shared.writeMindfulMinutes(start: start, end: end)
                }
            }
        }
    }

    private func toggleFavorite() {
        let c = displayedContent
        // Check by both contentID and youtubeVideoID for robustness
        let wasFavorite = favorites.contains(where: { $0.contentID == c.id || $0.youtubeVideoID == c.youtubeVideoID })
        if let existing = favorites.first(where: { $0.contentID == c.id || $0.youtubeVideoID == c.youtubeVideoID }) {
            modelContext.delete(existing)
        } else {
            let favorite = FavoriteContent(from: c)
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

    private func startPreviewTimer() {
        previewTimer?.cancel()
        previewTimer = Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            guard !Task.isCancelled else { return }
            await MainActor.run {
                // Fade out and show paywall
                playerManager.pause()
                showPaywall = true
                isPreviewMode = false
            }
        }
    }

    private func shareContent() {
        // Share with current timestamp if playback is in progress
        let timestamp = playerManager.currentTime > 5 ? Int(playerManager.currentTime) : nil
        ContentSharingHelper.share(displayedContent, atTimestamp: timestamp)
    }
}

struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePicker = AVRoutePickerView()
        routePicker.tintColor = .white
        routePicker.activeTintColor = .systemPurple
        return routePicker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

struct SpeedSelectorView: View {
    @Environment(\.dismiss) var dismiss
    let currentSpeed: Float
    let onSelect: (Float) -> Void

    let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    var body: some View {
        NavigationStack {
            List {
                ForEach(speeds, id: \.self) { speed in
                    Button {
                        onSelect(speed)
                        dismiss()
                    } label: {
                        HStack {
                            Text(String(format: "%.2fx", speed))
                                .foregroundStyle(.primary)

                            Spacer()

                            if speed == currentSpeed {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Playback Speed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Session Paywall View
struct SessionPaywallView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var storeManager = StoreManager.shared
    let onDismiss: () -> Void
    let onSubscribed: () -> Void

    var body: some View {
        ZStack {
            Theme.profileGradient.ignoresSafeArea()

            PremiumPaywallView(
                storeManager: storeManager,
                sessionLimitMessage: "You've used your \(Constants.Engagement.freeSessionLimit) free sessions. Subscribe to continue listening.",
                onSubscribed: {
                    onSubscribed()
                    dismiss()
                }
            )
        }
        .overlay(alignment: .topTrailing) {
            Button {
                onDismiss()
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
            .padding(.trailing, 20)
            .padding(.top, 16)
        }
    }
}

struct SubscriptionButton: View {
    let product: Product
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(product.displayName)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(product.displayPrice)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.profileAccent)
            )
        }
    }
}

// MARK: - Post-Session Reflection
struct PostSessionReflectionView: View {
    let content: Content
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedMood: String?

    private let moods = [
        ("😌", "Calm"),
        ("😊", "Happy"),
        ("😴", "Tired"),
        ("🧘", "Focused"),
        ("🙏", "Grateful"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        Text("How do you feel?")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)

                        Text("After \(content.title)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)

                        // Mood chips
                        HStack(spacing: 12) {
                            ForEach(moods, id: \.0) { emoji, label in
                                Button {
                                    HapticManager.selection()
                                    selectedMood = label
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(emoji)
                                            .font(.system(size: 32))
                                        Text(label)
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 8)
                                    .background(selectedMood == label ? Color.white.opacity(0.2) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }

                        // Save button
                        Button {
                            HapticManager.success()
                            saveReflection()
                            dismiss()
                        } label: {
                            Text(selectedMood != nil ? "Save Reflection" : "Skip")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(selectedMood != nil ? Theme.profileAccent : Color.white.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 32)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func saveReflection() {
        guard let mood = selectedMood else { return }
        // Save mood to the most recent session for this content
        let videoID = content.youtubeVideoID
        let descriptor = FetchDescriptor<MeditationSession>(
            predicate: #Predicate { $0.youtubeVideoID == videoID },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        if let session = try? modelContext.fetch(descriptor).first {
            session.postMood = mood
            try? modelContext.save()
        }
    }
}

// MARK: - Transparent FullScreenCover Background
/// Makes the fullScreenCover background transparent so the underlying view
/// shows through when the player is dragged down to dismiss.
struct ClearFullScreenBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            uiView.superview?.superview?.backgroundColor = .clear
        }
    }
}

#Preview {
    MeditationPlayerView(
        content: Content(
            title: "Morning Meditation",
            subtitle: "Start your day with peace",
            youtubeVideoID: "dQw4w9WgXcQ",
            contentType: .meditation,
            durationSeconds: 600,
            narrator: "Guide Name",
            tags: ["Reduce Anxiety", "Morning"],
            isPremium: false,
            description: "A gentle morning meditation to help you start your day with clarity and calm."
        )
    )
}
