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
    @Query(sort: \MeditationSession.startedAt, order: .reverse) private var sessions: [MeditationSession]
    @State private var timeRange: TimeRange = .week

    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case allTime = "All Time"
    }

    private var filteredSessions: [MeditationSession] {
        let now = Date()
        switch timeRange {
        case .week:
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
            return sessions.filter { $0.startedAt >= weekAgo }
        case .month:
            let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now
            return sessions.filter { $0.startedAt >= monthAgo }
        case .allTime:
            return sessions
        }
    }

    private var sessionsWithMoods: [MeditationSession] {
        filteredSessions.filter { $0.postMood != nil }
    }

    private var postMoodCounts: [(mood: Mood, count: Int)] {
        var counts: [Mood: Int] = [:]
        for session in filteredSessions {
            if let raw = session.postMood, let mood = Mood(rawValue: raw) {
                counts[mood, default: 0] += 1
            }
        }
        return counts.map { (mood: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    // Average post-session mood score
    private var averageMoodScore: Double {
        let scored = sessionsWithMoods.compactMap { session -> Int? in
            guard let raw = session.postMood else { return nil }
            return moodScore(raw)
        }
        guard !scored.isEmpty else { return 0 }
        return Double(scored.reduce(0, +)) / Double(scored.count)
    }

    private func moodScore(_ raw: String) -> Int {
        switch Mood(rawValue: raw) {
        case .grateful: return 9
        case .happy: return 8
        case .energetic: return 7
        case .focused: return 6
        case .calm: return 5
        case .tired: return 3
        case .sad: return 2
        case .anxious: return 1
        case .stressed: return 0
        case .none: return 4
        }
    }

    // Daily mood trend data
    private var dailyMoodTrend: [(date: Date, moodScore: Double)] {
        let calendar = Calendar.current
        var grouped: [Date: [Int]] = [:]

        for session in filteredSessions {
            let day = calendar.startOfDay(for: session.startedAt)
            if let post = session.postMood {
                grouped[day, default: []].append(moodScore(post))
            }
        }

        return grouped.compactMap { (date, scores) in
            guard !scores.isEmpty else { return nil }
            let avg = Double(scores.reduce(0, +)) / Double(scores.count)
            return (date: date, moodScore: avg)
        }
        .sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Time range picker
                        Picker("Time Range", selection: $timeRange) {
                            ForEach(TimeRange.allCases, id: \.self) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        if sessionsWithMoods.isEmpty {
                            emptyStateView
                        } else {
                            // Summary stats
                            summaryCard

                            // Mood trend chart
                            if !dailyMoodTrend.isEmpty {
                                moodTrendChart
                            }

                            // Post-mood distribution
                            if !postMoodCounts.isEmpty {
                                moodDistributionCard(title: "After Sessions", counts: postMoodCounts)
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 12)
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
        .presentationDetents([.large])
        .presentationBackground(Color(red: 0.08, green: 0.15, blue: 0.28))
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

            Text("Complete sessions with mood check-ins to see your insights here")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        HStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("\(sessionsWithMoods.count)")
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
                Text(String(format: "%.1f", averageMoodScore))
                    .font(.title2.bold())
                    .foregroundStyle(averageMoodScore >= 5 ? .green : .white)
                Text("Avg Mood")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1, height: 40)

            VStack(spacing: 6) {
                if let topMood = postMoodCounts.first {
                    Text(topMood.mood.rawValue)
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

    private var moodTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mood Trend")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            Chart {
                ForEach(dailyMoodTrend, id: \.date) { entry in
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("Score", entry.moodScore)
                    )
                    .foregroundStyle(.cyan)
                    .symbol(.circle)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", entry.date),
                        y: .value("Score", entry.moodScore)
                    )
                    .foregroundStyle(.cyan)
                }
            }
            .chartYScale(domain: 0...9)
            .chartYAxis {
                AxisMarks(values: [0, 3, 5, 7, 9]) { value in
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
                Text("Post-session mood").font(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func moodLabel(for score: Int) -> String {
        switch score {
        case 0: return "Stressed"
        case 3: return "Tired"
        case 5: return "Calm"
        case 7: return "Energetic"
        case 9: return "Grateful"
        default: return ""
        }
    }

    // MARK: - Mood Distribution Card

    private func moodDistributionCard(title: String, counts: [(mood: Mood, count: Int)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            Chart(counts, id: \.mood) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Mood", item.mood.rawValue)
                )
                .foregroundStyle(colorForMood(item.mood))
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

    private func colorForMood(_ mood: Mood) -> Color {
        switch mood {
        case .calm: return .cyan
        case .happy: return .yellow
        case .anxious: return .orange
        case .stressed: return .red
        case .sad: return .blue
        case .tired: return .gray
        case .energetic: return .green
        case .focused: return .purple
        case .grateful: return .pink
        }
    }
}
