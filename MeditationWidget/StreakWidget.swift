//
//  StreakWidget.swift
//  MeditationWidget
//

import WidgetKit
import SwiftUI

// MARK: - Shared Widget Colors

enum WidgetColors {
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.08, green: 0.15, blue: 0.28),
            Color(red: 0.12, green: 0.22, blue: 0.42)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentPurple = Color(red: 0.5, green: 0.3, blue: 0.9)
    static let accentLavender = Color(red: 0.65, green: 0.55, blue: 0.85)
    static let streakOrange = Color.orange
    static let successGreen = Color.green
    static let cardBackground = Color.white.opacity(0.1)
}

// MARK: - Timeline Provider

struct StreakTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(
            date: Date(),
            currentStreak: 7,
            totalMinutes: 120,
            meditatedToday: true,
            weeklyActivity: [true, true, false, true, true, true, true]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let entry = loadEntry()
        // Refresh at midnight
        let nextMidnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        let timeline = Timeline(entries: [entry], policy: .after(nextMidnight))
        completion(timeline)
    }

    private func loadEntry() -> StreakEntry {
        let defaults = UserDefaults(suiteName: "group.com.meditation.shared") ?? .standard
        let streak = defaults.integer(forKey: "widget_currentStreak")
        let minutes = defaults.integer(forKey: "widget_totalMinutes")
        let lastSessionDate = defaults.object(forKey: "widget_lastSessionDate") as? Date
        let weeklyActivityData = defaults.array(forKey: "widget_weeklyActivity") as? [Bool] ?? Array(repeating: false, count: 7)

        let meditatedToday: Bool
        if let last = lastSessionDate {
            meditatedToday = Calendar.current.isDateInToday(last)
        } else {
            meditatedToday = false
        }

        return StreakEntry(
            date: Date(),
            currentStreak: streak,
            totalMinutes: minutes,
            meditatedToday: meditatedToday,
            weeklyActivity: weeklyActivityData
        )
    }
}

// MARK: - Entry

struct StreakEntry: TimelineEntry {
    let date: Date
    let currentStreak: Int
    let totalMinutes: Int
    let meditatedToday: Bool
    let weeklyActivity: [Bool] // 7 days, most recent last

    var motivationalMessage: String {
        switch currentStreak {
        case 0: return "Start your journey today"
        case 1: return "Great start! Keep going"
        case 2...6: return "Building momentum!"
        case 7...13: return "One week strong!"
        case 14...29: return "Amazing dedication!"
        case 30...59: return "A month of mindfulness!"
        case 60...89: return "True commitment!"
        default: return "You're unstoppable!"
        }
    }
}

// MARK: - Widget Views

struct StreakWidgetSmallView: View {
    let entry: StreakEntry

    var body: some View {
        VStack(spacing: 6) {
            // Flame icon with glow effect
            ZStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(entry.currentStreak > 0 ? WidgetColors.streakOrange : .gray)
                    .blur(radius: entry.currentStreak > 0 ? 8 : 0)
                    .opacity(0.6)

                Image(systemName: "flame.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(entry.currentStreak > 0 ? WidgetColors.streakOrange : .gray)
            }

            Text("\(entry.currentStreak)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("day streak")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))

            // Today status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(entry.meditatedToday ? WidgetColors.successGreen : .white.opacity(0.3))
                    .frame(width: 6, height: 6)
                Text(entry.meditatedToday ? "Done" : "Today")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            WidgetColors.backgroundGradient
        }
    }
}

struct StreakWidgetMediumView: View {
    let entry: StreakEntry

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        HStack(spacing: 16) {
            // Left side: Streak count with flame
            VStack(spacing: 4) {
                ZStack {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(entry.currentStreak > 0 ? WidgetColors.streakOrange : .gray)
                        .blur(radius: entry.currentStreak > 0 ? 6 : 0)
                        .opacity(0.5)

                    Image(systemName: "flame.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(entry.currentStreak > 0 ? WidgetColors.streakOrange : .gray)
                }

                Text("\(entry.currentStreak)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("day streak")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(width: 90)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1, height: 70)

            // Right side: Weekly calendar and motivation
            VStack(alignment: .leading, spacing: 10) {
                // Weekly calendar dots
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { index in
                        VStack(spacing: 3) {
                            Text(dayLabels[index])
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))

                            Circle()
                                .fill(entry.weeklyActivity.indices.contains(index) && entry.weeklyActivity[index]
                                      ? WidgetColors.accentPurple
                                      : Color.white.opacity(0.2))
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(index == 6 ? WidgetColors.accentLavender : .clear, lineWidth: 1.5)
                                )
                        }
                    }
                }

                // Motivational message
                Text(entry.motivationalMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)

                // Start button if not meditated today
                if !entry.meditatedToday, let homeURL = URL(string: "meditation://home") {
                    Link(destination: homeURL) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 8))
                            Text("Start Session")
                                .font(.caption2.bold())
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(WidgetColors.accentPurple)
                        .clipShape(Capsule())
                    }
                } else {
                    // Show total minutes when done for the day
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(WidgetColors.successGreen)
                        Text("\(entry.totalMinutes) min total")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .containerBackground(for: .widget) {
            WidgetColors.backgroundGradient
        }
    }
}

// MARK: - Widget Definition

struct StreakWidget: Widget {
    let kind = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakTimelineProvider()) { entry in
            if #available(iOS 17.0, *) {
                StreakWidgetEntryView(entry: entry)
            } else {
                StreakWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Meditation Streak")
        .description("Track your daily meditation streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct StreakWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: StreakEntry

    var body: some View {
        switch family {
        case .systemSmall:
            StreakWidgetSmallView(entry: entry)
        case .systemMedium:
            StreakWidgetMediumView(entry: entry)
        default:
            StreakWidgetSmallView(entry: entry)
        }
    }
}

#Preview(as: .systemSmall) {
    StreakWidget()
} timeline: {
    StreakEntry(date: .now, currentStreak: 7, totalMinutes: 120, meditatedToday: true, weeklyActivity: [true, true, false, true, true, true, true])
    StreakEntry(date: .now, currentStreak: 0, totalMinutes: 0, meditatedToday: false, weeklyActivity: [false, false, false, false, false, false, false])
}

#Preview(as: .systemMedium) {
    StreakWidget()
} timeline: {
    StreakEntry(date: .now, currentStreak: 14, totalMinutes: 320, meditatedToday: true, weeklyActivity: [true, true, true, true, true, true, true])
    StreakEntry(date: .now, currentStreak: 3, totalMinutes: 45, meditatedToday: false, weeklyActivity: [false, false, false, false, true, true, true])
}
