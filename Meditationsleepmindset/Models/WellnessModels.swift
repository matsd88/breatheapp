//
//  WellnessModels.swift
//  Meditation Sleep Mindset
//
//  SwiftData models for the Daily Intention ritual and Gratitude Journal.
//

import Foundation
import SwiftData

// MARK: - Gratitude Journal Entry

@Model
final class GratitudeEntry {
    var id: UUID
    var text: String
    /// The reflective prompt the user was answering (nil for a freeform entry).
    var prompt: String?
    /// Optional mood tag captured alongside the entry.
    var moodRaw: String?
    var createdAt: Date

    init(text: String, prompt: String? = nil, mood: Mood? = nil) {
        self.id = UUID()
        self.text = text
        self.prompt = prompt
        self.moodRaw = mood?.rawValue
        self.createdAt = Date()
    }

    var mood: Mood? {
        guard let moodRaw else { return nil }
        return Mood(rawValue: moodRaw)
    }

    var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: createdAt)
    }
}

// MARK: - Daily Intention Record

@Model
final class DailyIntentionRecord {
    var id: UUID
    var text: String
    /// Raw value of the associated `AIMeditationFocus` (so the home feed can curate to it).
    var focusRaw: String?
    var createdAt: Date

    init(text: String, focusRaw: String? = nil) {
        self.id = UUID()
        self.text = text
        self.focusRaw = focusRaw
        self.createdAt = Date()
    }

    var isFromToday: Bool {
        Calendar.current.isDateInToday(createdAt)
    }
}
