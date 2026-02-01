//
//  NotificationSettingsView.swift
//  Meditation Sleep Mindset
//

import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var notificationService = NotificationService.shared
    @State private var showingDailyTimePicker = false
    @State private var showingBedtimeTimePicker = false

    var body: some View {
        ZStack {
            Theme.profileGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Daily Reminder Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("PRACTICE REMINDER")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            // Toggle
                            HStack(spacing: 12) {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Theme.profileAccent)
                                    .frame(width: 28)

                                Text("Daily Reminder")
                                    .foregroundStyle(Theme.textPrimary)

                                Spacer()

                                Toggle("", isOn: Binding(
                                    get: { notificationService.dailyReminderEnabled },
                                    set: { notificationService.setDailyReminder(enabled: $0) }
                                ))
                                .labelsHidden()
                                .tint(Theme.profileAccent)
                            }
                            .padding()

                            if notificationService.dailyReminderEnabled {
                                Divider()
                                    .background(Color.white.opacity(0.1))

                                Button {
                                    showingDailyTimePicker = true
                                } label: {
                                    HStack {
                                        Text("Reminder Time")
                                            .foregroundStyle(Theme.textPrimary)
                                        Spacer()
                                        Text(timeString(from: notificationService.dailyReminderTime))
                                            .foregroundStyle(Theme.textSecondary)
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(Theme.textTertiary)
                                    }
                                    .padding()
                                }
                            }
                        }
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        Text("Get a gentle nudge to meditate at your chosen time each day.")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.horizontal, 4)
                    }

                    // Bedtime Reminder Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("SLEEP")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            // Toggle
                            HStack(spacing: 12) {
                                Image(systemName: "moon.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.purple)
                                    .frame(width: 28)

                                Text("Bedtime Reminder")
                                    .foregroundStyle(Theme.textPrimary)

                                Spacer()

                                Toggle("", isOn: Binding(
                                    get: { notificationService.bedtimeReminderEnabled },
                                    set: { notificationService.setBedtimeReminder(enabled: $0) }
                                ))
                                .labelsHidden()
                                .tint(Theme.profileAccent)
                            }
                            .padding()

                            if notificationService.bedtimeReminderEnabled {
                                Divider()
                                    .background(Color.white.opacity(0.1))

                                Button {
                                    showingBedtimeTimePicker = true
                                } label: {
                                    HStack {
                                        Text("Bedtime")
                                            .foregroundStyle(Theme.textPrimary)
                                        Spacer()
                                        Text(timeString(from: notificationService.bedtimeReminderTime))
                                            .foregroundStyle(Theme.textSecondary)
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(Theme.textTertiary)
                                    }
                                    .padding()
                                }
                            }
                        }
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        Text("Remind you to wind down with a sleep story before bed.")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.horizontal, 4)
                    }

                    // Other Notifications Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("OTHER")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            // Streak Milestones
                            HStack(spacing: 12) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.orange)
                                    .frame(width: 28)

                                Text("Streak Milestones")
                                    .foregroundStyle(Theme.textPrimary)

                                Spacer()

                                Toggle("", isOn: $notificationService.streakNotificationsEnabled)
                                    .labelsHidden()
                                    .tint(Theme.profileAccent)
                            }
                            .padding()

                            Divider()
                                .background(Color.white.opacity(0.1))

                            // New Content
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.yellow)
                                    .frame(width: 28)

                                Text("New Content")
                                    .foregroundStyle(Theme.textPrimary)

                                Spacer()

                                Toggle("", isOn: $notificationService.newContentNotificationsEnabled)
                                    .labelsHidden()
                                    .tint(Theme.profileAccent)
                            }
                            .padding()
                        }
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        Text("Celebrate your progress and discover new meditations.")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.horizontal, 4)
                    }

                    // System Settings Link
                    if !notificationService.isAuthorized {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)

                                Text("Notifications are disabled in Settings")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            Button {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text("Open Settings")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Theme.profileAccent)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingDailyTimePicker) {
            TimePickerSheet(
                title: "Daily Reminder",
                selectedTime: Binding(
                    get: { notificationService.dailyReminderTime },
                    set: { notificationService.dailyReminderTime = $0 }
                )
            )
        }
        .sheet(isPresented: $showingBedtimeTimePicker) {
            TimePickerSheet(
                title: "Bedtime Reminder",
                selectedTime: Binding(
                    get: { notificationService.bedtimeReminderTime },
                    set: { notificationService.bedtimeReminderTime = $0 }
                )
            )
        }
        .task {
            await notificationService.checkAuthorizationStatus()
        }
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TimePickerSheet: View {
    let title: String
    @Binding var selectedTime: Date
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                VStack {
                    DatePicker(
                        title,
                        selection: $selectedTime,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Theme.profileAccent)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
