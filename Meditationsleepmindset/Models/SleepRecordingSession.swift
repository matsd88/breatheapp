//
//  SleepRecordingSession.swift
//  Meditation Sleep Mindset
//
//  A night's sleep-sound recording summary. We store only loudness metrics and a
//  downsampled level timeline — never the raw audio — for privacy and storage.
//

import Foundation
import SwiftData
import SwiftUI

enum SnoreSeverity: String, Codable, CaseIterable {
    case minimal
    case light
    case moderate
    case heavy

    /// Classify from the number of detected loud (snore-like) events per hour.
    static func from(eventsPerHour: Double) -> SnoreSeverity {
        switch eventsPerHour {
        case ..<5: return .minimal
        case 5..<15: return .light
        case 15..<30: return .moderate
        default: return .heavy
        }
    }

    var displayName: String {
        switch self {
        case .minimal: return String(localized: "Minimal")
        case .light: return String(localized: "Light")
        case .moderate: return String(localized: "Moderate")
        case .heavy: return String(localized: "Heavy")
        }
    }

    var color: Color {
        switch self {
        case .minimal: return .green
        case .light: return .cyan
        case .moderate: return .orange
        case .heavy: return .red
        }
    }

    var icon: String {
        switch self {
        case .minimal: return "checkmark.circle.fill"
        case .light: return "waveform"
        case .moderate: return "waveform.path"
        case .heavy: return "exclamationmark.triangle.fill"
        }
    }
}

@Model
final class SleepRecordingSession {
    var id: UUID
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Int
    /// Count of detected loud/snore-like events across the night.
    var eventCount: Int
    var severityRaw: String
    /// Downsampled normalized loudness (0...1) across the night, for a simple graph.
    var levelTimeline: [Double]

    init(startedAt: Date, endedAt: Date, eventCount: Int, severity: SnoreSeverity, levelTimeline: [Double]) {
        self.id = UUID()
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = max(0, Int(endedAt.timeIntervalSince(startedAt)))
        self.eventCount = eventCount
        self.severityRaw = severity.rawValue
        self.levelTimeline = levelTimeline
    }

    var severity: SnoreSeverity {
        SnoreSeverity(rawValue: severityRaw) ?? .minimal
    }

    var eventsPerHour: Double {
        let hours = max(0.1, Double(durationSeconds) / 3600.0)
        return Double(eventCount) / hours
    }

    var durationFormatted: String {
        let h = durationSeconds / 3600
        let m = (durationSeconds % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    var nightLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: startedAt)
    }
}
