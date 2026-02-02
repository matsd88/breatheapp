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

    private var players: [String: AVPlayer] = [:]
    private var playerObservers: [String: Any] = [:]
    private var loopObservers: [String: NSObjectProtocol] = [:]

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

        // Set initial volume
        let volume = volumes[sound.id] ?? 0.5
        player.volume = Float(volume)

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
    }

    func stopSound(_ sound: AmbientSound) {
        guard let player = players[sound.id] else { return }

        player.pause()

        // Remove loop observer
        if let observer = loopObservers[sound.id] {
            NotificationCenter.default.removeObserver(observer)
            loopObservers.removeValue(forKey: sound.id)
        }

        players.removeValue(forKey: sound.id)
        activeSounds.remove(sound.id)
        isLoading[sound.id] = false
    }

    func setVolume(for sound: AmbientSound, volume: Double) {
        volumes[sound.id] = volume
        players[sound.id]?.volume = Float(volume)
    }

    func resetAll() {
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

    func volume(for sound: AmbientSound) -> Double {
        volumes[sound.id] ?? 0.5
    }

    func isLoadingSound(_ sound: AmbientSound) -> Bool {
        isLoading[sound.id] ?? false
    }
}
