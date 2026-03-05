//
//  WatchSharedModels.swift
//  Meditation Sleep Mindset
//
//  Shared models for Watch-iOS communication
//

import Foundation
import CoreGraphics

// MARK: - Message Keys

enum WatchMessageKey {
    static let messageType = "messageType"
    static let streak = "streak"
    static let totalMinutes = "totalMinutes"
    static let mindfulMinutesToday = "mindfulMinutesToday"
    static let lastSessionDate = "lastSessionDate"
    static let recentSessions = "recentSessions"
    static let playbackState = "playbackState"
    static let currentContentTitle = "currentContentTitle"
    static let currentContentDuration = "currentContentDuration"
    static let currentPlaybackTime = "currentPlaybackTime"
    static let command = "command"
    static let breathingDuration = "breathingDuration"
}

// MARK: - Message Types

enum WatchMessageType: String, Codable {
    case requestSync = "requestSync"
    case syncData = "syncData"
    case playbackCommand = "playbackCommand"
    case playbackStateUpdate = "playbackStateUpdate"
    case breathingSessionComplete = "breathingSessionComplete"
    case startBreathingOnPhone = "startBreathingOnPhone"
}

// MARK: - Playback Commands

enum PlaybackCommand: String, Codable {
    case play = "play"
    case pause = "pause"
    case skipForward = "skipForward"
    case skipBackward = "skipBackward"
    case stop = "stop"
}

// MARK: - Playback State

enum PlaybackState: String, Codable {
    case stopped = "stopped"
    case playing = "playing"
    case paused = "paused"
    case loading = "loading"
}

// MARK: - Recent Session (Lightweight for Watch)

struct WatchRecentSession: Codable, Identifiable {
    let id: String
    let title: String
    let contentType: String
    let durationSeconds: Int
    let completedAt: Date

    var durationFormatted: String {
        let minutes = durationSeconds / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
        return "\(minutes)m"
    }

    var contentTypeIcon: String {
        switch contentType {
        case "Meditation": return "brain.head.profile"
        case "Sleep Story": return "book.closed.fill"
        case "Soundscape": return "waveform"
        case "Music": return "music.note"
        case "Movement": return "figure.mind.and.body"
        case "ASMR": return "ear.fill"
        case "Mindset": return "lightbulb.fill"
        default: return "brain.head.profile"
        }
    }
}

// MARK: - Sync Data Payload

struct WatchSyncData: Codable {
    let currentStreak: Int
    let totalMinutes: Int
    let mindfulMinutesToday: Int
    let lastSessionDate: Date?
    let recentSessions: [WatchRecentSession]
    let playbackState: PlaybackState
    let currentContentTitle: String?
    let currentContentDuration: Int?
    let currentPlaybackTime: Int?

    init(
        currentStreak: Int = 0,
        totalMinutes: Int = 0,
        mindfulMinutesToday: Int = 0,
        lastSessionDate: Date? = nil,
        recentSessions: [WatchRecentSession] = [],
        playbackState: PlaybackState = .stopped,
        currentContentTitle: String? = nil,
        currentContentDuration: Int? = nil,
        currentPlaybackTime: Int? = nil
    ) {
        self.currentStreak = currentStreak
        self.totalMinutes = totalMinutes
        self.mindfulMinutesToday = mindfulMinutesToday
        self.lastSessionDate = lastSessionDate
        self.recentSessions = recentSessions
        self.playbackState = playbackState
        self.currentContentTitle = currentContentTitle
        self.currentContentDuration = currentContentDuration
        self.currentPlaybackTime = currentPlaybackTime
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            WatchMessageKey.messageType: WatchMessageType.syncData.rawValue,
            WatchMessageKey.streak: currentStreak,
            WatchMessageKey.totalMinutes: totalMinutes,
            WatchMessageKey.mindfulMinutesToday: mindfulMinutesToday,
            WatchMessageKey.playbackState: playbackState.rawValue
        ]

        if let lastSessionDate {
            dict[WatchMessageKey.lastSessionDate] = lastSessionDate.timeIntervalSince1970
        }

        if let encoded = try? JSONEncoder().encode(recentSessions),
           let jsonString = String(data: encoded, encoding: .utf8) {
            dict[WatchMessageKey.recentSessions] = jsonString
        }

        if let currentContentTitle {
            dict[WatchMessageKey.currentContentTitle] = currentContentTitle
        }
        if let currentContentDuration {
            dict[WatchMessageKey.currentContentDuration] = currentContentDuration
        }
        if let currentPlaybackTime {
            dict[WatchMessageKey.currentPlaybackTime] = currentPlaybackTime
        }

        return dict
    }

    static func from(dictionary: [String: Any]) -> WatchSyncData? {
        let streak = dictionary[WatchMessageKey.streak] as? Int ?? 0
        let totalMinutes = dictionary[WatchMessageKey.totalMinutes] as? Int ?? 0
        let mindfulMinutesToday = dictionary[WatchMessageKey.mindfulMinutesToday] as? Int ?? 0

        var lastSessionDate: Date?
        if let timestamp = dictionary[WatchMessageKey.lastSessionDate] as? TimeInterval {
            lastSessionDate = Date(timeIntervalSince1970: timestamp)
        }

        var recentSessions: [WatchRecentSession] = []
        if let jsonString = dictionary[WatchMessageKey.recentSessions] as? String,
           let data = jsonString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([WatchRecentSession].self, from: data) {
            recentSessions = decoded
        }

        let playbackStateRaw = dictionary[WatchMessageKey.playbackState] as? String ?? "stopped"
        let playbackState = PlaybackState(rawValue: playbackStateRaw) ?? .stopped

        let currentContentTitle = dictionary[WatchMessageKey.currentContentTitle] as? String
        let currentContentDuration = dictionary[WatchMessageKey.currentContentDuration] as? Int
        let currentPlaybackTime = dictionary[WatchMessageKey.currentPlaybackTime] as? Int

        return WatchSyncData(
            currentStreak: streak,
            totalMinutes: totalMinutes,
            mindfulMinutesToday: mindfulMinutesToday,
            lastSessionDate: lastSessionDate,
            recentSessions: recentSessions,
            playbackState: playbackState,
            currentContentTitle: currentContentTitle,
            currentContentDuration: currentContentDuration,
            currentPlaybackTime: currentPlaybackTime
        )
    }
}

// MARK: - Watch Breathing Technique (Simplified)

enum WatchBreathingTechnique: String, CaseIterable, Identifiable {
    case boxBreathing = "Box Breathing"
    case relaxing = "4-7-8 Relaxing"
    case quickCalm = "Quick Calm"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .boxBreathing: return "square"
        case .relaxing: return "wind"
        case .quickCalm: return "heart.fill"
        }
    }

    var phases: [WatchBreathPhase] {
        switch self {
        case .boxBreathing:
            return [
                WatchBreathPhase(name: "Inhale", duration: 4, scale: 1.0, hapticType: .start),
                WatchBreathPhase(name: "Hold", duration: 4, scale: 1.0, hapticType: .click),
                WatchBreathPhase(name: "Exhale", duration: 4, scale: 0.4, hapticType: .directionDown),
                WatchBreathPhase(name: "Hold", duration: 4, scale: 0.4, hapticType: .click)
            ]
        case .relaxing:
            return [
                WatchBreathPhase(name: "Inhale", duration: 4, scale: 1.0, hapticType: .start),
                WatchBreathPhase(name: "Hold", duration: 7, scale: 1.0, hapticType: .click),
                WatchBreathPhase(name: "Exhale", duration: 8, scale: 0.4, hapticType: .directionDown)
            ]
        case .quickCalm:
            return [
                WatchBreathPhase(name: "Inhale", duration: 3, scale: 1.0, hapticType: .start),
                WatchBreathPhase(name: "Exhale", duration: 3, scale: 0.4, hapticType: .directionDown)
            ]
        }
    }

    var totalDuration: Int {
        phases.reduce(0) { $0 + Int($1.duration) }
    }
}

struct WatchBreathPhase {
    let name: String
    let duration: Double
    let scale: CGFloat
    let hapticType: WatchHapticType
}

enum WatchHapticType {
    case start
    case stop
    case click
    case directionUp
    case directionDown
    case success
    case failure
    case retry
    case notification
}
