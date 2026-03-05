//
//  MeditationWatchWidgets.swift
//  MeditationWatchWidgets
//
//  Widget bundle for Watch complications
//

import WidgetKit
import SwiftUI

// MARK: - Widget Bundle

@main
struct MeditationWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        StreakComplication()
        MindfulMinutesComplication()
        BreathingComplication()
    }
}

// MARK: - Complication Provider

struct WatchComplicationProvider: TimelineProvider {
    typealias Entry = WatchComplicationEntry

    func placeholder(in context: Context) -> WatchComplicationEntry {
        WatchComplicationEntry(
            date: Date(),
            streak: 7,
            mindfulMinutesToday: 15,
            meditatedToday: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchComplicationEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchComplicationEntry>) -> Void) {
        let entry = loadEntry()

        // Refresh at midnight or after 30 minutes
        let nextUpdate = min(
            Calendar.current.startOfDay(for: Date().addingTimeInterval(86400)),
            Date().addingTimeInterval(30 * 60)
        )

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> WatchComplicationEntry {
        let defaults = UserDefaults.standard

        let streak = defaults.integer(forKey: "cached_streak")
        let mindfulMinutes = defaults.integer(forKey: "cached_mindfulMinutesToday")
        let lastSessionDate = defaults.object(forKey: "cached_lastSessionDate") as? Date

        let meditatedToday: Bool
        if let last = lastSessionDate {
            meditatedToday = Calendar.current.isDateInToday(last)
        } else {
            meditatedToday = false
        }

        return WatchComplicationEntry(
            date: Date(),
            streak: streak,
            mindfulMinutesToday: mindfulMinutes,
            meditatedToday: meditatedToday
        )
    }
}

// MARK: - Complication Entry

struct WatchComplicationEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let mindfulMinutesToday: Int
    let meditatedToday: Bool
}

// MARK: - Streak Complication Widget

struct StreakComplication: Widget {
    let kind = "StreakComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchComplicationProvider()) { entry in
            StreakComplicationView(entry: entry)
        }
        .configurationDisplayName("Streak")
        .description("Shows your current meditation streak")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline
        ])
    }
}

struct StreakComplicationView: View {
    let entry: WatchComplicationEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryCorner:
            cornerView
        case .accessoryInline:
            inlineView
        default:
            circularView
        }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()

            VStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(entry.streak > 0 ? .orange : .gray)

                Text("\(entry.streak)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }

    private var cornerView: some View {
        ZStack {
            Text("\(entry.streak)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .widgetLabel {
            Label {
                Text("day streak")
            } icon: {
                Image(systemName: "flame.fill")
            }
        }
    }

    private var inlineView: some View {
        Label {
            Text("\(entry.streak) day streak")
        } icon: {
            Image(systemName: "flame.fill")
        }
    }
}

// MARK: - Mindful Minutes Complication Widget

struct MindfulMinutesComplication: Widget {
    let kind = "MindfulMinutesComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchComplicationProvider()) { entry in
            MindfulMinutesComplicationView(entry: entry)
        }
        .configurationDisplayName("Mindful Minutes")
        .description("Shows today's mindful minutes")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline
        ])
    }
}

struct MindfulMinutesComplicationView: View {
    let entry: WatchComplicationEntry

    @Environment(\.widgetFamily) var family

    private let dailyGoal = 10

    private var progress: Double {
        min(1.0, Double(entry.mindfulMinutesToday) / Double(dailyGoal))
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryCorner:
            cornerView
        case .accessoryInline:
            inlineView
        default:
            circularView
        }
    }

    private var circularView: some View {
        Gauge(value: progress) {
            VStack(spacing: 0) {
                Text("\(entry.mindfulMinutesToday)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("min")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(Gradient(colors: [.cyan, .purple]))
    }

    private var cornerView: some View {
        Text("\(entry.mindfulMinutesToday)")
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .widgetLabel {
                Gauge(value: progress) {
                    Text("min today")
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(.cyan)
            }
    }

    private var inlineView: some View {
        Label {
            Text("\(entry.mindfulMinutesToday) min today")
        } icon: {
            Image(systemName: "brain.head.profile")
        }
    }
}

// MARK: - Quick Breathing Complication Widget

struct BreathingComplication: Widget {
    let kind = "BreathingComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchComplicationProvider()) { entry in
            BreathingComplicationView(entry: entry)
        }
        .configurationDisplayName("Breathe")
        .description("Quick access to breathing exercises")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

struct BreathingComplicationView: View {
    let entry: WatchComplicationEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        default:
            circularView
        }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()

            Image(systemName: "wind")
                .font(.title2)
                .foregroundStyle(.cyan)
        }
    }

    private var rectangularView: some View {
        HStack(spacing: 10) {
            Image(systemName: "wind")
                .font(.title2)
                .foregroundStyle(.cyan)

            VStack(alignment: .leading, spacing: 2) {
                Text("Start Breathing")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Tap to begin")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding(.horizontal, 8)
    }

    private var inlineView: some View {
        Label {
            Text("Start Breathing")
        } icon: {
            Image(systemName: "wind")
        }
    }
}

// MARK: - Previews

#Preview("Streak Circular", as: .accessoryCircular) {
    StreakComplication()
} timeline: {
    WatchComplicationEntry(date: .now, streak: 7, mindfulMinutesToday: 15, meditatedToday: true)
    WatchComplicationEntry(date: .now, streak: 0, mindfulMinutesToday: 0, meditatedToday: false)
}

#Preview("Mindful Minutes Circular", as: .accessoryCircular) {
    MindfulMinutesComplication()
} timeline: {
    WatchComplicationEntry(date: .now, streak: 7, mindfulMinutesToday: 8, meditatedToday: true)
}

#Preview("Breathing Rectangular", as: .accessoryRectangular) {
    BreathingComplication()
} timeline: {
    WatchComplicationEntry(date: .now, streak: 7, mindfulMinutesToday: 15, meditatedToday: true)
}
