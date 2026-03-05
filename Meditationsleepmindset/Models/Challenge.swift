//
//  Challenge.swift
//  Meditation Sleep Mindset
//

import Foundation
import SwiftUI

// MARK: - Challenge Type

enum ChallengeType: String, Codable, CaseIterable, Identifiable {
    case dailySessions = "daily_sessions"
    case weeklyMinutes = "weekly_minutes"
    case streakDays = "streak_days"
    case tryContentTypes = "try_content_types"
    case completeProgram = "complete_program"
    case morningMeditations = "morning_meditations"
    case nightMeditations = "night_meditations"
    case sleepSessions = "sleep_sessions"
    case focusTimerSessions = "focus_timer"
    case meditationSessions = "meditation_sessions"
    case musicSessions = "music_sessions"
    case movementSessions = "movement_sessions"
    case mindsetSessions = "mindset_sessions"
    case soundscapeSessions = "soundscape_sessions"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dailySessions: return String(localized: "Daily Sessions")
        case .weeklyMinutes: return String(localized: "Weekly Minutes")
        case .streakDays: return String(localized: "Streak Days")
        case .tryContentTypes: return String(localized: "Try Content Types")
        case .completeProgram: return String(localized: "Complete Program")
        case .morningMeditations: return String(localized: "Morning Meditations")
        case .nightMeditations: return String(localized: "Night Meditations")
        case .sleepSessions: return String(localized: "Sleep Sessions")
        case .focusTimerSessions: return String(localized: "Focus Timer")
        case .meditationSessions: return String(localized: "Meditations")
        case .musicSessions: return String(localized: "Music Sessions")
        case .movementSessions: return String(localized: "Movement Sessions")
        case .mindsetSessions: return String(localized: "Mindset Sessions")
        case .soundscapeSessions: return String(localized: "Soundscape Sessions")
        }
    }

    var iconName: String {
        switch self {
        case .dailySessions: return "calendar.badge.checkmark"
        case .weeklyMinutes: return "clock.fill"
        case .streakDays: return "flame.fill"
        case .tryContentTypes: return "safari.fill"
        case .completeProgram: return "flag.checkered"
        case .morningMeditations: return "sunrise.fill"
        case .nightMeditations: return "moon.stars.fill"
        case .sleepSessions: return "bed.double.fill"
        case .focusTimerSessions: return "timer"
        case .meditationSessions: return "brain.head.profile"
        case .musicSessions: return "music.note"
        case .movementSessions: return "figure.mind.and.body"
        case .mindsetSessions: return "lightbulb.fill"
        case .soundscapeSessions: return "waveform"
        }
    }

    var color: Color {
        switch self {
        case .dailySessions: return .green
        case .weeklyMinutes: return .blue
        case .streakDays: return .orange
        case .tryContentTypes: return .purple
        case .completeProgram: return .pink
        case .morningMeditations: return .yellow
        case .nightMeditations: return .indigo
        case .sleepSessions: return .cyan
        case .focusTimerSessions: return .mint
        case .meditationSessions: return .teal
        case .musicSessions: return .pink
        case .movementSessions: return .orange
        case .mindsetSessions: return .green
        case .soundscapeSessions: return .cyan
        }
    }
}

// MARK: - Challenge Reward

enum ChallengeReward: Codable, Equatable {
    case xp(Int)
    case badge(String)

    var displayText: String {
        switch self {
        case .xp(let amount):
            return "+\(amount) XP"
        case .badge(let name):
            return "\(name) Badge"
        }
    }

    var iconName: String {
        switch self {
        case .xp:
            return "star.fill"
        case .badge:
            return "trophy.fill"
        }
    }

    var color: Color {
        switch self {
        case .xp:
            return .yellow
        case .badge:
            return .orange
        }
    }
}

// MARK: - Challenge Difficulty

enum ChallengeDifficulty: String, Codable, CaseIterable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"

    var displayName: String {
        switch self {
        case .easy: return String(localized: "Easy")
        case .medium: return String(localized: "Medium")
        case .hard: return String(localized: "Hard")
        }
    }

    var color: Color {
        switch self {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }

    var xpMultiplier: Double {
        switch self {
        case .easy: return 1.0
        case .medium: return 1.5
        case .hard: return 2.0
        }
    }
}

// MARK: - Challenge

struct Challenge: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let challengeDescription: String
    let type: ChallengeType
    let target: Int
    var progress: Int
    let reward: ChallengeReward
    let difficulty: ChallengeDifficulty
    let startDate: Date
    let endDate: Date
    var isCompleted: Bool
    var completedDate: Date?
    var isFeatured: Bool

    var progressPercentage: Double {
        guard target > 0 else { return 0 }
        return min(1.0, Double(progress) / Double(target))
    }

    var isExpired: Bool {
        Date() > endDate
    }

    var timeRemaining: String {
        let now = Date()
        guard now < endDate else { return "Expired" }

        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: now, to: endDate)

        if let days = components.day, days > 0 {
            return "\(days)d \(components.hour ?? 0)h left"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h \(components.minute ?? 0)m left"
        } else if let minutes = components.minute {
            return "\(minutes)m left"
        }
        return "Ending soon"
    }

    var iconName: String {
        type.iconName
    }

    var color: Color {
        type.color
    }

    static func == (lhs: Challenge, rhs: Challenge) -> Bool {
        lhs.id == rhs.id && lhs.progress == rhs.progress && lhs.isCompleted == rhs.isCompleted
    }
}

// MARK: - Challenge Templates

extension Challenge {

    /// Generate a unique ID for a challenge based on type and week
    static func generateID(type: ChallengeType, weekStart: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(type.rawValue)_\(formatter.string(from: weekStart))"
    }

    /// Get the start of the current week (Monday)
    static func currentWeekStart() -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return calendar.date(from: components) ?? Date()
    }

    /// Get the end of the current week (Sunday 11:59:59 PM)
    static func currentWeekEnd() -> Date {
        let weekStart = currentWeekStart()
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
            return Date()
        }
        return calendar.date(byAdding: .second, value: -1, to: weekEnd) ?? weekEnd
    }

    // MARK: - Challenge Templates

    static func morningPerson(weekStart: Date, weekEnd: Date) -> Challenge {
        Challenge(
            id: generateID(type: .morningMeditations, weekStart: weekStart),
            title: "Morning Person",
            challengeDescription: "Complete 3 morning meditations (before 9 AM)",
            type: .morningMeditations,
            target: 3,
            progress: 0,
            reward: .xp(75),
            difficulty: .medium,
            startDate: weekStart,
            endDate: weekEnd,
            isCompleted: false,
            completedDate: nil,
            isFeatured: false
        )
    }

    static func explorer(weekStart: Date, weekEnd: Date) -> Challenge {
        Challenge(
            id: generateID(type: .tryContentTypes, weekStart: weekStart),
            title: "Explorer",
            challengeDescription: "Try 3 different content types",
            type: .tryContentTypes,
            target: 3,
            progress: 0,
            reward: .xp(100),
            difficulty: .medium,
            startDate: weekStart,
            endDate: weekEnd,
            isCompleted: false,
            completedDate: nil,
            isFeatured: false
        )
    }

    static func consistent(weekStart: Date, weekEnd: Date, targetDays: Int = 5) -> Challenge {
        Challenge(
            id: generateID(type: .streakDays, weekStart: weekStart),
            title: "Consistent",
            challengeDescription: "Maintain a \(targetDays)-day streak",
            type: .streakDays,
            target: targetDays,
            progress: 0,
            reward: .xp(Int(Double(50 * targetDays) * 1.5)),
            difficulty: targetDays >= 5 ? .medium : .easy,
            startDate: weekStart,
            endDate: weekEnd,
            isCompleted: false,
            completedDate: nil,
            isFeatured: true
        )
    }

    static func deepDive(weekStart: Date, weekEnd: Date, targetMinutes: Int = 60) -> Challenge {
        Challenge(
            id: generateID(type: .weeklyMinutes, weekStart: weekStart),
            title: "Deep Dive",
            challengeDescription: "Listen for \(targetMinutes) total minutes",
            type: .weeklyMinutes,
            target: targetMinutes,
            progress: 0,
            reward: .xp(targetMinutes),
            difficulty: targetMinutes >= 90 ? .hard : (targetMinutes >= 60 ? .medium : .easy),
            startDate: weekStart,
            endDate: weekEnd,
            isCompleted: false,
            completedDate: nil,
            isFeatured: false
        )
    }

    static func nightOwl(weekStart: Date, weekEnd: Date) -> Challenge {
        Challenge(
            id: generateID(type: .sleepSessions, weekStart: weekStart),
            title: "Night Owl",
            challengeDescription: "Complete 5 sleep sessions",
            type: .sleepSessions,
            target: 5,
            progress: 0,
            reward: .xp(125),
            difficulty: .medium,
            startDate: weekStart,
            endDate: weekEnd,
            isCompleted: false,
            completedDate: nil,
            isFeatured: false
        )
    }

    static func focused(weekStart: Date, weekEnd: Date) -> Challenge {
        Challenge(
            id: generateID(type: .focusTimerSessions, weekStart: weekStart),
            title: "Focused",
            challengeDescription: "Use focus timer 3 times",
            type: .focusTimerSessions,
            target: 3,
            progress: 0,
            reward: .xp(75),
            difficulty: .easy,
            startDate: weekStart,
            endDate: weekEnd,
            isCompleted: false,
            completedDate: nil,
            isFeatured: false
        )
    }

    static func zenMaster(weekStart: Date, weekEnd: Date) -> Challenge {
        Challenge(
            id: generateID(type: .meditationSessions, weekStart: weekStart),
            title: "Zen Master",
            challengeDescription: "Complete 7 meditation sessions",
            type: .meditationSessions,
            target: 7,
            progress: 0,
            reward: .xp(150),
            difficulty: .hard,
            startDate: weekStart,
            endDate: weekEnd,
            isCompleted: false,
            completedDate: nil,
            isFeatured: false
        )
    }

    static func melodySeeker(weekStart: Date, weekEnd: Date) -> Challenge {
        Challenge(
            id: generateID(type: .musicSessions, weekStart: weekStart),
            title: "Melody Seeker",
            challengeDescription: "Complete 4 music sessions",
            type: .musicSessions,
            target: 4,
            progress: 0,
            reward: .xp(80),
            difficulty: .easy,
            startDate: weekStart,
            endDate: weekEnd,
            isCompleted: false,
            completedDate: nil,
            isFeatured: false
        )
    }

    static func activeBody(weekStart: Date, weekEnd: Date) -> Challenge {
        Challenge(
            id: generateID(type: .movementSessions, weekStart: weekStart),
            title: "Active Body",
            challengeDescription: "Complete 3 movement sessions",
            type: .movementSessions,
            target: 3,
            progress: 0,
            reward: .xp(90),
            difficulty: .medium,
            startDate: weekStart,
            endDate: weekEnd,
            isCompleted: false,
            completedDate: nil,
            isFeatured: false
        )
    }

    static func mindfulMornings(weekStart: Date, weekEnd: Date) -> Challenge {
        Challenge(
            id: generateID(type: .dailySessions, weekStart: weekStart),
            title: "Mindful Mornings",
            challengeDescription: "Complete a session every day this week",
            type: .dailySessions,
            target: 7,
            progress: 0,
            reward: .xp(200),
            difficulty: .hard,
            startDate: weekStart,
            endDate: weekEnd,
            isCompleted: false,
            completedDate: nil,
            isFeatured: true
        )
    }

    static func nighttimeRoutine(weekStart: Date, weekEnd: Date) -> Challenge {
        Challenge(
            id: generateID(type: .nightMeditations, weekStart: weekStart),
            title: "Nighttime Routine",
            challengeDescription: "Complete 4 evening sessions (after 8 PM)",
            type: .nightMeditations,
            target: 4,
            progress: 0,
            reward: .xp(100),
            difficulty: .medium,
            startDate: weekStart,
            endDate: weekEnd,
            isCompleted: false,
            completedDate: nil,
            isFeatured: false
        )
    }

    static func soundscapeExplorer(weekStart: Date, weekEnd: Date) -> Challenge {
        Challenge(
            id: generateID(type: .soundscapeSessions, weekStart: weekStart),
            title: "Soundscape Explorer",
            challengeDescription: "Complete 3 soundscape sessions",
            type: .soundscapeSessions,
            target: 3,
            progress: 0,
            reward: .xp(75),
            difficulty: .easy,
            startDate: weekStart,
            endDate: weekEnd,
            isCompleted: false,
            completedDate: nil,
            isFeatured: false
        )
    }

    static func mindsetShift(weekStart: Date, weekEnd: Date) -> Challenge {
        Challenge(
            id: generateID(type: .mindsetSessions, weekStart: weekStart),
            title: "Mindset Shift",
            challengeDescription: "Complete 4 mindset sessions",
            type: .mindsetSessions,
            target: 4,
            progress: 0,
            reward: .xp(100),
            difficulty: .medium,
            startDate: weekStart,
            endDate: weekEnd,
            isCompleted: false,
            completedDate: nil,
            isFeatured: false
        )
    }

    /// All available challenge templates
    static var allTemplates: [@Sendable (Date, Date) -> Challenge] {
        let templates: [@Sendable (Date, Date) -> Challenge] = [
            { start, end in morningPerson(weekStart: start, weekEnd: end) },
            { start, end in explorer(weekStart: start, weekEnd: end) },
            { start, end in consistent(weekStart: start, weekEnd: end) },
            { start, end in deepDive(weekStart: start, weekEnd: end) },
            { start, end in nightOwl(weekStart: start, weekEnd: end) },
            { start, end in focused(weekStart: start, weekEnd: end) },
            { start, end in zenMaster(weekStart: start, weekEnd: end) },
            { start, end in melodySeeker(weekStart: start, weekEnd: end) },
            { start, end in activeBody(weekStart: start, weekEnd: end) },
            { start, end in mindfulMornings(weekStart: start, weekEnd: end) },
            { start, end in nighttimeRoutine(weekStart: start, weekEnd: end) },
            { start, end in soundscapeExplorer(weekStart: start, weekEnd: end) },
            { start, end in mindsetShift(weekStart: start, weekEnd: end) }
        ]
        return templates
    }
}
