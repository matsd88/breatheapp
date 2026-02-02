//
//  ChatModels.swift
//  Meditation Sleep Mindset
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Mood Level

enum MoodLevel: String, Codable, CaseIterable, Identifiable {
    case great = "Great"
    case good = "Good"
    case okay = "Okay"
    case low = "Low"
    case struggling = "Struggling"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .great: return "😊"
        case .good: return "🙂"
        case .okay: return "😐"
        case .low: return "😔"
        case .struggling: return "😰"
        }
    }

    var color: Color {
        switch self {
        case .great: return .green
        case .good: return .teal
        case .okay: return .yellow
        case .low: return .orange
        case .struggling: return .red
        }
    }

    var systemPromptContext: String {
        switch self {
        case .great: return "The user reports feeling great today."
        case .good: return "The user reports feeling good today."
        case .okay: return "The user reports feeling okay — neutral mood."
        case .low: return "The user reports feeling low today. Be especially gentle and supportive."
        case .struggling: return "The user reports struggling today. Be very empathetic and supportive. If appropriate, gently mention professional support resources."
        }
    }
}

// MARK: - Chat Message Role

enum ChatMessageRole: String, Codable {
    case user
    case assistant
    case system
}

// MARK: - Chat Message Type

enum ChatMessageType: String, Codable {
    case text
    case moodCheckIn
    case crisisAlert
    case contentSuggestion
    case therapistReferral
}

// MARK: - Crisis Keywords

enum CrisisKeywords {
    static let keywords: Set<String> = [
        "suicide", "suicidal", "kill myself", "end my life", "want to die",
        "self-harm", "self harm", "cutting myself", "hurt myself",
        "overdose", "end it all", "no reason to live", "better off dead",
        "can't go on", "ending it all"
    ]

    static func containsCrisisKeyword(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return keywords.contains { lowered.contains($0) }
    }
}

// MARK: - Chat Session

@Model
final class ChatSession {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var moodLevelRaw: String?
    var messageCount: Int
    var isActive: Bool

    init() {
        self.id = UUID()
        self.startedAt = Date()
        self.endedAt = nil
        self.moodLevelRaw = nil
        self.messageCount = 0
        self.isActive = true
    }

    var moodLevel: MoodLevel? {
        guard let raw = moodLevelRaw else { return nil }
        return MoodLevel(rawValue: raw)
    }

    func endSession() {
        self.endedAt = Date()
        self.isActive = false
    }
}

// MARK: - Chat Message

@Model
final class ChatMessage {
    var id: UUID
    var sessionID: UUID
    var roleRaw: String
    var messageTypeRaw: String
    var content: String
    var timestamp: Date
    var suggestedContentID: UUID?
    var suggestedContentTitle: String?

    init(
        sessionID: UUID,
        role: ChatMessageRole,
        type: ChatMessageType,
        content: String,
        suggestedContentID: UUID? = nil,
        suggestedContentTitle: String? = nil
    ) {
        self.id = UUID()
        self.sessionID = sessionID
        self.roleRaw = role.rawValue
        self.messageTypeRaw = type.rawValue
        self.content = content
        self.timestamp = Date()
        self.suggestedContentID = suggestedContentID
        self.suggestedContentTitle = suggestedContentTitle
    }

    var role: ChatMessageRole {
        ChatMessageRole(rawValue: roleRaw) ?? .assistant
    }

    var messageType: ChatMessageType {
        ChatMessageType(rawValue: messageTypeRaw) ?? .text
    }
}
