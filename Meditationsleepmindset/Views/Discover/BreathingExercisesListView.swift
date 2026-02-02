//
//  BreathingExercisesListView.swift
//  Meditation Sleep Mindset
//

import SwiftUI

struct BreathingExercisesListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTechnique: BreathingTechnique?
    @State private var selectedCycles: Int = 3

    private let sheetBackground = Color(red: 0.09, green: 0.17, blue: 0.31)

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [.cyan.opacity(0.3), .cyan.opacity(0.05), .clear],
                                            center: .center,
                                            startRadius: 10,
                                            endRadius: 60
                                        )
                                    )
                                    .frame(width: 100, height: 100)

                                Image(systemName: "wind")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.cyan)
                            }

                            Text("Breathing Exercises")
                                .font(.title2.bold())
                                .foregroundStyle(.white)

                            Text("Choose a technique to calm your mind")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.top, 8)

                        // Cycle selector
                        VStack(spacing: 8) {
                            Text("Number of Cycles")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)

                            HStack(spacing: 12) {
                                ForEach([2, 3, 5], id: \.self) { count in
                                    Button {
                                        HapticManager.selection()
                                        selectedCycles = count
                                    } label: {
                                        Text("\(count)")
                                            .font(.headline)
                                            .foregroundStyle(selectedCycles == count ? .white : .white.opacity(0.5))
                                            .frame(width: 52, height: 36)
                                            .background(selectedCycles == count ? .cyan.opacity(0.3) : Color.white.opacity(0.08))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(selectedCycles == count ? .cyan.opacity(0.5) : .clear, lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 4)

                        // Technique cards
                        ForEach(BreathingTechnique.allCases) { technique in
                            BreathingTechniqueCard(
                                technique: technique,
                                onTap: { selectedTechnique = technique }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Breathing")
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
            .fullScreenCover(item: $selectedTechnique) { technique in
                BreathingExerciseView(technique: technique, totalCycles: selectedCycles)
            }
        }
        .presentationDetents([.large])
        .presentationBackground(sheetBackground)
    }
}

// MARK: - Technique Card

private struct BreathingTechniqueCard: View {
    let technique: BreathingTechnique
    let onTap: () -> Void

    private var accentColor: Color {
        switch technique {
        case .boxBreathing: return .cyan
        case .relaxing: return .indigo
        case .wimHof: return .mint
        case .alternateNostril: return .purple
        case .energizing: return .orange
        }
    }

    private var durationText: String {
        let totalSeconds = technique.phases.reduce(0.0) { $0 + $1.duration }
        let perCycle = Int(totalSeconds)
        return "\(perCycle)s/cycle"
    }

    private var difficultyText: String {
        switch technique {
        case .boxBreathing, .relaxing: return "Beginner"
        case .alternateNostril: return "Intermediate"
        case .wimHof, .energizing: return "Advanced"
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 14) {
                    // Icon with colored glow
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.15))
                            .frame(width: 52, height: 52)

                        Image(systemName: technique.icon)
                            .font(.title2)
                            .foregroundStyle(accentColor)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(technique.rawValue)
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text(technique.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))

                        // Tags
                        HStack(spacing: 8) {
                            Label(durationText, systemImage: "clock")
                            Label(difficultyText, systemImage: "chart.bar.fill")
                        }
                        .font(.caption2)
                        .foregroundStyle(accentColor.opacity(0.9))
                        .padding(.top, 2)
                    }

                    Spacer()

                    Image(systemName: "play.circle.fill")
                        .font(.title)
                        .foregroundStyle(accentColor.opacity(0.8))
                        .padding(.top, 4)
                }
                .padding()

                // Description
                Text(technique.description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(2)
                    .padding(.horizontal)
                    .padding(.bottom, 14)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(accentColor.opacity(0.12), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
