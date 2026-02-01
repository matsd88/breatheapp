//
//  StreakWidget.swift
//  MeditationWidget
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct StreakTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: Date(), currentStreak: 7, totalMinutes: 120, meditatedToday: true)
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
            meditatedToday: meditatedToday
        )
    }
}

// MARK: - Entry

struct StreakEntry: TimelineEntry {
    let date: Date
    let currentStreak: Int
    let totalMinutes: Int
    let meditatedToday: Bool
}

// MARK: - Widget Views

struct StreakWidgetSmallView: View {
    let entry: StreakEntry

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.title)
                .foregroundStyle(entry.currentStreak > 0 ? .orange : .gray)

            Text("\(entry.currentStreak)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("day streak")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))

            if entry.meditatedToday {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.15, blue: 0.28),
                    Color(red: 0.12, green: 0.22, blue: 0.42)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct StreakWidgetMediumView: View {
    let entry: StreakEntry

    var body: some View {
        HStack(spacing: 16) {
            // Streak info
            VStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(entry.currentStreak > 0 ? .orange : .gray)

                Text("\(entry.currentStreak)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("day streak")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 60)
                .background(Color.white.opacity(0.2))

            // Stats + action
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundStyle(.cyan)
                    Text("\(entry.totalMinutes) min total")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }

                HStack(spacing: 6) {
                    Image(systemName: entry.meditatedToday ? "checkmark.circle.fill" : "circle")
                        .font(.caption)
                        .foregroundStyle(entry.meditatedToday ? .green : .white.opacity(0.4))
                    Text(entry.meditatedToday ? "Done today" : "Not yet today")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }

                if !entry.meditatedToday {
                    Link(destination: URL(string: "meditation://home")!) {
                        Text("Start Session")
                            .font(.caption.bold())
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.white)
                            .clipShape(Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.15, blue: 0.28),
                    Color(red: 0.12, green: 0.22, blue: 0.42)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
    StreakEntry(date: .now, currentStreak: 7, totalMinutes: 120, meditatedToday: true)
    StreakEntry(date: .now, currentStreak: 0, totalMinutes: 0, meditatedToday: false)
}
