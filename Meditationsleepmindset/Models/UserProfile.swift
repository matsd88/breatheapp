//
//  UserProfile.swift
//  Meditation Sleep Mindset
//

import Foundation
import SwiftData

enum UserGoal: String, Codable, CaseIterable, Identifiable {
    case buildSelfEsteem = "Build Self Esteem"
    case reduceAnxiety = "Reduce Anxiety"
    case increaseHappiness = "Increase Happiness"
    case developGratitude = "Develop Gratitude"
    case reduceStress = "Reduce Stress"
    case improvePerformance = "Improve Performance"
    case betterSleep = "Better Sleep"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .buildSelfEsteem: return String(localized: "Build Self Esteem")
        case .reduceAnxiety: return String(localized: "Reduce Anxiety")
        case .increaseHappiness: return String(localized: "Increase Happiness")
        case .developGratitude: return String(localized: "Develop Gratitude")
        case .reduceStress: return String(localized: "Reduce Stress")
        case .improvePerformance: return String(localized: "Improve Performance")
        case .betterSleep: return String(localized: "Better Sleep")
        }
    }

    var iconName: String {
        switch self {
        case .buildSelfEsteem: return "star.fill"
        case .reduceAnxiety: return "heart.fill"
        case .increaseHappiness: return "sun.max.fill"
        case .developGratitude: return "hands.clap.fill"
        case .reduceStress: return "leaf.fill"
        case .improvePerformance: return "bolt.fill"
        case .betterSleep: return "moon.stars.fill"
        }
    }
}

enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case experienced = "Experienced"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beginner: return String(localized: "Beginner")
        case .intermediate: return String(localized: "Intermediate")
        case .experienced: return String(localized: "Experienced")
        }
    }

    var description: String {
        switch self {
        case .beginner: return String(localized: "New to meditation")
        case .intermediate: return String(localized: "Some experience")
        case .experienced: return String(localized: "Regular practice")
        }
    }
}

@Model
final class UserProfile {
    var id: UUID
    var selectedGoals: [String]
    var experienceLevel: String?
    var dailyReminderTime: Date?
    var hasCompletedOnboarding: Bool
    var appOpenCount: Int
    var hasShownSharePrompt: Bool
    var hasShownRatingPrompt: Bool
    var createdAt: Date
    var totalMinutesMeditated: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastMeditationDate: Date?
    var isPremiumSubscriber: Bool
    var subscriptionExpiryDate: Date?

    init() {
        self.id = UUID()
        self.selectedGoals = []
        self.experienceLevel = nil
        self.dailyReminderTime = nil
        self.hasCompletedOnboarding = false
        self.appOpenCount = 0
        self.hasShownSharePrompt = false
        self.hasShownRatingPrompt = false
        self.createdAt = Date()
        self.totalMinutesMeditated = 0
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastMeditationDate = nil
        self.isPremiumSubscriber = false
        self.subscriptionExpiryDate = nil
    }

    var goals: [UserGoal] {
        selectedGoals.compactMap { UserGoal(rawValue: $0) }
    }

    var experience: ExperienceLevel? {
        guard let level = experienceLevel else { return nil }
        return ExperienceLevel(rawValue: level)
    }
}
