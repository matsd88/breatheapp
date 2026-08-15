//
//  SleepAssessmentView.swift
//  Meditation Sleep Mindset
//
//  A short, reassuring sleep quiz (Flo/RISE-style) that assigns a sleep persona and
//  shows a projected improvement. Result is stored so the rest of the app can use it.
//

import SwiftUI

enum SleepPersona: String, CaseIterable, Codable {
    case nightOwl, earlyBird, restlessSleeper, lightSleeper, balanced

    var title: String {
        switch self {
        case .nightOwl: return String(localized: "The Night Owl")
        case .earlyBird: return String(localized: "The Early Bird")
        case .restlessSleeper: return String(localized: "The Restless Sleeper")
        case .lightSleeper: return String(localized: "The Light Sleeper")
        case .balanced: return String(localized: "The Balanced Sleeper")
        }
    }

    var emoji: String {
        switch self {
        case .nightOwl: return "🦉"
        case .earlyBird: return "🐦"
        case .restlessSleeper: return "🌊"
        case .lightSleeper: return "🌙"
        case .balanced: return "⚖️"
        }
    }

    var description: String {
        switch self {
        case .nightOwl: return "Your body clock runs late. We'll help you wind down earlier with evening sessions and a gentle melatonin-window nudge."
        case .earlyBird: return "You rise early and fade in the evening. Morning intention and a protected wind-down will keep your rhythm strong."
        case .restlessSleeper: return "You take a while to drift off. Breathing exercises and sleep stories are your fastest path to calm."
        case .lightSleeper: return "You wake easily in the night. Soundscapes and binaural beats can mask disruptions and deepen rest."
        case .balanced: return "You have a steady foundation. A consistent nightly ritual will take your sleep from good to great."
        }
    }

    var recommendation: String {
        switch self {
        case .nightOwl: return "Try tonight: a 10-minute wind-down 30 min before your target bedtime."
        case .earlyBird: return "Try tonight: a calming sleep story to protect your early bedtime."
        case .restlessSleeper: return "Try tonight: 4-7-8 breathing, then a sleep story."
        case .lightSleeper: return "Try tonight: a looping soundscape or Deep Sleep binaural beats."
        case .balanced: return "Try tonight: set a daily intention and a consistent bedtime reminder."
        }
    }
}

struct SleepAssessmentView: View {
    /// When set (onboarding use), the close button and "Start my plan" advance the flow
    /// instead of dismissing a sheet. nil = standalone sheet (default).
    var onComplete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @AppStorage("sleepPersona") private var storedPersona: String = ""

    private func finish() {
        if let onComplete { onComplete() } else { dismiss() }
    }

    @State private var step = 0
    @State private var answers: [Int] = Array(repeating: -1, count: 5)
    @State private var result: SleepPersona?

    private struct Question {
        let prompt: String
        let reassurance: String
        let options: [String]
    }

    private let questions: [Question] = [
        Question(prompt: "When do you naturally feel most awake?",
                 reassurance: "There's no wrong answer — everyone's body clock is different.",
                 options: ["Early morning", "Late evening", "It varies"]),
        Question(prompt: "How long does it usually take you to fall asleep?",
                 reassurance: "Lots of people take a while — it's more common than you'd think.",
                 options: ["Under 15 min", "15–45 min", "Over 45 min"]),
        Question(prompt: "Do you wake up during the night?",
                 reassurance: "Night wakings are normal, and there's a lot we can do to ease them.",
                 options: ["Rarely", "Sometimes", "Often"]),
        Question(prompt: "What would help you most right now?",
                 reassurance: "We'll tailor your plan around this.",
                 options: ["Fall asleep faster", "Wake up less", "More daytime energy"]),
        Question(prompt: "How consistent is your bedtime?",
                 reassurance: "Consistency is a skill — we'll help you build it gently.",
                 options: ["Very consistent", "Somewhat", "All over the place"])
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Steps 2–6 of onboarding show a progress bar; this screen
                    // didn't, so the indicator vanished right before the paywall
                    // — exactly where people most need to see the end in sight.
                    // Only shown in the onboarding context, not the standalone sheet.
                    if onComplete != nil {
                        OnboardingProgressDotsView(step: .sleepAssessment)
                            .padding(.top, 8)
                    }

                    if let result {
                        resultView(result)
                    } else {
                        questionView
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        finish()
                    } label: {
                        Image(systemName: onComplete == nil ? "xmark" : "chevron.right")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(onComplete == nil ? "Close" : "Skip")
                }
            }
        }
    }

    private var questionView: some View {
        let q = questions[step]
        return VStack(spacing: 24) {
            // Progress
            ProgressView(value: Double(step + 1), total: Double(questions.count))
                .tint(Theme.profileAccent)
                .padding(.horizontal)
                .padding(.top, 8)

            Spacer()

            VStack(spacing: 12) {
                Text("Question \(step + 1) of \(questions.count)")
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.profileAccent)
                Text(q.prompt)
                    .font(.title2.weight(.bold)).foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(q.reassurance)
                    .font(.subheadline).foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 12) {
                ForEach(Array(q.options.enumerated()), id: \.offset) { idx, option in
                    Button {
                        HapticManager.selection()
                        answers[step] = idx
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if step < questions.count - 1 {
                                step += 1
                            } else {
                                result = computePersona()
                                storedPersona = result?.rawValue ?? ""
                                HapticManager.success()
                            }
                        }
                    } label: {
                        Text(option)
                            .font(.body.weight(.medium)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Theme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
    }

    private func resultView(_ persona: SleepPersona) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(persona.emoji).font(.system(size: 64))
                Text("You're \(persona.title)")
                    .font(.title.weight(.bold)).foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(persona.description)
                    .font(.body).foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Projection card
                VStack(alignment: .leading, spacing: 8) {
                    Label("Your 2-week outlook", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.profileAccent)
                    Text("With a consistent nightly ritual, most people in your group fall asleep faster and wake less within about two weeks.")
                        .font(.caption).foregroundStyle(.white.opacity(0.7))
                    ProjectionBar()
                        .frame(height: 60)
                        .padding(.top, 4)
                }
                .padding()
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 6) {
                    Label("Start here", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Text(persona.recommendation)
                        .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Theme.profileAccent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Button {
                    HapticManager.light()
                    finish()
                } label: {
                    Text("Start my plan")
                        .font(.headline).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(.white).clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Spacer(minLength: 30)
            }
            .padding()
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
    }

    private func computePersona() -> SleepPersona {
        // answers: 0=chronotype, 1=latency, 2=wakings, 3=goal, 4=consistency
        if answers[2] == 2 { return .lightSleeper }        // wakes often
        if answers[1] == 2 { return .restlessSleeper }     // long to fall asleep
        if answers[0] == 1 { return .nightOwl }            // evening type
        if answers[0] == 0 && answers[4] == 0 { return .earlyBird }
        return .balanced
    }
}

/// Simple two-bar before/after projection visual.
private struct ProjectionBar: View {
    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 24) {
                bar(label: "Now", fraction: 0.4, color: .white.opacity(0.3), height: geo.size.height)
                bar(label: "2 weeks", fraction: 0.85, color: Theme.profileAccent, height: geo.size.height)
                Spacer()
            }
        }
    }

    private func bar(label: String, fraction: CGFloat, color: Color, height: CGFloat) -> some View {
        VStack(spacing: 4) {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 44, height: max(8, (height - 20) * fraction))
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.6))
        }
    }
}

#Preview {
    SleepAssessmentView()
}
