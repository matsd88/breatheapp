//
//  SleepToolsSection.swift
//  Meditation Sleep Mindset
//
//  Sleep-tab section surfacing the new sleep tools: Sleep Recorder (snore detection),
//  Binaural Beats, and a Sleep Insights detail (score, rhythm, heart-rate dip).
//  Self-contained — manages its own sheets so it drops into SleepView with one line.
//

import SwiftUI
import SwiftData

struct SleepToolsSection: View {
    @State private var activeTool: SleepTool?

    enum SleepTool: String, Identifiable {
        case recorder, binaural, insights, energy, assessment
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sleep Lab")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    SleepToolCard(icon: "waveform.badge.mic", title: "Sleep Recorder", subtitle: "Detect snoring", tint: .pink) {
                        HapticManager.light(); activeTool = .recorder
                    }
                    SleepToolCard(icon: "headphones", title: "Binaural Beats", subtitle: "Drift off faster", tint: .purple) {
                        HapticManager.light(); activeTool = .binaural
                    }
                    SleepToolCard(icon: "chart.bar.fill", title: "Sleep Insights", subtitle: "Score & rhythm", tint: .cyan) {
                        HapticManager.light(); activeTool = .insights
                    }
                    SleepToolCard(icon: "bolt.heart.fill", title: "Energy Forecast", subtitle: "Your daily rhythm", tint: .orange) {
                        HapticManager.light(); activeTool = .energy
                    }
                    SleepToolCard(icon: "list.bullet.clipboard.fill", title: "Sleep Assessment", subtitle: "Find your persona", tint: .indigo) {
                        HapticManager.light(); activeTool = .assessment
                    }
                }
                .padding(.horizontal)
            }
        }
        .sheet(item: $activeTool) { tool in
            switch tool {
            case .recorder: SleepRecordingView()
            case .binaural: BinauralBeatsView()
            case .insights: SleepInsightsDetailView()
            case .energy: EnergyScheduleView()
            case .assessment: SleepAssessmentView()
            }
        }
    }
}

private struct SleepToolCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon).font(.title2).foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
                    Text(subtitle).font(.caption2).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                }
            }
            .frame(width: 140, alignment: .leading)
            .padding(14)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sleep Recorder

struct SleepRecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var recorder = SleepRecordingService.shared
    @Query(sort: \SleepRecordingSession.startedAt, order: .reverse) private var sessions: [SleepRecordingSession]
    @State private var lastResult: SleepRecordingSession?

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        if recorder.isRecording {
                            recordingView
                        } else {
                            idleView
                        }

                        if !sessions.isEmpty {
                            historySection
                        }

                        Spacer(minLength: 40)
                    }
                    .padding()
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Sleep Recorder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        if recorder.isRecording { recorder.stop(context: modelContext) }
                        dismiss()
                    }.foregroundStyle(.white)
                }
            }
            .alert("Microphone needed", isPresented: $recorder.permissionDenied) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Allow microphone access in Settings to record and analyze your sleep sounds.")
            }
        }
    }

    private var idleView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Theme.profileAccent.opacity(0.2)).frame(width: 96, height: 96)
                Image(systemName: "waveform.badge.mic").font(.system(size: 40)).foregroundStyle(Theme.profileAccent)
            }
            Text("Record your night")
                .font(.title2.weight(.bold)).foregroundStyle(.white)
            Text("Keep your phone nearby on a charger. We listen for snoring and loud moments — and never save the audio, only the summary.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)

            if let r = lastResult {
                resultCard(r)
            }

            Button {
                Task { await recorder.start() }
            } label: {
                Label("Start Recording", systemImage: "record.circle")
                    .font(.headline).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(.white).clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.top, 12)
    }

    private var recordingView: some View {
        VStack(spacing: 24) {
            Text(recorder.elapsedFormatted)
                .font(.system(size: 52, weight: .light, design: .rounded))
                .monospacedDigit().foregroundStyle(.white)
            Text("Listening…").font(.subheadline).foregroundStyle(.white.opacity(0.6))

            // Live level meter
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12)).frame(height: 10)
                    Capsule().fill(Theme.profileAccent)
                        .frame(width: max(6, geo.size.width * recorder.currentLevel), height: 10)
                        .animation(.easeOut(duration: 0.3), value: recorder.currentLevel)
                }
            }
            .frame(height: 10)
            .padding(.horizontal, 8)

            HStack(spacing: 8) {
                Image(systemName: "waveform").foregroundStyle(.pink)
                Text("\(recorder.eventCount) loud events detected")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.8))
            }

            Button {
                lastResult = recorder.stop(context: modelContext)
            } label: {
                Label("Stop & Analyze", systemImage: "stop.circle.fill")
                    .font(.headline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.red.opacity(0.85)).clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.top, 12)
    }

    private func resultCard(_ r: SleepRecordingSession) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: r.severity.icon).foregroundStyle(r.severity.color)
                Text("Last night: \(r.severity.displayName) snoring")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            }
            Text("\(r.eventCount) events · \(r.durationFormatted)")
                .font(.caption).foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(r.severity.color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Past nights").font(.headline).foregroundStyle(.white)
            ForEach(sessions) { s in
                HStack(spacing: 12) {
                    Image(systemName: s.severity.icon).foregroundStyle(s.severity.color).frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.nightLabel).font(.subheadline.weight(.medium)).foregroundStyle(.white)
                        Text("\(s.severity.displayName) · \(s.eventCount) events · \(s.durationFormatted)")
                            .font(.caption).foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                }
                .padding()
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Binaural Beats

struct BinauralBeatsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var generator = BinauralToneGenerator.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Image(systemName: "headphones").font(.system(size: 40)).foregroundStyle(Theme.profileAccent)
                            Text("Binaural Beats").font(.title2.weight(.bold)).foregroundStyle(.white)
                            Text("Use headphones for the full effect. Pick a frequency to guide your mind toward rest.")
                                .font(.subheadline).foregroundStyle(.white.opacity(0.65))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 12)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(BinauralPreset.allCases) { preset in
                                let isOn = generator.isPlaying && generator.currentPreset == preset
                                Button {
                                    HapticManager.selection()
                                    if isOn { generator.stop() } else { generator.play(preset) }
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: isOn ? "pause.circle.fill" : preset.icon)
                                            .font(.title)
                                            .foregroundStyle(isOn ? .white : Theme.profileAccent)
                                        Text(preset.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                        Text(preset.subtitle).font(.caption2).foregroundStyle(.white.opacity(0.6))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .background(isOn ? Theme.profileAccent.opacity(0.35) : Theme.cardBackground)
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(isOn ? Theme.profileAccent : .clear, lineWidth: 1.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if generator.isPlaying {
                            Button { generator.stop() } label: {
                                Label("Stop", systemImage: "stop.fill")
                                    .font(.headline).foregroundStyle(.white)
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(Color.white.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding()
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Binaural Beats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(.white)
                }
            }
            // Keep playing if dismissed; stop only via the controls.
        }
    }
}

// MARK: - Sleep Insights Detail

struct SleepInsightsDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MeditationSession.startedAt, order: .reverse) private var sessions: [MeditationSession]
    @StateObject private var health = HealthKitService.shared
    private let analytics = SleepAnalyticsService.shared

    var body: some View {
        let score = analytics.calculateSleepScore(from: sessions)
        let trend = analytics.sleepScoreTrend(from: sessions)
        let rhythm = analytics.calculateSleepRhythm(from: sessions)

        return NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        // Sleep Score hero
                        VStack(spacing: 8) {
                            Text("\(score.overall)")
                                .font(.system(size: 64, weight: .bold, design: .rounded))
                                .foregroundStyle(score.color)
                            Text("Sleep Score · \(score.label)")
                                .font(.headline).foregroundStyle(.white)
                            if trend.delta != 0 {
                                Label("\(trend.delta > 0 ? "+" : "")\(trend.delta) vs your previous month",
                                      systemImage: trend.delta > 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.caption).foregroundStyle(trend.delta > 0 ? .green : .orange)
                            }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 24)
                        .background(Theme.cardBackground).clipShape(RoundedRectangle(cornerRadius: 20))

                        insightRow(icon: "metronome", tint: .cyan, title: "Sleep Rhythm",
                                   value: rhythm.label, detail: rhythm.description)

                        if let dip = health.heartRateDip {
                            insightRow(icon: "heart.fill", tint: .pink, title: "Heart-Rate Dip",
                                       value: String(format: "%.0f%%", dip),
                                       detail: "Your heart slowed \(String(format: "%.0f%%", dip)) during sleep vs. your day. A bigger dip often means deeper recovery.")
                        } else {
                            insightRow(icon: "heart", tint: .pink.opacity(0.6), title: "Heart-Rate Dip",
                                       value: "—", detail: "Wear your Apple Watch to bed and enable Health to see how much your heart slows overnight.")
                        }

                        scoreBreakdown(score)

                        Spacer(minLength: 40)
                    }
                    .padding()
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Sleep Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(.white)
                }
            }
            .task { await health.loadHeartRateDip() }
        }
    }

    private func insightRow(icon: String, tint: Color, title: String, value: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title3).foregroundStyle(tint).frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Spacer()
                    Text(value).font(.subheadline.weight(.bold)).foregroundStyle(tint)
                }
                Text(detail).font(.caption).foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func scoreBreakdown(_ score: SleepAnalyticsService.SleepScore) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What's behind your score").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            breakdownBar("Consistency", score.consistencyScore)
            breakdownBar("Completion", score.completionScore)
            breakdownBar("Variety", score.varietyScore)
            breakdownBar("Streak", score.streakScore)
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func breakdownBar(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption).foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text("\(value)").font(.caption.weight(.semibold)).foregroundStyle(.white)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12)).frame(height: 6)
                    Capsule().fill(Theme.profileAccent).frame(width: geo.size.width * CGFloat(value) / 100.0, height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}
