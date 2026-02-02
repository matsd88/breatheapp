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

    var displayName: String { rawValue }

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
        let minutes = durationSeconds / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
        }
        return "\(minutes) min"
    }

    var thumbnailURLComputed: String {
        // Use mqdefault.jpg (320x180) for clean 16:9 thumbnails without black letterbox bars
        // hqdefault.jpg (480x360) is 4:3 and adds black bars to 16:9 video thumbnails
        thumbnailURL ?? "https://img.youtube.com/vi/\(youtubeVideoID)/mqdefault.jpg"
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
        "https://img.youtube.com/vi/\(youtubeVideoID)/hqdefault.jpg"
    }

    var durationFormatted: String {
        let minutes = durationSeconds / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
        }
        return "\(minutes) min"
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
        "https://img.youtube.com/vi/\(youtubeVideoID)/mqdefault.jpg"
    }

    var durationFormatted: String {
        let minutes = durationSeconds / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
        }
        return "\(minutes) min"
    }
}
