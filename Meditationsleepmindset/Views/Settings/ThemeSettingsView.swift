//
//  ThemeSettingsView.swift
//  Meditation Sleep Mindset
//

import SwiftUI

struct ThemeSettingsView: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    // Adaptive grid columns for iPad
    private var themeColumns: [GridItem] {
        sizeClass == .regular ? [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())]
    }
    private var backgroundColumns: [GridItem] {
        sizeClass == .regular ? [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Preview the selected theme as background
                themeManager.currentTheme.gradient
                    .ignoresSafeArea()

                AnimatedBackgroundView(
                    backgroundID: themeManager.currentBackground,
                    accentColor: themeManager.currentTheme.accentColor
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Theme Selection
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Color Theme")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal)

                            LazyVGrid(columns: themeColumns, spacing: 12) {
                                ForEach(PlayerTheme.all) { theme in
                                    ThemeOptionCard(
                                        theme: theme,
                                        isSelected: themeManager.currentTheme.id == theme.id
                                    ) {
                                        themeManager.setTheme(theme.id)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Background Selection
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Animated Background")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal)

                            LazyVGrid(columns: backgroundColumns, spacing: 12) {
                                ForEach(AnimatedBackgroundID.allCases) { bg in
                                    BackgroundOptionCard(
                                        background: bg,
                                        accentColor: themeManager.currentTheme.accentColor,
                                        isSelected: themeManager.currentBackground == bg
                                    ) {
                                        themeManager.setBackground(bg)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 24)
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Player Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.3), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Theme Option Card

struct ThemeOptionCard: View {
    let theme: PlayerTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Theme preview
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.gradient)
                    .frame(height: 80)
                    .overlay(
                        Image(systemName: theme.icon)
                            .font(.title)
                            .foregroundStyle(theme.accentColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? theme.accentColor : Color.clear, lineWidth: 3)
                    )

                // Theme name
                Text(theme.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(.white)

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.accentColor)
                        .font(.caption)
                } else {
                    Circle()
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        .frame(width: 16, height: 16)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Background Option Card

struct BackgroundOptionCard: View {
    let background: AnimatedBackgroundID
    let accentColor: Color
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        Button(action: action) {
            VStack(spacing: isRegular ? 8 : 6) {
                // Icon - larger on iPad
                Image(systemName: background.icon)
                    .font(isRegular ? .title : .title2)
                    .foregroundStyle(isSelected ? accentColor : .white)
                    .frame(width: isRegular ? 70 : 50, height: isRegular ? 70 : 50)
                    .background(
                        Circle()
                            .fill(isSelected ? accentColor.opacity(0.2) : Color.white.opacity(0.1))
                    )
                    .overlay(
                        Circle()
                            .stroke(isSelected ? accentColor : Color.clear, lineWidth: isRegular ? 3 : 2)
                    )

                // Name
                Text(background.name)
                    .font(isRegular ? .caption : .caption2)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? accentColor : .white)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ThemeSettingsView()
}
