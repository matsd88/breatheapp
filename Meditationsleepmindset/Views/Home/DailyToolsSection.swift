//
//  DailyToolsSection.swift
//  Meditation Sleep Mindset
//
//  Home-screen section that surfaces the AI meditation studio prominently and
//  groups the daily rituals (Intention, Gratitude, Kids stories). Self-contained:
//  it manages its own sheet presentation so it can be dropped into Home with one line.
//

import SwiftUI

struct DailyToolsSection: View {
    /// Which part to render — Home places the hero high and the rituals lower.
    enum Mode { case hero, rituals }
    var mode: Mode = .rituals

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isRegular: Bool { sizeClass == .regular }

    @AppStorage(Constants.UserDefaultsKeys.dailyIntentionText) private var savedIntention: String = ""
    @AppStorage(Constants.UserDefaultsKeys.dailyIntentionDate) private var savedIntentionDate: Double = 0

    @State private var activeTool: DailyTool?

    enum DailyTool: String, Identifiable {
        case aiStudio, intention, gratitude, kids, breathe
        var id: String { rawValue }
    }

    private var hasTodayIntention: Bool {
        guard savedIntentionDate > 0 else { return false }
        return Calendar.current.isDateInToday(Date(timeIntervalSince1970: savedIntentionDate)) && !savedIntention.isEmpty
    }

    var body: some View {
        Group {
            switch mode {
            case .hero: heroContent
            case .rituals: ritualsContent
            }
        }
        // On iPad these tools deserve the full screen; a centered sheet wastes the space.
        .sheet(item: isRegular ? .constant(nil) : $activeTool) { tool in
            toolDestination(tool)
        }
        .fullScreenCover(item: isRegular ? $activeTool : .constant(nil)) { tool in
            toolDestination(tool)
        }
    }

    @ViewBuilder
    private func toolDestination(_ tool: DailyTool) -> some View {
        switch tool {
        case .aiStudio: AIGeneratedMeditationView()
        case .intention: DailyIntentionView()
        case .gratitude: GratitudeJournalView()
        case .kids: KidsView()
        case .breathe: HapticBreathingView()
        }
    }

    // AI Studio hero — the differentiated, demo-able feature gets top billing.
    private var heroContent: some View {
        Button {
            HapticManager.light()
            activeTool = .aiStudio
        } label: {
            aiStudioHero
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // Daily practices band (placed below the main content shelves).
    private var ritualsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily practices")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    DailyToolCard(
                        icon: "sunrise.fill",
                        title: hasTodayIntention ? "Intention set" : "Set Intention",
                        subtitle: hasTodayIntention ? "View or update" : "Start your day",
                        tint: .orange,
                        highlighted: hasTodayIntention
                    ) {
                        HapticManager.light()
                        activeTool = .intention
                    }

                    DailyToolCard(
                        icon: "heart.text.square.fill",
                        title: "Gratitude",
                        subtitle: "Reflect & journal",
                        tint: .pink,
                        highlighted: false
                    ) {
                        HapticManager.light()
                        activeTool = .gratitude
                    }

                    DailyToolCard(
                        icon: "lungs.fill",
                        title: "Breathe",
                        subtitle: "Haptic guided breathing",
                        tint: .mint,
                        highlighted: false
                    ) {
                        HapticManager.light()
                        activeTool = .breathe
                    }

                    DailyToolCard(
                        icon: "teddybear.fill",
                        title: "Kids Stories",
                        subtitle: "Personalized bedtime",
                        tint: .cyan,
                        highlighted: false
                    ) {
                        HapticManager.light()
                        activeTool = .kids
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var aiStudioHero: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.profileAccent.opacity(0.25))
                    .frame(width: 60, height: 60)
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("AI Meditation Studio")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("NEW")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.white)
                        .clipShape(Capsule())
                }
                Text("Create a meditation made just for you — any mood, any length")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Theme.profileAccent.opacity(0.35), Theme.profileAccent.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct DailyToolCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let highlighted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            .frame(width: 130, alignment: .leading)
            .padding(14)
            .background(Theme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(highlighted ? tint.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
