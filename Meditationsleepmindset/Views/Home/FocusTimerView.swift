//
//  FocusTimerView.swift
//  Meditation Sleep Mindset
//

import SwiftUI
import SwiftData

struct FocusTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var ambientManager = AmbientSoundManager.shared

    @State private var workMinutes: Int = 25
    @State private var breakMinutes: Int = 5
    @State private var isRunning = false
    @State private var isBreak = false
    @State private var timeRemaining: Int = 0
    @State private var sessionsCompleted: Int = 0
    @State private var timer: Timer?
    @State private var sessionStartTime: Date?
    @State private var selectedSound: AmbientSound?
    @State private var showSoundPicker = false

    private let workOptions = [15, 20, 25, 30, 45, 60]
    private let breakOptions = [3, 5, 10, 15]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                if isRunning {
                    runningView
                } else {
                    setupView
                }
            }
            .frame(maxWidth: sizeClass == .regular ? 700 : 600)
            .frame(maxWidth: .infinity)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SheetCloseButton {
                        stopSession()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents(isRunning || sizeClass == .regular ? [.large] : [.fraction(0.75), .large])
        .presentationDragIndicator(.visible)
        .onDisappear {
            stopSession()
        }
    }

    // MARK: - Setup View

    private var setupView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)

                    Text("Focus Timer")
                        .font(.title3.bold())
                        .foregroundStyle(.white)

                    Text("Pomodoro-style deep work sessions")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 8)

                // Work duration
                VStack(spacing: 10) {
                    Text("Work Duration")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: sizeClass == .regular ? 14 : 10) {
                            ForEach(workOptions, id: \.self) { min in
                                Button {
                                    workMinutes = min
                                } label: {
                                    Text("\(min)m")
                                        .font(sizeClass == .regular ? .body.weight(.semibold) : .body.weight(.medium))
                                        .foregroundStyle(workMinutes == min ? .white : Theme.textPrimary)
                                        .frame(width: sizeClass == .regular ? 68 : 52, height: sizeClass == .regular ? 54 : 44)
                                        .background(workMinutes == min ? Color.orange.opacity(0.4) : Theme.cardBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: sizeClass == .regular ? 12 : 10))
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Break duration
                VStack(spacing: 10) {
                    Text("Break Duration")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)

                    HStack(spacing: sizeClass == .regular ? 14 : 10) {
                        ForEach(breakOptions, id: \.self) { min in
                            Button {
                                breakMinutes = min
                            } label: {
                                Text("\(min)m")
                                    .font(sizeClass == .regular ? .body.weight(.semibold) : .body.weight(.medium))
                                    .foregroundStyle(breakMinutes == min ? .white : Theme.textPrimary)
                                    .frame(width: sizeClass == .regular ? 68 : 52, height: sizeClass == .regular ? 54 : 44)
                                    .background(breakMinutes == min ? Color.green.opacity(0.3) : Theme.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: sizeClass == .regular ? 12 : 10))
                            }
                        }
                    }
                }

                // Ambient sound
                Button {
                    showSoundPicker.toggle()
                } label: {
                    HStack {
                        Image(systemName: selectedSound?.iconName ?? "speaker.wave.2")
                            .foregroundStyle(.orange)

                        Text(selectedSound?.name ?? "No Background Sound")
                            .foregroundStyle(.white)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding()
                    .background(Theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)

                if showSoundPicker {
                    VStack(spacing: 8) {
                        // None option
                        Button {
                            selectedSound = nil
                            showSoundPicker = false
                        } label: {
                            HStack {
                                Image(systemName: "speaker.slash")
                                Text("No Sound")
                                Spacer()
                                if selectedSound == nil {
                                    Image(systemName: "checkmark").foregroundStyle(.orange)
                                }
                            }
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Theme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)

                        ForEach(ambientManager.availableSounds) { sound in
                            Button {
                                selectedSound = sound
                                showSoundPicker = false
                            } label: {
                                HStack {
                                    Image(systemName: sound.iconName)
                                    Text(sound.name)
                                    Spacer()
                                    if selectedSound?.id == sound.id {
                                        Image(systemName: "checkmark").foregroundStyle(.orange)
                                    }
                                }
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(Theme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                // Start button
                Button {
                    startWork()
                } label: {
                    Text("Start Focus Session")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)

                Spacer(minLength: 16)
            }
        }
    }

    // MARK: - Running View

    private var runningView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Phase label
            Text(isBreak ? "Break Time" : "Focus")
                .font(.title3.weight(.medium))
                .foregroundStyle(isBreak ? .green : .orange)

            // Timer ring - adaptive for iPad
            let timerSize: CGFloat = sizeClass == .regular ? 350 : 250
            let timerFontSize: CGFloat = sizeClass == .regular ? 64 : 48

            ZStack {
                Circle()
                    .stroke(Theme.cardBackground, lineWidth: sizeClass == .regular ? 12 : 8)
                    .frame(width: timerSize, height: timerSize)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        isBreak ? Color.green : Color.orange,
                        style: StrokeStyle(lineWidth: sizeClass == .regular ? 12 : 8, lineCap: .round)
                    )
                    .frame(width: timerSize, height: timerSize)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                VStack(spacing: 8) {
                    Text(timeFormatted)
                        .font(.system(size: timerFontSize, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    Text("remaining")
                        .font(sizeClass == .regular ? .body : .subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            // Sessions count
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i < sessionsCompleted ? Color.orange : Color.white.opacity(0.15))
                        .frame(width: 10, height: 10)
                }
            }

            Text("\(sessionsCompleted) sessions completed")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)

            Spacer()

            // Controls - adaptive for iPad
            let smallButtonSize: CGFloat = sizeClass == .regular ? 72 : 56
            let largeButtonSize: CGFloat = sizeClass == .regular ? 88 : 72

            HStack(spacing: sizeClass == .regular ? 48 : 32) {
                Button {
                    stopSession()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(sizeClass == .regular ? .title : .title2)
                        .foregroundStyle(.white)
                        .frame(width: smallButtonSize, height: smallButtonSize)
                        .background(Color.red.opacity(0.4))
                        .clipShape(Circle())
                }

                Button {
                    togglePause()
                } label: {
                    Image(systemName: timer != nil ? "pause.fill" : "play.fill")
                        .font(sizeClass == .regular ? .largeTitle : .title)
                        .foregroundStyle(.black)
                        .frame(width: largeButtonSize, height: largeButtonSize)
                        .background(.white)
                        .clipShape(Circle())
                }

                Button {
                    skipPhase()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Logic

    private var totalSeconds: Int {
        (isBreak ? breakMinutes : workMinutes) * 60
    }

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(timeRemaining) / Double(totalSeconds)
    }

    private var timeFormatted: String {
        let min = timeRemaining / 60
        let sec = timeRemaining % 60
        return String(format: "%02d:%02d", min, sec)
    }

    private func startWork() {
        isBreak = false
        timeRemaining = workMinutes * 60
        isRunning = true
        sessionStartTime = Date()

        // Start ambient sound
        if let sound = selectedSound {
            ambientManager.playSound(sound)
        }

        startTimer()
    }

    private func startBreak() {
        isBreak = true
        timeRemaining = breakMinutes * 60
        startTimer()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    timer?.invalidate()
                    timer = nil
                    phaseComplete()
                }
            }
        }
    }

    private func phaseComplete() {
        if !isBreak {
            sessionsCompleted += 1
            saveSession()
            startBreak()
        } else {
            startWork()
        }
    }

    private func skipPhase() {
        timer?.invalidate()
        timer = nil
        if !isBreak {
            sessionsCompleted += 1
            saveSession()
        }
        if isBreak {
            startWork()
        } else {
            startBreak()
        }
    }

    private func togglePause() {
        if timer != nil {
            timer?.invalidate()
            timer = nil
        } else {
            startTimer()
        }
    }

    private func stopSession() {
        timer?.invalidate()
        timer = nil

        // Stop ambient sounds
        if let sound = selectedSound {
            ambientManager.stopSound(sound)
        }

        if isRunning, !isBreak, let start = sessionStartTime {
            let elapsed = Int(Date().timeIntervalSince(start))
            if elapsed > 60 {
                saveSession()
            }
        }

        isRunning = false
    }

    private func saveSession() {
        let duration = workMinutes * 60
        let session = MeditationSession(
            contentTitle: "Focus Session",
            durationSeconds: duration,
            listenedSeconds: duration,
            wasCompleted: true,
            sessionType: "focus",
            completedAt: Date()
        )
        modelContext.insert(session)
        try? modelContext.save()
        StreakService.shared.recordSession(durationMinutes: workMinutes, context: modelContext)

        // Update challenge progress for focus timer
        ChallengeService.shared.recordFocusTimerSession()
    }
}
