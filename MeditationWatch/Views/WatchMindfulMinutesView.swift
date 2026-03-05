//
//  WatchMindfulMinutesView.swift
//  MeditationWatch
//
//  Shows today's mindful minutes synced with HealthKit
//

import SwiftUI
import HealthKit
import WatchKit

struct WatchMindfulMinutesView: View {
    @EnvironmentObject var connectivityService: WatchConnectivityService
    @EnvironmentObject var sessionManager: WatchSessionManager

    @State private var healthKitAuthorized = false
    @State private var weeklyData: [DayData] = []
    @State private var isLoading = true

    private let healthStore = HKHealthStore()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Today's circle
                TodayCircleView(
                    minutes: sessionManager.todayMindfulMinutes,
                    goal: 10
                )

                // Weekly chart
                if !weeklyData.isEmpty {
                    WeeklyChartView(data: weeklyData)
                }

                // Stats
                StatsRowView(
                    streak: connectivityService.syncData.currentStreak,
                    totalMinutes: connectivityService.syncData.totalMinutes
                )

                // HealthKit status
                if !healthKitAuthorized {
                    HealthKitPermissionView {
                        Task {
                            healthKitAuthorized = await sessionManager.requestHealthKitAuthorization()
                            if healthKitAuthorized {
                                loadWeeklyData()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Mindful")
        .onAppear {
            checkHealthKitStatus()
            loadWeeklyData()
            sessionManager.loadMindfulMinutes()
        }
    }

    // MARK: - HealthKit

    private func checkHealthKitStatus() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession)!
        let status = healthStore.authorizationStatus(for: mindfulType)
        healthKitAuthorized = status == .sharingAuthorized
    }

    private func loadWeeklyData() {
        guard HKHealthStore.isHealthDataAvailable() else {
            isLoading = false
            return
        }

        let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession)!
        let calendar = Calendar.current
        let now = Date()

        var data: [DayData] = []
        let group = DispatchGroup()

        for i in (0..<7).reversed() {
            guard let dayStart = calendar.date(byAdding: .day, value: -i, to: calendar.startOfDay(for: now)),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)

            group.enter()
            let query = HKSampleQuery(sampleType: mindfulType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                defer { group.leave() }

                let minutes: Int
                if let samples = samples as? [HKCategorySample] {
                    let totalSeconds = samples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                    minutes = Int(totalSeconds / 60)
                } else {
                    minutes = 0
                }

                let formatter = DateFormatter()
                formatter.dateFormat = "EEE"
                let dayName = formatter.string(from: dayStart)

                DispatchQueue.main.async {
                    data.append(DayData(day: dayName, minutes: minutes, date: dayStart))
                }
            }

            healthStore.execute(query)
        }

        group.notify(queue: .main) {
            weeklyData = data.sorted { $0.date < $1.date }
            isLoading = false
        }
    }
}

// MARK: - Day Data

struct DayData: Identifiable {
    let id = UUID()
    let day: String
    let minutes: Int
    let date: Date
}

// MARK: - Today Circle View

struct TodayCircleView: View {
    let minutes: Int
    let goal: Int

    private var progress: Double {
        min(1.0, Double(minutes) / Double(goal))
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                    .frame(width: 90, height: 90)

                // Progress circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [.cyan, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))

                // Center text
                VStack(spacing: 2) {
                    Text("\(minutes)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("min")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Text("Today")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            if minutes >= goal {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                    Text("Goal reached!")
                        .font(.caption2)
                }
                .foregroundStyle(.green)
            } else {
                Text("\(goal - minutes) min to goal")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Weekly Chart View

struct WeeklyChartView: View {
    let data: [DayData]

    private var maxMinutes: Int {
        max(10, data.map(\.minutes).max() ?? 10)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This Week")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.leading, 4)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(data) { day in
                    VStack(spacing: 4) {
                        // Bar
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                day.minutes > 0
                                    ? LinearGradient(colors: [.cyan, .purple], startPoint: .bottom, endPoint: .top)
                                    : LinearGradient(colors: [.white.opacity(0.1)], startPoint: .bottom, endPoint: .top)
                            )
                            .frame(width: 16, height: CGFloat(day.minutes) / CGFloat(maxMinutes) * 40 + 4)

                        // Day label
                        Text(String(day.day.prefix(1)))
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.06))
            )
        }
    }
}

// MARK: - Stats Row View

struct StatsRowView: View {
    let streak: Int
    let totalMinutes: Int

    var body: some View {
        HStack(spacing: 12) {
            StatItem(
                icon: "flame.fill",
                value: "\(streak)",
                label: "streak",
                color: .orange
            )

            StatItem(
                icon: "clock.fill",
                value: formatMinutes(totalMinutes),
                label: "total",
                color: .purple
            )
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            return "\(minutes / 60)h"
        }
        return "\(minutes)m"
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)

            Text(value)
                .font(.headline)
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.06))
        )
    }
}

// MARK: - HealthKit Permission View

struct HealthKitPermissionView: View {
    let onRequest: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.title3)
                .foregroundStyle(.red)

            Text("Enable HealthKit")
                .font(.caption.bold())
                .foregroundStyle(.white)

            Text("Track mindful minutes")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))

            Button(action: onRequest) {
                Text("Enable")
                    .font(.caption.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
        )
    }
}

#Preview {
    WatchMindfulMinutesView()
        .environmentObject(WatchConnectivityService.shared)
        .environmentObject(WatchSessionManager.shared)
}
