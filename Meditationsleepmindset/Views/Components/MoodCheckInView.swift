//
//  MoodCheckInView.swift
//  Meditation Sleep Mindset
//

import SwiftUI

struct MoodCheckInView: View {
    @Binding var isPresented: Bool
    var onMoodSelected: ((Mood) -> Void)?

    @State private var selectedMood: Mood?
    @State private var showingConfirmation = false

    var body: some View {
        ZStack {
            Theme.primaryGradient.ignoresSafeArea()

            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Text("How are you feeling?")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.textPrimary)

                    Text("Select your current mood to personalize your experience")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                // Mood Selection Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    ForEach(Mood.allCases) { mood in
                        MoodOptionButton(
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

                // Continue Button
                Button {
                    if let mood = selectedMood {
                        onMoodSelected?(mood)
                        withAnimation {
                            showingConfirmation = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            isPresented = false
                        }
                    }
                } label: {
                    Text(selectedMood != nil ? "Continue" : "Select a mood")
                        .primaryButton()
                        .opacity(selectedMood != nil ? 1 : 0.5)
                }
                .disabled(selectedMood == nil)
                .padding(.horizontal)

                // Skip Button
                Button("Skip for now") {
                    isPresented = false
                }
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 32)
            }

            // Confirmation Overlay
            if showingConfirmation {
                confirmationOverlay
            }
        }
    }

    private var confirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                if let mood = selectedMood {
                    Text(mood.emoji)
                        .font(.system(size: 64))

                    Text(mood.affirmation)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(32)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - Mood Option Button
struct MoodOptionButton: View {
    let mood: Mood
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? mood.color.opacity(0.3) : Theme.cardBackground)
                        .frame(width: 70, height: 70)

                    Text(mood.emoji)
                        .font(.system(size: 32))
                }
                .overlay {
                    if isSelected {
                        Circle()
                            .stroke(mood.color, lineWidth: 3)
                            .frame(width: 70, height: 70)
                    }
                }

                Text(mood.rawValue)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
    }
}

// MARK: - Mood Extensions
extension Mood {
    var emoji: String {
        switch self {
        case .calm: return "😌"
        case .happy: return "😊"
        case .anxious: return "😰"
        case .stressed: return "😤"
        case .sad: return "😢"
        case .tired: return "😴"
        case .energetic: return "⚡️"
        case .focused: return "🎯"
        case .grateful: return "🙏"
        }
    }

    var color: Color {
        switch self {
        case .calm: return .green
        case .happy: return .yellow
        case .anxious: return .orange
        case .stressed: return .red
        case .sad: return .blue
        case .tired: return .purple
        case .energetic: return .pink
        case .focused: return .indigo
        case .grateful: return .mint
        }
    }

    var affirmation: String {
        switch self {
        case .calm: return "Your peace is your power"
        case .happy: return "Joy radiates from within you"
        case .anxious: return "This too shall pass"
        case .stressed: return "Take it one breath at a time"
        case .sad: return "It's okay to feel your feelings"
        case .tired: return "Rest is productive too"
        case .energetic: return "Channel your energy mindfully"
        case .focused: return "Your attention is a gift"
        case .grateful: return "Gratitude opens doors"
        }
    }

    var recommendedContentTypes: [ContentType] {
        switch self {
        case .calm: return [.meditation, .music]
        case .happy: return [.meditation, .movement]
        case .anxious: return [.meditation, .soundscape]
        case .stressed: return [.meditation, .soundscape]
        case .sad: return [.meditation, .sleepStory]
        case .tired: return [.sleepStory, .soundscape]
        case .energetic: return [.movement, .meditation]
        case .focused: return [.soundscape, .music]
        case .grateful: return [.meditation, .music]
        }
    }
}

// MARK: - Mini Mood Check-In (for Home Screen)
struct MiniMoodCheckIn: View {
    @Binding var selectedMood: Mood?
    var onMoodSelected: ((Mood) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How are you feeling?")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Mood.allCases) { mood in
                        MiniMoodButton(
                            mood: mood,
                            isSelected: selectedMood == mood
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedMood = mood
                                onMoodSelected?(mood)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

struct MiniMoodButton: View {
    let mood: Mood
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(mood.emoji)
                    .font(.title2)

                Text(mood.rawValue)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? mood.color.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(mood.color, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pre-Session Mood Check
struct PreSessionMoodCheck: View {
    let content: Content
    @Binding var isPresented: Bool
    var onContinue: ((Mood?) -> Void)?

    @State private var selectedMood: Mood?

    var body: some View {
        ZStack {
            Theme.primaryGradient.ignoresSafeArea()

            VStack(spacing: 24) {
                // Close Button
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding()

                Spacer()

                // Content Preview
                VStack(spacing: 12) {
                    CachedAsyncImage(
                        url: URL(string: content.thumbnailURLComputed),
                        failedIconName: content.contentType.iconName,
                        content: { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .scaleEffect(1.15)
                        },
                        placeholder: {
                            Rectangle()
                                .fill(Theme.cardBackground)
                        }
                    )
                    .frame(width: 120, height: 80)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text(content.title)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(content.durationFormatted)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }

                // Mood Question
                Text("How are you feeling before this session?")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)

                // Mood Grid (smaller subset)
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach([Mood.calm, .happy, .anxious, .stressed, .sad, .tired], id: \.self) { mood in
                        MoodOptionButton(
                            mood: mood,
                            isSelected: selectedMood == mood
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedMood = mood
                            }
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Continue Button
                VStack(spacing: 12) {
                    Button {
                        onContinue?(selectedMood)
                        isPresented = false
                    } label: {
                        Text("Begin Session")
                            .primaryButton()
                    }

                    Button("Skip") {
                        onContinue?(nil)
                        isPresented = false
                    }
                    .foregroundStyle(Theme.textSecondary)
                }
                .padding()
            }
        }
    }
}

#Preview {
    MoodCheckInView(isPresented: .constant(true))
}
