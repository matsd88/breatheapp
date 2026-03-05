//
//  AlarmSettingsView.swift
//  Meditation Sleep Mindset
//

import SwiftUI

struct AlarmSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var alarmService = AlarmService.shared

    private let sheetBackground = Color(red: 0.04, green: 0.06, blue: 0.14)
    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        NavigationStack {
            ZStack {
                sheetBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: isRegular ? 28 : 24) {
                        // Enable toggle
                        Toggle(isOn: $alarmService.isEnabled) {
                            HStack(spacing: isRegular ? 16 : 12) {
                                Image(systemName: "alarm.fill")
                                    .foregroundStyle(.cyan)
                                    .font(isRegular ? .title2 : .title3)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Wake Up Alarm")
                                        .font(isRegular ? .title3.weight(.semibold) : .headline)
                                        .foregroundStyle(.white)

                                    Text("Gentle alarm to start your day")
                                        .font(isRegular ? .subheadline : .caption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                        .tint(.cyan)
                        .padding(isRegular ? 20 : 16)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .onChange(of: alarmService.isEnabled) { _, _ in
                            alarmService.scheduleAlarm()
                        }

                        if alarmService.isEnabled {
                            if isRegular {
                                // iPad: two-column layout — time picker left, sound + snooze right
                                HStack(alignment: .top, spacing: 20) {
                                    // Left column: Time picker
                                    VStack(spacing: 12) {
                                        Text("Alarm Time")
                                            .font(.headline)
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
                                    .padding(20)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))

                                    // Right column: Sound + Snooze
                                    VStack(spacing: 20) {
                                        // Sound selection
                                        VStack(alignment: .leading, spacing: 14) {
                                            Text("Alarm Sound")
                                                .font(.headline)
                                                .foregroundStyle(Theme.textSecondary)

                                            ForEach(AlarmService.soundOptions, id: \.self) { sound in
                                                Button {
                                                    alarmService.selectedSoundName = sound
                                                } label: {
                                                    HStack {
                                                        Image(systemName: AlarmService.iconForSound(sound))
                                                            .foregroundStyle(.cyan)
                                                            .font(.body)
                                                            .frame(width: 28)

                                                        Text(sound)
                                                            .font(.body)
                                                            .foregroundStyle(.white)

                                                        Spacer()

                                                        if alarmService.selectedSoundName == sound {
                                                            Image(systemName: "checkmark.circle.fill")
                                                                .foregroundStyle(.cyan)
                                                        }
                                                    }
                                                    .padding(.vertical, 10)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(20)
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))

                                        // Snooze
                                        VStack(spacing: 14) {
                                            Toggle(isOn: $alarmService.snoozeEnabled) {
                                                Text("Snooze")
                                                    .font(.body)
                                                    .foregroundStyle(.white)
                                            }
                                            .tint(.cyan)

                                            if alarmService.snoozeEnabled {
                                                HStack {
                                                    Text("Duration")
                                                        .font(.subheadline)
                                                        .foregroundStyle(Theme.textSecondary)

                                                    Spacer()

                                                    Picker("", selection: $alarmService.snoozeMinutes) {
                                                        Text("3 min").tag(3)
                                                        Text("5 min").tag(5)
                                                        Text("10 min").tag(10)
                                                    }
                                                    .pickerStyle(.segmented)
                                                    .frame(maxWidth: 240)
                                                }
                                            }
                                        }
                                        .padding(20)
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            } else {
                                // iPhone: stacked layout
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
                                            .frame(maxWidth: 220)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }

                    }
                    .padding(isRegular ? 24 : 16)
                    .frame(maxWidth: isRegular ? 700 : 600)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Sleep Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(sheetBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SheetCloseButton { dismiss() }
                }
            }
        }
        .presentationDetents(isRegular ? [.medium, .large] : (alarmService.isEnabled ? [.medium, .large] : [.height(180)]))
        .presentationBackground(sheetBackground)
    }
}
