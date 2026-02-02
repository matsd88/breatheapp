//
//  ProgramsListView.swift
//  Meditation Sleep Mindset
//

import SwiftUI
import SwiftData

struct ProgramsListView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Program.name) private var programs: [Program]
    @Query private var progress: [ProgramProgress]
    @State private var selectedProgram: Program?

    private let sheetBackground = Color(red: 0.09, green: 0.17, blue: 0.31)

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // In-progress programs first
                        let inProgress = programs.filter { program in
                            progress.contains { $0.programID == program.id && !$0.isCompleted }
                        }

                        if !inProgress.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Continue")
                                    .font(.headline)
                                    .foregroundStyle(Theme.textPrimary)
                                    .padding(.horizontal)

                                ForEach(inProgress) { program in
                                    ProgramCard(
                                        program: program,
                                        progress: progress.first { $0.programID == program.id }
                                    ) {
                                        selectedProgram = program
                                    }
                                }
                            }
                        }

                        // All programs
                        VStack(alignment: .leading, spacing: 12) {
                            Text("All Programs")
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)
                                .padding(.horizontal)

                            ForEach(programs) { program in
                                ProgramCard(
                                    program: program,
                                    progress: progress.first { $0.programID == program.id }
                                ) {
                                    selectedProgram = program
                                }
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Programs")
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
            .sheet(item: $selectedProgram) { program in
                ProgramDetailView(program: program)
            }
            .onReceive(NotificationCenter.default.publisher(for: .dismissAllSheetsAndPlay)) { _ in
                selectedProgram = nil
                dismiss()
            }
        }
        .presentationDetents([.large])
        .presentationBackground(sheetBackground)
    }
}

// MARK: - Program Card

struct ProgramCard: View {
    let program: Program
    let progress: ProgramProgress?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(program.contentType == .sleepStory
                            ? Color.indigo.opacity(0.3)
                            : Color.cyan.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: program.iconName)
                        .font(.title2)
                        .foregroundStyle(program.contentType == .sleepStory ? .indigo : .cyan)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(program.name)
                            .font(.headline)
                            .foregroundStyle(.white)

                        if program.isPremium {
                            Image(systemName: "crown.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                    }

                    Text("\(program.totalDays) days")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)

                    if let p = progress {
                        ProgressView(value: Double(p.completedDays.count), total: Double(program.totalDays))
                            .tint(.cyan)
                            .scaleEffect(y: 1.5)

                        Text("Day \(min(p.currentDay, program.totalDays)) of \(program.totalDays)")
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding()
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }
}
