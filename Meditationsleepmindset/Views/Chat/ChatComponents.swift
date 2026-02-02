//
//  ChatComponents.swift
//  Meditation Sleep Mindset
//

import SwiftUI

// MARK: - Mood Picker View

struct ChatMoodPickerView: View {
    var onMoodSelected: (MoodLevel?) -> Void
    var hasMiniPlayer: Bool = false
    @State private var selectedMood: MoodLevel?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 60))
                .foregroundStyle(Theme.profileAccent)

            VStack(spacing: 8) {
                Text("How are you feeling?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.textPrimary)

                Text("This helps me personalize our conversation")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                ForEach(MoodLevel.allCases) { mood in
                    MoodLevelButton(
                        mood: mood,
                        isSelected: selectedMood == mood
                    ) {
                        HapticManager.selection()
                        withAnimation(.spring(response: 0.3)) {
                            selectedMood = mood
                        }
                    }
                }
            }
            .padding(.horizontal)

            Spacer()

            Button {
                HapticManager.medium()
                onMoodSelected(selectedMood)
            } label: {
                Text(selectedMood != nil ? "Start Chat" : "Select a mood")
                    .font(.headline)
                    .foregroundStyle(selectedMood != nil ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedMood != nil ? Color.white : Color.white.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
            }
            .disabled(selectedMood == nil)
            .padding(.horizontal)

            Button("Skip for now") {
                onMoodSelected(nil)
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.bottom, hasMiniPlayer ? 170 : 100) // Space for tab bar + mini player
        }
    }
}

// MARK: - Mood Level Button

struct MoodLevelButton: View {
    let mood: MoodLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? mood.color.opacity(0.3) : Theme.cardBackground)
                        .frame(width: 56, height: 56)

                    Text(mood.emoji)
                        .font(.system(size: 28))
                }
                .overlay {
                    if isSelected {
                        Circle()
                            .stroke(mood.color, lineWidth: 3)
                            .frame(width: 56, height: 56)
                    }
                }

                Text(mood.rawValue)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage
    @State private var showCopied = false

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(isUser ? .white : Theme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        isUser
                            ? Theme.profileAccent
                            : Theme.cardBackground
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message.content
                            HapticManager.light()
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Chat Input Bar

struct ChatInputBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let remainingMessages: Int? // nil = unlimited (premium)
    let isLoading: Bool
    let onSend: () -> Void

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    var body: some View {
        VStack(spacing: 6) {
            if let remaining = remainingMessages, remaining < Int.max {
                Text("\(remaining) messages remaining")
                    .font(.caption2)
                    .foregroundStyle(remaining <= 3 ? .orange : Theme.textTertiary)
            }

            HStack(spacing: 10) {
                TextField("", text: $text, prompt: Text("Type a message...").foregroundStyle(.white.opacity(0.9)), axis: .vertical)
                    .focused(isFocused)
                    .lineLimit(1...4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .foregroundStyle(Theme.textPrimary)
                    .tint(.white)

                Button {
                    HapticManager.light()
                    onSend()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(canSend ? .white : Theme.textTertiary)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial.opacity(0.8))
            )
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Theme.textSecondary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animating ? 1.0 : 0.5)
                        .opacity(animating ? 1.0 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer()
        }
        .onAppear { animating = true }
    }
}

// MARK: - Suggested Content Card

struct SuggestedContentCard: View {
    let title: String
    let onTap: () -> Void

    var body: some View {
        HStack {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.profileAccent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Suggested Meditation")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding()
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 40)
        }
    }
}

// MARK: - Therapist Referral Card

struct TherapistReferralCard: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(.green)
                    Text("Professional Support")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.textPrimary)
                }

                Text("Connect with a licensed therapist who can provide personalized guidance.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)

                Button {
                    if let url = URL(string: Constants.Chat.therapistReferralURL) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Learn More")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.green)
                        .clipShape(Capsule())
                }
            }
            .padding()
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))

            Spacer(minLength: 40)
        }
    }
}

// MARK: - Crisis Resource View

struct CrisisResourceView: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    Text("Crisis Resources")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    CrisisButton(
                        label: "Call 988 Suicide & Crisis Lifeline",
                        action: { openURL("tel://\(Constants.CrisisResources.suicidePreventionHotline)") }
                    )
                    CrisisButton(
                        label: "Text HOME to \(Constants.CrisisResources.crisisTextLine)",
                        action: { openURL("sms:\(Constants.CrisisResources.crisisTextLine)&body=HELLO") }
                    )
                    CrisisButton(
                        label: "Call \(Constants.CrisisResources.emergencyNumber) for Emergencies",
                        action: { openURL("tel://\(Constants.CrisisResources.emergencyNumber)") }
                    )
                }
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))

            Spacer(minLength: 20)
        }
    }

    private func openURL(_ string: String) {
        if let url = URL(string: string) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Crisis Button

struct CrisisButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Theme.textPrimary)
                .underline()
        }
    }
}

// MARK: - Chat Paywall Prompt

struct ChatPaywallPrompt: View {
    let onUpgrade: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.title)
                .foregroundStyle(Theme.profileAccent)

            Text("You've reached your free message limit")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Theme.textPrimary)

            Text("Upgrade to Premium for unlimited conversations")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)

            Button(action: onUpgrade) {
                Text("Upgrade to Premium")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Theme.profileAccent)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
