//
//  ProgramDetailView.swift
//  Meditation Sleep Mindset
//

import SwiftUI
import SwiftData

struct ProgramDetailView: View {
    let program: Program
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allDays: [ProgramDay]
    @Query private var allProgress: [ProgramProgress]
    @Query private var allContent: [Content]

    private let sheetBackground = Color(red: 0.09, green: 0.17, blue: 0.31)

    private var days: [ProgramDay] {
        allDays
            .filter { $0.programID == program.id }
            .sorted { $0.dayNumber < $1.dayNumber }
    }

    private var progress: ProgramProgress? {
        allProgress.first { $0.programID == program.id }
    }

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
                                    .fill(program.contentType == .sleepStory
                                        ? Color.indigo.opacity(0.3)
                                        : Color.cyan.opacity(0.2))
                                    .frame(width: 80, height: 80)

                                Image(systemName: program.iconName)
                                    .font(.largeTitle)
                                    .foregroundStyle(program.contentType == .sleepStory ? .indigo : .cyan)
                            }

                            Text(program.name)
                                .font(.title2.bold())
                                .foregroundStyle(.white)

                            Text(program.programDescription)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            // Progress
                            if let p = progress {
                                HStack(spacing: 8) {
                                    Text("\(p.completedDays.count)/\(program.totalDays) completed")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)

                                    ProgressView(value: Double(p.completedDays.count), total: Double(program.totalDays))
                                        .tint(.cyan)
                                        .frame(width: 80)
                                }
                            }
                        }
                        .padding(.top, 16)

                        // Days list
                        VStack(spacing: 12) {
                            ForEach(days) { day in
                                let isUnlocked = isDayUnlocked(day.dayNumber)
                                let isCompleted = progress?.completedDays.contains(day.dayNumber) ?? false

                                Button {
                                    if isUnlocked {
                                        startDay(day)
                                    }
                                } label: {
                                    HStack(spacing: 14) {
                                        // Day number / status
                                        ZStack {
                                            Circle()
                                                .fill(isCompleted ? Color.green.opacity(0.2)
                                                    : isUnlocked ? Color.cyan.opacity(0.15)
                                                    : Color.white.opacity(0.06))
                                                .frame(width: 44, height: 44)

                                            if isCompleted {
                                                Image(systemName: "checkmark")
                                                    .font(.body.bold())
                                                    .foregroundStyle(.green)
                                            } else if isUnlocked {
                                                Text("\(day.dayNumber)")
                                                    .font(.headline)
                                                    .foregroundStyle(.cyan)
                                            } else {
                                                Image(systemName: "lock.fill")
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.3))
                                            }
                                        }

                                        // Thumbnail
                                        CachedAsyncImage(
                                            url: URL(string: day.thumbnailURL),
                                            failedIconName: "play.circle",
                                            content: { image in
                                                image.resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .scaleEffect(1.15)
                                            },
                                            placeholder: {
                                                Rectangle().fill(Theme.cardBackground)
                                            }
                                        )
                                        .frame(width: 60, height: 40)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .opacity(isUnlocked ? 1 : 0.4)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(day.title)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(isUnlocked ? .white : .white.opacity(0.4))

                                            Text("Day \(day.dayNumber)")
                                                .font(.caption)
                                                .foregroundStyle(Theme.textSecondary)
                                        }

                                        Spacer()

                                        if isUnlocked && !isCompleted {
                                            Image(systemName: "play.circle.fill")
                                                .font(.title2)
                                                .foregroundStyle(.cyan)
                                        }
                                    }
                                    .padding()
                                    .background(Theme.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                                .disabled(!isUnlocked)
                            }
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 100)
                    }
                }
            }
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
        .presentationDetents([.large])
        .presentationBackground(sheetBackground)
    }

    // MARK: - Logic

    private func isDayUnlocked(_ dayNumber: Int) -> Bool {
        guard let p = progress else { return dayNumber == 1 }
        return dayNumber <= p.currentDay
    }

    private func beginProgram() {
        let newProgress = ProgramProgress(programID: program.id)
        modelContext.insert(newProgress)
        try? modelContext.save()

        // Start day 1
        if let firstDay = days.first {
            startDay(firstDay)
        }
    }

    private func startDay(_ day: ProgramDay) {
        // Ensure progress exists
        if progress == nil {
            let newProgress = ProgramProgress(programID: program.id)
            modelContext.insert(newProgress)
            try? modelContext.save()
        }

        // Find matching content or create temporary content for playback
        if let content = allContent.first(where: { $0.youtubeVideoID == day.youtubeVideoID }) {
            markDayComplete(day.dayNumber)
            playContent(content)
        } else {
            // Content not found in library — create ephemeral content
            let content = Content(
                title: day.title,
                youtubeVideoID: day.youtubeVideoID,
                contentType: program.contentType,
                durationSeconds: 600,
                description: "Part of \(program.name)"
            )
            modelContext.insert(content)
            try? modelContext.save()
            markDayComplete(day.dayNumber)
            playContent(content)
        }
    }

    private func playContent(_ content: Content) {
        let manager = AudioPlayerManager.shared
        manager.queue = [content]
        manager.currentIndex = 0
        manager.currentContent = content

        // Dismiss all sheets first, then trigger player via the observed property
        // which MainTabView watches via .onChange(of: shouldPresentPlayer)
        NotificationCenter.default.post(name: .dismissAllSheetsAndPlay, object: nil)
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            manager.shouldPresentPlayer = true
        }
    }

    private func markDayComplete(_ dayNumber: Int) {
        if let p = allProgress.first(where: { $0.programID == program.id }) {
            p.completeDay(dayNumber)
            if p.completedDays.count >= program.totalDays {
                p.isCompleted = true
            }
            try? modelContext.save()
        }
    }
}
