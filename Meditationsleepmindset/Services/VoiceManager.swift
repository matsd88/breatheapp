//
//  VoiceManager.swift
//  Meditation Sleep Mindset
//
//  Voice mode for the AI chat: speech-to-text dictation (SFSpeechRecognizer) and
//  spoken assistant replies. Premium subscribers get a natural OpenAI TTS voice
//  (matched to the selected coach, cached per reply); free users — and any
//  offline/failure case — use the on-device AVSpeechSynthesizer (no API cost).
//
//  Requires Info.plist keys:
//    NSMicrophoneUsageDescription, NSSpeechRecognitionUsageDescription
//

import Foundation
import AVFoundation
import Speech

@MainActor
final class VoiceManager: NSObject, ObservableObject {
    static let shared = VoiceManager()

    @Published var isRecording = false
    @Published var isSpeaking = false
    @Published var partialTranscript = ""
    @Published var permissionDenied = false

    /// The chat message currently being spoken (either voice path), if any.
    @Published var speakingMessageID: UUID?
    /// The chat message whose premium audio is being fetched, if any.
    @Published var loadingSpeechMessageID: UUID?

    /// Whether assistant replies should be read aloud (persisted).
    @Published var voiceOutputEnabled: Bool {
        didSet { UserDefaults.standard.set(voiceOutputEnabled, forKey: "voiceOutputEnabled") }
    }

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var speechFetchTask: Task<Void, Never>?
    private var didPruneSpeechCache = false

    /// Called when a final transcript is ready (e.g. to populate / send the message).
    var onFinalTranscript: ((String) -> Void)?

    private override init() {
        self.voiceOutputEnabled = UserDefaults.standard.bool(forKey: "voiceOutputEnabled")
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Permissions

    func requestPermissions() async -> Bool {
        let speechOK = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechOK else { return false }

        let micOK = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        return micOK
    }

    // MARK: - Dictation

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            Task { await startRecording() }
        }
    }

    func startRecording() async {
        guard !isRecording else { return }

        // Stop any spoken reply first
        stopSpeaking()

        let granted = await requestPermissions()
        guard granted, let recognizer, recognizer.isAvailable else {
            permissionDenied = true
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            recognitionRequest = request

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            partialTranscript = ""
            isRecording = true

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let result {
                        self.partialTranscript = result.bestTranscription.formattedString
                        if result.isFinal {
                            self.finishRecording(send: true)
                        }
                    }
                    if error != nil {
                        self.finishRecording(send: !self.partialTranscript.isEmpty)
                    }
                }
            }
        } catch {
            cleanupAudio()
            isRecording = false
            permissionDenied = true
        }
    }

    func stopRecording() {
        finishRecording(send: true)
    }

    func cancelRecording() {
        finishRecording(send: false)
    }

    private func finishRecording(send: Bool) {
        guard isRecording else { return }
        let final = partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanupAudio()
        isRecording = false
        if send, !final.isEmpty {
            onFinalTranscript?(final)
        }
        partialTranscript = ""
    }

    private func cleanupAudio() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        // Release the record session so playback owners can reclaim it.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Speaking replies

    /// Read a reply aloud. Premium subscribers get a natural OpenAI TTS voice matched
    /// to the coach persona (audio cached per reply); free users — and any offline or
    /// failed-request case — automatically fall back to the on-device synthesizer.
    func speak(_ text: String, messageID: UUID? = nil, coach: WellnessCoach = .general) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        // One voice at a time: stop anything playing and cancel in-flight fetches.
        stopSpeaking()

        // Natural voice only for subscribers, online, and reasonable lengths
        // (OpenAI TTS caps input at 4096 chars).
        guard StoreManager.shared.isSubscribed,
              NetworkMonitor.shared.isConnected,
              clean.count <= 4000 else {
            speakWithSynthesizer(clean, messageID: messageID)
            return
        }

        pruneSpeechCacheIfNeeded()

        let cacheURL = Self.speechCacheURL(text: clean, voice: coach.ttsVoice, speed: coach.ttsSpeed)
        loadingSpeechMessageID = messageID

        speechFetchTask = Task { [weak self] in
            var data: Data?
            if FileManager.default.fileExists(atPath: cacheURL.path) {
                data = try? Data(contentsOf: cacheURL)
            }

            if data == nil {
                data = try? await OpenAIProxyService.generateSpeech(
                    text: clean,
                    voice: coach.ttsVoice,
                    speed: coach.ttsSpeed
                )
                if let fetched = data {
                    try? fetched.write(to: cacheURL)
                }
            }

            guard let self, !Task.isCancelled else { return }
            self.loadingSpeechMessageID = nil
            self.speechFetchTask = nil

            if let data, self.playSpeechData(data, messageID: messageID) {
                return
            }
            // Bad cache file? Drop it so the next attempt refetches.
            try? FileManager.default.removeItem(at: cacheURL)
            // Fall back to the robotic-but-reliable on-device voice.
            self.speakWithSynthesizer(clean, messageID: messageID)
        }
    }

    /// Configure the shared audio session for a spoken reply — but only when
    /// nothing else in the app is playing. The meditation player and ambient
    /// engines own their own category configs (.spokenAudio/.allowAirPlay,
    /// .mixWithOthers); clobbering them with a bare .playback/.duckOthers
    /// broke AirPlay/mixing until those engines reconfigured.
    private func configureSpeechSessionIfIdle() {
        guard !AudioPlayerManager.shared.isPlaying else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// On-device AVSpeechSynthesizer path (free tier + fallback).
    private func speakWithSynthesizer(_ text: String, messageID: UUID?) {
        configureSpeechSessionIfIdle()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.94
        utterance.pitchMultiplier = 1.0
        isSpeaking = true
        speakingMessageID = messageID
        synthesizer.speak(utterance)
    }

    /// Play fetched/cached TTS audio. Returns false if the data can't be decoded.
    private func playSpeechData(_ data: Data, messageID: UUID?) -> Bool {
        configureSpeechSessionIfIdle()

        guard let player = try? AVAudioPlayer(data: data) else { return false }
        player.delegate = self
        audioPlayer = player
        isSpeaking = true
        speakingMessageID = messageID
        player.play()
        return true
    }

    func stopSpeaking() {
        speechFetchTask?.cancel()
        speechFetchTask = nil
        loadingSpeechMessageID = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        audioPlayer?.stop()
        audioPlayer = nil
        isSpeaking = false
        speakingMessageID = nil
    }

    // MARK: - Speech cache (premium TTS audio, keyed by voice + speed + text hash)

    private static var speechCacheDirectory: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ChatSpeech", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func speechCacheURL(text: String, voice: String, speed: Double) -> URL {
        speechCacheDirectory.appendingPathComponent("\(voice)_\(Int(speed * 100))_\(text.stableHash).mp3")
    }

    /// Drop cached reply audio older than 7 days (once per launch).
    private func pruneSpeechCacheIfNeeded() {
        guard !didPruneSpeechCache else { return }
        didPruneSpeechCache = true
        let dir = Self.speechCacheDirectory
        Task.detached(priority: .utility) {
            let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            let files = (try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey]
            )) ?? []
            for file in files {
                let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                if let modified, modified < cutoff {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }
    }
}

extension VoiceManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.audioPlayer = nil
            self.isSpeaking = false
            self.speakingMessageID = nil
        }
    }
}

extension VoiceManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.speakingMessageID = nil
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.speakingMessageID = nil
        }
    }
}
