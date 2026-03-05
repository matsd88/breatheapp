//
//  SleepAnalyticsDashboard.swift
//  Meditation Sleep Mindset
//

import SwiftUI
import SwiftData
import Charts

struct SleepAnalyticsDashboard: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \MeditationSession.startedAt, order: .reverse) private var allSessions: [MeditationSession]
    @StateObject private var analyticsService = SleepAnalyticsService.shared
    @StateObject private var healthKit = HealthKitService.shared
    @State private var timeRange: TimeRange = .week

    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"

        var displayName: String {
            switch self {
            case .week: return String(localized: "Week")
            case .month: return String(localized: "Month")
            }
        }
    }

    // MARK: - Computed Data

    private var weeklyData: [SleepAnalyticsService.DailySleepData] {
        analyticsService.getWeeklyData(from: allSessions)
    }

    private var monthlyData: [SleepAnalyticsService.DailySleepData] {
        analyticsService.getMonthlyData(from: allSessions)
    }

    private var currentData: [SleepAnalyticsService.DailySleepData] {
        timeRange == .week ? weeklyData : monthlyData
    }

    private var sleepScore: SleepAnalyticsService.SleepScore {
        analyticsService.calculateSleepScore(from: allSessions)
    }

    private var sleepStreak: Int {
        analyticsService.calculateSleepStreak(from: allSessions)
    }

    private var totalTime: (hours: Int, minutes: Int) {
        analyticsService.getTotalSleepTime(from: allSessions)
    }

    private var totalSessions: Int {
        analyticsService.getTotalSleepSessions(from: allSessions)
    }

    private var mostPlayed: [SleepAnalyticsService.SleepContentStats] {
        analyticsService.getMostPlayedContent(from: allSessions, limit: 3)
    }

    private var bedtimeTrends: [SleepAnalyticsService.BedtimeTrend] {
        analyticsService.getBedtimeTrends(from: allSessions, days: timeRange == .week ? 7 : 14)
    }

    private var insights: [SleepAnalyticsService.SleepInsight] {
        analyticsService.generateInsights(from: allSessions)
    }

    private var sleepCorrelation: SleepAnalyticsService.SleepQualityCorrelation {
        analyticsService.calculateSleepQualityCorrelation(sessions: allSessions, sleepData: healthKit.sleepData)
    }

    private var hasSleepData: Bool {
        !analyticsService.filterSleepSessions(from: allSessions).isEmpty
    }

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.sleepBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: isRegular ? 24 : 20) {
                        // Time range picker
                        Picker("Time Range", selection: $timeRange) {
                            ForEach(TimeRange.allCases, id: \.self) { range in
                                Text(range.displayName).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, isRegular ? 24 : 16)

                        if hasSleepData {
                            if isRegular {
                                // iPad: two-column layout for score + chart
                                HStack(alignment: .top, spacing: 20) {
                                    sleepScoreCard
                                    weeklyOverviewChart
                                }
                                .padding(.horizontal, 8)

                                // Stats row full width
                                statsRow

                                // iPad: two-column for bedtime + most played
                                HStack(alignment: .top, spacing: 20) {
                                    if !bedtimeTrends.isEmpty {
                                        bedtimeTrendsChart
                                    }
                                    if !mostPlayed.isEmpty {
                                        mostPlayedSection
                                    }
                                }
                                .padding(.horizontal, 8)

                                // Insights full width
                                if !insights.isEmpty {
                                    insightsSection
                                }

                                // Sleep quality correlation
                                if healthKit.isEnabled && sleepCorrelation.hasEnoughData {
                                    sleepQualityCorrelationSection
                                }
                            } else {
                                // iPhone: stacked layout
                                sleepScoreCard
                                weeklyOverviewChart
                                statsRow

                                if !bedtimeTrends.isEmpty {
                                    bedtimeTrendsChart
                                }

                                if !mostPlayed.isEmpty {
                                    mostPlayedSection
                                }

                                if !insights.isEmpty {
                                    insightsSection
                                }

                                // Sleep quality correlation
                                if healthKit.isEnabled && sleepCorrelation.hasEnoughData {
                                    sleepQualityCorrelationSection
                                }
                            }
                        } else {
                            emptyStateView
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 12)
                    .frame(maxWidth: isRegular ? 800 : .infinity)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Sleep Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(red: 0.04, green: 0.06, blue: 0.14), for: .navigationBar)
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
        .onAppear {
            if healthKit.isEnabled {
                Task { await healthKit.loadWeeklySleepData() }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: isRegular ? 20 : 16) {
            Image(systemName: "moon.zzz")
                .font(.system(size: isRegular ? 64 : 48))
                .foregroundStyle(Theme.sleepPrimary.opacity(0.5))

            Text("No Sleep Data Yet")
                .font(isRegular ? .title2.weight(.semibold) : .headline)
                .foregroundStyle(Theme.sleepTextPrimary)

            Text("Start listening to sleep stories, soundscapes, or music to track your sleep habits")
                .font(isRegular ? .body : .subheadline)
                .foregroundStyle(Theme.sleepTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(isRegular ? 60 : 40)
    }

    // MARK: - Sleep Score Card

    private var sleepScoreCard: some View {
        VStack(spacing: isRegular ? 20 : 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sleep Score")
                        .font(isRegular ? .title3.weight(.semibold) : .headline)
                        .foregroundStyle(Theme.sleepTextPrimary)

                    Text(sleepScore.label)
                        .font(.subheadline)
                        .foregroundStyle(sleepScore.color)
                }

                Spacer()

                // Score Circle
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: isRegular ? 10 : 8)

                    Circle()
                        .trim(from: 0, to: Double(sleepScore.overall) / 100.0)
                        .stroke(sleepScore.color, style: StrokeStyle(lineWidth: isRegular ? 10 : 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(sleepScore.overall)")
                            .font(isRegular ? .largeTitle.bold() : .title.bold())
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: isRegular ? 100 : 80, height: isRegular ? 100 : 80)
            }

            // Score Breakdown
            HStack(spacing: isRegular ? 20 : 16) {
                ScoreComponent(title: "Consistency", score: sleepScore.consistencyScore, color: .cyan)
                ScoreComponent(title: "Completion", score: sleepScore.completionScore, color: .green)
                ScoreComponent(title: "Variety", score: sleepScore.varietyScore, color: .purple)
                ScoreComponent(title: "Streak", score: sleepScore.streakScore, color: .orange)
            }
        }
        .padding(isRegular ? 20 : 16)
        .background(Theme.sleepCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, isRegular ? 0 : 16)
    }

    // MARK: - Weekly Overview Chart

    private var weeklyOverviewChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(timeRange == .week ? "This Week" : "Last 30 Days")
                .font(isRegular ? .title3.weight(.semibold) : .headline)
                .foregroundStyle(Theme.sleepTextPrimary)

            Chart {
                ForEach(currentData) { day in
                    BarMark(
                        x: .value("Day", day.shortDayName),
                        y: .value("Minutes", day.minutesListened)
                    )
                    .foregroundStyle(
                        day.minutesListened > 0
                            ? Theme.sleepPrimary.gradient
                            : Color.white.opacity(0.1).gradient
                    )
                    .cornerRadius(4)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(Color.white.opacity(0.1))
                    AxisValueLabel {
                        if let intVal = value.as(Int.self) {
                            Text("\(intVal)m")
                                .font(.caption2)
                                .foregroundStyle(Theme.sleepTextSecondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .foregroundStyle(Theme.sleepTextSecondary)
                }
            }
            .frame(height: isRegular ? 220 : 180)

            // Legend
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.sleepPrimary)
                    .frame(width: 12, height: 12)
                Text("Minutes listened")
                    .font(.caption)
                    .foregroundStyle(Theme.sleepTextSecondary)
            }
        }
        .padding(isRegular ? 20 : 16)
        .background(Theme.sleepCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, isRegular ? 0 : 16)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            // Sleep Streak
            VStack(spacing: isRegular ? 8 : 6) {
                HStack(spacing: 4) {
                    Image(systemName: "moon.fill")
                        .font(isRegular ? .body : .caption)
                        .foregroundStyle(Theme.sleepPrimary)
                    Text("\(sleepStreak)")
                        .font(isRegular ? .title.bold() : .title2.bold())
                        .foregroundStyle(.white)
                }
                Text("Night Streak")
                    .font(isRegular ? .subheadline : .caption)
                    .foregroundStyle(Theme.sleepTextSecondary)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1, height: isRegular ? 50 : 40)

            // Total Time
            VStack(spacing: isRegular ? 8 : 6) {
                Text(analyticsService.formatDuration(hours: totalTime.hours, minutes: totalTime.minutes))
                    .font(isRegular ? .title.bold() : .title2.bold())
                    .foregroundStyle(.white)
                Text("Total Time")
                    .font(isRegular ? .subheadline : .caption)
                    .foregroundStyle(Theme.sleepTextSecondary)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1, height: isRegular ? 50 : 40)

            // Total Sessions
            VStack(spacing: isRegular ? 8 : 6) {
                Text("\(totalSessions)")
                    .font(isRegular ? .title.bold() : .title2.bold())
                    .foregroundStyle(.white)
                Text("Sessions")
                    .font(isRegular ? .subheadline : .caption)
                    .foregroundStyle(Theme.sleepTextSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(isRegular ? 20 : 16)
        .background(Theme.sleepCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, isRegular ? 8 : 16)
    }

    // MARK: - Bedtime Trends Chart

    private var bedtimeTrendsChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Bedtime Trends")
                    .font(.headline)
                    .foregroundStyle(Theme.sleepTextPrimary)

                Spacer()

                if let avgBedtime = calculateAverageBedtimeFromTrends() {
                    Text("Avg: \(analyticsService.formatBedtime(avgBedtime))")
                        .font(.caption)
                        .foregroundStyle(Theme.sleepTextSecondary)
                }
            }

            Chart {
                ForEach(bedtimeTrends) { trend in
                    PointMark(
                        x: .value("Date", trend.date),
                        y: .value("Hour", trend.hourOfDay)
                    )
                    .foregroundStyle(Theme.sleepPrimary)
                    .symbolSize(60)

                    if bedtimeTrends.count > 1 {
                        LineMark(
                            x: .value("Date", trend.date),
                            y: .value("Hour", trend.hourOfDay)
                        )
                        .foregroundStyle(Theme.sleepPrimary.opacity(0.5))
                        .interpolationMethod(.catmullRom)
                    }
                }
            }
            .chartYScale(domain: 20...28) // 8 PM to 4 AM range
            .chartYAxis {
                AxisMarks(values: [20, 22, 24, 26, 28]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(Color.white.opacity(0.1))
                    AxisValueLabel {
                        if let hour = value.as(Double.self) {
                            Text(formatHour(hour))
                                .font(.caption2)
                                .foregroundStyle(Theme.sleepTextSecondary)
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
                                .foregroundStyle(Theme.sleepTextSecondary)
                        }
                    }
                }
            }
            .frame(height: isRegular ? 200 : 160)

            // Legend
            HStack(spacing: 4) {
                Circle().fill(Theme.sleepPrimary).frame(width: 8, height: 8)
                Text("Start time of sleep content")
                    .font(.caption)
                    .foregroundStyle(Theme.sleepTextSecondary)
            }
        }
        .padding(isRegular ? 20 : 16)
        .background(Theme.sleepCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, isRegular ? 0 : 16)
    }

    private func formatHour(_ hour: Double) -> String {
        var displayHour = Int(hour)
        if displayHour >= 24 {
            displayHour -= 24
        }

        let period = displayHour >= 12 ? "AM" : "PM"
        var hour12 = displayHour % 12
        if hour12 == 0 { hour12 = 12 }

        return "\(hour12) \(period)"
    }

    private func calculateAverageBedtimeFromTrends() -> Date? {
        guard !bedtimeTrends.isEmpty else { return nil }
        let avgHour = bedtimeTrends.reduce(0.0) { $0 + $1.hourOfDay } / Double(bedtimeTrends.count)
        var hour = Int(avgHour)
        let minute = Int((avgHour - Double(hour)) * 60)

        if hour >= 24 {
            hour -= 24
        }

        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())
    }

    // MARK: - Most Played Section

    private var mostPlayedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Most Played")
                .font(.headline)
                .foregroundStyle(Theme.sleepTextPrimary)

            ForEach(Array(mostPlayed.enumerated()), id: \.element.id) { index, content in
                HStack(spacing: 12) {
                    // Rank Badge
                    Text("\(index + 1)")
                        .font(.headline)
                        .foregroundStyle(index == 0 ? .yellow : Theme.sleepTextSecondary)
                        .frame(width: 24)

                    // Thumbnail
                    if let videoID = content.youtubeVideoID {
                        AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(videoID)/mqdefault.jpg")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: content.contentType.iconName)
                            .font(.title3)
                            .foregroundStyle(Theme.sleepTextSecondary)
                            .frame(width: 50, height: 50)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(content.contentTitle)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Label("\(content.playCount)", systemImage: "play.fill")
                            Label("\(content.totalMinutes)m", systemImage: "clock")
                        }
                        .font(.caption)
                        .foregroundStyle(Theme.sleepTextSecondary)
                    }

                    Spacer()
                }
            }
        }
        .padding(isRegular ? 20 : 16)
        .background(Theme.sleepCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, isRegular ? 0 : 16)
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Insights")
                .font(.headline)
                .foregroundStyle(Theme.sleepTextPrimary)

            ForEach(insights) { insight in
                HStack(spacing: 12) {
                    Image(systemName: insight.icon)
                        .font(.title3)
                        .foregroundStyle(colorForInsightType(insight.type))
                        .frame(width: 36, height: 36)
                        .background(colorForInsightType(insight.type).opacity(0.15))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(insight.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)

                        Text(insight.message)
                            .font(.caption)
                            .foregroundStyle(Theme.sleepTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding(isRegular ? 20 : 16)
        .background(Theme.sleepCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, isRegular ? 8 : 16)
    }

    // MARK: - Sleep Quality Correlation Section

    private var sleepQualityCorrelationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "heart.text.square.fill")
                    .foregroundStyle(Theme.sleepPrimary)
                Text("Sleep & Meditation")
                    .font(.headline)
                    .foregroundStyle(Theme.sleepTextPrimary)
            }

            HStack(spacing: 12) {
                // With meditation card
                VStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill")
                        .font(.title3)
                        .foregroundStyle(.green)

                    Text(String(format: "%.1f hrs", sleepCorrelation.avgSleepWithMeditation))
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    Text("\(sleepCorrelation.meditatedNights) nights")
                        .font(.caption)
                        .foregroundStyle(Theme.sleepTextSecondary)

                    Text("With Meditation")
                        .font(.caption2)
                        .foregroundStyle(Theme.sleepTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Without meditation card
                VStack(spacing: 8) {
                    Image(systemName: "moon.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)

                    Text(String(format: "%.1f hrs", sleepCorrelation.avgSleepWithoutMeditation))
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    Text("\(sleepCorrelation.nonMeditatedNights) nights")
                        .font(.caption)
                        .foregroundStyle(Theme.sleepTextSecondary)

                    Text("Without Meditation")
                        .font(.caption2)
                        .foregroundStyle(Theme.sleepTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Improvement banner
            if sleepCorrelation.improvement > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(.green)
                    Text(String(format: "You sleep %.0f%% longer on nights you meditate", sleepCorrelation.improvement))
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(isRegular ? 20 : 16)
        .background(Theme.sleepCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, isRegular ? 8 : 16)
    }

    private func colorForInsightType(_ type: SleepAnalyticsService.SleepInsight.InsightType) -> Color {
        switch type {
        case .positive: return .green
        case .suggestion: return .orange
        case .neutral: return Theme.sleepPrimary
        }
    }
}

// MARK: - Score Component

struct ScoreComponent: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    let title: String
    let score: Int
    let color: Color

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        VStack(spacing: isRegular ? 6 : 4) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: isRegular ? 4 : 3)

                Circle()
                    .trim(from: 0, to: Double(score) / 100.0)
                    .stroke(color, style: StrokeStyle(lineWidth: isRegular ? 4 : 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(score)")
                    .font(isRegular ? .subheadline.bold() : .caption.bold())
                    .foregroundStyle(.white)
            }
            .frame(width: isRegular ? 50 : 40, height: isRegular ? 50 : 40)

            Text(title)
                .font(isRegular ? .caption : .caption2)
                .foregroundStyle(Theme.sleepTextSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    SleepAnalyticsDashboard()
        .modelContainer(for: MeditationSession.self, inMemory: true)
}
