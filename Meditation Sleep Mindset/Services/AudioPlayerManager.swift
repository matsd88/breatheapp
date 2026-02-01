//
//  AudioPlayerManager.swift
//  Meditation Sleep Mindset
//

import Foundation
import AVFoundation
import MediaPlayer
import Combine

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
            case .one: return .off
            case .all: return .off
            }
        }
    }

    // MARK: - Published Properties
    @Published var repeatMode: RepeatMode = .off
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isLoading = false
    @Published var isBuffering = false
    @Published var error: String?
    @Published var contentUnavailable = false
    @Published var playbackRate: Float = 1.0
    @Published var sleepTimerRemaining: TimeInterval?
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
    /// Track retry attempts for the current content to prevent infinite loops
    private var currentRetryCount = 0
    private static let maxAutoRetries = 2
    /// Track whether we're currently auto-retrying (prevent re-entrant retries)
    private var isAutoRetrying = false
    /// Debounce rapid next/previous taps
    private var isSkipping = false

    private init() {
        setupAudioSession()
        setupRemoteCommandCenter()
        setupInterruptionHandling()

        // Register default for auto-play (on by default)
        UserDefaults.standard.register(defaults: [
            Constants.UserDefaultsKeys.autoPlayNextContent: true
        ])
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

        // Notify about completed track before advancing
        if let content = currentContent {
            onTrackCompleted?(content, duration)
        }

        currentIndex += 1
        updateRemoteCommandState()

        guard let content = queue[safe: currentIndex] else { return }

        Task {
            await loadContent(content, videoMode: isVideoMode)
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

        // Notify about completed track before going back
        if let content = currentContent {
            onTrackCompleted?(content, duration)
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
        // Repeat One: loop the current track
        if repeatMode == .one {
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
                    await loadContent(content, videoMode: isVideoMode)
                    play()
                }
            }
            return
        }

        let autoPlayEnabled = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.autoPlayNextContent)

        guard autoPlayEnabled && hasNextTrack else {
            // Track ended, no auto-play or no next track
            isPlaying = false
            updateNowPlayingInfo(force: true)
            return
        }

        playNext()
    }

    // MARK: - Load Content
    func loadContent(_ content: Content, videoMode: Bool = false) async {
        // Stop and clean up any existing playback immediately
        cleanupPlayer()

        currentContent = content
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
                setupPlayerWithItem(prefetchedItem)
                prefetchNextInQueue()
                return
            }
            prefetchedPlayerItem = nil
            prefetchedVideoID = nil

            // Check disk cache for faster loading
            if let cachedURL = await VideoCache.shared.getCachedURL(for: content.youtubeVideoID, audioOnly: audioOnly) {
                #if DEBUG
                print("[AudioPlayerManager] Using cached file for \(content.youtubeVideoID)")
                #endif
                setupPlayer(with: cachedURL)
                prefetchNextInQueue()
                return
            }

            // Fall back to streaming from YouTube
            let streamURL = try await YouTubeService.shared.getStreamURL(
                for: content.youtubeVideoID,
                audioOnly: audioOnly
            )

            setupPlayer(with: streamURL)

            // Safety timeout: if still loading after 15s, show error and allow retry
            let contentID = content.youtubeVideoID
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                guard let self, self.isLoading, self.currentContent?.youtubeVideoID == contentID else { return }
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
                    // Check audio cache first
                    if let cachedAudio = await VideoCache.shared.getCachedURL(for: content.youtubeVideoID, audioOnly: true) {
                        #if DEBUG
                        print("[AudioPlayerManager] Using cached audio fallback for \(content.youtubeVideoID)")
                        #endif
                        isVideoMode = false
                        setupPlayer(with: cachedAudio)
                        prefetchNextInQueue()
                        return
                    }

                    let audioURL = try await YouTubeService.shared.getStreamURL(
                        for: content.youtubeVideoID,
                        audioOnly: true
                    )
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
                    self.error = error.localizedDescription
                    self.contentUnavailable = true
                    self.isLoading = false
                }
            } else {
                // Update Content record if replacement was applied at YouTubeService level
                if let replacement = await ContentHealthService.shared.replacement(for: content.youtubeVideoID) {
                    content.youtubeVideoID = replacement.videoID
                    if let dur = replacement.durationSeconds { content.durationSeconds = dur }
                }
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
            // Step 1: Check disk cache first, or get stream URL
            var playableURL: URL?
            if let cachedURL = await VideoCache.shared.getCachedURL(for: videoID, audioOnly: audioOnly) {
                playableURL = cachedURL
            } else {
                do {
                    let streamURL = try await YouTubeService.shared.getStreamURL(for: videoID, audioOnly: audioOnly)
                    playableURL = streamURL
                    #if DEBUG
                    print("[AudioPlayerManager] Prefetched stream URL for next: \(nextContent.title)")
                    #endif
                } catch {
                    #if DEBUG
                    print("[AudioPlayerManager] Next-track URL prefetch failed: \(error.localizedDescription)")
                    #endif
                    return
                }
            }

            // Step 2: Pre-build AVPlayerItem with preloaded keys so next track loads instantly
            if let url = playableURL {
                let asset = AVURLAsset(url: url, options: [
                    AVURLAssetPreferPreciseDurationAndTimingKey: false
                ])
                // Pre-load playable key so it's ready when we switch
                _ = try? await asset.load(.isPlayable, .duration)
                let item = AVPlayerItem(asset: asset)
                item.preferredForwardBufferDuration = 1.0
                await MainActor.run {
                    self.prefetchedPlayerItem = item
                    self.prefetchedVideoID = videoID
                    #if DEBUG
                    print("[AudioPlayerManager] Pre-built AVPlayerItem for next: \(nextContent.title)")
                    #endif
                }
            }

            // Step 3: Download file to disk cache in background (for future launches)
            if playableURL != nil {
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
            await YouTubeService.shared.prefetchStreamURLs(for: upcomingIDs, audioOnly: audioOnly)
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
        playerItem?.preferredForwardBufferDuration = 1.0

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
            Task { @MainActor in
                self?.currentTime = time.seconds
                self?.updateNowPlayingInfo()
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
            await YouTubeService.shared.evictCacheEntry(for: content.youtubeVideoID)
            // Reload
            await loadContent(content, videoMode: isVideoMode)
            isAutoRetrying = false
            if player != nil && error == nil {
                play()
            }
        }
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

        // Observe playback likely to keep up (stall recovery)
        item.publisher(for: \.isPlaybackLikelyToKeepUp)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] likelyToKeepUp in
                guard let self else { return }
                if likelyToKeepUp && self.isPlaying && self.player?.rate == 0 {
                    self.player?.play()
                    self.player?.rate = self.playbackRate
                }
            }
            .store(in: &cancellables)

        // Time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
                self?.updateNowPlayingInfo()
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
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo(force: true)
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        // Use small tolerance for responsive seeking (exact precision not needed for meditation audio)
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
        if isPlaying {
            player?.rate = rate
        }
        updateNowPlayingInfo(force: true)
    }

    // MARK: - Now Playing Info
    private func updateNowPlayingInfo(force: Bool = false) {
        guard let content = currentContent else { return }

        // Throttle periodic updates to once per second (force bypasses for play/pause/seek)
        let currentSecond = Int(currentTime)
        if !force && currentSecond == lastNowPlayingSecond { return }
        lastNowPlayingSecond = currentSecond

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
            Task {
                if let artworkURL = URL(string: content.thumbnailURLComputed),
                   let (data, _) = try? await URLSession.shared.data(from: artworkURL),
                   let image = UIImage(data: data) {
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
                } else if remaining <= 30 {
                    // Start fading out in last 30 seconds
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
        player?.volume = 1.0
    }

    private func fadeOutAndStop() {
        cancelSleepTimer()
        pause()
        player?.volume = 1.0
    }

    // MARK: - Cleanup
    func stop() {
        pause()
        cleanupPlayer()
        currentContent = nil
        queue = []
        currentIndex = 0
        cachedArtwork = nil
        cachedArtworkVideoID = nil
        updateRemoteCommandState()
    }

    private func cleanupPlayer() {
        // Stop playback immediately to prevent dual audio
        player?.pause()
        player?.replaceCurrentItem(with: nil)

        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let observer = endOfPlaybackObserver {
            NotificationCenter.default.removeObserver(observer)
            endOfPlaybackObserver = nil
        }
        player = nil
        playerItem = nil
        currentTime = 0
        duration = 0
        isPlaying = false
        isBuffering = false
        cancellables.removeAll()
    }
}
