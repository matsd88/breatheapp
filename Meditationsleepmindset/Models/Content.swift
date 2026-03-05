//
//  Content.swift
//  Meditation Sleep Mindset
//

import Foundation
import SwiftData

enum ContentType: String, Codable, CaseIterable, Identifiable {
    case meditation = "Meditation"
    case sleepStory = "Sleep Story"
    case soundscape = "Soundscape"
    case music = "Music"
    case movement = "Movement"
    case mindset = "Mindset"
    case asmr = "ASMR"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .meditation: return String(localized: "Meditation")
        case .sleepStory: return String(localized: "Sleep Story")
        case .soundscape: return String(localized: "Soundscape")
        case .music: return String(localized: "Music")
        case .movement: return String(localized: "Movement")
        case .mindset: return String(localized: "Mindset")
        case .asmr: return String(localized: "ASMR")
        }
    }

    var iconName: String {
        switch self {
        case .meditation: return "brain.head.profile"
        case .sleepStory: return "book.closed.fill"
        case .soundscape: return "waveform"
        case .music: return "music.note"
        case .movement: return "figure.mind.and.body"
        case .asmr: return "ear.fill"
        case .mindset: return "lightbulb.fill"
        }
    }

    var color: String {
        switch self {
        case .meditation: return "purple"
        case .sleepStory: return "indigo"
        case .soundscape: return "teal"
        case .music: return "pink"
        case .movement: return "orange"
        case .asmr: return "cyan"
        case .mindset: return "green"
        }
    }
}

enum Mood: String, Codable, CaseIterable, Identifiable {
    case calm = "Calm"
    case happy = "Happy"
    case anxious = "Anxious"
    case stressed = "Stressed"
    case sad = "Sad"
    case tired = "Tired"
    case energetic = "Energetic"
    case focused = "Focused"
    case grateful = "Grateful"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .calm: return String(localized: "Calm")
        case .happy: return String(localized: "Happy")
        case .anxious: return String(localized: "Anxious")
        case .stressed: return String(localized: "Stressed")
        case .sad: return String(localized: "Sad")
        case .tired: return String(localized: "Tired")
        case .energetic: return String(localized: "Energetic")
        case .focused: return String(localized: "Focused")
        case .grateful: return String(localized: "Grateful")
        }
    }
}

@Model
final class Content {
    var id: UUID
    var title: String
    var subtitle: String?
    @Attribute(.unique) var youtubeVideoID: String
    var thumbnailURL: String?
    var contentTypeRaw: String
    var durationSeconds: Int
    var narrator: String?
    var tags: [String]
    var isPremium: Bool
    var contentDescription: String?
    var isFeatured: Bool
    var featuredDate: Date?
    var isUserAdded: Bool

    init(
        title: String,
        subtitle: String? = nil,
        youtubeVideoID: String,
        thumbnailURL: String? = nil,
        contentType: ContentType,
        durationSeconds: Int,
        narrator: String? = nil,
        tags: [String] = [],
        isPremium: Bool = false,
        description: String? = nil,
        isFeatured: Bool = false,
        featuredDate: Date? = nil,
        isUserAdded: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.subtitle = subtitle
        self.youtubeVideoID = youtubeVideoID
        self.thumbnailURL = thumbnailURL
        self.contentTypeRaw = contentType.rawValue
        self.durationSeconds = durationSeconds
        self.narrator = narrator
        self.tags = tags
        self.isPremium = isPremium
        self.contentDescription = description
        self.isFeatured = isFeatured
        self.featuredDate = featuredDate
        self.isUserAdded = isUserAdded
    }

    var contentType: ContentType {
        ContentType(rawValue: contentTypeRaw) ?? .meditation
    }

    var durationFormatted: String {
        guard durationSeconds > 0 else { return "" }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = durationSeconds >= 3600 ? [.hour, .minute] : [.minute]
        return formatter.string(from: Double(durationSeconds)) ?? ""
    }

    var thumbnailURLComputed: String {
        // If custom thumbnail URL is set, use it
        if let custom = thumbnailURL { return custom }

        // Use R2-hosted thumbnails when enabled, otherwise fallback to YouTube
        if VideoService.useR2 {
            // R2 structure: {baseURL}/videos/{videoID}/thumb.jpg
            return "https://pub-7b886d08f03c4e4ebcee90f70a22739e.r2.dev/videos/\(youtubeVideoID)/thumb.jpg"
        }

        // Default: YouTube thumbnail (mqdefault for 16:9 without letterboxing)
        return "https://img.youtube.com/vi/\(youtubeVideoID)/mqdefault.jpg"
    }
}

@Model
final class FavoriteContent {
    var id: UUID
    var contentID: UUID
    var youtubeVideoID: String
    var contentTitle: String
    var contentTypeRaw: String
    var durationSeconds: Int
    var addedAt: Date

    init(contentID: UUID, youtubeVideoID: String, title: String, contentType: ContentType, durationSeconds: Int) {
        self.id = UUID()
        self.contentID = contentID
        self.youtubeVideoID = youtubeVideoID
        self.contentTitle = title
        self.contentTypeRaw = contentType.rawValue
        self.durationSeconds = durationSeconds
        self.addedAt = Date()
    }

    /// Convenience initializer from Content
    convenience init(from content: Content) {
        self.init(
            contentID: content.id,
            youtubeVideoID: content.youtubeVideoID,
            title: content.title,
            contentType: content.contentType,
            durationSeconds: content.durationSeconds
        )
    }

    var contentType: ContentType {
        ContentType(rawValue: contentTypeRaw) ?? .meditation
    }

    var thumbnailURL: String {
        if VideoService.useR2 {
            return "https://pub-7b886d08f03c4e4ebcee90f70a22739e.r2.dev/videos/\(youtubeVideoID)/thumb.jpg"
        }
        return "https://img.youtube.com/vi/\(youtubeVideoID)/mqdefault.jpg"
    }

    var durationFormatted: String {
        guard durationSeconds > 0 else { return "" }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = durationSeconds >= 3600 ? [.hour, .minute] : [.minute]
        return formatter.string(from: Double(durationSeconds)) ?? ""
    }
}

@Model
final class MeditationSession {
    var id: UUID
    var contentID: UUID?
    var youtubeVideoID: String?
    var contentTitle: String?
    var startedAt: Date
    var completedAt: Date?
    var durationSeconds: Int
    var listenedSeconds: Int
    var wasCompleted: Bool
    var sessionType: String
    var preMood: String?
    var postMood: String?

    init(
        contentID: UUID? = nil,
        youtubeVideoID: String? = nil,
        contentTitle: String? = nil,
        durationSeconds: Int = 0,
        listenedSeconds: Int = 0,
        wasCompleted: Bool = false,
        sessionType: String = "guided",
        completedAt: Date? = nil
    ) {
        self.id = UUID()
        self.contentID = contentID
        self.youtubeVideoID = youtubeVideoID
        self.contentTitle = contentTitle
        self.startedAt = completedAt ?? Date()
        self.completedAt = completedAt
        self.durationSeconds = durationSeconds
        self.listenedSeconds = listenedSeconds
        self.wasCompleted = wasCompleted
        self.sessionType = sessionType
    }

    /// Progress as a fraction (0.0 to 1.0)
    var progress: Double {
        guard durationSeconds > 0 else { return 0 }
        return min(1.0, Double(listenedSeconds) / Double(durationSeconds))
    }

    func complete() {
        self.completedAt = Date()
        self.wasCompleted = true
    }

    func setPreMood(_ mood: Mood) {
        self.preMood = mood.rawValue
    }

    func setPostMood(_ mood: Mood) {
        self.postMood = mood.rawValue
    }
}

// MARK: - Biometric Session Data

@Model
final class BiometricSessionData {
    var id: UUID
    var sessionID: UUID
    var startHeartRate: Int?
    var endHeartRate: Int?
    var avgHeartRate: Int?
    var recordedAt: Date

    init(sessionID: UUID, startHeartRate: Int?, endHeartRate: Int?, avgHeartRate: Int?) {
        self.id = UUID()
        self.sessionID = sessionID
        self.startHeartRate = startHeartRate
        self.endHeartRate = endHeartRate
        self.avgHeartRate = avgHeartRate
        self.recordedAt = Date()
    }

    var heartRateChange: Int? {
        guard let start = startHeartRate, let end = endHeartRate else { return nil }
        return end - start
    }

    var formattedChange: String {
        guard let change = heartRateChange else { return "--" }
        if change > 0 { return "+\(change) bpm" }
        if change < 0 { return "\(change) bpm" }
        return "0 bpm"
    }
}

// MARK: - Playlist

@Model
final class Playlist {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var coverYoutubeVideoID: String?

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
        self.coverYoutubeVideoID = nil
    }

    var coverThumbnailURL: String? {
        guard let videoID = coverYoutubeVideoID else { return nil }
        if VideoService.useR2 {
            return "https://pub-7b886d08f03c4e4ebcee90f70a22739e.r2.dev/videos/\(videoID)/thumb.jpg"
        }
        return "https://img.youtube.com/vi/\(videoID)/mqdefault.jpg"
    }
}

// MARK: - Playlist Item

@Model
final class PlaylistItem {
    var id: UUID
    var playlistID: UUID
    var contentID: UUID
    var youtubeVideoID: String
    var contentTitle: String
    var contentTypeRaw: String
    var durationSeconds: Int
    var orderIndex: Int
    var addedAt: Date

    init(
        playlistID: UUID,
        contentID: UUID,
        youtubeVideoID: String,
        title: String,
        contentType: ContentType,
        durationSeconds: Int,
        orderIndex: Int
    ) {
        self.id = UUID()
        self.playlistID = playlistID
        self.contentID = contentID
        self.youtubeVideoID = youtubeVideoID
        self.contentTitle = title
        self.contentTypeRaw = contentType.rawValue
        self.durationSeconds = durationSeconds
        self.orderIndex = orderIndex
        self.addedAt = Date()
    }

    /// Convenience initializer from Content
    convenience init(playlistID: UUID, from content: Content, orderIndex: Int) {
        self.init(
            playlistID: playlistID,
            contentID: content.id,
            youtubeVideoID: content.youtubeVideoID,
            title: content.title,
            contentType: content.contentType,
            durationSeconds: content.durationSeconds,
            orderIndex: orderIndex
        )
    }

    var contentType: ContentType {
        ContentType(rawValue: contentTypeRaw) ?? .meditation
    }

    var thumbnailURL: String {
        if VideoService.useR2 {
            return "https://pub-7b886d08f03c4e4ebcee90f70a22739e.r2.dev/videos/\(youtubeVideoID)/thumb.jpg"
        }
        return "https://img.youtube.com/vi/\(youtubeVideoID)/mqdefault.jpg"
    }

    var durationFormatted: String {
        guard durationSeconds > 0 else { return "" }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = durationSeconds >= 3600 ? [.hour, .minute] : [.minute]
        return formatter.string(from: Double(durationSeconds)) ?? ""
    }
}
