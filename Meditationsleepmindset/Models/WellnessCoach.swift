//
//  WellnessCoach.swift
//  Meditation Sleep Mindset
//
//  Domain-specific AI coach personas for the Breathe AI chat. Each coach tailors the
//  assistant's tone and expertise to a life area (inspired by multi-coach apps).
//

import Foundation

enum WellnessCoach: String, CaseIterable, Identifiable, Codable {
    case general
    case stress
    case sleep
    case relationships
    case parenting
    case focus

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .general: return String(localized: "Breathe AI")
        case .stress: return String(localized: "Stress Coach")
        case .sleep: return String(localized: "Sleep Coach")
        case .relationships: return String(localized: "Relationships Coach")
        case .parenting: return String(localized: "Parenting Coach")
        case .focus: return String(localized: "Focus Coach")
        }
    }

    var shortName: String {
        switch self {
        case .general: return String(localized: "General")
        case .stress: return String(localized: "Stress")
        case .sleep: return String(localized: "Sleep")
        case .relationships: return String(localized: "Relationships")
        case .parenting: return String(localized: "Parenting")
        case .focus: return String(localized: "Focus")
        }
    }

    var icon: String {
        switch self {
        case .general: return "sparkles"
        case .stress: return "leaf.fill"
        case .sleep: return "moon.stars.fill"
        case .relationships: return "heart.fill"
        case .parenting: return "figure.and.child.holdinghands"
        case .focus: return "target"
        }
    }

    var tagline: String {
        switch self {
        case .general: return String(localized: "Your everyday wellness companion")
        case .stress: return String(localized: "Calm anxiety & overwhelm")
        case .sleep: return String(localized: "Wind down & sleep better")
        case .relationships: return String(localized: "Navigate connection & conflict")
        case .parenting: return String(localized: "Support for the hardest job")
        case .focus: return String(localized: "Clear your mind & concentrate")
        }
    }

    /// Specialization appended to the base system prompt.
    var promptContext: String {
        switch self {
        case .general:
            return "You are in general wellness mode — support the user with whatever is on their mind."
        case .stress:
            return "You are specialized as a STRESS & ANXIETY coach. Lean on grounding, breathwork, cognitive reframing, and nervous-system regulation. Help the user name what they feel and find one small next step."
        case .sleep:
            return "You are specialized as a SLEEP coach. Focus on sleep hygiene, wind-down routines, racing-mind techniques, and bedtime relaxation. Keep responses especially calm and slow-paced, and suggest sleep stories or soundscapes when fitting."
        case .relationships:
            return "You are specialized as a RELATIONSHIPS coach. Support healthy communication, boundaries, empathy, and self-reflection. Stay neutral and non-judgmental; never take sides or give legal advice."
        case .parenting:
            return "You are specialized as a PARENTING coach. Support overwhelmed parents with self-compassion, co-regulation, realistic expectations, and tiny moments of calm. Validate how hard parenting is."
        case .focus:
            return "You are specialized as a FOCUS coach. Help with concentration, single-tasking, beating procrastination, and gentle productivity. Suggest the Focus Timer and short resets when relevant."
        }
    }

    /// OpenAI TTS voice used when reading this coach's replies aloud (premium).
    /// One of: alloy, echo, fable, onyx, nova, shimmer — chosen to match the coach's tone.
    var ttsVoice: String {
        switch self {
        case .general: return "nova"          // warm, friendly everyday companion
        case .stress: return "shimmer"        // soft, gentle, soothing
        case .sleep: return "onyx"            // deep, calm, unhurried
        case .relationships: return "fable"   // warm, expressive
        case .parenting: return "alloy"       // balanced, reassuring
        case .focus: return "echo"            // clear, steady
        }
    }

    /// Speech speed for read-aloud replies (wind-down coaches speak a touch slower).
    var ttsSpeed: Double {
        switch self {
        case .sleep: return 0.9
        case .stress: return 0.95
        default: return 1.0
        }
    }

    var welcomeLine: String {
        switch self {
        case .general: return "Hi, I'm here to support your wellness journey. How are you feeling today?"
        case .stress: return "I'm your stress coach. Whatever's weighing on you, let's take it one breath at a time. What's going on?"
        case .sleep: return "I'm your sleep coach. Let's help your mind and body settle. What's keeping you up?"
        case .relationships: return "I'm your relationships coach. This is a safe, judgment-free space. What's on your heart?"
        case .parenting: return "I'm your parenting coach. Parenting is hard — you're doing better than you think. What's happening?"
        case .focus: return "I'm your focus coach. Let's clear the noise and find your flow. What are you trying to focus on?"
        }
    }
}
