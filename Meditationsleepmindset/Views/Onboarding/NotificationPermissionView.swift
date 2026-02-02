//
//  NotificationPermissionView.swift
//  Meditation Sleep Mindset
//

import SwiftUI

struct NotificationPermissionView: View {
    @StateObject private var notificationService = NotificationService.shared
    @EnvironmentObject var appState: AppStateManager
    @State private var selectedTime = Date()
    @State private var showTimePicker = false

    let onContinue: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            Theme.profileGradient
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Navigation
                HStack {
                    Button {
                        onBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    Button("Skip") {
                        onSkip()
                    }
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 16)

                // Progress indicator
                OnboardingProgressDotsView(current: 3, total: 6)

                Spacer()

                // Icon
                ZStack {
                    // Inner glowing circle (matching welcome page style)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Theme.profileAccent.opacity(0.4),
                                    Theme.profileAccent.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)

                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 50, weight: .light))
                        .foregroundStyle(.white)
                        .shadow(color: Theme.profileAccent.opacity(0.5), radius: 10)
                }

                // Headline
                VStack(spacing: 12) {
                    Text("Stay on Track")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("Would you like a gentle reminder\nto meditate each day?")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }

                // Social proof
                HStack(spacing: 8) {
                    Image(systemName: "person.3.fill")
                        .foregroundStyle(.white.opacity(0.8))
                    Text("Users with reminders are ")
                        .foregroundStyle(.white.opacity(0.7))
                    + Text("3x more likely ")
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    + Text("to build a lasting habit")
                        .foregroundStyle(.white.opacity(0.7))
                }
                .font(.subheadline)
                .padding()
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)

                // Time picker
                if showTimePicker {
                    VStack(spacing: 16) {
                        Text("When would you like to be reminded?")
                            .font(.headline)
                            .foregroundStyle(.white)

                        DatePicker(
                            "Reminder Time",
                            selection: $selectedTime,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxHeight: 150)
                        .colorScheme(.dark)
                    }
                    .padding()
                    .background(Theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()

                // Buttons
                VStack(spacing: 16) {
                    Button {
                        if showTimePicker {
                            // Save time and request permission
                            Task {
                                let granted = await notificationService.requestAuthorization()
                                if granted {
                                    notificationService.dailyReminderTime = selectedTime
                                    notificationService.enableAllNotifications()
                                }
                                onContinue()
                            }
                        } else {
                            // Show time picker
                            withAnimation(.spring()) {
                                showTimePicker = true
                            }
                        }
                    } label: {
                        HStack {
                            Text(showTimePicker ? "Set Reminder" : "Yes, remind me daily")
                            if !showTimePicker {
                                Image(systemName: "bell.fill")
                            }
                        }
                        .primaryButton()
                    }

                    Button {
                        // Mark that user skipped so we can prompt on 2nd app open
                        appState.markSkippedNotificationsDuringOnboarding()
                        notificationService.disableAllNotifications()
                        onSkip()
                    } label: {
                        Text("Maybe later")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: 500)
        }
        .onAppear {
            // Default to 8 PM
            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            components.hour = 20
            components.minute = 0
            selectedTime = Calendar.current.date(from: components) ?? Date()
        }
    }
}

#Preview {
    NotificationPermissionView(
        onContinue: {},
        onBack: {},
        onSkip: {}
    )
}
