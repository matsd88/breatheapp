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

    var fileName: String? {
        switch self {
        case .rain: return "rain"
        case .ocean: return "ocean"
        case .forest: return "forest"
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

class AmbientSoundService: ObservableObject {
    static let shared = AmbientSoundService()

    @Published var isPlaying = false
    @Published var currentSound: TimerAmbientSound?
    @Published var volume: Float = 0.7

    private var audioPlayer: AVAudioPlayer?

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

    func play(sound: TimerAmbientSound) {
        // Stop any currently playing sound
        stop()

        // Silence means no sound
        guard sound != .silence else {
            currentSound = .silence
            return
        }

        guard let fileName = sound.fileName else { return }

        // Try to load from bundle
        if let url = Bundle.main.url(forResource: fileName, withExtension: "mp3") {
            playFromURL(url, sound: sound)
        } else if let url = Bundle.main.url(forResource: fileName, withExtension: "m4a") {
            playFromURL(url, sound: sound)
        } else if let url = Bundle.main.url(forResource: fileName, withExtension: "wav") {
            playFromURL(url, sound: sound)
        } else {
            // If no local file, use a placeholder/generated sound
            #if DEBUG
            print("No audio file found for \(sound.rawValue), using generated audio")
            #endif
            playGeneratedSound(for: sound)
        }
    }

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
        // Generate white/pink noise as fallback
        // For now, we'll create a simple audio buffer with noise

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

            leftChannel?[frame] = sample * volume
            rightChannel?[frame] = sample * volume
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

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentSound = nil
    }

    func setVolume(_ newVolume: Float) {
        volume = max(0, min(1, newVolume))
        audioPlayer?.volume = volume
    }

    func fadeOut(duration: TimeInterval = 2.0, completion: (() -> Void)? = nil) {
        guard let player = audioPlayer else {
            completion?()
            return
        }

        let steps = 20
        let interval = duration / Double(steps)
        let volumeStep = player.volume / Float(steps)

        var currentStep = 0

        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            currentStep += 1
            player.volume -= volumeStep

            if currentStep >= steps {
                timer.invalidate()
                self?.stop()
                completion?()
            }
        }
    }
}
