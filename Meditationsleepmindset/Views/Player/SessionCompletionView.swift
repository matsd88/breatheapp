//
//  SessionCompletionView.swift
//  Meditation Sleep Mindset
//
//  Post-session payoff sheet shown when a session finishes playing
//  naturally. Replaces PostSessionReflectionView for that path:
//  celebration + stats + mood reflection + streak share.
//

import SwiftUI
import SwiftData

struct SessionCompletionView: View {
    let content: Content
    let minutesListened: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var streakService = StreakService.shared

    @State private var selectedMood: String?
    @State private var sealVisible = false
    @State private var showShareSheet = false
    @State private var showPaywall = false
    @ObservedObject private var storeManager = StoreManager.shared

    /// Finishing a session is the highest-intent moment in the app, and this
    /// screen said nothing about Premium at all. It's also a deliberately calm
    /// moment, so this only appears once the user has actually felt something —
    /// a positive mood just logged, or a streak they're clearly building — and
    /// never on a first, indifferent session. It sits below the mood picker so
    /// it never competes with the reflection itself.
    private var showsPremiumMoment: Bool {
        guard !storeManager.isSubscribed else { return false }
        let feltGood = selectedMood.map { positiveMoods.contains($0) } ?? false
        return feltGood || streakService.currentStreak >= 2
    }

    /// Reason shown on the card, so the prompt is about them rather than us.
    private var premiumMomentReason: String {
        if streakService.currentStreak >= 2 {
            return String(localized: "\(streakService.currentStreak) days in a row. Premium keeps the full library open so you never run out of a next session.")
        }
        return String(localized: "Premium opens the full library — so the next session is always there when you need it.")
    }

    private let moods = [
        ("😌", "Calm"),
        ("😊", "Happy"),
        ("😴", "Tired"),
        ("🧘", "Focused"),
        ("🙏", "Grateful"),
    ]

    private let positiveMoods: Set<String> = ["Calm", "Happy", "Focused", "Grateful"]

    /// Quiet, single-tap invitation — no countdown, no price, no urgency. The
    /// paywall it opens carries the detail; this only has to earn the tap.
    private var premiumMomentCard: some View {
        Button {
            HapticManager.light()
            showPaywall = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.yellow)
                    .frame(width: 40, height: 40)
                    .background(Color.yellow.opacity(0.14))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Keep this going")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(premiumMomentReason)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(16)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.easeOut(duration: 0.25), value: showsPremiumMoment)
        .accessibilityLabel(String(localized: "Keep this going"))
        .accessibilityHint(String(localized: "Opens Premium plans"))
    }

    var body: some View {
        ZStack {
            Theme.profileGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    checkmarkSeal
                        .padding(.top, 36)

                    VStack(spacing: 6) {
                        Text("Session complete")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)

                        Text(content.title)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    statRow

                    moodSection

                    if showsPremiumMoment {
                        premiumMomentCard
                    }

                    VStack(spacing: 12) {
                        if streakService.currentStreak > 0 {
                            Button {
                                HapticManager.light()
                                showShareSheet = true
                            } label: {
                                Label("Share your streak", systemImage: "square.and.arrow.up")
                                    .font(.headline)
                                    .foregroundStyle(Theme.profileAccent)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Theme.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .accessibilityLabel("Share your streak")
                        }

                        Button {
                            HapticManager.medium()
                            dismiss()
                        } label: {
                            Text("Done")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.profileAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .accessibilityLabel("Done, close session summary")
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Close")
            .padding(.trailing, 8)
            .padding(.top, 4)
        }
        .sheet(isPresented: $showPaywall) {
            PremiumPaywallView(
                storeManager: storeManager,
                context: .postSession,
                onSubscribed: { showPaywall = false }
            )
        }
        .sheet(isPresented: $showShareSheet) {
            ShareableCardSheet(cardType: .streak(days: streakService.currentStreak))
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            HapticManager.success()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65).delay(0.1)) {
                sealVisible = true
            }
        }
    }

    // MARK: - Checkmark Seal

    private var checkmarkSeal: some View {
        ZStack {
            // Soft glow behind the seal
            Circle()
                .fill(Theme.profileAccent.opacity(0.45))
                .frame(width: 110, height: 110)
                .blur(radius: 28)
                .opacity(sealVisible ? 1 : 0)

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(Theme.profileAccent)
                .scaleEffect(sealVisible ? 1 : 0.3)
                .opacity(sealVisible ? 1 : 0)
        }
        .frame(height: 110)
        .accessibilityHidden(true)
    }

    // MARK: - Stats

    private var statRow: some View {
        HStack(spacing: 12) {
            statTile(
                value: "\(minutesListened) min",
                label: "This session",
                systemImage: "clock.fill",
                iconColor: Theme.profileAccent
            )
            statTile(
                value: "\(streakService.currentStreak) \(streakService.currentStreak == 1 ? "day" : "days")",
                label: "Streak",
                systemImage: "flame.fill",
                iconColor: .orange
            )
            statTile(
                value: "\(streakService.totalSessions)",
                label: "Sessions",
                systemImage: "leaf.fill",
                iconColor: .green
            )
        }
        .padding(.horizontal, 20)
    }

    private func statTile(value: String, label: String, systemImage: String, iconColor: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(iconColor)

            Text(value)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Mood Reflection

    private var moodSection: some View {
        VStack(spacing: 14) {
            Text("How do you feel now?")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 12) {
                ForEach(moods, id: \.0) { emoji, label in
                    Button {
                        HapticManager.selection()
                        selectedMood = label
                        saveReflection(mood: label)
                        if positiveMoods.contains(label) {
                            SmartRatingManager.shared.checkAndPromptIfAppropriate(trigger: .sessionCompletedWithPositiveMood)
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(emoji)
                                .font(.system(size: 30))
                            Text(label)
                                .font(.caption2)
                                .foregroundStyle(selectedMood == label ? Theme.textPrimary : Theme.textSecondary)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 8)
                        .background(selectedMood == label ? Color.white.opacity(0.2) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    selectedMood == label ? Theme.profileAccent.opacity(0.7) : Color.clear,
                                    lineWidth: 1.5
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityLabel("Feeling \(label)")
                    .accessibilityAddTraits(selectedMood == label ? .isSelected : [])
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func saveReflection(mood: String) {
        // Save mood to the most recent session for this content
        let videoID = content.youtubeVideoID
        let descriptor = FetchDescriptor<MeditationSession>(
            predicate: #Predicate { $0.youtubeVideoID == videoID },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        if let session = try? modelContext.fetch(descriptor).first {
            session.postMood = mood
            try? modelContext.save()
        }
    }
}
