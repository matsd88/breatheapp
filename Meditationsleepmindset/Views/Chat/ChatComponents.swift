//
//  ChatComponents.swift
//  Meditation Sleep Mindset
//

import SwiftUI

// MARK: - Mood Picker View (kept for compatibility but welcome experience in ChatView is primary)

struct ChatMoodPickerView: View {
    var onMoodSelected: (MoodLevel?) -> Void
    var hasMiniPlayer: Bool = false
    @State private var selectedMood: MoodLevel?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "sparkles")
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
            .padding(.bottom, hasMiniPlayer ? 170 : 100)
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

                Text(mood.displayName)
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
    @State private var appeared = false

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 50) }

            // AI avatar for assistant messages
            if !isUser {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.profileAccent.opacity(0.8), Color(red: 0.4, green: 0.3, blue: 0.9).opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)

                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 3) {
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(isUser ? .white : Theme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isUser
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [Theme.profileAccent, Color(red: 0.5, green: 0.35, blue: 0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(Color.white.opacity(0.1))
                    )
                    .clipShape(ChatBubbleShape(isUser: isUser))
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message.content
                            HapticManager.light()
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }

                Text(message.timestamp, style: .time)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 4)
            }

            if !isUser { Spacer(minLength: 50) }
        }
        .padding(.vertical, 2)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) {
                appeared = true
            }
        }
    }
}

// MARK: - Chat Bubble Shape (rounded with tail)

struct ChatBubbleShape: Shape {
    let isUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        let tailRadius: CGFloat = 6

        var path = Path()

        if isUser {
            // User bubble: rounded on all corners except bottom-right
            path.addRoundedRect(
                in: rect,
                cornerRadii: .init(
                    topLeading: radius,
                    bottomLeading: radius,
                    bottomTrailing: tailRadius,
                    topTrailing: radius
                )
            )
        } else {
            // AI bubble: rounded on all corners except bottom-left
            path.addRoundedRect(
                in: rect,
                cornerRadii: .init(
                    topLeading: radius,
                    bottomLeading: tailRadius,
                    bottomTrailing: radius,
                    topTrailing: radius
                )
            )
        }

        return path
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
        VStack(spacing: 4) {
            if let remaining = remainingMessages, remaining < Int.max {
                HStack(spacing: 4) {
                    Image(systemName: remaining <= 3 ? "exclamationmark.circle.fill" : "bubble.left.fill")
                        .font(.system(size: 9))
                    Text("\(remaining) messages remaining")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(remaining <= 3 ? .orange : Theme.textTertiary)
                .padding(.top, 4)
            }

            HStack(spacing: 10) {
                TextField("", text: $text, prompt: Text("Message Breathe AI...").foregroundStyle(.white.opacity(0.35)), axis: .vertical)
                    .focused(isFocused)
                    .lineLimit(1...4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .foregroundStyle(Theme.textPrimary)
                    .tint(.white)

                Button {
                    HapticManager.light()
                    onSend()
                } label: {
                    ZStack {
                        Circle()
                            .fill(canSend
                                ? LinearGradient(
                                    colors: [Theme.profileAccent, Color(red: 0.5, green: 0.35, blue: 0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color.white.opacity(0.1), Color.white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)

                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(canSend ? .white : Theme.textTertiary)
                    }
                }
                .disabled(!canSend)
                .scaleEffect(canSend ? 1.0 : 0.9)
                .animation(.spring(response: 0.2), value: canSend)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // AI avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.profileAccent.opacity(0.8), Color(red: 0.4, green: 0.3, blue: 0.9).opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)

                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Theme.profileAccent.opacity(0.7))
                        .frame(width: 7, height: 7)
                        .scaleEffect(animating ? 1.0 : 0.5)
                        .opacity(animating ? 1.0 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.1))
            .clipShape(ChatBubbleShape(isUser: false))

            Spacer()
        }
        .padding(.vertical, 2)
        .onAppear { animating = true }
    }
}

// MARK: - Suggested Content Card

struct SuggestedContentCard: View {
    let title: String
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Avatar spacer to align with bubbles
            Color.clear.frame(width: 28, height: 28)

            Button(action: onTap) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.profileAccent.opacity(0.2))
                            .frame(width: 40, height: 40)

                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.profileAccent)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Recommended")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.profileAccent)
                        Text(title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Theme.profileAccent.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 40)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Crisis Resource View

struct CrisisResourceView: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Color.clear.frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 32, height: 32)
                        Image(systemName: "heart.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                    }
                    Text("Crisis Resources")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                }

                Text("If you're in crisis, please reach out.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)

                VStack(alignment: .leading, spacing: 8) {
                    CrisisButton(
                        label: "Call 988 Suicide & Crisis Lifeline",
                        icon: "phone.fill",
                        action: { openURL("tel://\(Constants.CrisisResources.suicidePreventionHotline)") }
                    )
                    CrisisButton(
                        label: "Text HOME to \(Constants.CrisisResources.crisisTextLine)",
                        icon: "message.fill",
                        action: { openURL("sms:\(Constants.CrisisResources.crisisTextLine)&body=HELLO") }
                    )
                    CrisisButton(
                        label: "Call \(Constants.CrisisResources.emergencyNumber) for Emergencies",
                        icon: "staroflife.fill",
                        action: { openURL("tel://\(Constants.CrisisResources.emergencyNumber)") }
                    )
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.red.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                    )
            )

            Spacer(minLength: 20)
        }
        .padding(.vertical, 2)
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
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.8))
                    .frame(width: 16)
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.textPrimary)
            }
        }
    }
}

// MARK: - Chat Paywall Prompt

struct ChatPaywallPrompt: View {
    let onUpgrade: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.profileAccent.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "lock.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.profileAccent)
            }

            Text("You've reached your free limit")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            Text("Upgrade to Premium for unlimited conversations with Breathe AI")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: onUpgrade) {
                Text("Upgrade to Premium")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Theme.profileAccent, Color(red: 0.5, green: 0.35, blue: 0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 16)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}
