//
//  BinauralToneGenerator.swift
//  Meditation Sleep Mindset
//
//  Synthesizes binaural beats in real time (no audio assets): a carrier tone in each
//  ear with a small frequency offset creates the "beat" the brain perceives. Use with
//  headphones for the binaural effect.
//

import Foundation
import AVFoundation

enum BinauralPreset: String, CaseIterable, Identifiable {
    case delta      // deep sleep
    case theta      // deep relaxation / meditation
    case alpha      // calm focus
    case calm       // gentle wind-down

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .delta: return String(localized: "Deep Sleep")
        case .theta: return String(localized: "Relaxation")
        case .alpha: return String(localized: "Calm Focus")
        case .calm: return String(localized: "Wind Down")
        }
    }

    var subtitle: String {
        switch self {
        case .delta: return String(localized: "Delta · 2 Hz")
        case .theta: return String(localized: "Theta · 6 Hz")
        case .alpha: return String(localized: "Alpha · 10 Hz")
        case .calm: return String(localized: "Theta · 4 Hz")
        }
    }

    var icon: String {
        switch self {
        case .delta: return "moon.zzz.fill"
        case .theta: return "brain.head.profile"
        case .alpha: return "target"
        case .calm: return "leaf.fill"
        }
    }

    /// Carrier frequency (Hz) and beat (difference) frequency (Hz).
    var carrier: Double {
        switch self {
        case .delta: return 180
        case .theta: return 200
        case .alpha: return 210
        case .calm: return 190
        }
    }

    var beat: Double {
        switch self {
        case .delta: return 2
        case .theta: return 6
        case .alpha: return 10
        case .calm: return 4
        }
    }
}

/// Plain (non-isolated) holder for the audio render loop's mutable state.
private final class BinauralRenderState {
    var leftPhase: Double = 0
    var rightPhase: Double = 0
    var leftIncrement: Double = 0
    var rightIncrement: Double = 0
    var amplitude: Float = 0.25
}

@MainActor
final class BinauralToneGenerator: ObservableObject {
    static let shared = BinauralToneGenerator()

    @Published var isPlaying = false
    @Published var currentPreset: BinauralPreset?

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let sampleRate: Double = 44100

    /// Render state lives in a plain reference type so the real-time audio thread never
    /// touches @MainActor-isolated storage (which would be a data race).
    private let render = BinauralRenderState()

    private init() {}

    func play(_ preset: BinauralPreset) {
        stop()

        // Configure render state BEFORE the node is attached/started.
        render.leftIncrement = preset.carrier / sampleRate
        render.rightIncrement = (preset.carrier + preset.beat) / sampleRate
        render.leftPhase = 0
        render.rightPhase = 0

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let state = render

        let node = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let twoPi = 2.0 * Double.pi
            // Snapshot to locals for the render loop.
            var lPhase = state.leftPhase
            var rPhase = state.rightPhase
            let lInc = state.leftIncrement
            let rInc = state.rightIncrement
            let amp = state.amplitude

            for frame in 0..<Int(frameCount) {
                let lSample = Float(sin(lPhase * twoPi)) * amp
                let rSample = Float(sin(rPhase * twoPi)) * amp
                lPhase += lInc; if lPhase > 1 { lPhase -= 1 }
                rPhase += rInc; if rPhase > 1 { rPhase -= 1 }

                if abl.count >= 2 {
                    let left = abl[0].mData!.assumingMemoryBound(to: Float.self)
                    let right = abl[1].mData!.assumingMemoryBound(to: Float.self)
                    left[frame] = lSample
                    right[frame] = rSample
                } else if let mono = abl.first?.mData?.assumingMemoryBound(to: Float.self) {
                    mono[frame] = (lSample + rSample) * 0.5
                }
            }
            state.leftPhase = lPhase
            state.rightPhase = rPhase
            return noErr
        }

        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            isPlaying = true
            currentPreset = preset
        } catch {
            stop()
        }
    }

    func stop() {
        if engine.isRunning {
            engine.stop()
        }
        if let node = sourceNode {
            engine.detach(node)
            sourceNode = nil
        }
        isPlaying = false
        currentPreset = nil
    }
}
