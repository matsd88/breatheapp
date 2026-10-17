//
//  WeekProgressStrip.swift
//  Meditation Sleep Mindset
//
//  Seven day dots for the current calendar week: checked when the user
//  practised that day, ringed for today. The at-a-glance "how's my week"
//  row Calm, Breathwrk and Liven lead their home screens with.
//

import SwiftUI

struct WeekProgressStrip: View {
    @ObservedObject private var streakService = StreakService.shared

    /// Smaller dots for tight spots (session summary).
    var compact = false

    var body: some View {
        let dotSize: CGFloat = compact ? 30 : 34
        // Built once per render (reads defaults + iCloud KVS)
        let days = streakService.currentWeekActivity()

        VStack(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(days, id: \.date) { day in
                    let isToday = Calendar.current.isDateInToday(day.date)
                    let isFuture = !isToday && day.date > Date()

                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(day.hasActivity ? Theme.profileAccent : Color.white.opacity(isFuture ? 0.04 : 0.08))

                            if day.hasActivity {
                                Image(systemName: "checkmark")
                                    .font(.system(size: compact ? 12 : 13, weight: .bold))
                                    .foregroundStyle(.white)
                            }

                            if isToday {
                                Circle()
                                    .strokeBorder(Theme.profileAccent, lineWidth: 2)
                                    .padding(-4)
                            }
                        }
                        .frame(width: dotSize, height: dotSize)

                        Text(day.dayName)
                            .font(.caption2.weight(isToday ? .bold : .regular))
                            .foregroundStyle(.white.opacity(isToday ? 0.9 : 0.5))
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            if !compact {
                Text(summary(activeCount: days.filter(\.hasActivity).count))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary(days))
    }

    private func summary(activeCount: Int) -> String {
        switch activeCount {
        case 0: return String(localized: "Your week starts with one session.")
        case 1: return String(localized: "1 day of calm this week. Keep going!")
        default: return String(localized: "\(activeCount) days of calm this week. Keep going!")
        }
    }

    private func accessibilitySummary(_ days: [StreakService.DayActivity]) -> String {
        let practised = days.filter(\.hasActivity).map {
            $0.date.formatted(.dateTime.weekday(.wide))
        }
        if practised.isEmpty {
            return String(localized: "No sessions yet this week")
        }
        return String(localized: "Practised this week on \(practised.joined(separator: ", "))")
    }
}
