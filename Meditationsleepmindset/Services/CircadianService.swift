//
//  CircadianService.swift
//  Meditation Sleep Mindset
//
//  Forecasts the user's daily energy curve from their wake time (circadian model,
//  inspired by RISE): grogginess window, morning/evening peaks, the afternoon dip,
//  and the evening wind-down / melatonin window — so the app can suggest the right
//  session at the biologically right time.
//

import Foundation
import SwiftUI

@MainActor
final class CircadianService: ObservableObject {
    static let shared = CircadianService()

    /// User's typical wake time, stored as seconds since midnight (default 7:00 AM).
    @AppStorage("circadianWakeTimeSeconds") var wakeTimeSeconds: Double = 7 * 3600

    private init() {}

    enum EnergyWindowType {
        case grogginess, morningPeak, afternoonDip, eveningPeak, windDown

        var title: String {
            switch self {
            case .grogginess: return String(localized: "Wake-up window")
            case .morningPeak: return String(localized: "Morning peak")
            case .afternoonDip: return String(localized: "Afternoon dip")
            case .eveningPeak: return String(localized: "Evening peak")
            case .windDown: return String(localized: "Wind-down window")
            }
        }

        var icon: String {
            switch self {
            case .grogginess: return "sunrise.fill"
            case .morningPeak: return "bolt.fill"
            case .afternoonDip: return "cloud.fill"
            case .eveningPeak: return "sparkles"
            case .windDown: return "moon.stars.fill"
            }
        }

        var suggestion: String {
            switch self {
            case .grogginess: return String(localized: "Ease in — a few deep breaths beat reaching for your phone.")
            case .morningPeak: return String(localized: "Great for focus. Try a short focus or intention session.")
            case .afternoonDip: return String(localized: "Energy naturally dips. A 3-minute reset or breathing break helps.")
            case .eveningPeak: return String(localized: "A second wind. A calming meditation keeps it from becoming late-night alertness.")
            case .windDown: return String(localized: "Melatonin is rising. Start a sleep story or wind-down now for easier sleep.")
            }
        }
    }

    struct EnergyPoint: Identifiable {
        let id = UUID()
        let hour: Double      // 0–24 clock hour for the chart
        let level: Double     // 0–1
        let date: Date
    }

    struct EnergyWindow: Identifiable {
        let id = UUID()
        let type: EnergyWindowType
        let start: Date
        let end: Date
    }

    struct EnergySchedule {
        let points: [EnergyPoint]
        let windows: [EnergyWindow]
        let wakeTime: Date
        let suggestedBedtime: Date
        let currentLevel: Double
    }

    /// Energy as a function of hours since wake (0…~17). Smooth model with a morning
    /// rise out of inertia, a midday peak, the post-lunch dip, an evening peak, then decline.
    private func energy(hoursSinceWake t: Double) -> Double {
        guard t >= 0 else { return 0.15 }
        // Inertia: low for first ~1.5h, climbing.
        let inertia = 1.0 - exp(-t / 1.2)                       // 0→1 over first hours
        // Two cosine "humps": morning (~+3h) and evening (~+11h), dip between (~+8h).
        let morning = 0.5 * (1 + cos((t - 3.0) / 3.0 * .pi))    // peak at t=3
        let evening = 0.5 * (1 + cos((t - 11.0) / 3.0 * .pi))   // peak at t=11
        let hump = max(0, morning) * 0.55 + max(0, evening) * 0.45
        // Long decline toward bedtime.
        let decline = max(0, 1.0 - max(0, t - 13.0) / 5.0)
        let level = inertia * (0.45 + 0.55 * hump) * (0.5 + 0.5 * decline)
        return min(1, max(0.08, level))
    }

    func schedule(for now: Date = Date()) -> EnergySchedule {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: now)
        let wakeTime = todayStart.addingTimeInterval(wakeTimeSeconds)
        let suggestedBedtime = wakeTime.addingTimeInterval(16 * 3600)   // ~16h awake for 8h sleep

        // Sample the curve every 30 min from wake to wake+17h.
        var points: [EnergyPoint] = []
        var t = 0.0
        while t <= 17.0 {
            let date = wakeTime.addingTimeInterval(t * 3600)
            let hour = Double(cal.component(.hour, from: date)) + Double(cal.component(.minute, from: date)) / 60.0
            points.append(EnergyPoint(hour: hour, level: energy(hoursSinceWake: t), date: date))
            t += 0.5
        }

        func window(_ type: EnergyWindowType, fromHour a: Double, toHour b: Double) -> EnergyWindow {
            EnergyWindow(type: type,
                         start: wakeTime.addingTimeInterval(a * 3600),
                         end: wakeTime.addingTimeInterval(b * 3600))
        }

        let windows: [EnergyWindow] = [
            window(.grogginess, fromHour: 0, toHour: 1.5),
            window(.morningPeak, fromHour: 2.5, toHour: 4.5),
            window(.afternoonDip, fromHour: 7, toHour: 9),
            window(.eveningPeak, fromHour: 10, toHour: 12),
            window(.windDown, fromHour: 14.5, toHour: 16)
        ]

        let hoursSinceWake = now.timeIntervalSince(wakeTime) / 3600.0
        let currentLevel = energy(hoursSinceWake: hoursSinceWake)

        return EnergySchedule(points: points, windows: windows, wakeTime: wakeTime,
                              suggestedBedtime: suggestedBedtime, currentLevel: currentLevel)
    }

    /// The window the user is currently in (if any), for a contextual suggestion.
    func currentWindow(for now: Date = Date()) -> EnergyWindow? {
        schedule(for: now).windows.first { now >= $0.start && now <= $0.end }
    }
}
