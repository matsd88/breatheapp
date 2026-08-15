//
//  AudioPlayerManager.swift
//  Meditation Sleep Mindset
//

import Foundation
import AVFoundation
import MediaPlayer
import Combine
import ActivityKit

/// Fast-changing playback time state, split out of AudioPlayerManager so its
/// 2 Hz updates don't invalidate every observer of the manager. All writes
/// happen on the main thread (same as the previous @Published behavior).
@MainActor
final class PlaybackClock: ObservableObject {
    @Published var currentTime: TimeInterval = 0
}

/// Sleep-timer countdown state, separate from PlaybackClock so views that
/// only show the countdown (Sleep tab tile, timer sheet) tick at most 1 Hz
/// while a timer is active — and never re-render from 2 Hz playback time.
@MainActor
final class SleepTimerClock: ObservableObject {
    @Published var remaining: TimeInterval?
}

@MainActor
class AudioPlayerManager: ObservableObject {
    static let shared = AudioPlayerManager()

    // MARK: - Repeat Mode
    enum RepeatMode: String, CaseIterable {
        case off, one, all

        var icon: String {
            switch self {
            case .off: return "repeat"
            case .one: return "repeat.1"
            case .all: return "repeat"
            }
        }

        var next: RepeatMode {
            switch self {
            case .off: return .one
            case .one: return .all
            case .all: return .off
            }
        }
    }

    // MARK: - Published Properties
    @Published var repeatMode: RepeatMode = .off
    @Published var isPlaying = false
    @Published var duration: TimeInterval = 0
    @Published var isLoading = false
    @Published var isBuffering = false
    @Published var error: String?
    @Published var contentUnavailable = false
    @Published var playbackRate: Float = 1.0

    // MARK: - Fast-changing time state (isolated)
    /// 2 Hz `currentTime` and the 1 Hz sleep-timer countdown live on
    /// separate ObservableObjects so they only re-render the few views that
    /// actually display them (player scrubber, mini-player progress, timer
    /// labels) — not every view observing AudioPlayerManager (tab shell,
    /// SleepView, …). Views showing live time must observe `clock` /
    /// `sleepTimerClock`.
    let clock = PlaybackClock()
    let sleepTimerClock = SleepTimerClock()

    var currentTime: TimeInterval {
        get { clock.currentTime }
        set { clock.currentTime = newValue }
    }

    var sleepTimerRemaining: TimeInterval? {
        get { sleepTimerClock.remaining }
        set { sleepTimerClock.remaining = newValue }
    }
    /// Set to true to request the full-screen player be presented (observed by MainTabView)
    @Published var shouldPresentPlayer = false

    // MARK: - Current Content
    @Published var currentContent: Content?
    @Published var isVideoMode = false

    // MARK: - Queue Properties
    @Published var queue: [Content] = []
    @Published var currentIndex: Int = 0

    var hasNextTrack: Bool {
        currentIndex < queue.count - 1
    }

    var hasPreviousTrack: Bool {
        currentIndex > 0
    }

    var nextTrackTitle: String? {
        guard hasNextTrack else { return nil }
        return queue[safe: currentIndex + 1]?.title
    }

    /// Callback for views to record session when a track auto-advances
    var onTrackCompleted: ((Content, TimeInterval) -> Void)?

    /// Fired when playback comes to a natural stop with the player idle —
    /// track ended with no auto-advance, or a sleep stop mode kicked in.
    /// MeditationPlayerView uses it to show the session-complete moment.
    var onPlaybackFinishedNaturally: ((Content) -> Void)?

    // MARK: - Sleep Stop Modes
    /// Alternative sleep-timer behavior: stop at the end of the current track
    /// or at the end of the queue instead of after a fixed duration.
    /// Mutually exclusive with the countdown timer.
    enum SleepStopMode: String {
        case endOfTrack
        case endOfQueue

        var label: String {
            switch self {
            case .endOfTrack: return String(localized: "End of session")
            case .endOfQueue: return String(localized: "End of queue")
            }
        }
    }

    @Published var sleepStopMode: SleepStopMode?

    /// Whether any form of sleep timer is active (countdown or stop mode).
    var sleepTimerActive: Bool {
        sleepTimerRemaining != nil || sleepStopMode != nil
    }

    func setSleepStopMode(_ mode: SleepStopMode?) {
        // The countdown and the stop modes are mutually exclusive.
        if mode != nil {
            sleepTimer?.invalidate()
            sleepTimer = nil
            sleepTimerRemaining = nil
            player?.volume = 1.0
        }
        sleepStopMode = mode
    }

    // MARK: - Player Properties
    @Published private(set) var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var endOfPlaybackObserver: NSObjectProtocol?
    private var sleepTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var cachedArtwork: MPMediaItemArtwork?
    private var cachedArtworkVideoID: String?
    /// Last time (in seconds, truncated) we pushed to MPNowPlayingInfoCenter — throttle to 1 update/sec
    private var lastNowPlayingSecond: Int = -1
    /// Pre-built AVPlayerItem for the next track in queue (instant advance)
    private var prefetchedPlayerItem: AVPlayerItem?
    private var prefetchedVideoID: String?
    /// Which mode the prefetched item was actually built in. Without this, an
    /// item prefetched audio-only could be handed to a video-mode load and
    /// leave isVideoMode claiming video over an audio-only asset.
    private var prefetchedAudioOnly: Bool?
    /// Track retry attempts for the current content to prevent infinite loops
    private var currentRetryCount = 0
    private static let maxAutoRetries = 2
    /// Track whether we're currently auto-retrying (prevent re-entrant retries)
    private var isAutoRetrying = false
    /// Debounce rapid next/previous taps
    private var isSkipping = false
    /// Buffer stall recovery: fires when buffer is empty for too long
    private var bufferStallTimer: Timer?
    private static let bufferStallTimeout: TimeInterval = 30
    /// Crossfade: old player that's fading out
    private var crossfadePlayer: AVPlayer?
    private var crossfadeTimer: Timer?
    private var fadeInTimer: Timer?

    /// Tracks which video ID is actually loaded into the AVPlayer (vs. currentContent which can be set early)
    private(set) var loadedVideoID: String?

    private init() {
        setupAudioSession()
        setupRemoteCommandCenter()
        setupInterruptionHandling()

        // Register default for auto-play (on by default)
        UserDefaults.standard.register(defaults: [
            Constants.UserDefaultsKeys.autoPlayNextContent: true
        ])

        // Restore the user's preferred playback speed (0 means never set).
        let savedRate = UserDefaults.standard.double(forKey: Constants.UserDefaultsKeys.preferredPlaybackSpeed)
        if savedRate > 0 {
            playbackRate = Float(savedRate)
        }
    }

    // MARK: - Audio Session Setup
    nonisolated private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.allowAirPlay, .duckOthers])
            try session.setActive(true, options: [])
        } catch {
            #if DEBUG
            print("Failed to set up audio session: \(error)")
            #endif
        }
    }

    /// Re-activate audio session (call after interruptions end)
    nonisolated private func reactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
            #if DEBUG
            print("[AudioPlayerManager] Failed to reactivate audio session: \(error)")
            #endif
        }
    }

    // MARK: - Remote Command Center (Lock Screen Controls)
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.play()
            }
            return .success
        }

        // Pause
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.pause()
            }
            return .success
        }

        // Toggle Play/Pause
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.togglePlayPause()
            }
            return .success
        }

        // Skip Forward 15 seconds
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            if let skipEvent = event as? MPSkipIntervalCommandEvent {
                Task { @MainActor in
                    self?.skipForward(seconds: skipEvent.interval)
                }
            }
            return .success
        }

        // Skip Backward 15 seconds
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            if let skipEvent = event as? MPSkipIntervalCommandEvent {
                Task { @MainActor in
                    self?.skipBackward(seconds: skipEvent.interval)
                }
            }
            return .success
        }

        // Seek
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let positionEvent = event as? MPChangePlaybackPositionCommandEvent {
                Task { @MainActor in
                    self?.seek(to: positionEvent.positionTime)
                }
            }
            return .success
        }

        // Next Track
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.playNext()
            }
            return .success
        }

        // Previous Track
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.playPrevious()
            }
            return .success
        }
    }

    /// Update lock screen next/previous button state based on queue position
    private func updateRemoteCommandState() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.nextTrackCommand.isEnabled = hasNextTrack
        commandCenter.previousTrackCommand.isEnabled = true // Always enabled (restart or go back)
    }

    // MARK: - Interruption Handling
    nonisolated private func setupInterruptionHandling() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleInterruption(notification)
            }
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleRouteChange(notification)
            }
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            pause()
        case .ended:
            reactivateAudioSession()
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                play()
            }
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        // Pause when headphones are unplugged
        if reason == .oldDeviceUnavailable {
            pause()
        }
    }

    // MARK: - Queue Management

    /// Load a queue and start playing from a specific index
    func loadQueue(_ items: [Content], startIndex: Int) {
        guard !items.isEmpty else { return } // Guard against empty queue crash
        queue = items
        currentIndex = max(0, min(startIndex, items.count - 1))
        updateRemoteCommandState()

        guard let content = items[safe: currentIndex] else { return }

        // Prefetch stream URLs for upcoming items while current loads
        prefetchQueueURLs()

        Task {
            await loadContent(content, videoMode: isVideoMode)
            play()
        }
    }

    /// Play the next item in the queue
    func playNext() {
        guard hasNextTrack, !isSkipping else { return }
        isSkipping = true
        Task { try? await Task.sleep(nanoseconds: 300_000_000); isSkipping = false }

        // Notify about the track being left before advancing — pass the actual
        // listen position, NOT the full duration (a manual skip 3s in must not
        // record a fully-completed session).
        if let content = currentContent {
            onTrackCompleted?(content, currentTime)
        }

        currentIndex += 1
        updateRemoteCommandState()

        guard let content = queue[safe: currentIndex] else { return }

        Task {
            await loadContentWithCrossfade(content, videoMode: isVideoMode)
            play()
        }
    }

    /// Remove an upcoming (or already-played) item from the queue.
    /// The currently playing item can't be removed.
    func removeFromQueue(at index: Int) {
        guard queue.indices.contains(index), index != currentIndex else { return }
        queue.remove(at: index)
        if index < currentIndex {
            currentIndex -= 1
        }
        updateRemoteCommandState()
        prefetchQueueURLs()
    }

    /// Reorder queue items (List onMove semantics). The playing item keeps
    /// playing; currentIndex is recomputed from its new position.
    func moveQueueItems(from source: IndexSet, to destination: Int) {
        let currentID = currentContent?.youtubeVideoID
        queue.move(fromOffsets: source, toOffset: destination)
        if let currentID,
           let newIndex = queue.firstIndex(where: { $0.youtubeVideoID == currentID }) {
            currentIndex = newIndex
        }
        updateRemoteCommandState()
        prefetchQueueURLs()
    }

    /// Append items to the end of the queue, skipping ones already queued.
    func appendToQueue(_ items: [Content]) {
        let queuedIDs = Set(queue.map { $0.youtubeVideoID })
        let newItems = items.filter { !queuedIDs.contains($0.youtubeVideoID) }
        guard !newItems.isEmpty else { return }
        queue.append(contentsOf: newItems)
        updateRemoteCommandState()
        prefetchQueueURLs()
    }

    /// Jump directly to a specific item in the queue (from the Up Next list)
    func playItem(at index: Int) {
        guard index != currentIndex, queue.indices.contains(index), !isSkipping else { return }
        isSkipping = true
        Task { try? await Task.sleep(nanoseconds: 300_000_000); isSkipping = false }

        // Notify about the track being left before jumping — pass the actual
        // listen position, not the full duration.
        if let content = currentContent {
            onTrackCompleted?(content, currentTime)
        }

        currentIndex = index
        updateRemoteCommandState()

        guard let content = queue[safe: currentIndex] else { return }

        prefetchQueueURLs()

        Task {
            await loadContentWithCrossfade(content, videoMode: isVideoMode)
            play()
        }
    }

    /// Play the previous item in the queue, or restart current track if >3s in
    func playPrevious() {
        guard !isSkipping else { return }
        isSkipping = true
        Task { try? await Task.sleep(nanoseconds: 300_000_000); isSkipping = false }
        // If more than 3 seconds into the track, restart it
        if currentTime > 3 {
            seek(to: 0)
            return
        }

        guard hasPreviousTrack else {
            seek(to: 0)
            return
        }

        // Notify about the track being left before going back — pass the
        // actual listen position, not the full duration.
        if let content = currentContent {
            onTrackCompleted?(content, currentTime)
        }

        currentIndex -= 1
        updateRemoteCommandState()

        guard let content = queue[safe: currentIndex] else { return }

        Task {
            await loadContent(content, videoMode: isVideoMode)
            play()
        }
    }

    /// Called when AVPlayer reaches end of current item
    private func handlePlaybackEnded() {
        // AVPlayerItemDidPlayToEndTime can occasionally fire twice (e.g. after
        // a seek to the end) — a second invocation after we already stopped
        // must not restart playback or defeat a sleep stop.
        guard isPlaying else { return }

        // Sleep stop modes win over repeat/auto-play: stop at the end of this
        // track, or at the end of the queue.
        if sleepStopMode == .endOfTrack || (sleepStopMode == .endOfQueue && !hasNextTrack) {
            sleepStopMode = nil
            isPlaying = false
            updateNowPlayingInfo(force: true)
            Task {
                await LiveActivityManager.shared.endActivity(showFinalState: true)
            }
            liveActivityStarted = false
            if let content = currentContent {
                onPlaybackFinishedNaturally?(content)
            }
            return
        }

        // Repeat One: loop the current track. Suspended while a sleep stop
        // mode is set — "end of queue" must advance toward the queue's end,
        // not loop this track all night.
        if repeatMode == .one && sleepStopMode == nil {
            let cmTime = CMTime(seconds: 0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            player?.seek(to: cmTime) { [weak self] finished in
                guard finished else { return }
                Task { @MainActor in
                    self?.currentTime = 0
                    self?.play()
                }
            }
            return
        }

        // Repeat All: wrap around when at end of queue
        if repeatMode == .all && !hasNextTrack && queue.count > 1 {
            if let content = currentContent {
                onTrackCompleted?(content, duration)
            }
            currentIndex = 0
            updateRemoteCommandState()
            if let content = queue.first {
                Task {
                    await loadContentWithCrossfade(content, videoMode: isVideoMode)
                    play()
                }
            }
            return
        }

        let autoPlayEnabled = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.autoPlayNextContent)

        guard autoPlayEnabled && hasNextTrack else {
            // Track ended, no auto-play or no next track — playback has come
            // to rest, so any pending sleep stop mode is moot; clearing it
            // prevents it from firing on an unrelated session days later.
            sleepStopMode = nil
            isPlaying = false
            updateNowPlayingInfo(force: true)
            // End Live Activity with completion state
            Task {
                await LiveActivityManager.shared.endActivity(showFinalState: true)
            }
            liveActivityStarted = false
            if let content = currentContent {
                onPlaybackFinishedNaturally?(content)
            }
            return
        }

        playNext()
    }

    // MARK: - Load Content
    func loadContent(_ content: Content, videoMode: Bool = false) async {
        // Stop and clean up any existing playback immediately
        cleanupPlayer()

        currentContent = content
        loadedVideoID = content.youtubeVideoID
        isVideoMode = videoMode
        isLoading = true
        error = nil
        contentUnavailable = false
        if !isAutoRetrying {
            currentRetryCount = 0
        }

        do {
            let audioOnly = !videoMode

            // Check if we have a pre-built AVPlayerItem for this track (instant)
            if let prefetchedItem = prefetchedPlayerItem,
               prefetchedVideoID == content.youtubeVideoID {
                #if DEBUG
                print("[AudioPlayerManager] Using prefetched AVPlayerItem for \(content.youtubeVideoID)")
                #endif
                prefetchedPlayerItem = nil
                prefetchedVideoID = nil
                isVideoMode = !(prefetchedAudioOnly ?? audioOnly)
                prefetchedAudioOnly = nil
                setupPlayerWithItem(prefetchedItem)
                prefetchNextInQueue()
                return
            }
            prefetchedPlayerItem = nil
            prefetchedVideoID = nil
            prefetchedAudioOnly = nil

            // Race disk cache vs stream URL extraction — use whichever resolves first
            let videoID = content.youtubeVideoID
            let playURL: URL = try await withThrowingTaskGroup(of: URL?.self) { group in
                // Task 1: Check disk cache (fast if file exists)
                group.addTask {
                    if let cachedURL = await VideoCache.shared.getCachedURL(for: videoID, audioOnly: audioOnly) {
                        #if DEBUG
                        print("[AudioPlayerManager] Disk cache hit for \(videoID)")
                        #endif
                        return cachedURL
                    }
                    return nil // No cache — let stream URL win
                }

                // Task 2: Extract stream URL from YouTube (network)
                group.addTask {
                    let url = try await MediaStreamService.shared.getStreamURL(for: videoID, audioOnly: audioOnly)
                    #if DEBUG
                    print("[AudioPlayerManager] Stream URL ready for \(videoID)")
                    #endif
                    return url
                }

                // Use first non-nil successful result
                for try await result in group {
                    if let url = result {
                        group.cancelAll()
                        return url
                    }
                }
                throw YouTubeError.extractionFailed
            }

            setupPlayer(with: playURL)

            // Safety timeout: if still loading after 10s, show error and allow retry
            // Reduced from 20s for better UX - users abandon after ~8-10s
            let contentID = content.youtubeVideoID
            let contentTitle = content.title
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                guard let self, self.isLoading, self.currentContent?.youtubeVideoID == contentID else { return }
                FirebaseService.shared.logPlaybackFailed(
                    videoID: contentID,
                    reason: "loading_timeout_10s",
                    retryCount: self.currentRetryCount,
                    contentTitle: contentTitle
                )
                self.error = "Playback timed out. Tap retry to try again."
                self.isLoading = false
            }

            // Cache current track in background for next time
            Task.detached(priority: .background) {
                do {
                    _ = try await VideoCache.shared.cacheVideo(videoID: content.youtubeVideoID, audioOnly: audioOnly)
                } catch {
                    #if DEBUG
                    print("[AudioPlayerManager] Background caching failed: \(error.localizedDescription)")
                    #endif
                }
            }

            // Prefetch next track in queue
            prefetchNextInQueue()
        } catch {
            // If video mode failed, try audio-only as fallback
            if videoMode {
                #if DEBUG
                print("[AudioPlayerManager] Video mode failed, trying audio-only fallback...")
                #endif
                do {
                    // Race cache vs network for audio fallback
                    let fallbackVideoID = content.youtubeVideoID
                    let audioURL: URL = try await withThrowingTaskGroup(of: URL?.self) { group in
                        group.addTask {
                            await VideoCache.shared.getCachedURL(for: fallbackVideoID, audioOnly: true)
                        }
                        group.addTask {
                            try await MediaStreamService.shared.getStreamURL(for: fallbackVideoID, audioOnly: true)
                        }
                        for try await result in group {
                            if let url = result { group.cancelAll(); return url }
                        }
                        throw YouTubeError.extractionFailed
                    }
                    isVideoMode = false
                    setupPlayer(with: audioURL)

                    Task.detached(priority: .background) {
                        do {
                            _ = try await VideoCache.shared.cacheVideo(videoID: content.youtubeVideoID, audioOnly: true)
                        } catch {
                            #if DEBUG
                            print("[AudioPlayerManager] Audio fallback caching failed: \(error.localizedDescription)")
                            #endif
                        }
                    }
                    prefetchNextInQueue()
                    return
                } catch {
                    #if DEBUG
                    print("[AudioPlayerManager] Audio-only fallback also failed: \(error.localizedDescription)")
                    #endif
                    // Check if a replacement was applied — update Content record
                    if let replacement = await ContentHealthService.shared.replacement(for: content.youtubeVideoID) {
                        #if DEBUG
                        print("[AudioPlayerManager] Applying replacement \(replacement.videoID) to Content record")
                        #endif
                        content.youtubeVideoID = replacement.videoID
                        if let dur = replacement.durationSeconds { content.durationSeconds = dur }
                    }
                    FirebaseService.shared.logPlaybackFailed(
                        videoID: content.youtubeVideoID,
                        reason: "all_fallbacks_failed_video_mode",
                        retryCount: currentRetryCount,
                        contentTitle: content.title
                    )
                    self.error = error.localizedDescription
                    self.contentUnavailable = true
                    self.isLoading = false
                }
            } else {
                // Audio-only extraction failed — try progressive (video+audio) as fallback
                #if DEBUG
                print("[AudioPlayerManager] Audio-only failed, trying progressive stream fallback...")
                #endif
                do {
                    let fallbackVideoID = content.youtubeVideoID
                    let progressiveURL: URL = try await withThrowingTaskGroup(of: URL?.self) { group in
                        group.addTask {
                            await VideoCache.shared.getCachedURL(for: fallbackVideoID, audioOnly: false)
                        }
                        group.addTask {
                            try await MediaStreamService.shared.getStreamURL(for: fallbackVideoID, audioOnly: false)
                        }
                        for try await result in group {
                            if let url = result { group.cancelAll(); return url }
                        }
                        throw YouTubeError.extractionFailed
                    }
                    isVideoMode = false // Still treat as audio playback (no video UI)
                    setupPlayer(with: progressiveURL)
                    prefetchNextInQueue()
                    return
                } catch {
                    #if DEBUG
                    print("[AudioPlayerManager] Progressive fallback also failed: \(error.localizedDescription)")
                    #endif
                }

                // Update Content record if replacement was applied at YouTubeService level
                if let replacement = await ContentHealthService.shared.replacement(for: content.youtubeVideoID) {
                    content.youtubeVideoID = replacement.videoID
                    if let dur = replacement.durationSeconds { content.durationSeconds = dur }
                }

                // Auto-retry once on extraction failure with fresh cache
                if !isAutoRetrying && currentRetryCount < Self.maxAutoRetries {
                    currentRetryCount += 1
                    isAutoRetrying = true
                    #if DEBUG
                    print("[AudioPlayerManager] Extraction failed - auto-retrying (\(currentRetryCount)/\(Self.maxAutoRetries)) with fresh cache...")
                    #endif
                    // Clear ALL cache for this video and try again after a short delay
                    await MediaStreamService.shared.evictCacheEntry(for: content.youtubeVideoID)
                    await VideoCache.shared.evictCacheEntry(for: content.youtubeVideoID)
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s delay before retry
                    isAutoRetrying = false
                    await loadContent(content, videoMode: isVideoMode)
                    if player != nil && self.error == nil {
                        play()
                    }
                    return
                }

                FirebaseService.shared.logPlaybackFailed(
                    videoID: content.youtubeVideoID,
                    reason: "all_fallbacks_failed_audio_mode",
                    retryCount: currentRetryCount,
                    contentTitle: content.title
                )
                self.error = error.localizedDescription
                self.contentUnavailable = true
                self.isLoading = false
            }
        }
    }

    // MARK: - Prefetching

    /// Prefetch the next item in the queue so playback starts instantly on advance
    private func prefetchNextInQueue() {
        guard hasNextTrack, let nextContent = queue[safe: currentIndex + 1] else { return }
        let audioOnly = !isVideoMode
        let videoID = nextContent.youtubeVideoID

        Task.detached(priority: .utility) {
            // Step 1: Race disk cache vs stream URL extraction
            let playableURL: URL?
            do {
                playableURL = try await withThrowingTaskGroup(of: URL?.self) { group in
                    group.addTask {
                        await VideoCache.shared.getCachedURL(for: videoID, audioOnly: audioOnly)
                    }
                    group.addTask {
                        try await MediaStreamService.shared.getStreamURL(for: videoID, audioOnly: audioOnly)
                    }
                    for try await result in group {
                        if let url = result { group.cancelAll(); return url }
                    }
                    throw YouTubeError.extractionFailed
                }
            } catch {
                #if DEBUG
                print("[AudioPlayerManager] Next-track prefetch failed: \(error.localizedDescription)")
                #endif
                return
            }

            // Step 2: Pre-build AVPlayerItem with preloaded keys so next track loads instantly
            guard let url = playableURL else { return }
            // Bail if queue changed while extracting
            let stillNext = await MainActor.run { self.queue[safe: self.currentIndex + 1]?.youtubeVideoID == videoID }
            guard stillNext else { return }
            let asset = AVURLAsset(url: url, options: [
                AVURLAssetPreferPreciseDurationAndTimingKey: false
            ])
            _ = try? await asset.load(.isPlayable, .duration)
            let item = AVPlayerItem(asset: asset)
            item.preferredForwardBufferDuration = 0.5
            await MainActor.run {
                // Final check before storing
                guard self.queue[safe: self.currentIndex + 1]?.youtubeVideoID == videoID else { return }
                self.prefetchedPlayerItem = item
                self.prefetchedVideoID = videoID
                self.prefetchedAudioOnly = audioOnly
                #if DEBUG
                print("[AudioPlayerManager] Pre-built AVPlayerItem for next: \(nextContent.title)")
                #endif
            }

            // Step 3: Download file to disk cache in background (for future launches)
            do {
                _ = try await VideoCache.shared.cacheVideo(videoID: videoID, audioOnly: audioOnly)
                #if DEBUG
                print("[AudioPlayerManager] Cached next track: \(nextContent.title)")
                #endif
            } catch {
                #if DEBUG
                print("[AudioPlayerManager] Next-track cache failed: \(error.localizedDescription)")
                #endif
            }
        }
    }

    /// Prefetch stream URLs for upcoming queue items when a queue is first loaded
    private func prefetchQueueURLs() {
        let audioOnly = !isVideoMode
        // Prefetch URLs for the next 3 items in queue (fast, just URL extraction)
        let startIdx = currentIndex + 1
        let endIdx = min(startIdx + 3, queue.count)
        guard startIdx < endIdx else { return }

        let upcomingIDs = queue[startIdx..<endIdx].map { $0.youtubeVideoID }

        Task.detached(priority: .utility) {
            await MediaStreamService.shared.prefetchStreamURLs(for: upcomingIDs, audioOnly: audioOnly)
            #if DEBUG
            print("[AudioPlayerManager] Prefetched \(upcomingIDs.count) upcoming queue URLs")
            #endif
        }
    }

    private func setupPlayer(with url: URL) {
        // Create asset with optimized loading — skip precise timing for faster start
        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: false
        ])

        // Asynchronously load the playable key so AVPlayer doesn't block on it
        Task { [weak self] in
            do {
                let isPlayable = try await asset.load(.isPlayable)
                guard let self else { return }
                guard self.isLoading else { return }
                guard isPlayable else {
                    self.error = "Content is not playable"
                    self.isLoading = false
                    return
                }
                self.finishPlayerSetup(with: asset)
            } catch {
                guard let self else { return }
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    /// Complete player setup once asset keys are loaded
    private func finishPlayerSetup(with asset: AVURLAsset) {
        playerItem = AVPlayerItem(asset: asset)

        // Minimal initial buffer — start playback ASAP, buffer more as we play
        playerItem?.preferredForwardBufferDuration = 0.5

        player = AVPlayer(playerItem: playerItem)
        // Let AVPlayer start as soon as it has minimum buffer rather than waiting for "safe" amount
        player?.automaticallyWaitsToMinimizeStalling = false

        // Observe duration
        playerItem?.publisher(for: \.duration)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                if duration.isNumeric {
                    self?.duration = duration.seconds
                }
            }
            .store(in: &cancellables)

        // Observe status
        playerItem?.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .readyToPlay:
                    self?.isLoading = false
                    self?.currentRetryCount = 0 // Reset retries on success
                    self?.updateNowPlayingInfo()
                case .failed:
                    self?.handlePlayerItemFailure()
                default:
                    break
                }
            }
            .store(in: &cancellables)

        // Observe buffer state — detect stalls and show buffering indicator
        playerItem?.publisher(for: \.isPlaybackBufferEmpty)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bufferEmpty in
                guard let self else { return }
                if bufferEmpty && self.isPlaying {
                    self.isBuffering = true
                    self.startBufferStallTimer()
                }
                #if DEBUG
                if bufferEmpty && self.isPlaying && self.currentTime < 1 {
                    print("[AudioPlayerManager] Buffer empty at start — possible stale URL")
                }
                #endif
            }
            .store(in: &cancellables)

        // Observe playback likely to keep up
        playerItem?.publisher(for: \.isPlaybackLikelyToKeepUp)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] likelyToKeepUp in
                guard let self else { return }
                if likelyToKeepUp {
                    self.isBuffering = false
                    self.cancelBufferStallTimer()
                    if self.isPlaying && self.player?.rate == 0 {
                        self.player?.play()
                        self.player?.rate = self.playbackRate
                    }
                }
            }
            .store(in: &cancellables)

        // Time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentTime = time.seconds
                self.updateNowPlayingInfo()
            }
        }

        // End-of-playback observer for auto-advance
        endOfPlaybackObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlePlaybackEnded()
            }
        }

        isLoading = false
    }

    /// Handle player item failure — auto-retry with fresh URL if possible
    private func handlePlayerItemFailure() {
        let failureError = playerItem?.error?.localizedDescription ?? "Playback failed"
        #if DEBUG
        print("[AudioPlayerManager] Player item failed: \(failureError)")
        #endif

        guard !isAutoRetrying,
              currentRetryCount < Self.maxAutoRetries,
              let content = currentContent else {
            // Retries exhausted — log to analytics
            if let content = currentContent {
                FirebaseService.shared.logPlaybackFailed(
                    videoID: content.youtubeVideoID,
                    reason: "player_item_failed: \(failureError)",
                    retryCount: currentRetryCount,
                    contentTitle: content.title
                )
            }
            error = failureError
            isLoading = false
            return
        }

        // Auto-retry: evict stale cache and reload with fresh URL
        currentRetryCount += 1
        isAutoRetrying = true
        #if DEBUG
        print("[AudioPlayerManager] Auto-retrying (\(currentRetryCount)/\(Self.maxAutoRetries)) with fresh URL...")
        #endif

        Task {
            // Evict the stale cached URL
            await MediaStreamService.shared.evictCacheEntry(for: content.youtubeVideoID)
            // Reload
            await loadContent(content, videoMode: isVideoMode)
            isAutoRetrying = false
            if player != nil && error == nil {
                play()
            }
        }
    }

    // MARK: - Buffer Stall Recovery

    private func startBufferStallTimer() {
        cancelBufferStallTimer()
        let contentID = currentContent?.youtubeVideoID
        bufferStallTimer = Timer.scheduledTimer(withTimeInterval: Self.bufferStallTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self,
                      self.isBuffering,
                      self.currentContent?.youtubeVideoID == contentID else { return }

                self.cancelBufferStallTimer()

                // Log to analytics
                if let content = self.currentContent {
                    FirebaseService.shared.logPlaybackFailed(
                        videoID: content.youtubeVideoID,
                        reason: "buffer_stall_timeout",
                        retryCount: self.currentRetryCount,
                        contentTitle: content.title
                    )
                }

                // Auto-retry if possible, otherwise show error
                if !self.isAutoRetrying && self.currentRetryCount < Self.maxAutoRetries,
                   let content = self.currentContent {
                    self.currentRetryCount += 1
                    self.isAutoRetrying = true
                    await MediaStreamService.shared.evictCacheEntry(for: content.youtubeVideoID)
                    await VideoCache.shared.evictCacheEntry(for: content.youtubeVideoID)
                    await self.loadContent(content, videoMode: self.isVideoMode)
                    self.isAutoRetrying = false
                    if self.player != nil && self.error == nil {
                        self.play()
                    }
                } else {
                    self.error = "Playback stalled. Tap retry to try again."
                    self.isBuffering = false
                    self.isLoading = false
                }
            }
        }
    }

    private func cancelBufferStallTimer() {
        bufferStallTimer?.invalidate()
        bufferStallTimer = nil
    }

    /// Use a pre-built AVPlayerItem for instant playback (from prefetch)
    private func setupPlayerWithItem(_ item: AVPlayerItem) {
        playerItem = item

        player = AVPlayer(playerItem: item)
        player?.automaticallyWaitsToMinimizeStalling = false

        // Observe duration
        item.publisher(for: \.duration)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                if duration.isNumeric {
                    self?.duration = duration.seconds
                }
            }
            .store(in: &cancellables)

        // Observe status
        item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .readyToPlay:
                    self?.isLoading = false
                    self?.currentRetryCount = 0
                    self?.updateNowPlayingInfo()
                case .failed:
                    self?.handlePlayerItemFailure()
                default:
                    break
                }
            }
            .store(in: &cancellables)

        // Observe buffer state — detect stalls and show buffering indicator
        item.publisher(for: \.isPlaybackBufferEmpty)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bufferEmpty in
                guard let self else { return }
                if bufferEmpty && self.isPlaying {
                    self.isBuffering = true
                    self.startBufferStallTimer()
                }
            }
            .store(in: &cancellables)

        // Observe playback likely to keep up (stall recovery)
        item.publisher(for: \.isPlaybackLikelyToKeepUp)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] likelyToKeepUp in
                guard let self else { return }
                if likelyToKeepUp {
                    self.isBuffering = false
                    self.cancelBufferStallTimer()
                    if self.isPlaying && self.player?.rate == 0 {
                        self.player?.play()
                        self.player?.rate = self.playbackRate
                    }
                }
            }
            .store(in: &cancellables)

        // Time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentTime = time.seconds
                self.updateNowPlayingInfo()
            }
        }

        // End-of-playback observer
        endOfPlaybackObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlePlaybackEnded()
            }
        }

        isLoading = false
    }

    // MARK: - Playback Controls
    func play() {
        player?.play()
        player?.rate = playbackRate
        isPlaying = true
        updateNowPlayingInfo(force: true)
        updateLiveActivity()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo(force: true)
        updateLiveActivity()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to time: TimeInterval) {
        guard !isLoading, player?.currentItem != nil else {
            // Update UI position even if we can't seek yet
            currentTime = time
            return
        }
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        let tolerance = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: cmTime, toleranceBefore: tolerance, toleranceAfter: tolerance)
        currentTime = time
        updateNowPlayingInfo(force: true)
    }

    func skipForward(seconds: TimeInterval = 15) {
        let newTime = min(currentTime + seconds, duration)
        seek(to: newTime)
    }

    func skipBackward(seconds: TimeInterval = 15) {
        let newTime = max(currentTime - seconds, 0)
        seek(to: newTime)
    }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        // Persist so the preferred speed survives relaunches and syncs via iCloud.
        UserDefaults.standard.set(Double(rate), forKey: Constants.UserDefaultsKeys.preferredPlaybackSpeed)
        if isPlaying {
            player?.rate = rate
        }
        updateNowPlayingInfo(force: true)
    }

    // MARK: - Live Activity

    /// Track whether we've started a Live Activity for the current content
    private var liveActivityStarted = false

    /// Start or update the Live Activity for current playback
    private func updateLiveActivity() {
        guard let content = currentContent else { return }

        // Start Live Activity if not already started for this content
        if !liveActivityStarted && isPlaying && duration > 0 {
            LiveActivityManager.shared.startActivity(
                sessionId: content.id.uuidString,
                videoId: content.youtubeVideoID,
                title: content.title,
                contentType: content.contentType.displayName,
                duration: duration
            )
            liveActivityStarted = true
            return
        }

        // Update existing Live Activity
        if liveActivityStarted {
            LiveActivityManager.shared.updateActivity(
                currentTime: currentTime,
                duration: duration,
                isPlaying: isPlaying,
                title: content.title,
                contentType: content.contentType.displayName
            )
        }
    }

    // MARK: - Now Playing Info
    private func updateNowPlayingInfo(force: Bool = false) {
        guard let content = currentContent else { return }

        // Throttle periodic updates to once per second (force bypasses for play/pause/seek)
        let currentSecond = Int(currentTime)
        if !force && currentSecond == lastNowPlayingSecond { return }
        lastNowPlayingSecond = currentSecond

        // Update Live Activity alongside Now Playing info
        updateLiveActivity()

        var info = [String: Any]()

        info[MPMediaItemPropertyTitle] = content.title
        info[MPMediaItemPropertyArtist] = content.narrator ?? "Meditation"
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate : 0

        // Queue position info for lock screen
        if queue.count > 1 {
            info[MPNowPlayingInfoPropertyPlaybackQueueIndex] = currentIndex
            info[MPNowPlayingInfoPropertyPlaybackQueueCount] = queue.count
        }

        // Include cached artwork if available for current content
        if let artwork = cachedArtwork, cachedArtworkVideoID == content.youtubeVideoID {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        // Load artwork asynchronously if not yet cached for this content
        if cachedArtworkVideoID != content.youtubeVideoID {
            let videoID = content.youtubeVideoID
            let thumbnailURLString = content.thumbnailURLComputed
            Task {
                guard let artworkURL = URL(string: thumbnailURLString) else { return }

                // The thumbnail cache almost certainly has this image already
                // (it's the same URL every content card displays) — avoid a
                // redundant network fetch per track change.
                var image = await ImageCache.shared.image(for: artworkURL)
                if image == nil,
                   let (data, _) = try? await URLSession.shared.data(from: artworkURL) {
                    image = UIImage(data: data)
                }

                if let image {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    self.cachedArtwork = artwork
                    self.cachedArtworkVideoID = videoID
                    // Update now playing info again with artwork
                    if var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo {
                        currentInfo[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
                    }
                }
            }
        }
    }

    // MARK: - Sleep Timer
    func setSleepTimer(minutes: Int) {
        cancelSleepTimer()

        sleepTimerRemaining = TimeInterval(minutes * 60)

        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, var remaining = self.sleepTimerRemaining else { return }
                remaining -= 1

                if remaining <= 0 {
                    self.fadeOutAndStop()
                } else if remaining <= 30 && self.crossfadePlayer == nil && self.fadeInTimer == nil {
                    // Start fading out in last 30 seconds (skip if crossfade or fade-in is active)
                    let volume = Float(remaining / 30)
                    self.player?.volume = volume
                }

                self.sleepTimerRemaining = remaining > 0 ? remaining : nil
            }
        }
    }

    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerRemaining = nil
        sleepStopMode = nil
        player?.volume = 1.0
    }

    private func fadeOutAndStop() {
        cancelSleepTimer()
        pause()
        player?.volume = 1.0
    }

    // MARK: - Cleanup
    func stop() {
        // Tear down any sleep timer state with the session it belonged to.
        cancelSleepTimer()
        pause()
        cleanupPlayer()
        stopCrossfade()
        currentContent = nil
        queue = []
        currentIndex = 0
        cachedArtwork = nil
        cachedArtworkVideoID = nil
        updateRemoteCommandState()
        // Stop ambient sounds when main player stops
        AmbientSoundManager.shared.stopAll()
        // End Live Activity
        Task {
            await LiveActivityManager.shared.endActivity(showFinalState: false)
        }
    }

    private func cleanupPlayer() {
        // Stop playback immediately to prevent dual audio
        player?.pause()
        fadeInTimer?.invalidate()
        fadeInTimer = nil
        cancelBufferStallTimer()

        // Remove observers BEFORE nilling the player reference
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let observer = endOfPlaybackObserver {
            NotificationCenter.default.removeObserver(observer)
            endOfPlaybackObserver = nil
        }
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerItem = nil
        loadedVideoID = nil
        currentTime = 0
        duration = 0
        isPlaying = false
        isBuffering = false
        cancellables.removeAll()
        liveActivityStarted = false
    }

    // MARK: - Crossfade

    /// Move current player to crossfade slot and fade it out over 3 seconds
    private func beginCrossfade() {
        // Clean up any existing crossfade
        stopCrossfade()

        guard let oldPlayer = player else { return }

        // Detach old player from observation but keep it playing
        if let observer = timeObserver {
            oldPlayer.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let observer = endOfPlaybackObserver {
            NotificationCenter.default.removeObserver(observer)
            endOfPlaybackObserver = nil
        }
        cancellables.removeAll()

        // Move to crossfade slot
        crossfadePlayer = oldPlayer
        player = nil
        playerItem = nil

        // Fade out over 3 seconds (30 steps at 0.1s intervals)
        let initialVolume = max(oldPlayer.volume, 0.01) // Prevent zero division
        var stepsRemaining = 30
        crossfadeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self, self.crossfadePlayer != nil else { timer.invalidate(); return }
                stepsRemaining -= 1
                if stepsRemaining <= 0 {
                    self.stopCrossfade()
                } else {
                    self.crossfadePlayer?.volume = initialVolume * Float(stepsRemaining) / 30.0
                }
            }
        }
    }

    private func stopCrossfade() {
        crossfadeTimer?.invalidate()
        crossfadeTimer = nil
        crossfadePlayer?.pause()
        crossfadePlayer = nil
    }

    /// Load content with crossfade from current track (used for queue advances)
    func loadContentWithCrossfade(_ content: Content, videoMode: Bool = false) async {
        // Start fading out old track
        beginCrossfade()

        // Now load new content (this sets up new player)
        currentContent = content
        loadedVideoID = content.youtubeVideoID
        isVideoMode = videoMode
        isLoading = true
        error = nil
        contentUnavailable = false
        if !isAutoRetrying {
            currentRetryCount = 0
        }

        do {
            let audioOnly = !videoMode

            if let prefetchedItem = prefetchedPlayerItem,
               prefetchedVideoID == content.youtubeVideoID {
                prefetchedPlayerItem = nil
                prefetchedVideoID = nil
                setupPlayerWithItem(prefetchedItem)
                // Fade in new player
                player?.volume = 0
                fadeInPlayer()
                prefetchNextInQueue()
                return
            }
            prefetchedPlayerItem = nil
            prefetchedVideoID = nil

            // Race disk cache vs stream URL for crossfade
            let cfVideoID = content.youtubeVideoID
            let cfURL: URL = try await withThrowingTaskGroup(of: URL?.self) { group in
                group.addTask {
                    await VideoCache.shared.getCachedURL(for: cfVideoID, audioOnly: audioOnly)
                }
                group.addTask {
                    try await MediaStreamService.shared.getStreamURL(for: cfVideoID, audioOnly: audioOnly)
                }
                for try await result in group {
                    if let url = result { group.cancelAll(); return url }
                }
                throw YouTubeError.extractionFailed
            }
            // Guard: if user tapped next again during extraction, bail out
            guard currentContent?.youtubeVideoID == cfVideoID else { return }
            setupPlayer(with: cfURL)
            // Volume fade-in happens in finishPlayerSetup won't apply here since it's async
            // We set initial volume after player is ready via observation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard self?.currentContent?.youtubeVideoID == cfVideoID else { return }
                self?.player?.volume = 0
                self?.fadeInPlayer()
            }
            prefetchNextInQueue()
        } catch {
            // Crossfade failed — stop old player immediately
            stopCrossfade()
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    private func fadeInPlayer() {
        guard player != nil else { return }
        fadeInTimer?.invalidate()
        var stepsRemaining = 20
        fadeInTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self, let currentPlayer = self.player else { timer.invalidate(); return }
                stepsRemaining -= 1
                if stepsRemaining <= 0 {
                    currentPlayer.volume = 1.0
                    timer.invalidate()
                    self.fadeInTimer = nil
                } else {
                    currentPlayer.volume = 1.0 - Float(stepsRemaining) / 20.0
                }
            }
        }
    }
}
