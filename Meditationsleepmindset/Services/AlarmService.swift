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
    @Published var selectedSoundName: String {
        didSet {
            UserDefaults.standard.set(selectedSoundName, forKey: "alarmSound")
            scheduleAlarm() // Reschedule with new sound
        }
    }
    @Published var snoozeEnabled: Bool {
        didSet { UserDefaults.standard.set(snoozeEnabled, forKey: "alarmSnooze") }
    }
    @Published var snoozeMinutes: Int {
        didSet { UserDefaults.standard.set(snoozeMinutes, forKey: "alarmSnoozeMinutes") }
    }

    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "alarmEnabled")
        let savedTime = UserDefaults.standard.double(forKey: "alarmTime")
        self.alarmTime = savedTime > 0 ? Date(timeIntervalSince1970: savedTime) : Self.defaultAlarmTime()
        self.selectedSoundName = UserDefaults.standard.string(forKey: "alarmSound") ?? "Gentle Chimes"
        self.snoozeEnabled = UserDefaults.standard.object(forKey: "alarmSnooze") == nil ? true : UserDefaults.standard.bool(forKey: "alarmSnooze")
        self.snoozeMinutes = max(1, UserDefaults.standard.integer(forKey: "alarmSnoozeMinutes") == 0 ? 5 : UserDefaults.standard.integer(forKey: "alarmSnoozeMinutes"))
    }

    private static func defaultAlarmTime() -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 7
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    static let soundOptions = [
        "Gentle Chimes",
        "Birds",
        "Ocean Waves",
        "Soft Piano",
        "Rain",
        "Forest"
    ]

    static func iconForSound(_ name: String) -> String {
        switch name {
        case "Gentle Chimes": return "bell.fill"
        case "Birds": return "bird.fill"
        case "Ocean Waves": return "water.waves"
        case "Soft Piano": return "pianokeys"
        case "Rain": return "cloud.rain.fill"
        case "Forest": return "leaf.fill"
        default: return "bell.fill"
        }
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
        content.sound = notificationSound(for: selectedSoundName)
        content.categoryIdentifier = "ALARM"

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

    func snooze() {
        guard snoozeEnabled else { return }

        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Alarm"
        content.body = "Snooze is over — time to rise."
        content.sound = notificationSound(for: selectedSoundName)

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(snoozeMinutes * 60),
            repeats: false
        )

        let request = UNNotificationRequest(identifier: "sleepAlarmSnooze", content: content, trigger: trigger)
        center.add(request)
    }

    /// Map user-facing sound name to a system notification sound.
    /// If custom .caf files are added to the bundle, they'll be used automatically.
    /// Otherwise iOS falls back to the default system sound gracefully.
    private func notificationSound(for soundName: String) -> UNNotificationSound {
        let fileName: String? = switch soundName {
        case "Birds": "birds.caf"
        case "Ocean Waves": "ocean.caf"
        case "Soft Piano": "piano.caf"
        case "Rain": "rain.caf"
        case "Forest": "forest.caf"
        default: nil
        }

        // Only use custom sound if the file actually exists in the bundle
        if let fileName, Bundle.main.url(forResource: fileName.replacingOccurrences(of: ".caf", with: ""), withExtension: "caf") != nil {
            return UNNotificationSound(named: UNNotificationSoundName(fileName))
        }
        return .default
    }

    var formattedAlarmTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: alarmTime)
    }
}
