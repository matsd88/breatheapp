//
//  AIGeneratedMeditation.swift
//  Meditation Sleep Mindset
//
//  SwiftData model for storing AI-generated personalized meditations.
//

import Foundation
import SwiftData

// MARK: - AI Meditation Configuration Types

enum AIMeditationDuration: Int, CaseIterable, Identifiable {
    case five = 5
    case ten = 10
    case fifteen = 15
    case twenty = 20
    case thirty = 30

    var id: Int { rawValue }

    var displayName: String {
        "\(rawValue) min"
    }

    /// Approximate word count for the script based on meditation pacing
    /// (Slower than typical speech: ~100 words per minute for meditation)
    var approximateWordCount: Int {
        rawValue * 80 // 80 words per minute for slow, calming speech with pauses
    }
}

enum AIMeditationFocus: String, CaseIterable, Identifiable {
    case anxiety = "anxiety"
    case sleep = "sleep"
    case stress = "stress"
    case focus = "focus"
    case gratitude = "gratitude"
    case selfLove = "self-love"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anxiety: return String(localized: "Anxiety Relief")
        case .sleep: return String(localized: "Sleep")
        case .stress: return String(localized: "Stress Relief")
        case .focus: return String(localized: "Focus")
        case .gratitude: return String(localized: "Gratitude")
        case .selfLove: return String(localized: "Self-Love")
        }
    }

    var icon: String {
        switch self {
        case .anxiety: return "heart.circle"
        case .sleep: return "moon.stars"
        case .stress: return "leaf"
        case .focus: return "target"
        case .gratitude: return "hands.clap"
        case .selfLove: return "heart.fill"
        }
    }

    var promptContext: String {
        switch self {
        case .anxiety:
            return "calming anxiety, releasing worry, finding inner peace, grounding techniques"
        case .sleep:
            return "preparing for restful sleep, letting go of the day, relaxing deeply, drifting off peacefully"
        case .stress:
            return "releasing tension, finding calm amid chaos, letting go of stress, restoring balance"
        case .focus:
            return "sharpening concentration, clearing mental clutter, enhancing awareness, staying present"
        case .gratitude:
            return "appreciating life's blessings, cultivating thankfulness, recognizing abundance, opening the heart"
        case .selfLove:
            return "self-compassion, accepting yourself fully, nurturing your inner self, embracing who you are"
        }
    }
}

enum AIMeditationVoice: String, CaseIterable, Identifiable {
    case calmFemale = "calm_female"
    case calmMale = "calm_male"
    case whispered = "whispered"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .calmFemale: return String(localized: "Calm Female")
        case .calmMale: return String(localized: "Calm Male")
        case .whispered: return String(localized: "Whispered")
        }
    }

    var icon: String {
        switch self {
        case .calmFemale: return "person.wave.2"
        case .calmMale: return "person.wave.2.fill"
        case .whispered: return "speaker.wave.1"
        }
    }

    /// OpenAI TTS voice mapping
    var openAIVoice: String {
        switch self {
        case .calmFemale: return "nova"    // warm, friendly female
        case .calmMale: return "onyx"      // deep, calm male
        case .whispered: return "shimmer"  // soft, gentle female
        }
    }

    /// Speech speed for meditation pacing (0.25–4.0, default 1.0)
    var speechSpeed: Double {
        switch self {
        case .calmFemale: return 0.85
        case .calmMale: return 0.85
        case .whispered: return 0.80
        }
    }
}

enum AIMeditationBackground: String, CaseIterable, Identifiable {
    case nature = "nature"
    case rain = "rain"
    case silence = "silence"
    case singingBowls = "singing_bowls"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nature: return String(localized: "Nature")
        case .rain: return String(localized: "Rain")
        case .silence: return String(localized: "Silence")
        case .singingBowls: return String(localized: "Singing Bowls")
        }
    }

    var icon: String {
        switch self {
        case .nature: return "leaf.fill"
        case .rain: return "cloud.rain.fill"
        case .silence: return "speaker.slash.fill"
        case .singingBowls: return "bell.fill"
        }
    }
}

// MARK: - AI Meditation Request

struct AIMeditationRequest {
    let duration: AIMeditationDuration
    let focus: AIMeditationFocus
    let voice: AIMeditationVoice
    let background: AIMeditationBackground
    let personalNote: String?

    /// Unique identifier for caching
    var cacheKey: String {
        let noteHash = personalNote?.hashValue ?? 0
        return "ai_meditation_\(duration.rawValue)_\(focus.rawValue)_\(voice.rawValue)_\(background.rawValue)_\(noteHash)"
    }
}

// MARK: - AI Generated Meditation Model

@Model
final class AIGeneratedMeditation {
    var id: UUID
    var title: String
    var script: String
    var audioFileURL: String
    var durationSeconds: Int
    var focus: String
    var voice: String
    var background: String
    var createdAt: Date
    var playCount: Int
    var isFavorite: Bool

    init(
        title: String,
        script: String,
        audioFileURL: String,
        durationSeconds: Int,
        focus: String,
        voice: String,
        background: String
    ) {
        self.id = UUID()
        self.title = title
        self.script = script
        self.audioFileURL = audioFileURL
        self.durationSeconds = durationSeconds
        self.focus = focus
        self.voice = voice
        self.background = background
        self.createdAt = Date()
        self.playCount = 0
        self.isFavorite = false
    }

    // MARK: - Computed Properties

    var durationFormatted: String {
        guard durationSeconds > 0 else { return "" }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = durationSeconds >= 3600 ? [.hour, .minute] : [.minute]
        return formatter.string(from: Double(durationSeconds)) ?? ""
    }

    var focusType: AIMeditationFocus? {
        AIMeditationFocus(rawValue: focus)
    }

    var voiceType: AIMeditationVoice? {
        AIMeditationVoice(rawValue: voice)
    }

    var backgroundType: AIMeditationBackground? {
        AIMeditationBackground(rawValue: background)
    }

    var createdAtFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    var createdAtRelative: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    // MARK: - Methods

    func incrementPlayCount() {
        playCount += 1
    }

    func toggleFavorite() {
        isFavorite.toggle()
    }
}
