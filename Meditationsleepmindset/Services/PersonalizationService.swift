//
//  PersonalizationService.swift
//  Meditation Sleep Mindset
//
//  AI-powered personalization based on user engagement patterns.
//  Tracks content category preferences, time-of-day patterns, and mood correlations.
//

import Foundation
import SwiftData

@MainActor
class PersonalizationService: ObservableObject {
    static let shared = PersonalizationService()

    // MARK: - Published Preferences (computed from engagement history)
    @Published private(set) var categoryEngagement: [ContentType: CategoryEngagementData] = [:]
    @Published private(set) var timeOfDayPreferences: [TimeOfDayBucket: [ContentType]] = [:]
    @Published private(set) var moodContentCorrelations: [String: [ContentType]] = [:] // mood rawValue → preferred types
    @Published private(set) var topNarrators: [String] = []
    @Published private(set) var lastAnalyzedDate: Date?

    // MARK: - Engagement Data Structures

    struct CategoryEngagementData {
        var playCount: Int = 0
        var completionCount: Int = 0
        var totalMinutesListened: Int = 0

        var completionRate: Double {
            guard playCount > 0 else { return 0 }
            return Double(completionCount) / Double(playCount)
        }

        var engagementScore: Double {
            // Weighted score: completion matters more than just play count
            let playScore = min(Double(playCount) / 10.0, 1.0) * 30 // Up to 30 points
            let completionScore = completionRate * 40 // Up to 40 points
            let durationScore = min(Double(totalMinutesListened) / 60.0, 1.0) * 30 // Up to 30 points
            return playScore + completionScore + durationScore
        }
    }

    enum TimeOfDayBucket: String, CaseIterable {
        case earlyMorning  // 5-8 AM
        case morning       // 8-12 PM
        case afternoon     // 12-5 PM
        case evening       // 5-9 PM
        case night         // 9 PM - 5 AM

        static func from(hour: Int) -> TimeOfDayBucket {
            switch hour {
            case 5..<8: return .earlyMorning
            case 8..<12: return .morning
            case 12..<17: return .afternoon
            case 17..<21: return .evening
            default: return .night
            }
        }
    }

    private init() {}

    // MARK: - Analysis

    /// Analyze user's session history and compute engagement patterns
    func analyzeEngagement(sessions: [MeditationSession], allContent: [Content]) {
        guard !sessions.isEmpty else { return }

        // Build content lookup by videoID
        let contentByVideoID = Dictionary(uniqueKeysWithValues: allContent.map { ($0.youtubeVideoID, $0) })

        // Reset metrics
        var newCategoryEngagement: [ContentType: CategoryEngagementData] = [:]
        var timeContentMap: [TimeOfDayBucket: [ContentType: Int]] = [:]
        var moodContentMap: [String: [ContentType: Int]] = [:]
        var narratorPlayCounts: [String: Int] = [:]

        for session in sessions {
            guard let videoID = session.youtubeVideoID,
                  let content = contentByVideoID[videoID] else { continue }

            let contentType = content.contentType

            // Category engagement
            var data = newCategoryEngagement[contentType] ?? CategoryEngagementData()
            data.playCount += 1
            if session.wasCompleted { data.completionCount += 1 }
            data.totalMinutesListened += session.listenedSeconds / 60
            newCategoryEngagement[contentType] = data

            // Time-of-day patterns
            let hour = Calendar.current.component(.hour, from: session.startedAt)
            let bucket = TimeOfDayBucket.from(hour: hour)
            var bucketMap = timeContentMap[bucket] ?? [:]
            bucketMap[contentType, default: 0] += 1
            timeContentMap[bucket] = bucketMap

            // Mood correlations (what content types do they pick when feeling X?)
            if let preMood = session.preMood {
                var moodMap = moodContentMap[preMood] ?? [:]
                // Weight completed sessions higher for mood correlation
                moodMap[contentType, default: 0] += session.wasCompleted ? 2 : 1
                moodContentMap[preMood] = moodMap
            }

            // Narrator preferences
            if let narrator = content.narrator, !narrator.isEmpty {
                narratorPlayCounts[narrator, default: 0] += 1
            }
        }

        // Publish category engagement
        categoryEngagement = newCategoryEngagement

        // Compute time-of-day preferences (top 3 content types per bucket)
        var newTimePrefs: [TimeOfDayBucket: [ContentType]] = [:]
        for (bucket, typeMap) in timeContentMap {
            let sorted = typeMap.sorted { $0.value > $1.value }
            newTimePrefs[bucket] = Array(sorted.prefix(3).map { $0.key })
        }
        timeOfDayPreferences = newTimePrefs

        // Compute mood correlations (top 2 content types per mood)
        var newMoodCorrelations: [String: [ContentType]] = [:]
        for (mood, typeMap) in moodContentMap {
            let sorted = typeMap.sorted { $0.value > $1.value }
            newMoodCorrelations[mood] = Array(sorted.prefix(2).map { $0.key })
        }
        moodContentCorrelations = newMoodCorrelations

        // Top narrators
        topNarrators = narratorPlayCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }

        lastAnalyzedDate = Date()

        #if DEBUG
        print("[PersonalizationService] Analyzed \(sessions.count) sessions")
        print("[PersonalizationService] Category engagement: \(categoryEngagement.mapValues { $0.engagementScore })")
        print("[PersonalizationService] Top narrators: \(topNarrators)")
        #endif
    }

    // MARK: - Scoring for Recommendations

    /// Get personalization score boost for content based on engagement history
    func personalizedScoreBoost(for content: Content, currentHour: Int, currentMood: String?) -> Int {
        var boost = 0

        // Category engagement boost (max +8)
        if let engagement = categoryEngagement[content.contentType] {
            boost += Int(engagement.engagementScore / 12.5) // 0-8 points based on 0-100 score
        }

        // Time-of-day preference boost (max +4)
        let bucket = TimeOfDayBucket.from(hour: currentHour)
        if let preferredTypes = timeOfDayPreferences[bucket] {
            if let index = preferredTypes.firstIndex(of: content.contentType) {
                boost += (3 - index) + 1 // 4, 3, or 2 points for top 3
            }
        }

        // Mood correlation boost (max +3)
        if let mood = currentMood, let correlatedTypes = moodContentCorrelations[mood] {
            if let index = correlatedTypes.firstIndex(of: content.contentType) {
                boost += (2 - index) + 1 // 3 or 2 points for top 2
            }
        }

        // Favorite narrator boost (max +3)
        if let narrator = content.narrator, topNarrators.contains(narrator) {
            if let index = topNarrators.firstIndex(of: narrator) {
                boost += max(1, 3 - index) // 3, 2, 1, 1, 1 for top 5
            }
        }

        return boost
    }

    /// Get content types the user engages with most
    var preferredContentTypes: [ContentType] {
        categoryEngagement
            .sorted { $0.value.engagementScore > $1.value.engagementScore }
            .prefix(3)
            .map { $0.key }
    }

    /// Check if user has enough engagement data for personalization
    var hasEnoughDataForPersonalization: Bool {
        let totalPlays = categoryEngagement.values.reduce(0) { $0 + $1.playCount }
        return totalPlays >= 5 // Need at least 5 sessions for meaningful patterns
    }

    /// Get a "Because you liked X" recommendation reason
    func recommendationReason(for content: Content) -> String? {
        // Check if this matches a top category
        if let engagement = categoryEngagement[content.contentType],
           engagement.engagementScore > 50,
           preferredContentTypes.first == content.contentType {
            return String(localized: "Because you enjoy \(content.contentType.displayName.lowercased())")
        }

        // Check if from a favorite narrator
        if let narrator = content.narrator, topNarrators.prefix(3).contains(narrator) {
            return String(localized: "From \(narrator), a creator you love")
        }

        // Check if matches time preference
        let hour = Calendar.current.component(.hour, from: Date())
        let bucket = TimeOfDayBucket.from(hour: hour)
        if let preferredTypes = timeOfDayPreferences[bucket],
           preferredTypes.first == content.contentType {
            return String(localized: "Perfect for this time of day")
        }

        return nil
    }
}
