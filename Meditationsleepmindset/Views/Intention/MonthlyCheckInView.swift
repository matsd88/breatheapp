//
//  MonthlyCheckInView.swift
//  Meditation Sleep Mindset
//
//  A once-a-month reflection that resets the user's focus and sets a theme for the
//  month ahead (inspired by monthly check-in / intention-reset rituals).
//

import SwiftUI

/// Helper for deciding when the monthly check-in is due.
enum MonthlyCheckIn {
    static var isDue: Bool {
        let last = UserDefaults.standard.double(forKey: Constants.UserDefaultsKeys.monthlyCheckInDate)
        guard last > 0 else { return true }
        let lastDate = Date(timeIntervalSince1970: last)
        return !Calendar.current.isDate(lastDate, equalTo: Date(), toGranularity: .month)
    }

    static var currentTheme: String {
        UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.monthlyTheme) ?? ""
    }

    static var monthName: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f.string(from: Date())
    }
}

struct MonthlyCheckInView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var reflection: String = ""
    @State private var theme: String = ""

    private let themeSuggestions = ["Calm", "Consistency", "Self-compassion", "Better sleep", "Focus", "Gratitude", "Letting go", "Presence"]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Theme.profileAccent.opacity(0.2))
                                    .frame(width: 72, height: 72)
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 30))
                                    .foregroundStyle(Theme.profileAccent)
                            }
                            Text("\(MonthlyCheckIn.monthName) check-in")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                            Text("A fresh month. Reflect on the last one and choose what matters now.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                        // Reflection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Looking back, how did last month feel?")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            TextField("A few words on how it went...", text: $reflection, axis: .vertical)
                                .lineLimit(3...6)
                                .padding()
                                .background(Theme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                        }

                        // Theme
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your theme for this month")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            TextField("One word or phrase", text: $theme)
                                .padding()
                                .background(Theme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(themeSuggestions, id: \.self) { suggestion in
                                        Button {
                                            HapticManager.light()
                                            theme = suggestion
                                        } label: {
                                            Text(suggestion)
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

                        Button {
                            save()
                        } label: {
                            Text("Set my month")
                                .font(.headline)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(theme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(theme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)

                        Spacer(minLength: 40)
                    }
                    .padding()
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Monthly Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Later") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .onAppear {
                reflection = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.monthlyReflection) ?? ""
                theme = MonthlyCheckIn.currentTheme
            }
        }
    }

    private func save() {
        let trimmedTheme = theme.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTheme.isEmpty else { return }
        let defaults = UserDefaults.standard
        defaults.set(trimmedTheme, forKey: Constants.UserDefaultsKeys.monthlyTheme)
        defaults.set(reflection.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Constants.UserDefaultsKeys.monthlyReflection)
        defaults.set(Date().timeIntervalSince1970, forKey: Constants.UserDefaultsKeys.monthlyCheckInDate)
        HapticManager.success()
        ToastManager.shared.show("Theme set: \(trimmedTheme)", icon: "calendar.badge.checkmark", style: .success)
        dismiss()
    }
}

#Preview {
    MonthlyCheckInView()
}
