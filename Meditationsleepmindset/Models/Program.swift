//
//  Program.swift
//  Meditation Sleep Mindset
//

import Foundation
import SwiftData

@Model
final class Program {
    var id: UUID
    var name: String
    var programDescription: String
    var totalDays: Int
    var category: String
    var iconName: String
    var isPremium: Bool

    init(
        name: String,
        description: String,
        totalDays: Int,
        category: ContentType,
        iconName: String = "book.closed.fill",
        isPremium: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.programDescription = description
        self.totalDays = totalDays
        self.category = category.rawValue
        self.iconName = iconName
        self.isPremium = isPremium
    }

    var contentType: ContentType {
        ContentType(rawValue: category) ?? .meditation
    }
}

@Model
final class ProgramDay {
    var id: UUID
    var programID: UUID
    var dayNumber: Int
    var contentID: UUID?
    var youtubeVideoID: String
    var title: String

    init(
        programID: UUID,
        dayNumber: Int,
        youtubeVideoID: String,
        title: String,
        contentID: UUID? = nil
    ) {
        self.id = UUID()
        self.programID = programID
        self.dayNumber = dayNumber
        self.youtubeVideoID = youtubeVideoID
        self.title = title
        self.contentID = contentID
    }

    var thumbnailURL: String {
        if VideoService.useR2 {
            return "https://pub-7b886d08f03c4e4ebcee90f70a22739e.r2.dev/videos/\(youtubeVideoID)/thumb.jpg"
        }
        return "https://img.youtube.com/vi/\(youtubeVideoID)/mqdefault.jpg"
    }
}

@Model
final class ProgramProgress {
    var id: UUID
    var programID: UUID
    var currentDay: Int
    var startedAt: Date
    var completedDays: [Int]
    var isCompleted: Bool

    init(programID: UUID) {
        self.id = UUID()
        self.programID = programID
        self.currentDay = 1
        self.startedAt = Date()
        self.completedDays = []
        self.isCompleted = false
    }

    func completeDay(_ day: Int) {
        if !completedDays.contains(day) {
            completedDays.append(day)
        }
        if day >= currentDay {
            currentDay = day + 1
        }
    }
}
