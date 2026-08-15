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
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query private var favorites: [FavoriteContent]
    @StateObject private var playerManager = AudioPlayerManager.shared
    /// Fast time updates live on the clock; observing it here keeps the
    /// scrubber/time labels live while sparing views that don't show time.
    @ObservedObject private var clock = AudioPlayerManager.shared.clock
    /// Sleep-timer countdown ("Sleep in 12:34" label).
    @ObservedObject private var sleepTimerClock = AudioPlayerManager.shared.sleepTimerClock
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var appStateManager = AppStateManager.shared
    @State private var showSleepTimer = false
    @State private var showAddToPlaylist = false
    @State private var showSpeedSelector = false
    @State private var showSoundscapeMixer = false
    @State private var isVideoMode = true
    @State private var hasRecordedSession = false
    @State private var showPaywall = false
    @State private var hasCheckedSubscription = false
    @State private var showPostSessionReflection = false
    @State private var showBiometricSummary = false
    @State private var biometricData: BiometricSessionData?
    @State private var isPreviewMode = false
    @State private var previewTimer: Task<Void, Never>?
    @State private var showUpNextQueue = false

    // Session-complete moment (natural end of playback)
    @State private var showSessionComplete = false
    @State private var completedMinutes = 1

    // Breathe-with-me overlay
    @State private var showBreathGuide = false

    // Ambient mixer state for the Sounds chip
    @ObservedObject private var ambientManager = AmbientSoundManager.shared

    // Player display preferences
    @AppStorage("playerShowsRemainingTime") private var showsRemainingTime = false
    @AppStorage("playerSkipInterval") private var skipInterval = 15

    // Scrubbing state — seek is committed on release, not on every drag tick
    @State private var scrubTime: TimeInterval?

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

    // iPad detection
    private var isRegular: Bool { sizeClass == .regular }

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

                // Artwork-derived ambient backdrop. The player is where a user
                // spends the whole session, and it previously read as a small
                // thumbnail floating in empty space. Bleeding a heavily blurred
                // copy of the artwork to the edges makes the screen feel like
                // the session rather than a control panel.
                ambientArtworkBackdrop
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

                        // Slack used to collect in a single Spacer here, leaving a
                        // conspicuous void between the actions and the transport.
                        // Splitting it centres the content block instead, so tall
                        // screens breathe evenly rather than sagging in the middle.
                        Spacer(minLength: 12)

                        // Bottom controls (progress + play/pause)
                        bottomControlsSection
                            .padding(.horizontal, 24)

                        Spacer(minLength: 8)

                        // Chip row: ambient sounds + up-next queue
                        HStack(spacing: 10) {
                            // Ambient sounds chip — surfaces the buried mixer
                            Button {
                                impactLight.impactOccurred()
                                showSoundscapeMixer = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "waveform")
                                        .font(isRegular ? .caption : .caption2)
                                    Text(ambientManager.activeSounds.isEmpty
                                         ? "Sounds"
                                         : (ambientManager.activeSounds.count == 1
                                            ? "1 sound"
                                            : "\(ambientManager.activeSounds.count) sounds"))
                                }
                                .font(isRegular ? .subheadline : .caption)
                                .foregroundStyle(ambientManager.activeSounds.isEmpty
                                                 ? .white.opacity(0.55)
                                                 : theme.accentColor)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(ambientManager.activeSounds.isEmpty
                                            ? Color.white.opacity(0.08)
                                            : theme.accentColor.opacity(0.15))
                                .clipShape(Capsule())
                            }
                            .accessibilityLabel(ambientManager.activeSounds.isEmpty
                                                ? "Ambient sounds"
                                                : "\(ambientManager.activeSounds.count) ambient sounds playing")
                            .accessibilityHint("Opens the soundscape mixer")

                            // Up Next indicator — opens the browsable queue
                            if playerManager.queue.count > 1 {
                                Button {
                                    impactLight.impactOccurred()
                                    showUpNextQueue = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "list.bullet")
                                            .font(isRegular ? .caption : .caption2)
                                        if let nextTitle = playerManager.nextTrackTitle {
                                            Text("Up next: \(nextTitle)")
                                                .lineLimit(1)
                                        } else {
                                            Text("Queue")
                                        }
                                        Image(systemName: "chevron.up")
                                            .font(isRegular ? .caption : .caption2)
                                    }
                                    .font(isRegular ? .subheadline : .caption)
                                    .foregroundStyle(.white.opacity(0.55))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Capsule())
                                }
                                .accessibilityLabel("Up next queue")
                                .accessibilityHint("Shows the list of upcoming sessions")
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 27)

                        Spacer().frame(height: 50)
                    }
                    .frame(maxWidth: isRegular ? 720 : .infinity)
                }
                // Toast overlay for fullScreenCover context
                ToastOverlay()

                // Badge celebration overlay
                BadgeCelebrationOverlay(badgeService: BadgeService.shared)

                // Challenge celebration overlay
                ChallengeCelebrationOverlay(challengeService: ChallengeService.shared)

                // Breathe-with-me overlay (audio keeps playing underneath)
                if showBreathGuide {
                    BreathGuideOverlay(accentColor: theme.accentColor) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showBreathGuide = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(10)
                }
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
        .sheet(isPresented: $showSoundscapeMixer) {
            SoundscapeMixerView()
        }
        .sheet(isPresented: $showUpNextQueue) {
            UpNextQueueView()
        }
        .sheet(isPresented: $showSessionComplete) {
            SessionCompletionView(content: displayedContent, minutesListened: completedMinutes)
        }
        .sheet(isPresented: $showSpeedSelector) {
            SpeedSelectorView(
                currentSpeed: playerManager.playbackRate,
                onSelect: { speed in
                    playerManager.setPlaybackRate(speed)
                }
            )
        }
        .sheet(isPresented: $showPostSessionReflection, onDismiss: {
            // Show biometric summary after reflection is dismissed, if data is available
            if biometricData != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showBiometricSummary = true
                }
            }
        }) {
            PostSessionReflectionView(content: displayedContent)
        }
        .sheet(isPresented: $showBiometricSummary) {
            if let data = biometricData {
                BiometricSummaryCard(biometricData: data)
            }
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

            // Natural end of playback → record + show the completion moment
            playerManager.onPlaybackFinishedNaturally = { _ in
                // Fold the live segment in NOW: isPlaying already flipped to
                // false, so the onChange fold hasn't run and record would
                // otherwise miss the whole uninterrupted listen.
                if let start = sessionStartTime {
                    accumulatedListenTime += Date().timeIntervalSince(start)
                    sessionStartTime = nil
                }
                let listened = accumulatedListenTime
                completedMinutes = max(1, Int(listened / 60))
                recordSessionIfEligible(showReflection: false)

                // Only celebrate when a session was genuinely recorded, and
                // give any open sheet (mixer, queue, timer) time to dismiss —
                // a second presentation would silently fail.
                guard listened >= Constants.Session.minimumListenTimeForRecord else { return }
                showSoundscapeMixer = false
                showUpNextQueue = false
                showSleepTimer = false
                showSpeedSelector = false
                showAddToPlaylist = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                    showSessionComplete = true
                }
            }

            // Set up callback for auto-advance session recording
            playerManager.onTrackCompleted = { [weak modelContext] completedContent, completedDuration in
                guard let modelContext = modelContext else { return }
                // Mark recorded so recordSessionIfEligible() won't duplicate on dismiss
                hasRecordedSession = true
                // Record session for the track that just finished
                let actualDuration = Int(min(completedDuration, Double(completedContent.durationSeconds > 0 ? completedContent.durationSeconds : Int(completedDuration))))
                guard actualDuration >= Int(Constants.Session.minimumListenTimeForRecord) else { return }
                let isCompleted = completedContent.durationSeconds > 0 && Double(actualDuration) >= Double(completedContent.durationSeconds) * Constants.Session.completionThreshold
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
                // Streak credit for auto-advance completions too (context: nil —
                // the session was already inserted above).
                StreakService.shared.recordSession(durationMinutes: max(1, actualDuration / 60), context: nil)
            }
        }
        .onDisappear {
            previewTimer?.cancel()
            controlsHideTask?.cancel()
            AppDelegate.allowLandscape = false
            // Force back to portrait when leaving player (iPhone only — iPad supports all orientations)
            if UIDevice.current.userInterfaceIdiom != .pad,
               let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            }
            // Record session when player closes (if user listened enough)
            recordSessionIfEligible()
            // Clear the callbacks
            playerManager.onTrackCompleted = nil
            playerManager.onPlaybackFinishedNaturally = nil
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
                // Free user tapped premium content — allow 2-minute preview
                isPreviewMode = true
                loadContent()
                startPreviewTimer()
            } else {
                // Non-premium content is free for all users
                loadContent()
            }
        }
    }

    // MARK: - Navigation Bar
    private var navigationBar: some View {
        let btnSize: CGFloat = isRegular ? 44 : 36

        return HStack {
            // Minimize button
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: isRegular ? 18 : 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: btnSize, height: btnSize)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Minimize player")

            Spacer()

            // AirPlay route picker
            AirPlayButton()
                .frame(width: btnSize, height: btnSize)
                .background(Color.white.opacity(0.1))
                .clipShape(Circle())
                .accessibilityLabel("AirPlay")
                .accessibilityHint("Choose a speaker or TV")

            // More menu (Speed, Sounds, Share)
            Menu {
                Button {
                    showSpeedSelector = true
                } label: {
                    Label(playerManager.playbackRate != 1.0 ? String(format: "Speed (%.1fx)", playerManager.playbackRate) : "Playback Speed", systemImage: "gauge.with.dots.needle.33percent")
                }
                Button {
                    showSoundscapeMixer = true
                } label: {
                    Label("Ambient Sounds", systemImage: "waveform")
                }
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showBreathGuide = true
                    }
                } label: {
                    Label("Breathe With Me", systemImage: "circle.circle")
                }
                Button {
                    shareContent()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: isRegular ? 18 : 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: btnSize, height: btnSize)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .accessibilityLabel("More options")
        }
        .padding(.horizontal, isRegular ? 24 : 16)
        .padding(.top, 12)
    }

    // MARK: - Ambient Artwork Backdrop
    /// A blurred, dimmed copy of the session artwork bled to the screen edges.
    /// Sits under the theme gradient so themed colour still reads, but the
    /// screen takes on the mood of whatever is playing.
    private var ambientArtworkBackdrop: some View {
        CachedAsyncImage(
            url: URL(string: content.thumbnailURLComputed),
            failedIconName: content.contentType.iconName,
            content: { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 60, opaque: true)
                    .overlay(theme.gradient.opacity(0.72))
                    .overlay(
                        // Darken top and bottom so the nav bar and transport
                        // controls keep contrast against bright artwork.
                        LinearGradient(
                            colors: [.black.opacity(0.45), .clear, .black.opacity(0.55)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            },
            placeholder: { Color.clear }
        )
        .allowsHitTesting(false)
        // Decorative only — VoiceOver should never announce it.
        .accessibilityHidden(true)
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
                // Artwork is the focal point of an audio session — 280pt left it
                // looking incidental on a 6.7" screen.
                .frame(maxWidth: isRegular ? 500 : 330)
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
                            // Progress bar — same preview-then-commit scrubbing
                            // as the portrait bar (seek only on release).
                            HStack(spacing: 12) {
                                Text(formatTime(scrubTime ?? playerManager.currentTime))
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .monospacedDigit()

                                GeometryReader { geo in
                                    let displayTime = scrubTime ?? playerManager.currentTime
                                    let progress = playerManager.duration > 0
                                        ? max(0, min(1, displayTime / playerManager.duration))
                                        : 0

                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.white.opacity(0.3))
                                            .frame(height: 4)

                                        Capsule()
                                            .fill(Color.white)
                                            .frame(width: max(0, geo.size.width * progress), height: 4)
                                    }
                                    .contentShape(Rectangle())
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                if scrubTime == nil {
                                                    impactLight.impactOccurred()
                                                }
                                                let p = max(0, min(1, value.location.x / geo.size.width))
                                                scrubTime = p * playerManager.duration
                                                scheduleControlsHide()
                                            }
                                            .onEnded { value in
                                                let p = max(0, min(1, value.location.x / geo.size.width))
                                                playerManager.seek(to: p * playerManager.duration)
                                                impactLight.impactOccurred()
                                                scrubTime = nil
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
                                    playerManager.skipBackward(seconds: TimeInterval(skipInterval))
                                    scheduleControlsHide()
                                } label: {
                                    Image(systemName: "gobackward.\(skipInterval)")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                }
                                .contextMenu { skipIntervalMenu }
                                .accessibilityLabel("Skip back \(skipInterval) seconds")

                                Button {
                                    playerManager.togglePlayPause()
                                    scheduleControlsHide()
                                } label: {
                                    Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.largeTitle)
                                        .foregroundStyle(.white)
                                }

                                Button {
                                    playerManager.skipForward(seconds: TimeInterval(skipInterval))
                                    scheduleControlsHide()
                                } label: {
                                    Image(systemName: "goforward.\(skipInterval)")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                }
                                .contextMenu { skipIntervalMenu }
                                .accessibilityLabel("Skip forward \(skipInterval) seconds")
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
        VStack(spacing: isRegular ? 10 : 6) {
            // Title
            Text(displayedContent.title)
                .font(isRegular ? .title : .title2)
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

                let durationText = playerManager.duration > 0 ? formatDuration(playerManager.duration) : displayedContent.durationFormatted
                if !durationText.isEmpty {
                    if displayedContent.narrator != nil {
                        Text("·")
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    Text(durationText)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .font(isRegular ? .body : .subheadline)

        }
    }

    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 8) {
            // Sleep timer status (visible when active)
            if let remaining = playerManager.sleepTimerRemaining {
                Text("Sleep in \(formatTime(remaining))")
                    .font(.caption)
                    .foregroundStyle(theme.accentColor)
                    .transition(.opacity)
            } else if let mode = playerManager.sleepStopMode {
                Text("Stopping at: \(mode.label)")
                    .font(.caption)
                    .foregroundStyle(theme.accentColor)
                    .transition(.opacity)
            }

            HStack(spacing: isRegular ? 36 : 24) {
                // Favorite
                actionButton(icon: isFavorite ? "heart.fill" : "heart",
                             label: "Favorite",
                             active: isFavorite) {
                    impactMedium.impactOccurred()
                    toggleFavorite()
                }
                .animation(.spring(response: 0.3), value: isFavorite)
                .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")

                // Playlist
                actionButton(icon: "text.badge.plus",
                             label: "Playlist",
                             active: false) {
                    impactLight.impactOccurred()
                    showAddToPlaylist = true
                }
                .accessibilityLabel("Add to playlist")

                // Sleep Timer — label becomes the live countdown when running
                actionButton(icon: "timer",
                             label: playerManager.sleepTimerRemaining.map { formatTime($0) }
                                ?? (playerManager.sleepStopMode != nil ? String(localized: "On") : String(localized: "Timer")),
                             active: playerManager.sleepTimerActive) {
                    impactLight.impactOccurred()
                    showSleepTimer = true
                }
                .accessibilityLabel("Sleep timer")
                .accessibilityValue(playerManager.sleepTimerActive ? "On" : "Off")

                // Repeat
                actionButton(icon: playerManager.repeatMode.icon,
                             label: "Repeat",
                             active: playerManager.repeatMode != .off) {
                    selectionFeedback.selectionChanged()
                    withAnimation(.spring(response: 0.3)) {
                        playerManager.repeatMode = playerManager.repeatMode.next
                    }
                }
                .accessibilityLabel("Repeat mode")
            }
        }
        .padding(.horizontal, 24)
    }

    /// Long-press menu for choosing the skip interval (shared by both buttons).
    @ViewBuilder
    private var skipIntervalMenu: some View {
        ForEach([15, 30, 60], id: \.self) { seconds in
            Button {
                HapticManager.selection()
                skipInterval = seconds
            } label: {
                if skipInterval == seconds {
                    Label("\(seconds) seconds", systemImage: "checkmark")
                } else {
                    Text("\(seconds) seconds")
                }
            }
        }
    }

    private func actionButton(icon: String, label: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: isRegular ? 6 : 4) {
                Image(systemName: icon)
                    .font(isRegular ? .title3.weight(.semibold) : .body.weight(.semibold))
                    .foregroundStyle(active ? theme.accentColor : .white.opacity(0.8))
                    .frame(width: isRegular ? 56 : 40, height: isRegular ? 56 : 40)
                    .background(active ? theme.accentColor.opacity(0.15) : Color.white.opacity(0.1))
                    .clipShape(Circle())

                Text(label)
                    .font(.system(size: isRegular ? 13 : 10))
                    .foregroundStyle(active ? theme.accentColor : .white.opacity(0.5))
            }
        }
    }

    // MARK: - Bottom Controls Section (Progress + Play/Pause)
    private var bottomControlsSection: some View {
        VStack(spacing: 26) {
            // Progress bar - Custom styled to match reference
            VStack(spacing: 8) {
                // Custom progress bar with draggable thumb.
                // Dragging previews the target position; the seek commits on release.
                GeometryReader { geometry in
                    let trackWidth = geometry.size.width - 16 // inset for thumb radius
                    let displayTime = scrubTime ?? playerManager.currentTime
                    let progress = playerManager.duration > 0
                        ? max(0, min(1, displayTime / playerManager.duration))
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

                        // Thumb/knob — grows slightly while scrubbing
                        Circle()
                            .fill(.white)
                            .frame(width: scrubTime != nil ? 20 : 16, height: scrubTime != nil ? 20 : 16)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            .position(x: thumbX, y: 8)
                            .animation(.spring(response: 0.25), value: scrubTime != nil)

                        // Scrub preview time bubble
                        if scrubTime != nil {
                            Text(formatTime(displayTime))
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Capsule())
                                .position(x: min(max(thumbX, 34), geometry.size.width - 34), y: -22)
                                .transition(.opacity)
                        }
                    }
                    // Inset by a negative amount to grow the touch target well
                    // beyond the 16pt visual track (~44pt effective height).
                    .contentShape(Rectangle().inset(by: -14))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if scrubTime == nil {
                                    impactLight.impactOccurred()
                                }
                                let p = max(0, min(1, (value.location.x - 8) / trackWidth))
                                scrubTime = p * playerManager.duration
                            }
                            .onEnded { value in
                                let p = max(0, min(1, (value.location.x - 8) / trackWidth))
                                playerManager.seek(to: p * playerManager.duration)
                                impactLight.impactOccurred()
                                scrubTime = nil
                            }
                    )
                }
                .frame(height: 16)
                .accessibilityElement()
                .accessibilityLabel("Playback position")
                .accessibilityValue("\(formatTime(playerManager.currentTime)) of \(formatTime(playerManager.duration))")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: playerManager.skipForward(seconds: 15)
                    case .decrement: playerManager.skipBackward(seconds: 15)
                    @unknown default: break
                    }
                }

                // Time labels — tap the right label to flip total ⇄ remaining
                HStack {
                    Text(formatTime(scrubTime ?? playerManager.currentTime))
                        .font(isRegular ? .body : .subheadline)
                        .foregroundStyle(scrubTime != nil ? .white : .white.opacity(0.6))
                        .monospacedDigit()

                    Spacer()

                    Button {
                        HapticManager.light()
                        showsRemainingTime.toggle()
                    } label: {
                        Text(showsRemainingTime
                             ? "-\(formatTime(max(0, playerManager.duration - (scrubTime ?? playerManager.currentTime))))"
                             : formatTime(playerManager.duration))
                            .font(isRegular ? .body : .subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                            .monospacedDigit()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showsRemainingTime ? "Time remaining" : "Total duration")
                    .accessibilityHint("Switches between total duration and time remaining")
                }
            }

            // Playback controls with skip and next/prev buttons
            HStack(spacing: isRegular ? 36 : 24) {
                // Previous track
                Button {
                    impactLight.impactOccurred()
                    playerManager.playPrevious()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(isRegular ? .title : .title2)
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: isRegular ? 56 : 44, height: isRegular ? 56 : 44)
                }
                .accessibilityLabel("Previous track")

                // Skip backward (long-press to change the interval)
                Button {
                    impactLight.impactOccurred()
                    playerManager.skipBackward(seconds: TimeInterval(skipInterval))
                } label: {
                    Image(systemName: "gobackward.\(skipInterval)")
                        .font(isRegular ? .largeTitle : .title)
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: isRegular ? 64 : 50, height: isRegular ? 64 : 50)
                }
                .contextMenu { skipIntervalMenu }
                .accessibilityLabel("Skip back \(skipInterval) seconds")

                // Play/Pause button
                Button {
                    impactMedium.impactOccurred()
                    playerManager.togglePlayPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: isRegular ? 92 : 72, height: isRegular ? 92 : 72)

                        if playerManager.isLoading {
                            VStack(spacing: 2) {
                                ProgressView()
                                    .tint(.black)
                                Text("Loading")
                                    .font(.system(size: isRegular ? 10 : 8, weight: .medium))
                                    .foregroundStyle(.black.opacity(0.6))
                            }
                        } else if playerManager.isBuffering {
                            VStack(spacing: 2) {
                                ProgressView()
                                    .tint(.black)
                                Text("Buffering")
                                    .font(.system(size: isRegular ? 10 : 8, weight: .medium))
                                    .foregroundStyle(.black.opacity(0.6))
                            }
                        } else {
                            Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(isRegular ? .largeTitle : .title)
                                .foregroundStyle(.black)
                                .offset(x: playerManager.isPlaying ? 0 : 2)
                        }
                    }
                }
                .accessibilityLabel(playerManager.isPlaying ? "Pause" : "Play")

                // Skip forward (long-press to change the interval)
                Button {
                    impactLight.impactOccurred()
                    playerManager.skipForward(seconds: TimeInterval(skipInterval))
                } label: {
                    Image(systemName: "goforward.\(skipInterval)")
                        .font(isRegular ? .largeTitle : .title)
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: isRegular ? 64 : 50, height: isRegular ? 64 : 50)
                }
                .contextMenu { skipIntervalMenu }
                .accessibilityLabel("Skip forward \(skipInterval) seconds")

                // Next track
                Button {
                    impactLight.impactOccurred()
                    playerManager.playNext()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(isRegular ? .title : .title2)
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: isRegular ? 56 : 44, height: isRegular ? 56 : 44)
                }
                .accessibilityLabel("Next track")
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
        playerManager.error = nil
        playerManager.contentUnavailable = false
        Task {
            // Clear stale stream cache for this video so we get a fresh extraction
            await MediaStreamService.shared.evictCacheEntry(for: retryContent.youtubeVideoID)
            await VideoCache.shared.evictCacheEntry(for: retryContent.youtubeVideoID)
            await playerManager.loadContent(retryContent, videoMode: isVideoMode)
            playerManager.play()
        }
    }

    // MARK: - Helper Methods
    private func loadContent() {
        // Skip if same content is already loaded and ready, or currently loading
        if playerManager.loadedVideoID == content.youtubeVideoID {
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
    private func recordSessionIfEligible(showReflection: Bool = true) {
        guard !hasRecordedSession else { return }

        // Calculate total listen time including current playing session.
        // sessionStartTime is nilled whenever a segment is folded in, so
        // counting it here whenever present never double-counts — and NOT
        // requiring isPlaying avoids missing the segment in the window where
        // playback just stopped but the onChange fold hasn't run yet.
        var totalListenTime = accumulatedListenTime
        if let startTime = sessionStartTime {
            totalListenTime += Date().timeIntervalSince(startTime)
        }

        // Only record if user listened for at least the minimum time
        guard totalListenTime >= Constants.Session.minimumListenTimeForRecord else { return }

        hasRecordedSession = true

        let currentlyDisplayed = displayedContent

        // Record the actual time listened, not content duration
        let actualListenedSeconds = Int(min(totalListenTime, Double(currentlyDisplayed.durationSeconds > 0 ? currentlyDisplayed.durationSeconds : Int(totalListenTime))))
        let isCompleted = currentlyDisplayed.durationSeconds > 0 && Double(actualListenedSeconds) >= Double(currentlyDisplayed.durationSeconds) * Constants.Session.completionThreshold

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

            // Keep the streak alive from guided sessions too — this was only
            // ever called by the timers/breathing/body-scan flows, so the
            // app's core loop never grew the streak. context: nil because the
            // MeditationSession was already inserted above.
            StreakService.shared.recordSession(durationMinutes: max(1, actualListenedSeconds / 60), context: nil)

            // Trigger review prompt after completed sessions
            if isCompleted {
                appStateManager.onSessionCompleted()
                // Show post-session reflection (suppressed when the caller is
                // about to present the richer SessionCompletionView instead)
                if showReflection {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showPostSessionReflection = true
                    }
                }
            }

            // Record session time for badge tracking (morning/night/weekend)
            BadgeService.shared.recordSessionTime()

            // Check for newly earned badges
            BadgeService.shared.checkBadges(
                context: modelContext,
                streakService: StreakService.shared,
                currentContentType: currentlyDisplayed.contentType
            )

            // Update challenge progress
            ChallengeService.shared.recordSession(
                contentType: currentlyDisplayed.contentType,
                durationMinutes: actualListenedSeconds / 60,
                context: modelContext,
                streakService: StreakService.shared
            )

            // Write to Apple Health if enabled
            if HealthKitService.shared.isEnabled {
                let end = Date()
                let start = end.addingTimeInterval(-Double(actualListenedSeconds))
                Task {
                    await HealthKitService.shared.writeMindfulMinutes(start: start, end: end)
                }

                // For sleep content, capture biometric data
                let sleepTypes: Set<String> = ["Sleep Story", "Soundscape", "Music", "ASMR"]
                if sleepTypes.contains(currentlyDisplayed.contentType.rawValue) {
                    let sessionCompleted = isCompleted
                    Task {
                        let hrData = await HealthKitService.shared.getHeartRateDuringSession(
                            start: start, end: end
                        )
                        if hrData.startHR != nil || hrData.endHR != nil || hrData.avgHR != nil {
                            let bioData = BiometricSessionData(
                                sessionID: session.id,
                                startHeartRate: hrData.startHR,
                                endHeartRate: hrData.endHR,
                                avgHeartRate: hrData.avgHR
                            )
                            modelContext.insert(bioData)
                            try? modelContext.save()
                            biometricData = bioData
                            // Only show directly if no other end-of-session sheet
                            // is up (reflection chains it from its onDismiss; a
                            // second presentation would silently fail).
                            if !sessionCompleted {
                                try? await Task.sleep(nanoseconds: 1_500_000_000)
                                if !showSessionComplete {
                                    showBiometricSummary = true
                                }
                            }
                        }
                    }
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
            try? await Task.sleep(nanoseconds: 120_000_000_000) // 2 minutes
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

    @State private var selectedSpeed: Float
    @State private var appeared = false

    init(currentSpeed: Float, onSelect: @escaping (Float) -> Void) {
        self.currentSpeed = currentSpeed
        self.onSelect = onSelect
        self._selectedSpeed = State(initialValue: currentSpeed)
    }

    private func speedLabel(_ speed: Float) -> String {
        if speed == 1.0 { return "1x" }
        if speed == floor(speed) { return "\(Int(speed))x" }
        return String(format: "%.1fx", speed).replacingOccurrences(of: ".0x", with: "x")
    }

    private func speedDescription(_ speed: Float) -> String {
        switch speed {
        case 0.5: return "Slow"
        case 0.75: return "Relaxed"
        case 1.0: return "Normal"
        case 1.25: return "Slightly faster"
        case 1.5: return "Fast"
        case 1.75: return "Faster"
        case 2.0: return "Double"
        default: return ""
        }
    }

    var body: some View {
        ZStack {
            // Dark background
            Color.black.opacity(0.95).ignoresSafeArea()

            VStack(spacing: 28) {
                // Handle
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)

                // Title
                Text("Playback Speed")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                // Current speed display
                Text(speedLabel(selectedSpeed))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: selectedSpeed)

                Text(speedDescription(selectedSpeed))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: selectedSpeed)

                // Speed buttons grid
                HStack(spacing: 10) {
                    ForEach(speeds, id: \.self) { speed in
                        let isSelected = speed == selectedSpeed

                        Button {
                            HapticManager.selection()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedSpeed = speed
                            }
                            onSelect(speed)
                        } label: {
                            VStack(spacing: 6) {
                                Text(speedLabel(speed))
                                    .font(.system(size: 15, weight: isSelected ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(isSelected ? .black : .white.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isSelected ? Color.white : Color.white.opacity(0.08))
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Reset button (only if not 1x)
                if selectedSpeed != 1.0 {
                    Button {
                        HapticManager.light()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedSpeed = 1.0
                        }
                        onSelect(1.0)
                    } label: {
                        Text("Reset to Normal")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .transition(.opacity)
                }

                Spacer()
            }
        }
        .presentationDetents([.fraction(0.45)])
        .presentationBackground(.clear)
        .presentationDragIndicator(.hidden)
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
                context: .premiumSession,
                sessionLimitMessage: "This is a premium meditation. Subscribe to unlock the full library.",
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
            .padding(.top, 8)
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
                            // Trigger rating prompt on positive mood
                            if let mood = selectedMood,
                               ["Calm", "Happy", "Focused", "Grateful"].contains(mood) {
                                SmartRatingManager.shared.checkAndPromptIfAppropriate(trigger: .sessionCompletedWithPositiveMood)
                            }
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
                            .accessibilityLabel("Close")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
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

// MARK: - Biometric Summary Card

struct BiometricSummaryCard: View {
    let biometricData: BiometricSessionData
    @Environment(\.dismiss) var dismiss

    private var changeColor: Color {
        guard let change = biometricData.heartRateChange else { return .white }
        return change < 0 ? .green : (change > 0 ? .orange : .white)
    }

    private var relaxationMessage: String? {
        guard let change = biometricData.heartRateChange, change < -5 else { return nil }
        return "Great relaxation!"
    }

    var body: some View {
        ZStack {
            Theme.sleepBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.sleepPrimary)

                Text("Session Biometrics")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                HStack(spacing: 20) {
                    if let startHR = biometricData.startHeartRate {
                        VStack(spacing: 4) {
                            Text("\(startHR)")
                                .font(.title.bold())
                                .foregroundStyle(.white)
                            Text("Start HR")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                    }

                    if let avgHR = biometricData.avgHeartRate {
                        VStack(spacing: 4) {
                            Text("\(avgHR)")
                                .font(.title.bold())
                                .foregroundStyle(.white)
                            Text("Avg HR")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                    }

                    if let endHR = biometricData.endHeartRate {
                        VStack(spacing: 4) {
                            Text("\(endHR)")
                                .font(.title.bold())
                                .foregroundStyle(.white)
                            Text("End HR")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 24)

                // Change indicator
                VStack(spacing: 6) {
                    Text(biometricData.formattedChange)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(changeColor)

                    if let message = relaxationMessage {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(Color(red: 0.04, green: 0.06, blue: 0.14))
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
