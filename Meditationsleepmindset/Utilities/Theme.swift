//
//  Theme.swift
//  Meditation Sleep Mindset
//

import SwiftUI

enum Theme {
    // MARK: - Gradients
    static let primaryGradient = LinearGradient(
        colors: [
            Color(red: 0.1, green: 0.1, blue: 0.3),
            Color(red: 0.2, green: 0.1, blue: 0.4)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let sleepGradient = LinearGradient(
        colors: [
            Color(red: 0.05, green: 0.05, blue: 0.15),
            Color(red: 0.1, green: 0.05, blue: 0.2)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let profileGradient = LinearGradient(
        colors: [
            Color(red: 0.08, green: 0.15, blue: 0.28),
            Color(red: 0.1, green: 0.2, blue: 0.35)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.15),
            Color.white.opacity(0.05)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Colors
    static let accentColor = Color(red: 0.5, green: 0.3, blue: 0.9) // True purple, not pink
    static let secondaryAccent = Color.indigo
    static let profileAccent = Color(red: 0.65, green: 0.55, blue: 0.85) // Soft lavender/purple
    static let cardBackground = Color.white.opacity(0.1)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.5)

    // MARK: - Sleep Theme Colors
    static let sleepPrimary = Color(red: 0.3, green: 0.4, blue: 0.9)
    static let sleepSecondary = Color(red: 0.5, green: 0.3, blue: 0.8)

    // MARK: - Sleep Night Mode
    static let sleepBackground = LinearGradient(
        colors: [
            Color(red: 0.04, green: 0.06, blue: 0.14),
            Color(red: 0.06, green: 0.08, blue: 0.18)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let sleepCardBackground = Color.white.opacity(0.06)
    static let sleepTextPrimary = Color.white.opacity(0.85)
    static let sleepTextSecondary = Color.white.opacity(0.5)

    // MARK: - Mood Colors
    static let moodHappy = Color.yellow
    static let moodCalm = Color.green
    static let moodStressed = Color.orange
    static let moodSad = Color.blue
    static let moodAnxious = Color.red

    // MARK: - Spacing
    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 16
    static let paddingLarge: CGFloat = 24
    static let paddingXLarge: CGFloat = 32

    // MARK: - Corner Radius
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 16
    static let cornerRadiusXLarge: CGFloat = 24

    // MARK: - Shadows
    static let shadowColor = Color.black.opacity(0.3)
    static let shadowRadius: CGFloat = 10

    // MARK: - Adaptive Grid
    /// Returns the number of columns for content grids based on available width
    static func gridColumns(for width: CGFloat, minItemWidth: CGFloat = 160) -> Int {
        let columns = Int(width / minItemWidth)
        return max(2, min(columns, 6)) // Between 2 and 6 columns
    }

    /// Creates adaptive grid columns based on available width
    static func adaptiveGridItems(for width: CGFloat, minItemWidth: CGFloat = 160, spacing: CGFloat = 16) -> [GridItem] {
        let columnCount = gridColumns(for: width, minItemWidth: minItemWidth)
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: columnCount)
    }
}

// MARK: - View Extensions (instead of ViewModifiers to avoid Content naming conflict)
extension View {
    func primaryButton() -> some View {
        self
            .font(.headline)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.profileAccent)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
    }

    func secondaryButton() -> some View {
        self
            .font(.headline)
            .foregroundStyle(Theme.profileAccent)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
    }

    func cardStyle() -> some View {
        self
            .padding()
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge))
    }

    /// Standard app background gradient used across all main views
    func withAppBackground() -> some View {
        ZStack {
            Theme.profileGradient.ignoresSafeArea()
            self
        }
    }
}
