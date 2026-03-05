//
//  ProgressWidget.swift
//  MeditationWidget
//
//  Shows weekly mindful minutes, sessions, and progress toward goal
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct ProgressTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProgressEntry {
        ProgressEntry(
            date: Date(),
            weeklyMinutes: 45,
            weeklySessions: 5,
            weeklyGoalMinutes: 70,
            dailyMinutes: [10, 15, 0, 8, 12, 0, 0]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ProgressEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProgressEntry>) -> Void) {
        let entry = loadEntry()
        // Refresh every 30 minutes to keep stats current
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> ProgressEntry {
        let defaults = UserDefaults(suiteName: "group.com.meditation.shared") ?? .standard
        let weeklyMinutes = defaults.integer(forKey: "widget_weeklyMinutes")
        let weeklySessions = defaults.integer(forKey: "widget_weeklySessions")
        let weeklyGoal = defaults.integer(forKey: "widget_weeklyGoalMinutes")
        let dailyMinutes = defaults.array(forKey: "widget_dailyMinutes") as? [Int] ?? Array(repeating: 0, count: 7)

        return ProgressEntry(
            date: Date(),
            weeklyMinutes: weeklyMinutes,
            weeklySessions: weeklySessions,
            weeklyGoalMinutes: weeklyGoal > 0 ? weeklyGoal : 70, // Default 70 min/week (10 min/day)
            dailyMinutes: dailyMinutes
        )
    }
}

// MARK: - Entry

struct ProgressEntry: TimelineEntry {
    let date: Date
    let weeklyMinutes: Int
    let weeklySessions: Int
    let weeklyGoalMinutes: Int
    let dailyMinutes: [Int] // 7 days, Monday first

    var progress: Double {
        guard weeklyGoalMinutes > 0 else { return 0 }
        return min(1.0, Double(weeklyMinutes) / Double(weeklyGoalMinutes))
    }

    var progressPercentage: Int {
        Int(progress * 100)
    }

    var remainingMinutes: Int {
        max(0, weeklyGoalMinutes - weeklyMinutes)
    }

    var maxDailyMinutes: Int {
        dailyMinutes.max() ?? 1
    }
}

// MARK: - Widget Views

struct ProgressWidgetMediumView: View {
    let entry: ProgressEntry

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        HStack(spacing: 16) {
            // Left side: Circular progress
            VStack(spacing: 6) {
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 8)
                        .frame(width: 70, height: 70)

                    // Progress arc
                    Circle()
                        .trim(from: 0, to: entry.progress)
                        .stroke(
                            LinearGradient(
                                colors: [WidgetColors.accentPurple, WidgetColors.accentLavender],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))

                    // Percentage text
                    VStack(spacing: 0) {
                        Text("\(entry.progressPercentage)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("%")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Text("Weekly Goal")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(width: 90)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1, height: 80)

            // Right side: Stats and bar chart
            VStack(alignment: .leading, spacing: 10) {
                // Stats row
                HStack(spacing: 16) {
                    // Minutes
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(WidgetColors.accentPurple)
                            Text("\(entry.weeklyMinutes)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        Text("min this week")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    // Sessions
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 10))
                                .foregroundStyle(WidgetColors.accentLavender)
                            Text("\(entry.weeklySessions)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        Text("sessions")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                // Mini bar chart
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(0..<7, id: \.self) { index in
                        VStack(spacing: 2) {
                            // Bar
                            RoundedRectangle(cornerRadius: 2)
                                .fill(barColor(for: index))
                                .frame(width: 14, height: barHeight(for: index))

                            // Day label
                            Text(dayLabels[index])
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                }
                .frame(height: 40)

                // Goal status message
                if entry.remainingMinutes > 0 {
                    Text("\(entry.remainingMinutes) min to reach goal")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(WidgetColors.successGreen)
                        Text("Goal reached!")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(WidgetColors.successGreen)
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

    private func barHeight(for index: Int) -> CGFloat {
        guard entry.dailyMinutes.indices.contains(index) else { return 4 }
        let minutes = entry.dailyMinutes[index]
        guard minutes > 0, entry.maxDailyMinutes > 0 else { return 4 }
        let ratio = CGFloat(minutes) / CGFloat(entry.maxDailyMinutes)
        return max(4, ratio * 24)
    }

    private func barColor(for index: Int) -> Color {
        guard entry.dailyMinutes.indices.contains(index) else {
            return Color.white.opacity(0.2)
        }
        let minutes = entry.dailyMinutes[index]
        if minutes > 0 {
            return WidgetColors.accentPurple
        }
        return Color.white.opacity(0.2)
    }
}

// MARK: - Widget Definition

struct ProgressWidget: Widget {
    let kind = "ProgressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProgressTimelineProvider()) { entry in
            ProgressWidgetMediumView(entry: entry)
        }
        .configurationDisplayName("Weekly Progress")
        .description("Track your mindful minutes and weekly goal.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Previews

#Preview(as: .systemMedium) {
    ProgressWidget()
} timeline: {
    ProgressEntry(
        date: .now,
        weeklyMinutes: 45,
        weeklySessions: 5,
        weeklyGoalMinutes: 70,
        dailyMinutes: [10, 15, 0, 8, 12, 0, 0]
    )
    ProgressEntry(
        date: .now,
        weeklyMinutes: 85,
        weeklySessions: 8,
        weeklyGoalMinutes: 70,
        dailyMinutes: [15, 10, 12, 8, 20, 10, 10]
    )
    ProgressEntry(
        date: .now,
        weeklyMinutes: 0,
        weeklySessions: 0,
        weeklyGoalMinutes: 70,
        dailyMinutes: [0, 0, 0, 0, 0, 0, 0]
    )
}
