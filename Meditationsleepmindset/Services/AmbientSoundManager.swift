//
//  AmbientSoundManager.swift
//  Meditation Sleep Mindset
//

import Foundation
import AVFoundation
import Combine

struct AmbientSound: Identifiable, Hashable {
    let id: String
    let name: String
    let iconName: String
    let youtubeVideoID: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AmbientSound, rhs: AmbientSound) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
class AmbientSoundManager: ObservableObject {
    static let shared = AmbientSoundManager()

    @Published var activeSounds: Set<String> = []
    @Published var volumes: [String: Double] = [:]
    @Published var isLoading: [String: Bool] = [:]
    @Published var errors: [String: String] = [:]
    @Published var sleepModeEnabled: Bool = false
    @Published var sleepModeDuration: TimeInterval = 30 * 60 // default 30 min

    private var players: [String: AVPlayer] = [:]
    private var playerObservers: [String: Any] = [:]
    private var loopObservers: [String: NSObjectProtocol] = [:]
    private var sleepModeTimer: Timer?
    private var sleepModeStartTime: Date?
    private var originalVolumes: [String: Double] = [:]
    /// Per-sound fade-IN timers (keyed by sound id). Fade-out uses detached timers.
    private var fadeTimers: [String: Timer] = [:]
    private let fadeSteps = 16

    let availableSounds: [AmbientSound] = [
        AmbientSound(id: "rain", name: "Rain", iconName: "cloud.rain.fill", youtubeVideoID: "yIQd2Ya0Ziw"),
        AmbientSound(id: "ocean", name: "Ocean Waves", iconName: "water.waves", youtubeVideoID: "WHPEKLQID4U"),
        AmbientSound(id: "forest", name: "Forest", iconName: "leaf.fill", youtubeVideoID: "xNN7iTA57jM"),
        AmbientSound(id: "fireplace", name: "Fireplace", iconName: "flame.fill", youtubeVideoID: "L_LUpnjgPso"),
        AmbientSound(id: "wind", name: "Wind", iconName: "wind", youtubeVideoID: "2rKoL_JBvZU"),
        AmbientSound(id: "thunder", name: "Thunder", iconName: "cloud.bolt.fill", youtubeVideoID: "nDq6TstdEi8"),
        AmbientSound(id: "birds", name: "Birds", iconName: "bird.fill", youtubeVideoID: "rYoZgpAEkFs"),
        AmbientSound(id: "whitenoise", name: "White Noise", iconName: "waveform", youtubeVideoID: "nMfPqeZjc2c")
    ]

    private init() {
        setupAudioSession()
        prefetchAllSoundURLs()
    }

    /// Pre-fetch all ambient sound stream URLs at launch so toggling is instant
    private func prefetchAllSoundURLs() {
        let videoIDs = availableSounds.map { $0.youtubeVideoID }
        Task.detached(priority: .utility) {
            await YouTubeService.shared.prefetchStreamURLs(for: videoIDs, audioOnly: true)
            #if DEBUG
            print("[AmbientSoundManager] Prefetched all ambient sound URLs")
            #endif
        }
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            #if DEBUG
            print("Failed to set up audio session for ambient sounds: \(error)")
            #endif
        }
    }

    func toggleSound(_ sound: AmbientSound) {
        if activeSounds.contains(sound.id) {
            stopSound(sound)
            HapticManager.light()
        } else if activeSounds.count < 3 {
            playSound(sound)
            HapticManager.medium()
        } else {
            // At 3-sound limit — tell the user
            HapticManager.error()
            ToastManager.shared.show(
                "Max 3 sounds at once",
                icon: "speaker.wave.3.fill",
                style: .standard
            )
        }
    }

    func playSound(_ sound: AmbientSound) {
        guard !activeSounds.contains(sound.id) else { return }

        isLoading[sound.id] = true
        errors[sound.id] = nil

        Task {
            do {
                // Check file cache first (instant), then stream URL cache, then extract
                let url: URL
                if let cachedFile = await VideoCache.shared.getCachedURL(for: sound.youtubeVideoID, audioOnly: true) {
                    url = cachedFile
                } else {
                    url = try await YouTubeService.shared.getStreamURL(
                        for: sound.youtubeVideoID,
                        audioOnly: true
                    )
                }

                await MainActor.run {
                    setupPlayer(for: sound, with: url)
                }
            } catch {
                await MainActor.run {
                    self.errors[sound.id] = error.localizedDescription
                    self.isLoading[sound.id] = false
                }
            }
        }
    }

    private func setupPlayer(for sound: AmbientSound, with url: URL) {
        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: false
        ])
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 2.0

        let player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = false

        // Start silent and fade in for a smooth entrance.
        player.volume = 0

        // Store player
        players[sound.id] = player

        // Loop the audio when it ends
        let observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }
        loopObservers[sound.id] = observer

        // Start playing
        player.play()
        activeSounds.insert(sound.id)
        isLoading[sound.id] = false

        // Set default volume if not set
        if volumes[sound.id] == nil {
            volumes[sound.id] = 0.5
        }

        // Fade in to the target volume.
        fadeIn(soundID: sound.id, player: player, to: Float(volumes[sound.id] ?? 0.5))
    }

    /// Smoothly ramp a freshly-started player up to its target volume.
    private func fadeIn(soundID: String, player: AVPlayer, to target: Float) {
        fadeTimers[soundID]?.invalidate()
        var step = 0
        fadeTimers[soundID] = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            Task { @MainActor in
                step += 1
                player.volume = target * Float(step) / Float(self?.fadeSteps ?? 16)
                if step >= (self?.fadeSteps ?? 16) {
                    player.volume = target
                    timer.invalidate()
                    self?.fadeTimers[soundID] = nil
                }
            }
        }
    }

    func stopSound(_ sound: AmbientSound) {
        guard let player = players[sound.id] else { return }

        // Cancel any in-progress fade-in.
        fadeTimers[sound.id]?.invalidate()
        fadeTimers[sound.id] = nil

        // Detach from shared state immediately (UI shows off; id can be reused cleanly).
        if let observer = loopObservers[sound.id] {
            NotificationCenter.default.removeObserver(observer)
            loopObservers.removeValue(forKey: sound.id)
        }
        players.removeValue(forKey: sound.id)
        activeSounds.remove(sound.id)
        isLoading[sound.id] = false

        // Gracefully fade the detached player out, then pause it. The timer retains
        // `player` until it finishes, so this can't race a new playSound for the same id.
        let start = player.volume
        var step = 0
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            Task { @MainActor in
                let steps = self?.fadeSteps ?? 16
                step += 1
                player.volume = max(0, start * Float(steps - step) / Float(steps))
                if step >= steps {
                    timer.invalidate()
                    player.pause()
                }
            }
        }
    }

    func setVolume(for sound: AmbientSound, volume: Double) {
        // A manual change wins over an in-progress fade-in.
        fadeTimers[sound.id]?.invalidate()
        fadeTimers[sound.id] = nil
        volumes[sound.id] = volume
        players[sound.id]?.volume = Float(volume)
    }

    func resetAll() {
        if sleepModeEnabled {
            sleepModeTimer?.invalidate()
            sleepModeTimer = nil
            sleepModeEnabled = false
            sleepModeStartTime = nil
            originalVolumes.removeAll()
        }
        for sound in availableSounds {
            if activeSounds.contains(sound.id) {
                stopSound(sound)
            }
        }
        volumes.removeAll()
    }

    func stopAll() {
        for sound in availableSounds {
            if activeSounds.contains(sound.id) {
                stopSound(sound)
            }
        }
    }

    func isActive(_ sound: AmbientSound) -> Bool {
        activeSounds.contains(sound.id)
    }

    // MARK: - Saved Mixes

    /// Snapshot of the currently active sounds and their volumes (for saving a mix).
    func currentMixSnapshot() -> [String: Double] {
        var result: [String: Double] = [:]
        for id in activeSounds {
            result[id] = volumes[id] ?? volume(for: AmbientSound(id: id, name: "", iconName: "", youtubeVideoID: ""))
        }
        return result
    }

    /// Replace the current mix with a saved one: stops everything, then plays the saved
    /// sounds at their saved volumes (respecting the 3-sound limit).
    func applyMix(_ mix: [String: Double]) {
        stopAll()
        // Re-add up to 3 sounds in a stable order.
        let entries = mix.sorted { $0.key < $1.key }.prefix(3)
        for (soundID, vol) in entries {
            guard let sound = availableSounds.first(where: { $0.id == soundID }) else { continue }
            // setupPlayer reads volumes[soundID] for its fade-in target, so set it before playing.
            volumes[soundID] = vol
            playSound(sound)
        }
    }

    func volume(for sound: AmbientSound) -> Double {
        volumes[sound.id] ?? 0.5
    }

    func isLoadingSound(_ sound: AmbientSound) -> Bool {
        isLoading[sound.id] ?? false
    }

    // MARK: - Sleep Mode

    func enableSleepMode(duration: TimeInterval) {
        let wasEnabled = sleepModeEnabled
        sleepModeDuration = duration
        sleepModeEnabled = true
        sleepModeStartTime = Date()

        // Capture the restore baseline only on first entry — re-tapping a duration while
        // already fading must not overwrite it with already-lowered volumes.
        if !wasEnabled {
            originalVolumes = volumes
        }

        // Start a timer that fires every second to manage the fade
        sleepModeTimer?.invalidate()
        sleepModeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sleepModeTimerTick()
            }
        }
    }

    func disableSleepMode() {
        sleepModeTimer?.invalidate()
        sleepModeTimer = nil
        sleepModeEnabled = false
        sleepModeStartTime = nil

        // Restore original volumes
        for (soundID, volume) in originalVolumes {
            volumes[soundID] = volume
            players[soundID]?.volume = Float(volume)
        }
        originalVolumes.removeAll()
    }

    private func sleepModeTimerTick() {
        guard sleepModeEnabled, let startTime = sleepModeStartTime else { return }

        let elapsed = Date().timeIntervalSince(startTime)
        let fadeStartPoint = sleepModeDuration * 0.7 // Start fading at 70%
        let remaining = sleepModeDuration - elapsed

        if remaining <= 0 {
            // Time's up — stop all sounds and clean up sleep mode state
            sleepModeTimer?.invalidate()
            sleepModeTimer = nil
            sleepModeEnabled = false
            sleepModeStartTime = nil
            originalVolumes.removeAll()
            stopAll()
            return
        }

        if elapsed >= fadeStartPoint {
            // In the fade zone — gradually reduce volume
            let fadeZoneDuration = sleepModeDuration * 0.3
            let fadeElapsed = elapsed - fadeStartPoint
            let fadeFraction = 1.0 - (fadeElapsed / fadeZoneDuration) // 1.0 → 0.0

            for (soundID, originalVolume) in originalVolumes {
                let newVolume = originalVolume * max(0, fadeFraction)
                volumes[soundID] = newVolume
                players[soundID]?.volume = Float(newVolume)
            }

            // Drop sounds one by one as volume gets low
            let activeSoundIDs = Array(activeSounds).sorted()
            if fadeFraction < 0.3 && activeSoundIDs.count > 2 {
                // Drop the first sound
                if let soundToStop = availableSounds.first(where: { $0.id == activeSoundIDs.first }) {
                    stopSound(soundToStop)
                }
            } else if fadeFraction < 0.15 && activeSoundIDs.count > 1 {
                // Drop another sound
                if let soundToStop = availableSounds.first(where: { $0.id == activeSoundIDs.first }) {
                    stopSound(soundToStop)
                }
            }
        }
    }
}
