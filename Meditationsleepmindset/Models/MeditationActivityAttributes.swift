//
//  MeditationActivityAttributes.swift
//  Meditation Sleep Mindset
//
//  Live Activity attributes for meditation timer
//

import ActivityKit
import Foundation

/// Attributes for the meditation Live Activity
/// These define the static and dynamic data for the activity
struct MeditationActivityAttributes: ActivityAttributes {

    /// Dynamic content state that updates during the activity
    public struct ContentState: Codable, Hashable {
        /// Current playback time in seconds
        var currentTime: TimeInterval

        /// Total duration of the content in seconds
        var totalDuration: TimeInterval

        /// Whether playback is currently active
        var isPlaying: Bool

        /// Title of the meditation content
        var contentTitle: String

        /// Type of content (e.g., "Meditation", "Sleep Story")
        var contentType: String

        /// Progress as a fraction (0.0 to 1.0)
        var progress: Double {
            guard totalDuration > 0 else { return 0 }
            return min(1.0, currentTime / totalDuration)
        }

        /// Time remaining in seconds
        var timeRemaining: TimeInterval {
            max(0, totalDuration - currentTime)
        }

        /// Formatted time remaining string (e.g., "5:23")
        var timeRemainingFormatted: String {
            let minutes = Int(timeRemaining) / 60
            let seconds = Int(timeRemaining) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }

        /// Formatted current time string (e.g., "2:15")
        var currentTimeFormatted: String {
            let minutes = Int(currentTime) / 60
            let seconds = Int(currentTime) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }

        /// Formatted total duration string
        var totalDurationFormatted: String {
            let minutes = Int(totalDuration) / 60
            let seconds = Int(totalDuration) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Unique identifier for this meditation session
    var sessionId: String

    /// YouTube video ID for thumbnail
    var videoId: String

    /// Thumbnail URL for the content
    var thumbnailURL: String {
        "https://img.youtube.com/vi/\(videoId)/mqdefault.jpg"
    }
}
