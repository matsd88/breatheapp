//
//  SleepPreparationView.swift
//  Meditation Sleep Mindset
//

import SwiftUI

struct SleepPreparationView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentStep = 0
    @State private var selectedMood: Mood?
    @State private var showBreathing = false
    @State private var showSoundMixer = false

    private let totalSteps = 4

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.sleepBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress bar
                    progressBar
                        .padding(.top, 8)
                        .padding(.horizontal, 20)

                    // Step content — using ZStack instead of TabView to prevent swipe-to-skip
                    ZStack {
                        switch currentStep {
                        case 0: moodCheckStep.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        case 1: breathingStep.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        case 2: soundscapeStep.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        case 3: contentStep.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        default: EmptyView()
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if currentStep > 0 {
                        Button {
                            withAnimation { currentStep -= 1 }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }

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
            .sheet(isPresented: $showBreathing) {
                BreathingExerciseView(technique: .relaxing)
            }
            .sheet(isPresented: $showSoundMixer) {
                SoundscapeMixerView()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Theme.sleepPrimary : Color.white.opacity(0.15))
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
    }

    // MARK: - Step 1: Mood Check

    private var moodCheckStep: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "moon.stars.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.sleepPrimary)

            VStack(spacing: 8) {
                Text("How are you feeling?")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text("Let us tailor your bedtime routine")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }

            // Mood grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(Mood.allCases) { mood in
                    Button {
                        HapticManager.selection()
                        selectedMood = mood
                    } label: {
                        VStack(spacing: 6) {
                            Text(moodEmoji(mood))
                                .font(.title)
                            Text(mood.displayName)
                                .font(.caption)
                                .foregroundStyle(selectedMood == mood ? .white : .white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(selectedMood == mood ? Theme.sleepPrimary.opacity(0.3) : Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedMood == mood ? Theme.sleepPrimary.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            nextButton(enabled: selectedMood != nil)
        }
        .padding(.bottom, 24)
    }

    // MARK: - Step 2: Breathing

    private var breathingStep: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.sleepPrimary.opacity(0.15))
                    .frame(width: 140, height: 140)

                Image(systemName: "wind")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.sleepPrimary)
            }

            VStack(spacing: 8) {
                Text("Calm Your Mind")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text("A short breathing exercise to release tension")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Button {
                HapticManager.medium()
                showBreathing = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lungs.fill")
                    Text("Start Breathing Exercise")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.sleepPrimary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.sleepPrimary.opacity(0.5), lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)

            Spacer()

            nextButton(enabled: true, label: "Continue")
        }
        .padding(.bottom, 24)
    }

    // MARK: - Step 3: Soundscape

    private var soundscapeStep: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.15))
                    .frame(width: 140, height: 140)

                Image(systemName: "waveform")
                    .font(.system(size: 56))
                    .foregroundStyle(.cyan)
            }

            VStack(spacing: 8) {
                Text("Set Your Soundscape")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text("Layer ambient sounds to create your perfect sleep environment")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Button {
                HapticManager.medium()
                showSoundMixer = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                    Text("Open Soundscape Mixer")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.cyan.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)

            Spacer()

            nextButton(enabled: true, label: "Continue")
        }
        .padding(.bottom, 24)
    }

    // MARK: - Step 4: Content

    private var contentStep: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.sleepPrimary.opacity(0.2))
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(Theme.sleepPrimary.opacity(0.3))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 8) {
                Text("You're Ready for Sleep")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text("Browse sleep content to complete your bedtime routine")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            // Summary of what they did
            VStack(spacing: 12) {
                if let mood = selectedMood {
                    SleepPrepSummaryRow(icon: "face.smiling", text: "Mood: \(mood.displayName)")
                }
                SleepPrepSummaryRow(icon: "wind", text: "Breathing exercise available")
                SleepPrepSummaryRow(icon: "waveform", text: "Soundscape configured")
            }
            .padding(.horizontal, 20)

            Spacer()

            Button {
                HapticManager.success()
                dismiss()
            } label: {
                Text("Browse Sleep Content")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 24)
    }

    // MARK: - Helpers

    private func nextButton(enabled: Bool, label: String = "Next") -> some View {
        Button {
            if currentStep < totalSteps - 1 {
                HapticManager.selection()
                withAnimation { currentStep += 1 }
            }
        } label: {
            Text(label)
                .font(.headline)
                .foregroundStyle(enabled ? .black : .white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding()
                .background(enabled ? Color.white : Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!enabled)
        .padding(.horizontal, 20)
    }

    private func moodEmoji(_ mood: Mood) -> String {
        switch mood {
        case .calm: return "😌"
        case .happy: return "😊"
        case .anxious: return "😰"
        case .stressed: return "😤"
        case .sad: return "😢"
        case .tired: return "😴"
        case .energetic: return "⚡"
        case .focused: return "🧘"
        case .grateful: return "🙏"
        }
    }
}

// MARK: - Summary Row

struct SleepPrepSummaryRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Theme.sleepPrimary)
                .frame(width: 28)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            Spacer()

            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(.green)
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    SleepPreparationView()
}
