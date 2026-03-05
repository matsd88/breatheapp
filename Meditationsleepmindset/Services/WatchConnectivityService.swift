//
//  WatchConnectivityService.swift
//  Meditation Sleep Mindset
//
//  iOS-side service for Watch communication
//

import Foundation
import SwiftData

#if os(iOS)
import WatchConnectivity

@MainActor
class PhoneWatchConnectivityService: NSObject, ObservableObject {
    static let shared = PhoneWatchConnectivityService()

    @Published var isWatchAppInstalled = false
    @Published var isWatchReachable = false

    private var session: WCSession?
    private var modelContext: ModelContext?

    private override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Send Sync Data

    func sendSyncData() {
        guard let session, session.activationState == .activated else { return }

        let syncData = buildSyncData()
        let dict = syncData.toDictionary()

        // Update application context (persists and syncs when watch connects)
        do {
            try session.updateApplicationContext(dict)
        } catch {
            #if DEBUG
            print("iOS: Failed to update application context: \(error)")
            #endif
        }

        // Also send message if reachable
        if session.isReachable {
            session.sendMessage(dict, replyHandler: nil) { error in
                #if DEBUG
                print("iOS: Failed to send sync data: \(error)")
                #endif
            }
        }
    }

    // MARK: - Send Playback State

    func sendPlaybackStateUpdate(state: PlaybackState, title: String?, duration: Int?, currentTime: Int?) {
        guard let session, session.isReachable else { return }

        var message: [String: Any] = [
            WatchMessageKey.messageType: WatchMessageType.playbackStateUpdate.rawValue,
            WatchMessageKey.playbackState: state.rawValue
        ]

        if let title { message[WatchMessageKey.currentContentTitle] = title }
        if let duration { message[WatchMessageKey.currentContentDuration] = duration }
        if let currentTime { message[WatchMessageKey.currentPlaybackTime] = currentTime }

        session.sendMessage(message, replyHandler: nil) { error in
            #if DEBUG
            print("iOS: Failed to send playback state: \(error)")
            #endif
        }
    }

    // MARK: - Build Sync Data

    private func buildSyncData() -> WatchSyncData {
        let streakService = StreakService.shared

        var recentSessions: [WatchRecentSession] = []

        // Fetch recent sessions from SwiftData
        if let context = modelContext {
            let descriptor = FetchDescriptor<MeditationSession>(
                predicate: #Predicate { $0.wasCompleted == true },
                sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
            )
            if let sessions = try? context.fetch(descriptor) {
                recentSessions = Array(sessions.prefix(5)).compactMap { session in
                    guard let completedAt = session.completedAt else { return nil }
                    return WatchRecentSession(
                        id: session.id.uuidString,
                        title: session.contentTitle ?? "Session",
                        contentType: session.sessionType == "breathing" ? "Breathing" : "Meditation",
                        durationSeconds: session.durationSeconds,
                        completedAt: completedAt
                    )
                }
            }
        }

        // Get playback state
        let playerManager = AudioPlayerManager.shared
        let playbackState: PlaybackState
        if playerManager.isPlaying {
            playbackState = .playing
        } else if playerManager.currentContent != nil {
            playbackState = .paused
        } else {
            playbackState = .stopped
        }

        return WatchSyncData(
            currentStreak: streakService.currentStreak,
            totalMinutes: streakService.totalMinutes,
            mindfulMinutesToday: getMindfulMinutesToday(),
            lastSessionDate: streakService.lastSessionDate,
            recentSessions: recentSessions,
            playbackState: playbackState,
            currentContentTitle: playerManager.currentContent?.title,
            currentContentDuration: playerManager.currentContent?.durationSeconds,
            currentPlaybackTime: Int(playerManager.currentTime)
        )
    }

    private func getMindfulMinutesToday() -> Int {
        // Sum up today's session minutes from StreakService weekly activity
        let today = Calendar.current.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: today)

        let weeklyMinutes = UserDefaults.standard.dictionary(forKey: "weeklyMinutes") as? [String: Int] ?? [:]
        return weeklyMinutes[todayKey] ?? 0
    }

    // MARK: - Handle Breathing Session Complete

    private func handleBreathingSessionComplete(durationSeconds: Int) {
        let minutes = max(1, durationSeconds / 60)

        // Record session
        StreakService.shared.recordSession(durationMinutes: minutes, context: modelContext)
        StreakService.shared.recordMinutesForToday(minutes)

        // Write to HealthKit
        let endTime = Date()
        let startTime = endTime.addingTimeInterval(-Double(durationSeconds))
        Task {
            await HealthKitService.shared.writeMindfulMinutes(start: startTime, end: endTime)
        }

        // Send updated data back to watch
        sendSyncData()
    }

    // MARK: - Handle Playback Command

    private func handlePlaybackCommand(_ command: PlaybackCommand) {
        let playerManager = AudioPlayerManager.shared

        switch command {
        case .play:
            playerManager.play()
        case .pause:
            playerManager.pause()
        case .skipForward:
            playerManager.skipForward(seconds: 15)
        case .skipBackward:
            playerManager.skipBackward(seconds: 15)
        case .stop:
            playerManager.stop()
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneWatchConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isWatchReachable = session.isReachable

            if activationState == .activated {
                self.sendSyncData()
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate for switching between watches
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            guard let typeRaw = message[WatchMessageKey.messageType] as? String,
                  let type = WatchMessageType(rawValue: typeRaw) else {
                replyHandler([:])
                return
            }

            switch type {
            case .requestSync:
                let syncData = self.buildSyncData()
                replyHandler(syncData.toDictionary())

            case .playbackCommand:
                if let commandRaw = message[WatchMessageKey.command] as? String,
                   let command = PlaybackCommand(rawValue: commandRaw) {
                    self.handlePlaybackCommand(command)
                }
                replyHandler([:])

            case .startBreathingOnPhone:
                // Post notification to open breathing exercise
                NotificationCenter.default.post(name: .openBreathingExercise, object: nil)
                replyHandler([:])

            default:
                replyHandler([:])
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in
            guard let typeRaw = userInfo[WatchMessageKey.messageType] as? String,
                  let type = WatchMessageType(rawValue: typeRaw) else { return }

            if type == .breathingSessionComplete {
                if let duration = userInfo[WatchMessageKey.breathingDuration] as? Int {
                    self.handleBreathingSessionComplete(durationSeconds: duration)
                }
            }
        }
    }
}

#endif

// MARK: - Notification Name

extension Notification.Name {
    static let openBreathingExercise = Notification.Name("openBreathingExercise")
}
