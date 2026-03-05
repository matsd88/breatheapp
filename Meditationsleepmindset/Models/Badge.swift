//
//  Badge.swift
//  Meditation Sleep Mindset
//

import Foundation
import SwiftUI

// MARK: - Badge Category

enum BadgeCategory: String, Codable, CaseIterable, Identifiable {
    case streak = "Streak"
    case sessions = "Sessions"
    case time = "Time"
    case exploration = "Exploration"
    case social = "Social"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .streak: return String(localized: "Streak")
        case .sessions: return String(localized: "Sessions")
        case .time: return String(localized: "Time")
        case .exploration: return String(localized: "Exploration")
        case .social: return String(localized: "Social")
        }
    }

    var iconName: String {
        switch self {
        case .streak: return "flame.fill"
        case .sessions: return "figure.mind.and.body"
        case .time: return "clock.fill"
        case .exploration: return "safari.fill"
        case .social: return "person.2.fill"
        }
    }

    var color: Color {
        switch self {
        case .streak: return .orange
        case .sessions: return .green
        case .time: return .blue
        case .exploration: return .purple
        case .social: return .pink
        }
    }
}

// MARK: - Badge Requirement

enum BadgeRequirement: Codable, Equatable {
    case firstSession
    case sessionsCompleted(Int)
    case streakDays(Int)
    case totalMinutes(Int)
    case meditationSessions(Int)
    case musicSessions(Int)
    case soundscapeSessions(Int)
    case movementSessions(Int)
    case mindsetSessions(Int)
    case asmrSessions(Int)
    case sleepStorySessions(Int)
    case triedAllContentTypes
    case morningMeditation  // Before 8 AM
    case nightMeditation    // After 10 PM
    case weekendWarrior     // 4 weekend sessions
    case createdPlaylist
    case favorited(Int)
    case sharedContent

    var description: String {
        switch self {
        case .firstSession:
            return String(localized: "Complete your first session")
        case .sessionsCompleted(let count):
            return String(localized: "Complete \(count) sessions")
        case .streakDays(let days):
            return String(localized: "Maintain a \(days)-day streak")
        case .totalMinutes(let minutes):
            let hours = minutes / 60
            if hours >= 1 {
                return String(localized: "Listen for \(hours) hours total")
            }
            return String(localized: "Listen for \(minutes) minutes total")
        case .meditationSessions(let count):
            return String(localized: "Complete \(count) meditation sessions")
        case .musicSessions(let count):
            return String(localized: "Complete \(count) music sessions")
        case .soundscapeSessions(let count):
            return String(localized: "Complete \(count) soundscape sessions")
        case .movementSessions(let count):
            return String(localized: "Complete \(count) movement sessions")
        case .mindsetSessions(let count):
            return String(localized: "Complete \(count) mindset sessions")
        case .asmrSessions(let count):
            return String(localized: "Complete \(count) ASMR sessions")
        case .sleepStorySessions(let count):
            return String(localized: "Complete \(count) sleep story sessions")
        case .triedAllContentTypes:
            return String(localized: "Try all content types")
        case .morningMeditation:
            return String(localized: "Meditate before 8 AM")
        case .nightMeditation:
            return String(localized: "Meditate after 10 PM")
        case .weekendWarrior:
            return String(localized: "Complete 4 weekend sessions")
        case .createdPlaylist:
            return String(localized: "Create your first playlist")
        case .favorited(let count):
            return String(localized: "Add \(count) favorites")
        case .sharedContent:
            return String(localized: "Share content with a friend")
        }
    }
}

// MARK: - Badge

struct Badge: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let iconName: String
    let category: BadgeCategory
    let requirement: BadgeRequirement
    var dateEarned: Date?

    var isEarned: Bool {
        dateEarned != nil
    }

    var color: Color {
        category.color
    }

    static func == (lhs: Badge, rhs: Badge) -> Bool {
        lhs.id == rhs.id && lhs.dateEarned == rhs.dateEarned
    }
}

// MARK: - Predefined Badges

extension Badge {
    static let allBadges: [Badge] = [
        // Streak Badges
        Badge(
            id: "first_step",
            name: "First Step",
            description: "Complete your first meditation session",
            iconName: "figure.walk",
            category: .streak,
            requirement: .firstSession
        ),
        Badge(
            id: "week_warrior",
            name: "Week Warrior",
            description: "Maintain a 7-day meditation streak",
            iconName: "flame.fill",
            category: .streak,
            requirement: .streakDays(7)
        ),
        Badge(
            id: "two_week_triumph",
            name: "Two Week Triumph",
            description: "Maintain a 14-day meditation streak",
            iconName: "flame.circle.fill",
            category: .streak,
            requirement: .streakDays(14)
        ),
        Badge(
            id: "zen_master",
            name: "Zen Master",
            description: "Maintain a 30-day meditation streak",
            iconName: "sparkles",
            category: .streak,
            requirement: .streakDays(30)
        ),
        Badge(
            id: "mindful_legend",
            name: "Mindful Legend",
            description: "Maintain a 100-day meditation streak",
            iconName: "crown.fill",
            category: .streak,
            requirement: .streakDays(100)
        ),
        Badge(
            id: "yearly_yogi",
            name: "Yearly Yogi",
            description: "Maintain a 365-day meditation streak",
            iconName: "star.circle.fill",
            category: .streak,
            requirement: .streakDays(365)
        ),

        // Sessions Badges
        Badge(
            id: "getting_started",
            name: "Getting Started",
            description: "Complete 5 sessions",
            iconName: "leaf.fill",
            category: .sessions,
            requirement: .sessionsCompleted(5)
        ),
        Badge(
            id: "dedicated",
            name: "Dedicated",
            description: "Complete 25 sessions",
            iconName: "heart.fill",
            category: .sessions,
            requirement: .sessionsCompleted(25)
        ),
        Badge(
            id: "half_century",
            name: "Half Century",
            description: "Complete 50 sessions",
            iconName: "star.fill",
            category: .sessions,
            requirement: .sessionsCompleted(50)
        ),
        Badge(
            id: "century",
            name: "Century",
            description: "Complete 100 sessions",
            iconName: "trophy.fill",
            category: .sessions,
            requirement: .sessionsCompleted(100)
        ),
        Badge(
            id: "meditation_master",
            name: "Meditation Master",
            description: "Complete 500 sessions",
            iconName: "medal.fill",
            category: .sessions,
            requirement: .sessionsCompleted(500)
        ),

        // Time Badges
        Badge(
            id: "first_hour",
            name: "First Hour",
            description: "Listen for 1 hour total",
            iconName: "clock.fill",
            category: .time,
            requirement: .totalMinutes(60)
        ),
        Badge(
            id: "five_hours",
            name: "Five Hours",
            description: "Listen for 5 hours total",
            iconName: "clock.badge.checkmark.fill",
            category: .time,
            requirement: .totalMinutes(300)
        ),
        Badge(
            id: "marathon",
            name: "Marathon",
            description: "Listen for 10 hours total",
            iconName: "figure.run",
            category: .time,
            requirement: .totalMinutes(600)
        ),
        Badge(
            id: "day_listener",
            name: "Day Listener",
            description: "Listen for 24 hours total",
            iconName: "sun.max.fill",
            category: .time,
            requirement: .totalMinutes(1440)
        ),
        Badge(
            id: "time_traveler",
            name: "Time Traveler",
            description: "Listen for 100 hours total",
            iconName: "hourglass",
            category: .time,
            requirement: .totalMinutes(6000)
        ),

        // Exploration Badges
        Badge(
            id: "night_owl",
            name: "Night Owl",
            description: "Complete 10 sleep stories",
            iconName: "moon.stars.fill",
            category: .exploration,
            requirement: .sleepStorySessions(10)
        ),
        Badge(
            id: "sleep_champion",
            name: "Sleep Champion",
            description: "Complete 50 sleep stories",
            iconName: "bed.double.fill",
            category: .exploration,
            requirement: .sleepStorySessions(50)
        ),
        Badge(
            id: "story_lover",
            name: "Story Lover",
            description: "Complete 10 sleep stories",
            iconName: "book.closed.fill",
            category: .exploration,
            requirement: .sleepStorySessions(10)
        ),
        Badge(
            id: "music_lover",
            name: "Music Lover",
            description: "Complete 10 music sessions",
            iconName: "music.note",
            category: .exploration,
            requirement: .musicSessions(10)
        ),
        Badge(
            id: "soundscape_seeker",
            name: "Soundscape Seeker",
            description: "Complete 10 soundscape sessions",
            iconName: "waveform",
            category: .exploration,
            requirement: .soundscapeSessions(10)
        ),
        Badge(
            id: "movement_maven",
            name: "Movement Maven",
            description: "Complete 10 movement sessions",
            iconName: "figure.yoga",
            category: .exploration,
            requirement: .movementSessions(10)
        ),
        Badge(
            id: "mindset_master",
            name: "Mindset Master",
            description: "Complete 10 mindset sessions",
            iconName: "lightbulb.fill",
            category: .exploration,
            requirement: .mindsetSessions(10)
        ),
        Badge(
            id: "asmr_aficionado",
            name: "ASMR Aficionado",
            description: "Complete 10 ASMR sessions",
            iconName: "ear.fill",
            category: .exploration,
            requirement: .asmrSessions(10)
        ),
        Badge(
            id: "explorer",
            name: "Explorer",
            description: "Try all content types",
            iconName: "safari.fill",
            category: .exploration,
            requirement: .triedAllContentTypes
        ),
        Badge(
            id: "early_bird",
            name: "Early Bird",
            description: "Meditate before 8 AM",
            iconName: "sunrise.fill",
            category: .exploration,
            requirement: .morningMeditation
        ),
        Badge(
            id: "night_meditator",
            name: "Night Meditator",
            description: "Meditate after 10 PM",
            iconName: "moon.fill",
            category: .exploration,
            requirement: .nightMeditation
        ),
        Badge(
            id: "weekend_warrior",
            name: "Weekend Warrior",
            description: "Complete 4 weekend sessions",
            iconName: "calendar.badge.checkmark",
            category: .exploration,
            requirement: .weekendWarrior
        ),

        // Social Badges
        Badge(
            id: "curator",
            name: "Curator",
            description: "Create your first playlist",
            iconName: "rectangle.stack.fill",
            category: .social,
            requirement: .createdPlaylist
        ),
        Badge(
            id: "collector",
            name: "Collector",
            description: "Add 10 favorites",
            iconName: "heart.circle.fill",
            category: .social,
            requirement: .favorited(10)
        ),
        Badge(
            id: "super_collector",
            name: "Super Collector",
            description: "Add 50 favorites",
            iconName: "heart.rectangle.fill",
            category: .social,
            requirement: .favorited(50)
        ),
        Badge(
            id: "sharing_is_caring",
            name: "Sharing is Caring",
            description: "Share content with a friend",
            iconName: "square.and.arrow.up.fill",
            category: .social,
            requirement: .sharedContent
        ),
    ]
}
