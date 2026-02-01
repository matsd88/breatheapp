//
//  AlarmSettingsView.swift
//  Meditation Sleep Mindset
//

import SwiftUI

struct AlarmSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var alarmService = AlarmService.shared

    private let sheetBackground = Color(red: 0.04, green: 0.06, blue: 0.14)

    var body: some View {
        NavigationStack {
            ZStack {
                sheetBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Enable toggle
                        Toggle(isOn: $alarmService.isEnabled) {
                            HStack(spacing: 12) {
                                Image(systemName: "alarm.fill")
                                    .foregroundStyle(.cyan)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Wake Up Alarm")
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    Text("Gentle alarm to start your day")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                        .tint(.cyan)
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .onChange(of: alarmService.isEnabled) { _, _ in
                            alarmService.scheduleAlarm()
                        }

                        if alarmService.isEnabled {
                            // Time picker
                            VStack(spacing: 12) {
                                Text("Alarm Time")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.textSecondary)

                                DatePicker(
                                    "Alarm Time",
                                    selection: $alarmService.alarmTime,
                                    displayedComponents: .hourAndMinute
                                )
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .onChange(of: alarmService.alarmTime) { _, _ in
                                    alarmService.scheduleAlarm()
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                            // Sound selection
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Alarm Sound")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.textSecondary)

                                ForEach(AlarmService.soundOptions, id: \.self) { sound in
                                    Button {
                                        alarmService.selectedSoundName = sound
                                    } label: {
                                        HStack {
                                            Image(systemName: AlarmService.iconForSound(sound))
                                                .foregroundStyle(.cyan)
                                                .frame(width: 24)

                                            Text(sound)
                                                .foregroundStyle(.white)

                                            Spacer()

                                            if alarmService.selectedSoundName == sound {
                                                Image(systemName: "checkmark")
                                                    .foregroundStyle(.cyan)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                            // Snooze
                            VStack(spacing: 12) {
                                Toggle(isOn: $alarmService.snoozeEnabled) {
                                    Text("Snooze")
                                        .foregroundStyle(.white)
                                }
                                .tint(.cyan)

                                if alarmService.snoozeEnabled {
                                    HStack {
                                        Text("Snooze Duration")
                                            .font(.subheadline)
                                            .foregroundStyle(Theme.textSecondary)

                                        Spacer()

                                        Picker("", selection: $alarmService.snoozeMinutes) {
                                            Text("3 min").tag(3)
                                            Text("5 min").tag(5)
                                            Text("10 min").tag(10)
                                        }
                                        .pickerStyle(.segmented)
                                        .frame(width: 200)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                    }
                    .padding()
                }
            }
            .navigationTitle("Sleep Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(sheetBackground, for: .navigationBar)
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
        .presentationDetents(alarmService.isEnabled ? [.medium, .large] : [.height(180)])
        .presentationBackground(sheetBackground)
    }
}
