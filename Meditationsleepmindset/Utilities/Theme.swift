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

// MARK: - Reusable Sheet Components

/// Premium styled close button for sheets
struct SheetCloseButton: View {
    let action: () -> Void
    var style: CloseButtonStyle = .circle

    enum CloseButtonStyle {
        case circle      // Circle with X icon
        case pill        // Pill with "Done" text
        case minimal     // Just the X icon
    }

    var body: some View {
        Button(action: {
            HapticManager.light()
            action()
        }) {
            switch style {
            case .circle:
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

            case .pill:
                Text("Done")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())

            case .minimal:
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

/// Premium styled drag indicator for sheets
struct SheetDragIndicator: View {
    var body: some View {
        Capsule()
            .fill(Color.white.opacity(0.4))
            .frame(width: 36, height: 5)
            .padding(.top, 12)
    }
}

/// Consistent sheet header with title and close button
struct SheetHeader: View {
    let title: String
    var subtitle: String? = nil
    let onClose: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()

            SheetCloseButton(action: onClose)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}
