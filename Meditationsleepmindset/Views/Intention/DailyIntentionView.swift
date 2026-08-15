//
//  DailyIntentionView.swift
//  Meditation Sleep Mindset
//
//  A morning ritual: set today's intention and a focus area. The chosen focus
//  is persisted so the rest of the app (Home, recommendations, AI) can align to it.
//

import SwiftUI
import SwiftData

struct DailyIntentionView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \DailyIntentionRecord.createdAt, order: .reverse) private var records: [DailyIntentionRecord]

    @AppStorage(Constants.UserDefaultsKeys.dailyIntentionText) private var savedIntention: String = ""
    @AppStorage(Constants.UserDefaultsKeys.dailyIntentionDate) private var savedIntentionDate: Double = 0
    @AppStorage(Constants.UserDefaultsKeys.dailyIntentionFocus) private var savedIntentionFocus: String = ""

    @State private var intentionText: String = ""
    @State private var selectedFocus: AIMeditationFocus = .stress
    @State private var didSaveThisVisit = false
    @State private var showMonthlyCheckIn = false
    @State private var monthlyCheckInDue = MonthlyCheckIn.isDue

    /// Suggested intention starters the user can tap to fill the field.
    private let starters: [String] = [
        String(localized: "Today, I choose calm over chaos."),
        String(localized: "I will be present in each moment."),
        String(localized: "I am patient with myself today."),
        String(localized: "I will move through today with ease."),
        String(localized: "I choose to focus on what matters.")
    ]

    private var hasTodayIntention: Bool {
        guard savedIntentionDate > 0 else { return false }
        return Calendar.current.isDateInToday(Date(timeIntervalSince1970: savedIntentionDate)) && !savedIntention.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header

                        if monthlyCheckInDue {
                            monthlyCheckInBanner
                        } else if !MonthlyCheckIn.currentTheme.isEmpty {
                            monthlyThemeChip
                        }

                        if hasTodayIntention && !didSaveThisVisit {
                            todayIntentionCard
                        }

                        // Intention editor
                        VStack(alignment: .leading, spacing: 12) {
                            Text(hasTodayIntention ? "Update your intention" : "Set your intention")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)

                            TextField("What do you want today to feel like?", text: $intentionText, axis: .vertical)
                                .lineLimit(2...4)
                                .padding()
                                .background(Theme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)

                            // Starters
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(starters, id: \.self) { starter in
                                        Button {
                                            HapticManager.light()
                                            intentionText = starter
                                        } label: {
                                            Text(starter)
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.8))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(Theme.cardBackground)
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        // Focus area
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Today's focus")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(AIMeditationFocus.allCases) { focus in
                                    SelectableCard(icon: focus.icon, title: focus.displayName, isSelected: selectedFocus == focus) {
                                        HapticManager.selection()
                                        selectedFocus = focus
                                    }
                                }
                            }
                        }

                        // Save
                        Button {
                            saveIntention()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "sun.max.fill")
                                Text("Set my intention")
                            }
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(intentionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(intentionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)

                        Spacer(minLength: 40)
                    }
                    .padding()
                    .frame(maxWidth: sizeClass == .regular ? 720 : 600)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Daily Intention")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .onAppear {
                if hasTodayIntention {
                    intentionText = savedIntention
                    if let focus = AIMeditationFocus(rawValue: savedIntentionFocus) {
                        selectedFocus = focus
                    }
                }
            }
            .sheet(isPresented: $showMonthlyCheckIn, onDismiss: {
                monthlyCheckInDue = MonthlyCheckIn.isDue
            }) {
                MonthlyCheckInView()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Theme.profileAccent.opacity(0.2))
                    .frame(width: 72, height: 72)
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Theme.profileAccent)
            }
            Text("Begin with intention")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Text("A clear intention shapes the whole day. Set yours in a sentence.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var monthlyCheckInBanner: some View {
        Button {
            HapticManager.light()
            showMonthlyCheckIn = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title3)
                    .foregroundStyle(Theme.profileAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("New month — time to check in")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Reflect and set your theme for \(MonthlyCheckIn.monthName)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding()
            .background(Theme.profileAccent.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var monthlyThemeChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkle")
                .font(.caption)
                .foregroundStyle(Theme.profileAccent)
            Text("This month: \(MonthlyCheckIn.currentTheme)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            Button("Update") {
                HapticManager.light()
                showMonthlyCheckIn = true
            }
            .font(.caption2)
            .foregroundStyle(Theme.profileAccent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }

    private var todayIntentionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TODAY'S INTENTION")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.profileAccent)
            Text(savedIntention)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.profileAccent.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func saveIntention() {
        let trimmed = intentionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        savedIntention = trimmed
        savedIntentionDate = Date().timeIntervalSince1970
        savedIntentionFocus = selectedFocus.rawValue

        let record = DailyIntentionRecord(text: trimmed, focusRaw: selectedFocus.rawValue)
        modelContext.insert(record)
        try? modelContext.save()

        didSaveThisVisit = true
        HapticManager.success()
        ToastManager.shared.show("Intention set for today", icon: "sun.max.fill", style: .success)
        dismiss()
    }
}

#Preview {
    DailyIntentionView()
        .modelContainer(for: [DailyIntentionRecord.self], inMemory: true)
}
