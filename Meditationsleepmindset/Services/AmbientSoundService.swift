//
//  AmbientSoundService.swift
//  Meditation Sleep Mindset
//

import AVFoundation
import Combine

enum TimerAmbientSound: String, CaseIterable {
    case rain = "Rain"
    case ocean = "Ocean"
    case forest = "Forest"
    case silence = "Silence"

    var displayName: String {
        switch self {
        case .rain: return String(localized: "Rain")
        case .ocean: return String(localized: "Ocean")
        case .forest: return String(localized: "Forest")
        case .silence: return String(localized: "Silence")
        }
    }

    var fileName: String? {
        switch self {
        case .rain: return "rain"
        case .ocean: return "ocean"
        case .forest: return "forest"
        case .silence: return nil
        }
    }

    /// Real streamed source for this sound — same catalog entries the
    /// soundscape mixer (AmbientSoundManager) uses.
    var youtubeVideoID: String? {
        switch self {
        case .rain: return "yIQd2Ya0Ziw"
        case .ocean: return "WHPEKLQID4U"
        case .forest: return "xNN7iTA57jM"
        case .silence: return nil
        }
    }

    var iconName: String {
        switch self {
        case .rain: return "cloud.rain.fill"
        case .ocean: return "water.waves"
        case .forest: return "leaf.fill"
        case .silence: return "speaker.slash.fill"
        }
    }
}

/// Plays a single looping ambient sound for timer-style features (focus timer,
/// unguided timer, AI meditation background).
///
/// Playback strategy, in order of preference:
///   1. Bundled audio file (if one ever ships in the app bundle)
///   2. Locally cached stream file (works offline)
///   3. Real streamed audio (R2-first via MediaStreamService, YouTube fallback)
///   4. Synthesized noise (offline, or if the stream fails to start)
///
/// This service owns its own AVPlayer instances and never touches
/// AmbientSoundManager's players, so a user's soundscape mix keeps playing
/// untouched alongside a timer sound (both sessions use .mixWithOthers).
@MainActor
class AmbientSoundService: ObservableObject {
    static let shared = AmbientSoundService()

    @Published var isPlaying = false
    @Published var currentSound: TimerAmbientSound?
    @Published var volume: Float = 0.7

    /// Player for bundled / synthesized fallback audio.
    private var audioPlayer: AVAudioPlayer?
    /// Player for real streamed audio (seamless looping via AVPlayerLooper).
    private var streamPlayer: AVQueuePlayer?
    private var streamLooper: AVPlayerLooper?
    private var itemStatusObservation: NSKeyValueObservation?
    private var currentItemObservation: NSKeyValueObservation?
    private var streamFailObserver: NSObjectProtocol?
    private var startupTimeoutTask: Task<Void, Never>?
    private var fadeTimer: Timer?

    /// Bumped on every play/stop so stale async work can detect it's outdated.
    private var playGeneration = 0
    /// Whether playback is wanted right now (false while paused).
    private var desiredPlaying = false
    /// Catalog sound id currently playing (when started via play(catalogSound:)).
    private var currentCatalogSoundID: String?

    /// How long to wait for a stream to become ready before falling back to
    /// synthesized noise.
    private let streamStartupTimeout: UInt64 = 5_000_000_000 // 5s

    private init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            #if DEBUG
            print("Failed to setup audio session: \(error)")
            #endif
        }
    }

    // MARK: - Public API

    func play(sound: TimerAmbientSound) {
        // Stop any currently playing sound
        stop()

        // Silence means no sound
        guard sound != .silence else {
            currentSound = .silence
            return
        }

        currentSound = sound
        desiredPlaying = true

        // Try to load from bundle first (instant, offline-safe)
        if let fileName = sound.fileName, let url = bundledAudioURL(named: fileName) {
            playFromURL(url, sound: sound)
            return
        }

        if let videoID = sound.youtubeVideoID {
            // Real streamed audio, with synthesized noise as automatic fallback
            startRealSound(videoID: videoID, profile: sound)
        } else {
            playGeneratedSound(for: sound)
        }
    }

    /// Play a sound from the soundscape mixer's catalog (used by the Focus
    /// Timer, whose picker shows AmbientSoundManager.availableSounds). Uses
    /// this service's own player so an active mixer mix is left alone.
    func play(catalogSound: AmbientSound) {
        // Already playing this exact sound (e.g. work → break → work cycle):
        // keep it going instead of restarting the stream.
        if currentCatalogSoundID == catalogSound.id, streamPlayer != nil || audioPlayer != nil {
            resume()
            return
        }

        stop()

        let profile = Self.noiseProfile(forCatalogID: catalogSound.id)
        currentCatalogSoundID = catalogSound.id
        currentSound = profile
        desiredPlaying = true
        startRealSound(videoID: catalogSound.youtubeVideoID, profile: profile)
    }

    func stop() {
        playGeneration += 1
        desiredPlaying = false
        fadeTimer?.invalidate()
        fadeTimer = nil
        teardownStreamPlayer()
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentSound = nil
        currentCatalogSoundID = nil
    }

    /// Pause the current sound without tearing it down (for timer pause).
    func pause() {
        desiredPlaying = false
        streamPlayer?.pause()
        audioPlayer?.pause()
        isPlaying = false
    }

    /// Resume a paused sound.
    func resume() {
        guard streamPlayer != nil || audioPlayer != nil || currentSound != nil else { return }
        desiredPlaying = true
        if let streamPlayer {
            streamPlayer.play()
            isPlaying = true
        }
        if let audioPlayer {
            audioPlayer.play()
            isPlaying = true
        }
        // If neither player exists yet (stream still resolving), desiredPlaying
        // makes playback start as soon as the stream is ready.
    }

    func setVolume(_ newVolume: Float) {
        volume = max(0, min(1, newVolume))
        streamPlayer?.volume = volume
        audioPlayer?.volume = volume
    }

    func fadeOut(duration: TimeInterval = 2.0, completion: (() -> Void)? = nil) {
        let stream = streamPlayer
        let file = audioPlayer
        guard stream != nil || file != nil else {
            // Nothing audible yet (stream may still be resolving) — stop so the
            // pending stream can't start playing after the fade-out request.
            stop()
            completion?()
            return
        }

        let steps = 20
        let interval = duration / Double(steps)
        let streamStart = stream?.volume ?? 0
        let fileStart = file?.volume ?? 0

        var currentStep = 0

        fadeTimer?.invalidate()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            Task { @MainActor in
                currentStep += 1
                let fraction = Float(max(0, steps - currentStep)) / Float(steps)
                stream?.volume = streamStart * fraction
                file?.volume = fileStart * fraction

                if currentStep >= steps {
                    timer.invalidate()
                    self?.fadeTimer = nil
                    self?.stop()
                    completion?()
                }
            }
        }
    }

    // MARK: - Real streamed playback

    private func bundledAudioURL(named fileName: String) -> URL? {
        for ext in ["mp3", "m4a", "wav"] {
            if let url = Bundle.main.url(forResource: fileName, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    /// Noise profile used when a catalog sound has to fall back to synthesis.
    private static func noiseProfile(forCatalogID id: String) -> TimerAmbientSound {
        switch id {
        case "ocean", "wind": return .ocean
        case "forest", "birds": return .forest
        default: return .rain // rain, thunder, fireplace, whitenoise
        }
    }

    private func startRealSound(videoID: String, profile: TimerAmbientSound) {
        playGeneration += 1
        let generation = playGeneration
        // Optimistic: the UI treats loading as playing (matches the mixer's UX).
        isPlaying = desiredPlaying

        Task {
            // 1. Locally cached file — instant and works offline
            if let cached = await VideoCache.shared.getCachedURL(for: videoID, audioOnly: true) {
                guard generation == self.playGeneration else { return }
                self.beginStreamPlayback(url: cached, profile: profile, generation: generation)
                return
            }

            // 2. Offline with no cache — synthesized noise immediately
            guard NetworkMonitor.shared.isConnected else {
                self.fallBackToGenerated(profile, generation: generation)
                return
            }

            // 3. R2-first via MediaStreamService, then YouTube extraction
            var url = try? await MediaStreamService.shared.getStreamURL(for: videoID, audioOnly: true)
            if url == nil {
                url = try? await YouTubeService.shared.getStreamURL(for: videoID, audioOnly: true)
            }

            guard generation == self.playGeneration else { return }

            if let url {
                self.beginStreamPlayback(url: url, profile: profile, generation: generation)
            } else {
                self.fallBackToGenerated(profile, generation: generation)
            }
        }
    }

    private func beginStreamPlayback(url: URL, profile: TimerAmbientSound, generation: Int) {
        guard generation == playGeneration else { return }

        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: false
        ])
        let templateItem = AVPlayerItem(asset: asset)
        templateItem.preferredForwardBufferDuration = 2.0

        let player = AVQueuePlayer()
        player.automaticallyWaitsToMinimizeStalling = false
        player.volume = volume

        // Seamless gapless looping
        let looper = AVPlayerLooper(player: player, templateItem: templateItem)

        streamPlayer = player
        streamLooper = looper

        // Fall back to synthesized noise if the stream fails. AVPlayerLooper
        // enqueues a fresh item copy per loop, so observe the PLAYER's
        // currentItem and re-attach the status observation to each new item —
        // observing only the first copy left later loop failures (expired
        // stream URL, network drop) silently killing the sound mid-session.
        currentItemObservation = player.observe(\.currentItem, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor in
                guard let self, generation == self.playGeneration,
                      let item = self.streamPlayer?.currentItem else { return }
                self.itemStatusObservation?.invalidate()
                self.itemStatusObservation = item.observe(\.status) { [weak self] observedItem, _ in
                    guard observedItem.status == .failed else { return }
                    Task { @MainActor in
                        self?.fallBackToGenerated(profile, generation: generation)
                    }
                }
            }
        }
        // The failed-to-play notification is filtered by player identity
        // instead of item identity so it covers every loop iteration.
        streamFailObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self, generation == self.playGeneration,
                      let failedItem = notification.object as? AVPlayerItem,
                      self.streamPlayer?.items().contains(failedItem) == true
                        || self.streamPlayer?.currentItem == failedItem else { return }
                self.fallBackToGenerated(profile, generation: generation)
            }
        }

        if desiredPlaying {
            player.play()
            isPlaying = true
        }

        // Watchdog: if the stream isn't ready within a few seconds, fall back
        startupTimeoutTask?.cancel()
        startupTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.streamStartupTimeout ?? 5_000_000_000)
            guard !Task.isCancelled, let self else { return }
            guard generation == self.playGeneration else { return }
            if self.streamPlayer?.currentItem?.status != .readyToPlay {
                self.fallBackToGenerated(profile, generation: generation)
            }
        }
    }

    private func fallBackToGenerated(_ profile: TimerAmbientSound, generation: Int) {
        guard generation == playGeneration else { return }
        #if DEBUG
        print("Stream unavailable for \(profile.rawValue), using generated audio")
        #endif
        teardownStreamPlayer()
        guard profile != .silence else { return }
        playGeneratedSound(for: profile)
        if !desiredPlaying {
            audioPlayer?.pause()
            isPlaying = false
        }
    }

    private func teardownStreamPlayer() {
        startupTimeoutTask?.cancel()
        startupTimeoutTask = nil
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        currentItemObservation?.invalidate()
        currentItemObservation = nil
        if let streamFailObserver {
            NotificationCenter.default.removeObserver(streamFailObserver)
            self.streamFailObserver = nil
        }
        streamLooper?.disableLooping()
        streamLooper = nil
        streamPlayer?.pause()
        streamPlayer = nil
    }

    // MARK: - Local / synthesized playback

    private func playFromURL(_ url: URL, sound: TimerAmbientSound) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = volume
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            currentSound = sound
            isPlaying = true
        } catch {
            #if DEBUG
            print("Failed to play audio: \(error)")
            #endif
        }
    }

    private func playGeneratedSound(for sound: TimerAmbientSound) {
        // Generate white/pink noise as fallback when no stream is available

        let sampleRate: Double = 44100
        let duration: Double = 10.0 // 10 second loop
        let frameCount = Int(sampleRate * duration)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else { return }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else { return }

        buffer.frameLength = AVAudioFrameCount(frameCount)

        let leftChannel = buffer.floatChannelData?[0]
        let rightChannel = buffer.floatChannelData?[1]

        // Generate noise based on sound type
        for frame in 0..<frameCount {
            var sample: Float = 0

            switch sound {
            case .rain:
                // Pink-ish noise for rain (filtered random)
                sample = Float.random(in: -0.3...0.3)
                // Simple low-pass filter approximation
                if frame > 0 {
                    let prev = leftChannel?[frame - 1] ?? 0
                    sample = prev * 0.7 + sample * 0.3
                }
            case .ocean:
                // Slower wave-like modulation
                let wave = sin(Double(frame) / sampleRate * 0.1 * .pi * 2) * 0.5 + 0.5
                sample = Float.random(in: -0.25...0.25) * Float(wave)
                if frame > 0 {
                    let prev = leftChannel?[frame - 1] ?? 0
                    sample = prev * 0.8 + sample * 0.2
                }
            case .forest:
                // Light ambient with occasional "chirps"
                sample = Float.random(in: -0.15...0.15)
                // Add occasional higher frequency bursts
                if Int.random(in: 0..<10000) < 5 {
                    sample += Float.random(in: -0.2...0.2)
                }
                if frame > 0 {
                    let prev = leftChannel?[frame - 1] ?? 0
                    sample = prev * 0.6 + sample * 0.4
                }
            case .silence:
                sample = 0
            }

            // Full-scale samples — playFromURL applies `volume` on the player;
            // baking it in here too made the fallback play at volume².
            leftChannel?[frame] = sample
            rightChannel?[frame] = sample
        }

        // Write buffer to temporary file and play
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(sound.rawValue.lowercased())_generated.wav")

        do {
            // Remove existing file if any
            try? FileManager.default.removeItem(at: tempURL)

            let audioFile = try AVAudioFile(forWriting: tempURL, settings: format.settings)
            try audioFile.write(from: buffer)

            playFromURL(tempURL, sound: sound)
        } catch {
            #if DEBUG
            print("Failed to create generated audio: \(error)")
            #endif
        }
    }
}
