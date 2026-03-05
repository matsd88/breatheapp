//
//  MorningCheckInView.swift
//  Meditation Sleep Mindset
//

import SwiftUI

struct MorningCheckInView: View {
    let lastSleepContent: String?
    let onRate: (Int) -> Void
    let onDismiss: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selectedRating: Int?
    @State private var appeared = false
    @State private var dismissTask: Task<Void, Never>?

    private let sleepRatings = [
        (emoji: "😴", label: "Terrible"),
        (emoji: "😕", label: "Poor"),
        (emoji: "😐", label: "Okay"),
        (emoji: "😊", label: "Good"),
        (emoji: "🌟", label: "Amazing")
    ]

    var body: some View {
        VStack(spacing: 20) {
            // Handle
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 12)

            // Moon icon
            Image(systemName: "sun.and.horizon.fill")
                .font(.system(size: 36))
                .foregroundStyle(.orange.opacity(0.8))
                .padding(.top, 8)

            // Title
            VStack(spacing: 6) {
                Text("Good Morning")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                if let content = lastSleepContent {
                    Text("You fell asleep to \"\(content)\"")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 20)
                } else {
                    Text("How did you sleep last night?")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            // Rating buttons
            HStack(spacing: 16) {
                ForEach(0..<5, id: \.self) { index in
                    let rating = sleepRatings[index]
                    let isSelected = selectedRating == index

                    Button {
                        HapticManager.selection()
                        withAnimation(.spring(response: 0.3)) {
                            selectedRating = index
                        }
                        // Delay dismiss to show selection
                        dismissTask?.cancel()
                        dismissTask = Task {
                            try? await Task.sleep(nanoseconds: 600_000_000)
                            guard !Task.isCancelled else { return }
                            onRate(index + 1) // 1-5 rating
                            onDismiss()
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text(rating.emoji)
                                .font(.system(size: isSelected ? 36 : 28))

                            Text(rating.label)
                                .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                                .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ? Color.white.opacity(0.15) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.05), value: appeared)
                }
            }
            .padding(.horizontal, 16)

            // Skip button
            Button {
                onDismiss()
            } label: {
                Text("Skip")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: sizeClass == .regular ? 700 : 500)
        .background(Color.black.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .onAppear {
            withAnimation {
                appeared = true
            }
        }
        .onDisappear {
            dismissTask?.cancel()
        }
    }
}

// MARK: - Morning Check-In Manager

@MainActor
class MorningCheckInManager: ObservableObject {
    static let shared = MorningCheckInManager()

    @Published var shouldShowCheckIn = false
    @Published var lastSleepContentTitle: String?

    @AppStorage("lastMorningCheckInDate") private var lastCheckInDateString: String = ""
    @AppStorage("lastSleepRating") private var lastSleepRating: Int = 0

    private init() {}

    /// Call on app open to determine if we should show the morning check-in
    func checkForMorningPrompt(sessions: [MeditationSession]) {
        let hour = Calendar.current.component(.hour, from: Date())
        // Only show between 5 AM and 11 AM
        guard (5...11).contains(hour) else { return }

        // Only show once per day
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        guard today != lastCheckInDateString else { return }

        // Check if user listened to sleep content last night (after 8 PM yesterday or before 2 AM today)
        let calendar = Calendar.current
        let now = Date()
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
              let yesterdayEvening = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: yesterday),
              let thisEarlyMorning = calendar.date(bySettingHour: 2, minute: 0, second: 0, of: now) else {
            return
        }

        let sleepSession = sessions.first { session in
            let date = session.startedAt
            let isNightTime = date >= yesterdayEvening || (date >= calendar.startOfDay(for: now) && date <= thisEarlyMorning)
            let isSleepContent = session.sessionType == "sleepStory" ||
                                 session.sessionType == "asmr" ||
                                 session.sessionType == "soundscape"
            return isNightTime && isSleepContent
        }

        if sleepSession != nil {
            lastSleepContentTitle = sleepSession?.contentTitle
            shouldShowCheckIn = true
        }
    }

    func recordRating(_ rating: Int) {
        lastSleepRating = rating
        dismissCheckIn()
    }

    func dismissCheckIn() {
        shouldShowCheckIn = false
        lastCheckInDateString = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
    }
}
