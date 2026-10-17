//
//  MoodLog.swift
//  Meditation Sleep Mindset
//
//  One mood history for the whole app. Moods are logged in two places with
//  two vocabularies — the AI coach check-in (MoodLevel: Great…Struggling on
//  ChatSession) and the after-session reflection (Mood: Calm, Happy… on
//  MeditationSession.postMood). The Profile mood card read only the first
//  and Mood Insights only the second, so a user with a week of check-ins
//  tapped the card and got "No mood data yet". Everything now reads here.
//

import Foundation
import SwiftData

struct MoodEntry: Identifiable {
    let id: String
    let date: Date
    /// Common 5-point scale both sources map onto.
    let level: MoodLevel
    /// What the user actually picked ("Grateful", "Okay"…), for distribution.
    let label: String
}

extension MoodLevel {
    /// 1 (Struggling) … 5 (Great)
    var score: Int {
        switch self {
        case .great: return 5
        case .good: return 4
        case .okay: return 3
        case .low: return 2
        case .struggling: return 1
        }
    }

    /// Nearest level for an averaged score.
    init(score: Double) {
        switch score.rounded() {
        case 5...: self = .great
        case 4: self = .good
        case 3: self = .okay
        case 2: self = .low
        default: self = .struggling
        }
    }
}

extension Mood {
    /// Post-session moods placed on the coach's 5-point scale.
    var level: MoodLevel {
        switch self {
        case .grateful, .happy: return .great
        case .calm, .focused, .energetic: return .good
        case .tired: return .okay
        case .sad, .anxious: return .low
        case .stressed: return .struggling
        }
    }
}

enum MoodLog {
    /// Every mood check-in from both sources since `start` (nil = all time),
    /// newest first.
    @MainActor
    static func entries(since start: Date?, in context: ModelContext) -> [MoodEntry] {
        let from = start ?? .distantPast
        var result: [MoodEntry] = []

        let chatDescriptor = FetchDescriptor<ChatSession>(
            predicate: #Predicate { $0.startedAt >= from && $0.moodLevelRaw != nil }
        )
        for chat in (try? context.fetch(chatDescriptor)) ?? [] {
            guard let level = chat.moodLevel else { continue }
            result.append(MoodEntry(id: "chat-\(chat.id)", date: chat.startedAt, level: level, label: level.displayName))
        }

        let sessionDescriptor = FetchDescriptor<MeditationSession>(
            predicate: #Predicate { $0.startedAt >= from && $0.postMood != nil }
        )
        for session in (try? context.fetch(sessionDescriptor)) ?? [] {
            guard let raw = session.postMood, let mood = Mood(rawValue: raw) else { continue }
            result.append(MoodEntry(id: "session-\(session.id)", date: session.startedAt, level: mood.level, label: mood.displayName))
        }

        return result.sorted { $0.date > $1.date }
    }

    /// Average score per calendar day, oldest first. The card, the chart and
    /// the share image all use this, so they always agree.
    static func dailyAverages(_ entries: [MoodEntry]) -> [(date: Date, score: Double)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
        return grouped.map { day, items in
            (date: day, score: Double(items.map(\.level.score).reduce(0, +)) / Double(items.count))
        }
        .sorted { $0.date < $1.date }
    }
}
