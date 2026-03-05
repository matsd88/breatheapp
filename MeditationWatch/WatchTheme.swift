//
//  WatchTheme.swift
//  MeditationWatch
//
//  Theme constants matching the iOS app
//

import SwiftUI

enum WatchTheme {
    // MARK: - Gradients

    static let primaryGradient = LinearGradient(
        colors: [
            Color(red: 0.08, green: 0.15, blue: 0.28),
            Color(red: 0.12, green: 0.22, blue: 0.42)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.12),
            Color.white.opacity(0.05)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Colors

    static let accentColor = Color(red: 0.5, green: 0.3, blue: 0.9)
    static let secondaryAccent = Color.indigo
    static let profileAccent = Color(red: 0.65, green: 0.55, blue: 0.85)
    static let cardBackground = Color.white.opacity(0.1)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.5)

    // MARK: - Content Type Colors

    static func colorFor(contentType: String) -> Color {
        switch contentType {
        case "Meditation": return .purple
        case "Sleep Story": return .indigo
        case "Soundscape": return .teal
        case "Music": return .pink
        case "Movement": return .orange
        case "ASMR": return .cyan
        case "Mindset": return .green
        case "Breathing": return .cyan
        default: return .purple
        }
    }

    // MARK: - Spacing

    static let paddingSmall: CGFloat = 4
    static let paddingMedium: CGFloat = 8
    static let paddingLarge: CGFloat = 12

    // MARK: - Corner Radius

    static let cornerRadiusSmall: CGFloat = 6
    static let cornerRadiusMedium: CGFloat = 10
    static let cornerRadiusLarge: CGFloat = 14
}

// MARK: - Watch View Modifiers

extension View {
    func watchCardStyle() -> some View {
        self
            .padding(WatchTheme.paddingMedium)
            .background(WatchTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: WatchTheme.cornerRadiusMedium))
    }

    func watchPrimaryButton() -> some View {
        self
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: WatchTheme.cornerRadiusMedium))
    }

    func watchSecondaryButton() -> some View {
        self
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.15))
            .clipShape(Capsule())
    }
}
