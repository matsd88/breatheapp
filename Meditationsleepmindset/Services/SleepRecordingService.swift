//
//  SleepRecordingService.swift
//  Meditation Sleep Mindset
//
//  Records the night using the microphone to METER loudness only — it detects
//  loud / snore-like events and a level timeline, then discards the audio file.
//  No raw audio is ever stored (privacy + storage).
//
//  Requires Info.plist NSMicrophoneUsageDescription (already present for voice mode)
//  and the `audio` UIBackgroundMode (already present) so metering continues while locked.
//

import Foundation
import AVFoundation
import SwiftData

@MainActor
final class SleepRecordingService: ObservableObject {
    static let shared = SleepRecordingService()

    @Published var isRecording = false
    @Published var elapsed: TimeInterval = 0
    @Published var currentLevel: Double = 0      // normalized 0...1 for the live meter
    @Published var eventCount = 0
    @Published var permissionDenied = false

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var startDate: Date?
    private var tempURL: URL?

    // Event detection: a loud sample sustained above threshold, with a refractory gap
    // so one snore isn't counted many times.
    private let levelThreshold: Double = 0.55      // normalized loudness that counts as "loud"
    private var aboveThresholdStreak = 0
    private var ticksSinceLastEvent = 0
    private let minTicksBetweenEvents = 3          // ~3s refractory at 1Hz sampling

    // Downsampled timeline (one averaged sample per ~2 minutes of recording).
    private var timeline: [Double] = []
    private var bucketSum: Double = 0
    private var bucketCount = 0
    private let ticksPerBucket = 120               // 120s at 1Hz

    private init() {}

    func requestPermission() async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
    }

    func start() async {
        guard !isRecording else { return }
        guard await requestPermission() else {
            permissionDenied = true
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker])
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory.appendingPathComponent("sleep_metering.caf")
            tempURL = url
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatAppleLossless),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
            ]
            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.isMeteringEnabled = true
            rec.record()
            recorder = rec

            // Reset state
            startDate = Date()
            elapsed = 0
            eventCount = 0
            currentLevel = 0
            timeline = []
            bucketSum = 0
            bucketCount = 0
            aboveThresholdStreak = 0
            ticksSinceLastEvent = minTicksBetweenEvents
            isRecording = true

            meterTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
        } catch {
            isRecording = false
            permissionDenied = true
        }
    }

    private func tick() {
        guard let rec = recorder, let start = startDate else { return }
        rec.updateMeters()
        elapsed = Date().timeIntervalSince(start)

        // Convert dB (−160...0) to a normalized 0...1 loudness.
        let power = Double(rec.averagePower(forChannel: 0))
        let normalized = max(0, min(1, (power + 60) / 60))   // treat −60 dB as silence floor
        currentLevel = normalized

        // Event detection with refractory period.
        ticksSinceLastEvent += 1
        if normalized >= levelThreshold {
            aboveThresholdStreak += 1
            if aboveThresholdStreak >= 2 && ticksSinceLastEvent >= minTicksBetweenEvents {
                eventCount += 1
                ticksSinceLastEvent = 0
            }
        } else {
            aboveThresholdStreak = 0
        }

        // Timeline bucketing.
        bucketSum += normalized
        bucketCount += 1
        if bucketCount >= ticksPerBucket {
            timeline.append(bucketSum / Double(bucketCount))
            bucketSum = 0
            bucketCount = 0
        }
    }

    /// Stop recording, persist a summary session, and delete the audio file.
    @discardableResult
    func stop(context: ModelContext) -> SleepRecordingSession? {
        guard isRecording, let start = startDate else {
            cleanup()
            return nil
        }
        let end = Date()

        // Flush any partial bucket.
        if bucketCount > 0 {
            timeline.append(bucketSum / Double(bucketCount))
        }

        recorder?.stop()
        cleanup()

        let hours = max(0.1, end.timeIntervalSince(start) / 3600.0)
        let perHour = Double(eventCount) / hours
        let severity = SnoreSeverity.from(eventsPerHour: perHour)

        let session = SleepRecordingSession(
            startedAt: start,
            endedAt: end,
            eventCount: eventCount,
            severity: severity,
            levelTimeline: timeline
        )
        context.insert(session)
        try? context.save()
        return session
    }

    func cancel() {
        recorder?.stop()
        cleanup()
    }

    private func cleanup() {
        meterTimer?.invalidate()
        meterTimer = nil
        recorder = nil
        isRecording = false
        currentLevel = 0
        // Delete the metering audio — we never keep raw audio.
        if let url = tempURL {
            try? FileManager.default.removeItem(at: url)
        }
        tempURL = nil
        startDate = nil
        // Release the record session so playback owners can reclaim it.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    var elapsedFormatted: String {
        let total = Int(elapsed)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}
