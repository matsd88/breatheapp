//
//  SleepAnalyticsService.swift
//  Meditation Sleep Mindset
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
class SleepAnalyticsService: ObservableObject {
    static let shared = SleepAnalyticsService()

    // Sleep content types for filtering
    static let sleepContentTypes: Set<String> = ["Sleep Story", "Soundscape", "Music", "ASMR"]

    private init() {}

    // MARK: - Data Structures

    struct DailySleepData: Identifiable {
        let id = UUID()
        let date: Date
        let dayName: String
        let shortDayName: String
        let minutesListened: Int
        let sessionsCount: Int
        let averageBedtime: Date?
    }

    struct SleepContentStats: Identifiable {
        let id = UUID()
        let contentTitle: String
        let contentType: ContentType
        let playCount: Int
        let totalMinutes: Int
        let youtubeVideoID: String?
    }

    struct SleepScore {
        let overall: Int // 0-100
        let consistencyScore: Int // 0-100
        let completionScore: Int // 0-100
        let varietyScore: Int // 0-100
        let streakScore: Int // 0-100

        var label: String {
            switch overall {
            case 90...100: return "Excellent"
            case 75..<90: return "Great"
            case 60..<75: return "Good"
            case 40..<60: return "Fair"
            default: return "Getting Started"
            }
        }

        var color: Color {
            switch overall {
            case 90...100: return .green
            case 75..<90: return .cyan
            case 60..<75: return .blue
            case 40..<60: return .orange
            default: return .gray
            }
        }
    }

    struct BedtimeTrend: Identifiable {
        let id = UUID()
        let date: Date
        let bedtime: Date
        let hourOfDay: Double // For chart positioning (e.g., 22.5 = 10:30 PM)
    }

    struct SleepInsight: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let message: String
        let type: InsightType

        enum InsightType {
            case positive
            case suggestion
            case neutral
        }
    }

    struct SleepQualityCorrelation {
        let meditatedNights: Int
        let nonMeditatedNights: Int
        let avgSleepWithMeditation: Double // hours
        let avgSleepWithoutMeditation: Double // hours
        let improvement: Double // percentage

        var hasEnoughData: Bool {
            meditatedNights >= 3 && nonMeditatedNights >= 3
        }
    }

    // MARK: - Sleep Quality Correlation

    func calculateSleepQualityCorrelation(
        sessions: [MeditationSession],
        sleepData: [HealthKitService.DaySleepData]
    ) -> SleepQualityCorrelation {
        let calendar = Calendar.current

        // Get dates when user meditated (any session type)
        var meditationDates: Set<Date> = []
        for session in sessions {
            let day = calendar.startOfDay(for: session.startedAt)
            meditationDates.insert(day)
        }

        // Cross-reference with sleep data
        var meditatedSleepHours: [Double] = []
        var nonMeditatedSleepHours: [Double] = []

        for sleep in sleepData {
            let day = calendar.startOfDay(for: sleep.date)
            // Check if user meditated on the previous day (meditation before sleep)
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else { continue }
            let prevDayStart = calendar.startOfDay(for: previousDay)

            if meditationDates.contains(prevDayStart) || meditationDates.contains(day) {
                meditatedSleepHours.append(sleep.hoursSlept)
            } else {
                nonMeditatedSleepHours.append(sleep.hoursSlept)
            }
        }

        let avgWith = meditatedSleepHours.isEmpty ? 0 : meditatedSleepHours.reduce(0, +) / Double(meditatedSleepHours.count)
        let avgWithout = nonMeditatedSleepHours.isEmpty ? 0 : nonMeditatedSleepHours.reduce(0, +) / Double(nonMeditatedSleepHours.count)
        let improvement = avgWithout > 0 ? ((avgWith - avgWithout) / avgWithout) * 100 : 0

        return SleepQualityCorrelation(
            meditatedNights: meditatedSleepHours.count,
            nonMeditatedNights: nonMeditatedSleepHours.count,
            avgSleepWithMeditation: avgWith,
            avgSleepWithoutMeditation: avgWithout,
            improvement: improvement
        )
    }

    // MARK: - Filter Sleep Sessions

    func filterSleepSessions(from sessions: [MeditationSession]) -> [MeditationSession] {
        sessions.filter { session in
            // Check if session type indicates sleep content
            Self.sleepContentTypes.contains(session.sessionType)
        }
    }

    // MARK: - Weekly Data

    func getWeeklyData(from sessions: [MeditationSession]) -> [DailySleepData] {
        let sleepSessions = filterSleepSessions(from: sessions)
        let calendar = Calendar.current
        let today = Date()
        var weeklyData: [DailySleepData] = []

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"

        let shortDayFormatter = DateFormatter()
        shortDayFormatter.dateFormat = "EEE"

        for i in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            let daySessions = sleepSessions.filter { session in
                session.startedAt >= dayStart && session.startedAt < dayEnd
            }

            let totalMinutes = daySessions.reduce(0) { $0 + $1.listenedSeconds } / 60
            let sessionTimes = daySessions.map { $0.startedAt }
            let avgBedtime = calculateAverageBedtime(from: sessionTimes)

            weeklyData.append(DailySleepData(
                date: date,
                dayName: dayFormatter.string(from: date),
                shortDayName: shortDayFormatter.string(from: date),
                minutesListened: totalMinutes,
                sessionsCount: daySessions.count,
                averageBedtime: avgBedtime
            ))
        }

        return weeklyData
    }

    // MARK: - Monthly Data

    func getMonthlyData(from sessions: [MeditationSession]) -> [DailySleepData] {
        let sleepSessions = filterSleepSessions(from: sessions)
        let calendar = Calendar.current
        let today = Date()
        var monthlyData: [DailySleepData] = []

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "MMM d"

        for i in (0..<30).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            let daySessions = sleepSessions.filter { session in
                session.startedAt >= dayStart && session.startedAt < dayEnd
            }

            let totalMinutes = daySessions.reduce(0) { $0 + $1.listenedSeconds } / 60
            let sessionTimes = daySessions.map { $0.startedAt }
            let avgBedtime = calculateAverageBedtime(from: sessionTimes)

            monthlyData.append(DailySleepData(
                date: date,
                dayName: dayFormatter.string(from: date),
                shortDayName: dayFormatter.string(from: date),
                minutesListened: totalMinutes,
                sessionsCount: daySessions.count,
                averageBedtime: avgBedtime
            ))
        }

        return monthlyData
    }

    // MARK: - Most Played Content

    func getMostPlayedContent(from sessions: [MeditationSession], limit: Int = 3) -> [SleepContentStats] {
        let sleepSessions = filterSleepSessions(from: sessions)

        // Group by content title
        var contentStats: [String: (count: Int, minutes: Int, type: String, videoID: String?)] = [:]

        for session in sleepSessions {
            guard let title = session.contentTitle else { continue }
            let existing = contentStats[title] ?? (count: 0, minutes: 0, type: session.sessionType, videoID: session.youtubeVideoID)
            contentStats[title] = (
                count: existing.count + 1,
                minutes: existing.minutes + (session.listenedSeconds / 60),
                type: session.sessionType,
                videoID: session.youtubeVideoID ?? existing.videoID
            )
        }

        return contentStats.map { title, stats in
            SleepContentStats(
                contentTitle: title,
                contentType: ContentType(rawValue: stats.type) ?? .sleepStory,
                playCount: stats.count,
                totalMinutes: stats.minutes,
                youtubeVideoID: stats.videoID
            )
        }
        .sorted { $0.playCount > $1.playCount }
        .prefix(limit)
        .map { $0 }
    }

    // MARK: - Sleep Score Calculation

    func calculateSleepScore(from sessions: [MeditationSession]) -> SleepScore {
        let sleepSessions = filterSleepSessions(from: sessions)
        let calendar = Calendar.current
        let now = Date()

        // Get last 30 days of data
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) else {
            return SleepScore(overall: 0, consistencyScore: 0, completionScore: 0, varietyScore: 0, streakScore: 0)
        }

        let recentSessions = sleepSessions.filter { $0.startedAt >= thirtyDaysAgo }

        // 1. Consistency Score (days with sleep content / 30 days)
        var daysWithSleepContent: Set<String> = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for session in recentSessions {
            daysWithSleepContent.insert(dateFormatter.string(from: session.startedAt))
        }
        let consistencyScore = min(100, Int((Double(daysWithSleepContent.count) / 30.0) * 100))

        // 2. Completion Score (completed sessions / total sessions)
        let completedSessions = recentSessions.filter { $0.wasCompleted || $0.progress > 0.8 }
        let completionScore = recentSessions.isEmpty ? 0 : min(100, Int((Double(completedSessions.count) / Double(recentSessions.count)) * 100))

        // 3. Variety Score (unique content types / 4 sleep types)
        var uniqueTypes: Set<String> = []
        for session in recentSessions {
            uniqueTypes.insert(session.sessionType)
        }
        let varietyScore = min(100, Int((Double(uniqueTypes.count) / 4.0) * 100))

        // 4. Streak Score (current streak / 30 days target)
        let currentStreak = calculateSleepStreak(from: sessions)
        let streakScore = min(100, Int((Double(currentStreak) / 30.0) * 100))

        // Overall weighted score
        let overall = (consistencyScore * 35 + completionScore * 25 + varietyScore * 15 + streakScore * 25) / 100

        return SleepScore(
            overall: overall,
            consistencyScore: consistencyScore,
            completionScore: completionScore,
            varietyScore: varietyScore,
            streakScore: streakScore
        )
    }

    // MARK: - Sleep Streak

    func calculateSleepStreak(from sessions: [MeditationSession]) -> Int {
        let sleepSessions = filterSleepSessions(from: sessions)
        guard !sleepSessions.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Get unique days with sleep content
        var daysWithSleep: Set<Date> = []
        for session in sleepSessions {
            let day = calendar.startOfDay(for: session.startedAt)
            daysWithSleep.insert(day)
        }

        // Count consecutive days backwards from today
        var streak = 0
        var checkDate = today

        // First check if user has listened today or yesterday (allow 1 day grace)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        if !daysWithSleep.contains(today) && !daysWithSleep.contains(yesterday) {
            return 0
        }

        // If not today but yesterday, start from yesterday
        if !daysWithSleep.contains(today) {
            checkDate = yesterday
        }

        while daysWithSleep.contains(checkDate) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previousDay
        }

        return streak
    }

    // MARK: - Bedtime Trends

    func getBedtimeTrends(from sessions: [MeditationSession], days: Int = 14) -> [BedtimeTrend] {
        let sleepSessions = filterSleepSessions(from: sessions)
        let calendar = Calendar.current
        let now = Date()

        guard let startDate = calendar.date(byAdding: .day, value: -days, to: now) else { return [] }

        let recentSessions = sleepSessions.filter { $0.startedAt >= startDate }

        // Group by day and get average bedtime for each day
        var dailyBedtimes: [Date: [Date]] = [:]

        for session in recentSessions {
            let day = calendar.startOfDay(for: session.startedAt)
            dailyBedtimes[day, default: []].append(session.startedAt)
        }

        return dailyBedtimes.compactMap { day, times in
            guard let avgBedtime = calculateAverageBedtime(from: times) else { return nil }
            let hour = Double(calendar.component(.hour, from: avgBedtime))
            let minute = Double(calendar.component(.minute, from: avgBedtime))
            var hourOfDay = hour + (minute / 60.0)

            // Adjust for late-night viewing (wrap around midnight)
            if hourOfDay < 12 {
                hourOfDay += 24 // Treat early morning as late night
            }

            return BedtimeTrend(date: day, bedtime: avgBedtime, hourOfDay: hourOfDay)
        }
        .sorted { $0.date < $1.date }
    }

    // MARK: - Total Time Stats

    func getTotalSleepTime(from sessions: [MeditationSession]) -> (hours: Int, minutes: Int) {
        let sleepSessions = filterSleepSessions(from: sessions)
        let totalSeconds = sleepSessions.reduce(0) { $0 + $1.listenedSeconds }
        let totalMinutes = totalSeconds / 60
        return (hours: totalMinutes / 60, minutes: totalMinutes % 60)
    }

    func getTotalSleepSessions(from sessions: [MeditationSession]) -> Int {
        filterSleepSessions(from: sessions).count
    }

    // MARK: - Insights Generation

    func generateInsights(from sessions: [MeditationSession]) -> [SleepInsight] {
        let sleepSessions = filterSleepSessions(from: sessions)
        var insights: [SleepInsight] = []

        guard !sleepSessions.isEmpty else {
            return [SleepInsight(
                icon: "moon.zzz",
                title: "Start Your Sleep Journey",
                message: "Listen to sleep content to see personalized insights here.",
                type: .neutral
            )]
        }

        let calendar = Calendar.current
        let now = Date()
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return insights }

        let recentSessions = sleepSessions.filter { $0.startedAt >= sevenDaysAgo }

        // Insight 1: Best content type
        var typeMinutes: [String: Int] = [:]
        for session in recentSessions {
            typeMinutes[session.sessionType, default: 0] += session.listenedSeconds / 60
        }

        if let bestType = typeMinutes.max(by: { $0.value < $1.value }) {
            let contentType = ContentType(rawValue: bestType.key)?.displayName ?? bestType.key
            insights.append(SleepInsight(
                icon: "star.fill",
                title: "Your Sleep Favorite",
                message: "You sleep best with \(contentType). Keep it up!",
                type: .positive
            ))
        }

        // Insight 2: Most consistent day
        var dayOfWeekCounts: [Int: Int] = [:]
        for session in sleepSessions {
            let weekday = calendar.component(.weekday, from: session.startedAt)
            dayOfWeekCounts[weekday, default: 0] += 1
        }

        if let bestDay = dayOfWeekCounts.max(by: { $0.value < $1.value }) {
            let dayName = calendar.weekdaySymbols[bestDay.key - 1]
            insights.append(SleepInsight(
                icon: "calendar",
                title: "Most Consistent Day",
                message: "You're most consistent on \(dayName)s. Try matching this on other nights!",
                type: .positive
            ))
        }

        // Insight 3: Bedtime suggestion
        let bedtimeTrends = getBedtimeTrends(from: sessions, days: 14)
        if !bedtimeTrends.isEmpty {
            let avgHour = bedtimeTrends.reduce(0.0) { $0 + $1.hourOfDay } / Double(bedtimeTrends.count)

            if avgHour > 24 { // After midnight
                insights.append(SleepInsight(
                    icon: "clock",
                    title: "Earlier Bedtime",
                    message: "Try starting your sleep content 30 minutes earlier for better rest.",
                    type: .suggestion
                ))
            }
        }

        // Insight 4: Streak encouragement
        let streak = calculateSleepStreak(from: sessions)
        if streak >= 7 {
            insights.append(SleepInsight(
                icon: "flame.fill",
                title: "\(streak) Night Streak!",
                message: "Amazing consistency! You're building great sleep habits.",
                type: .positive
            ))
        } else if streak >= 3 {
            insights.append(SleepInsight(
                icon: "flame",
                title: "Building Momentum",
                message: "\(streak) nights in a row! Keep going to build a stronger streak.",
                type: .positive
            ))
        }

        return insights
    }

    // MARK: - Helper Methods

    private func calculateAverageBedtime(from times: [Date]) -> Date? {
        guard !times.isEmpty else { return nil }

        let calendar = Calendar.current
        var totalMinutesFromMidnight = 0

        for time in times {
            var minutes = calendar.component(.hour, from: time) * 60 + calendar.component(.minute, from: time)
            // Adjust for times after midnight (treat as late night)
            if minutes < 720 { // Before noon
                minutes += 1440 // Add 24 hours worth of minutes
            }
            totalMinutesFromMidnight += minutes
        }

        var averageMinutes = totalMinutesFromMidnight / times.count

        // Unwrap if over 24 hours
        if averageMinutes >= 1440 {
            averageMinutes -= 1440
        }

        let avgHour = averageMinutes / 60
        let avgMinute = averageMinutes % 60

        return calendar.date(bySettingHour: avgHour, minute: avgMinute, second: 0, of: Date())
    }

    // MARK: - Formatted Strings

    func formatBedtime(_ date: Date?) -> String {
        guard let date = date else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    func formatDuration(hours: Int, minutes: Int) -> String {
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
