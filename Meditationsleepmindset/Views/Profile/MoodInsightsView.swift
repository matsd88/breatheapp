//
//  MoodInsightsView.swift
//  Meditation Sleep Mindset
//

import SwiftUI
import SwiftData
import Charts

struct MoodInsightsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    /// Re-read when sessions or chats change (SwiftData @Query drives refresh).
    @Query private var sessions: [MeditationSession]
    @Query private var chatSessions: [ChatSession]
    @State private var timeRange: TimeRange = .week

    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case allTime = "All Time"

        var displayName: String {
            switch self {
            case .week: return String(localized: "Week")
            case .month: return String(localized: "Month")
            case .allTime: return String(localized: "All Time")
            }
        }
    }

    /// Same mood log the Profile card reads: coach check-ins + after-session moods.
    private var entries: [MoodEntry] {
        let now = Date()
        let start: Date?
        switch timeRange {
        case .week: start = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: now))
        case .month: start = Calendar.current.date(byAdding: .month, value: -1, to: now)
        case .allTime: start = nil
        }
        _ = sessions.count + chatSessions.count // dependency for refresh
        return MoodLog.entries(since: start, in: modelContext)
    }

    private func labelCounts(_ entries: [MoodEntry]) -> [(label: String, level: MoodLevel, count: Int)] {
        Dictionary(grouping: entries, by: \.label)
            .map { (label: $0.key, level: $0.value[0].level, count: $0.value.count) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.level.score > $1.level.score }
    }

    var body: some View {
        let current = entries
        let daily = MoodLog.dailyAverages(current)
        let counts = labelCounts(current)

        return NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Time range picker
                        Picker("Time Range", selection: $timeRange) {
                            ForEach(TimeRange.allCases, id: \.self) { range in
                                Text(range.displayName).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        if current.isEmpty {
                            emptyStateView
                        } else {
                            // Summary stats
                            summaryCard(current, topLabel: counts.first?.label)

                            // Mood trend chart
                            if !daily.isEmpty {
                                moodTrendChart(daily)
                            }

                            // Distribution across everything the user picked
                            if !counts.isEmpty {
                                moodDistributionCard(title: "How You've Felt", counts: counts)
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 12)
                    .frame(maxWidth: 700)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Mood Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(red: 0.08, green: 0.15, blue: 0.28), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))

            Text("No mood data yet")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            Text("Check in after a session or with Breathe AI to see your insights here")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - Summary Card

    private func summaryCard(_ current: [MoodEntry], topLabel: String?) -> some View {
        let average = Double(current.map(\.level.score).reduce(0, +)) / Double(max(current.count, 1))
        let averageLevel = MoodLevel(score: average)
        return HStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("\(current.count)")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Check-ins")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1, height: 40)

            VStack(spacing: 6) {
                Text("\(averageLevel.emoji) \(averageLevel.displayName)")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Avg Mood")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1, height: 40)

            VStack(spacing: 6) {
                if let topLabel {
                    Text(topLabel)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                } else {
                    Text("—")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }
                Text("Top Mood")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Mood Trend Chart

    private func moodTrendChart(_ daily: [(date: Date, score: Double)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mood Trend")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            Chart {
                ForEach(daily, id: \.date) { entry in
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("Score", entry.score)
                    )
                    .foregroundStyle(.cyan)
                    .symbol(.circle)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", entry.date),
                        y: .value("Score", entry.score)
                    )
                    .foregroundStyle(.cyan)
                }
            }
            .chartYScale(domain: 1...5)
            .chartYAxis {
                AxisMarks(values: [1, 2, 3, 4, 5]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(Color.white.opacity(0.1))
                    AxisValueLabel {
                        if let intVal = value.as(Int.self) {
                            Text(moodLabel(for: intVal))
                                .font(.caption2)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.05))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.month(.abbreviated).day())
                                .font(.caption2)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
            .frame(height: 200)

            // Legend
            HStack(spacing: 4) {
                Circle().fill(.cyan).frame(width: 8, height: 8)
                Text("Daily mood · check-ins + after sessions").font(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    /// Same 5-point scale (and names) as the Profile mood card.
    private func moodLabel(for score: Int) -> String {
        MoodLevel(score: Double(score)).displayName
    }

    // MARK: - Mood Distribution Card

    private func moodDistributionCard(title: String, counts: [(label: String, level: MoodLevel, count: Int)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            Chart(counts, id: \.label) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Mood", item.label)
                )
                .foregroundStyle(item.level.color.opacity(0.75))
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.1))
                    AxisValueLabel()
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(height: CGFloat(counts.count) * 36)
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

}
