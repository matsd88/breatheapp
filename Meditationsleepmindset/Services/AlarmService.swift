//
//  AlarmService.swift
//  Meditation Sleep Mindset
//

import Foundation
import UserNotifications

@MainActor
class AlarmService: ObservableObject {
    static let shared = AlarmService()

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "alarmEnabled") }
    }
    @Published var alarmTime: Date {
        didSet { UserDefaults.standard.set(alarmTime.timeIntervalSince1970, forKey: "alarmTime") }
    }
    @Published var snoozeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(snoozeEnabled, forKey: "alarmSnooze")
            // The notification's category decides whether it shows a Snooze
            // button, so the pending alarm has to be re-registered.
            if isEnabled && oldValue != snoozeEnabled {
                scheduleAlarm()
            }
        }
    }
    @Published var snoozeMinutes: Int {
        didSet { UserDefaults.standard.set(snoozeMinutes, forKey: "alarmSnoozeMinutes") }
    }

    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "alarmEnabled")
        let savedTime = UserDefaults.standard.double(forKey: "alarmTime")
        self.alarmTime = savedTime > 0 ? Date(timeIntervalSince1970: savedTime) : Self.defaultAlarmTime()
        // The sound picker is gone (no sound files ever shipped); drop its key.
        UserDefaults.standard.removeObject(forKey: "alarmSound")
        self.snoozeEnabled = UserDefaults.standard.object(forKey: "alarmSnooze") == nil ? true : UserDefaults.standard.bool(forKey: "alarmSnooze")
        self.snoozeMinutes = max(1, UserDefaults.standard.integer(forKey: "alarmSnoozeMinutes") == 0 ? 5 : UserDefaults.standard.integer(forKey: "alarmSnoozeMinutes"))
    }

    private static func defaultAlarmTime() -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 7
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    func scheduleAlarm() {
        guard isEnabled else {
            cancelAlarm()
            return
        }

        let center = UNUserNotificationCenter.current()

        // Remove existing alarm
        center.removePendingNotificationRequests(withIdentifiers: ["sleepAlarm", "sleepAlarmSnooze"])

        let content = UNMutableNotificationContent()
        content.title = "Good Morning"
        content.body = "Time to wake up and start your day mindfully."
        content.sound = .default
        // With snooze off, the alarm used to still show a Snooze button that
        // silently did nothing.
        content.categoryIdentifier = snoozeEnabled ? "ALARM" : "ALARM_NO_SNOOZE"

        let components = Calendar.current.dateComponents([.hour, .minute], from: alarmTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: "sleepAlarm", content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                #if DEBUG
                print("Failed to schedule alarm: \(error)")
                #endif
            }
        }
    }

    func cancelAlarm() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["sleepAlarm", "sleepAlarmSnooze"]
        )
    }

    /// Async so the notification-action handler can finish scheduling before
    /// it tells the system it's done (a background action launch can be
    /// suspended right after, dropping the snooze).
    func snooze() async {
        guard snoozeEnabled else { return }

        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Alarm"
        content.body = "Snooze is over — time to rise."
        content.sound = .default
        // Same category as the alarm, so the snoozed alarm can be snoozed again.
        content.categoryIdentifier = "ALARM"

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(snoozeMinutes * 60),
            repeats: false
        )

        let request = UNNotificationRequest(identifier: "sleepAlarmSnooze", content: content, trigger: trigger)
        try? await center.add(request)
    }

    var formattedAlarmTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: alarmTime)
    }
}
