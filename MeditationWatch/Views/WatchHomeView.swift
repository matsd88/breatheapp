//
//  WatchHomeView.swift
//  MeditationWatch
//
//  Home screen with streak, quick actions, and recent sessions
//

import SwiftUI
import WatchKit

struct WatchHomeView: View {
    @EnvironmentObject var connectivityService: WatchConnectivityService

    @State private var showBreathingPicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Streak Card
                StreakCard(
                    streak: connectivityService.syncData.currentStreak,
                    meditatedToday: hasMeditatedToday
                )

                // Quick Actions
                VStack(spacing: 8) {
                    NavigationLink(destination: WatchBreathingView()) {
                        QuickActionRow(
                            icon: "wind",
                            title: "Breathe",
                            subtitle: "1-3 min",
                            color: .cyan
                        )
                    }
                    .buttonStyle(.plain)

                    if connectivityService.syncData.playbackState != .stopped {
                        NavigationLink(destination: WatchNowPlayingView()) {
                            QuickActionRow(
                                icon: "play.circle.fill",
                                title: connectivityService.syncData.currentContentTitle ?? "Now Playing",
                                subtitle: connectivityService.syncData.playbackState == .playing ? "Playing" : "Paused",
                                color: .purple
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Today's Stats
                TodayStatsCard(
                    mindfulMinutes: connectivityService.syncData.mindfulMinutesToday,
                    totalMinutes: connectivityService.syncData.totalMinutes
                )

                // Recent Sessions
                if !connectivityService.syncData.recentSessions.isEmpty {
                    RecentSessionsList(sessions: connectivityService.syncData.recentSessions)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Meditate")
        .onAppear {
            connectivityService.requestSync()
        }
    }

    private var hasMeditatedToday: Bool {
        guard let lastSession = connectivityService.syncData.lastSessionDate else { return false }
        return Calendar.current.isDateInToday(lastSession)
    }
}

// MARK: - Streak Card

struct StreakCard: View {
    let streak: Int
    let meditatedToday: Bool

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.title3)
                    .foregroundStyle(streak > 0 ? .orange : .gray)

                Text("\(streak)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text(streak == 1 ? "day streak" : "days streak")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))

            if meditatedToday {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("Done today")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.12, blue: 0.35),
                            Color(red: 0.2, green: 0.15, blue: 0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

// MARK: - Quick Action Row

struct QuickActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.1))
        )
    }
}

// MARK: - Today Stats Card

struct TodayStatsCard: View {
    let mindfulMinutes: Int
    let totalMinutes: Int

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text("\(mindfulMinutes)")
                    .font(.headline)
                    .foregroundStyle(.cyan)
                Text("today")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 30)
                .background(Color.white.opacity(0.2))

            VStack(spacing: 2) {
                Text(formatTotalTime(totalMinutes))
                    .font(.headline)
                    .foregroundStyle(.purple)
                Text("total")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.08))
        )
    }

    private func formatTotalTime(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            return "\(hours)h"
        }
        return "\(minutes)m"
    }
}

// MARK: - Recent Sessions List

struct RecentSessionsList: View {
    let sessions: [WatchRecentSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.leading, 4)

            ForEach(sessions.prefix(3)) { session in
                RecentSessionRow(session: session)
            }
        }
    }
}

struct RecentSessionRow: View {
    let session: WatchRecentSession

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: session.contentTypeIcon)
                .font(.caption)
                .foregroundStyle(.purple.opacity(0.8))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(session.title)
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(session.durationFormatted)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.06))
        )
    }
}

#Preview {
    WatchHomeView()
        .environmentObject(WatchConnectivityService.shared)
}
