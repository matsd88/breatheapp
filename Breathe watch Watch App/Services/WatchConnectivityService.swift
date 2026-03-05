//
//  WatchConnectivityService.swift
//  MeditationWatch
//
//  Handles communication between Watch and iOS app
//

import Foundation
import Combine
import WatchConnectivity
import WatchKit

@MainActor
class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    @Published var syncData = WatchSyncData()
    @Published var isReachable = false
    @Published var isPhoneAppInstalled = false

    private var session: WCSession?

    private override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    // MARK: - Request Sync

    func requestSync() {
        guard let session, session.isReachable else {
            // Try to get cached data from UserDefaults
            loadCachedData()
            return
        }

        let message: [String: Any] = [
            WatchMessageKey.messageType: WatchMessageType.requestSync.rawValue
        ]

        session.sendMessage(message, replyHandler: { [weak self] reply in
            Task { @MainActor in
                if let data = WatchSyncData.from(dictionary: reply) {
                    self?.syncData = data
                    self?.cacheData(data)
                }
            }
        }, errorHandler: { error in
            #if DEBUG
            print("Watch: Failed to request sync: \(error)")
            #endif
        })
    }

    // MARK: - Playback Commands

    func sendPlaybackCommand(_ command: PlaybackCommand) {
        guard let session, session.isReachable else { return }

        let message: [String: Any] = [
            WatchMessageKey.messageType: WatchMessageType.playbackCommand.rawValue,
            WatchMessageKey.command: command.rawValue
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            #if DEBUG
            print("Watch: Failed to send playback command: \(error)")
            #endif
        }

        // Play haptic feedback
        WKInterfaceDevice.current().play(.click)
    }

    // MARK: - Breathing Session Complete

    func sendBreathingSessionComplete(durationSeconds: Int) {
        guard let session else { return }

        let message: [String: Any] = [
            WatchMessageKey.messageType: WatchMessageType.breathingSessionComplete.rawValue,
            WatchMessageKey.breathingDuration: durationSeconds
        ]

        // Use transferUserInfo for reliability (works even when phone is not reachable)
        session.transferUserInfo(message)

        // Play success haptic
        WKInterfaceDevice.current().play(.success)
    }

    // MARK: - Start Breathing on Phone

    func startBreathingOnPhone() {
        guard let session, session.isReachable else { return }

        let message: [String: Any] = [
            WatchMessageKey.messageType: WatchMessageType.startBreathingOnPhone.rawValue
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            #if DEBUG
            print("Watch: Failed to start breathing on phone: \(error)")
            #endif
        }
    }

    // MARK: - Caching

    private func cacheData(_ data: WatchSyncData) {
        let defaults = UserDefaults.standard
        defaults.set(data.currentStreak, forKey: "cached_streak")
        defaults.set(data.totalMinutes, forKey: "cached_totalMinutes")
        defaults.set(data.mindfulMinutesToday, forKey: "cached_mindfulMinutesToday")
        if let lastSession = data.lastSessionDate {
            defaults.set(lastSession, forKey: "cached_lastSessionDate")
        }
    }

    private func loadCachedData() {
        let defaults = UserDefaults.standard
        syncData = WatchSyncData(
            currentStreak: defaults.integer(forKey: "cached_streak"),
            totalMinutes: defaults.integer(forKey: "cached_totalMinutes"),
            mindfulMinutesToday: defaults.integer(forKey: "cached_mindfulMinutesToday"),
            lastSessionDate: defaults.object(forKey: "cached_lastSessionDate") as? Date
        )
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isReachable = session.isReachable

            #if os(watchOS)
            self.isPhoneAppInstalled = session.isCompanionAppInstalled
            #endif

            if activationState == .activated {
                self.requestSync()
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            if session.isReachable {
                self.requestSync()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            self.handleMessage(message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            self.handleMessage(message)
            replyHandler([:])
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            if let data = WatchSyncData.from(dictionary: applicationContext) {
                self.syncData = data
                self.cacheData(data)
            }
        }
    }

    @MainActor
    private func handleMessage(_ message: [String: Any]) {
        guard let typeRaw = message[WatchMessageKey.messageType] as? String,
              let type = WatchMessageType(rawValue: typeRaw) else { return }

        switch type {
        case .syncData:
            if let data = WatchSyncData.from(dictionary: message) {
                syncData = data
                cacheData(data)
            }

        case .playbackStateUpdate:
            if let stateRaw = message[WatchMessageKey.playbackState] as? String,
               let state = PlaybackState(rawValue: stateRaw) {
                var updatedData = syncData
                updatedData = WatchSyncData(
                    currentStreak: syncData.currentStreak,
                    totalMinutes: syncData.totalMinutes,
                    mindfulMinutesToday: syncData.mindfulMinutesToday,
                    lastSessionDate: syncData.lastSessionDate,
                    recentSessions: syncData.recentSessions,
                    playbackState: state,
                    currentContentTitle: message[WatchMessageKey.currentContentTitle] as? String ?? syncData.currentContentTitle,
                    currentContentDuration: message[WatchMessageKey.currentContentDuration] as? Int ?? syncData.currentContentDuration,
                    currentPlaybackTime: message[WatchMessageKey.currentPlaybackTime] as? Int ?? syncData.currentPlaybackTime
                )
                syncData = updatedData
            }

        default:
            break
        }
    }
}
