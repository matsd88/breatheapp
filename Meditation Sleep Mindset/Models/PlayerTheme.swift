//
//  PlayerTheme.swift
//  Meditation Sleep Mindset
//

import SwiftUI

// MARK: - Theme Definition

enum PlayerThemeID: String, CaseIterable, Codable, Identifiable {
    case midnight
    case forest
    case sunset
    case ocean
    case moonlit
    case minimal

    var id: String { rawValue }
}

struct PlayerTheme: Identifiable {
    let id: PlayerThemeID
    let name: String
    let description: String
    let gradientColors: [Color]
    let accentColor: Color
    let cardBackground: Color
    let icon: String

    var gradient: LinearGradient {
        LinearGradient(
            colors: gradientColors,
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

extension PlayerTheme {
    static let midnight = PlayerTheme(
        id: .midnight,
        name: "Midnight",
        description: "Deep blues for evening calm",
        gradientColors: [
            Color(hex: "1a1a2e"),
            Color(hex: "16213e"),
            Color(hex: "0f3460")
        ],
        accentColor: Color(hex: "7c73e6"),
        cardBackground: Color(hex: "1e2a4a").opacity(0.8),
        icon: "moon.stars.fill"
    )

    static let forest = PlayerTheme(
        id: .forest,
        name: "Twilight Forest",
        description: "Grounding greens for stress relief",
        gradientColors: [
            Color(hex: "1a2e1a"),
            Color(hex: "163e2e"),
            Color(hex: "0f4a3d")
        ],
        accentColor: Color(hex: "4ecdc4"),
        cardBackground: Color(hex: "1e3a2a").opacity(0.8),
        icon: "leaf.fill"
    )

    static let sunset = PlayerTheme(
        id: .sunset,
        name: "Sunset Calm",
        description: "Warm tones for gentle energy",
        gradientColors: [
            Color(hex: "2e1a1a"),
            Color(hex: "3e2416"),
            Color(hex: "4a3020")
        ],
        accentColor: Color(hex: "f4a261"),
        cardBackground: Color(hex: "3a2a1e").opacity(0.8),
        icon: "sun.horizon.fill"
    )

    static let ocean = PlayerTheme(
        id: .ocean,
        name: "Ocean Depths",
        description: "Cool blues for focus & calm",
        gradientColors: [
            Color(hex: "0a1628"),
            Color(hex: "0d2137"),
            Color(hex: "0f2d4a")
        ],
        accentColor: Color(hex: "00b4d8"),
        cardBackground: Color(hex: "142a3e").opacity(0.8),
        icon: "water.waves"
    )

    static let moonlit = PlayerTheme(
        id: .moonlit,
        name: "Moonlit Sky",
        description: "Soft purples for sleep stories",
        gradientColors: [
            Color(hex: "1a1a2e"),
            Color(hex: "2d1f3d"),
            Color(hex: "3d2a4a")
        ],
        accentColor: Color(hex: "b39ddb"),
        cardBackground: Color(hex: "2a1e3a").opacity(0.8),
        icon: "moon.fill"
    )

    static let minimal = PlayerTheme(
        id: .minimal,
        name: "Minimal Dark",
        description: "Pure black for OLED screens",
        gradientColors: [
            Color(hex: "000000"),
            Color(hex: "0a0a0a"),
            Color(hex: "121212")
        ],
        accentColor: .white,
        cardBackground: Color(hex: "1a1a1a").opacity(0.8),
        icon: "circle.fill"
    )

    static let all: [PlayerTheme] = [
        .midnight, .forest, .sunset, .ocean, .moonlit, .minimal
    ]

    static func theme(for id: PlayerThemeID) -> PlayerTheme {
        switch id {
        case .midnight: return .midnight
        case .forest: return .forest
        case .sunset: return .sunset
        case .ocean: return .ocean
        case .moonlit: return .moonlit
        case .minimal: return .minimal
        }
    }
}

// MARK: - Animated Background

enum AnimatedBackgroundID: String, CaseIterable, Codable, Identifiable {
    case none
    case rain
    case water
    case aurora
    case stars
    case pulse

    var id: String { rawValue }

    var name: String {
        switch self {
        case .none: return "None"
        case .rain: return "Gentle Rain"
        case .water: return "Flowing Water"
        case .aurora: return "Drifting Mist"
        case .stars: return "Starry Sky"
        case .pulse: return "Breathing Pulse"
        }
    }

    var icon: String {
        switch self {
        case .none: return "circle.slash"
        case .rain: return "cloud.rain.fill"
        case .water: return "water.waves"
        case .aurora: return "cloud.fog.fill"
        case .stars: return "sparkles"
        case .pulse: return "circle.circle"
        }
    }
}

// Note: Color(hex:) extension is defined in Utilities/Extensions.swift
