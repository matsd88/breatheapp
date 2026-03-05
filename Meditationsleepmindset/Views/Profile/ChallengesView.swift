//
//  ChallengesView.swift
//  Meditation Sleep Mindset
//

import SwiftUI
import SwiftData

struct ChallengesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var challengeService = ChallengeService.shared
    @StateObject private var streakService = StreakService.shared
    @State private var selectedChallenge: Challenge?

    private var isRegular: Bool { sizeClass == .regular }

    private var activeChallenges: [Challenge] {
        challengeService.activeChallenges.filter { !$0.isCompleted }
    }

    private var completedChallenges: [Challenge] {
        challengeService.activeChallenges.filter { $0.isCompleted }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Weekly Progress Summary
                        weeklyProgressCard

                        // Challenge of the Week (Featured)
                        if let featured = challengeService.featuredChallenge {
                            featuredChallengeCard(featured)
                        }

                        // Time Remaining
                        timeRemainingBanner

                        // Active Challenges
                        if !activeChallenges.isEmpty {
                            activeChallengesSection
                        }

                        // Completed This Week
                        if !completedChallenges.isEmpty {
                            completedChallengesSection
                        }

                        // XP Stats
                        xpStatsCard
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Weekly Challenges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        HapticManager.light()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(item: $selectedChallenge) { challenge in
                ChallengeDetailSheet(challenge: challenge)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Material.ultraThinMaterial)
            }
        }
        .onAppear {
            challengeService.checkAndRotateChallenges()
        }
    }

    // MARK: - Weekly Progress Card

    private var weeklyProgressCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Circular progress
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 8)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: challengeService.weeklyProgress)
                        .stroke(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(challengeService.completedThisWeek)")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        Text("/\(challengeService.activeChallenges.count)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly Progress")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(progressMessage)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))

                    // Difficulty breakdown
                    HStack(spacing: 8) {
                        ForEach(ChallengeDifficulty.allCases, id: \.self) { difficulty in
                            let count = challengeService.activeChallenges.filter { $0.difficulty == difficulty }.count
                            if count > 0 {
                                HStack(spacing: 2) {
                                    Circle()
                                        .fill(difficulty.color)
                                        .frame(width: 6, height: 6)
                                    Text("\(count)")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }

                Spacer()
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var progressMessage: String {
        let percentage = challengeService.weeklyProgress
        switch percentage {
        case 0:
            return "Start your first challenge!"
        case 0..<0.25:
            return "Great start! Keep going!"
        case 0.25..<0.5:
            return "You're making progress!"
        case 0.5..<0.75:
            return "Halfway there!"
        case 0.75..<1.0:
            return "Almost complete!"
        default:
            return "All challenges complete!"
        }
    }

    // MARK: - Featured Challenge Card

    private func featuredChallengeCard(_ challenge: Challenge) -> some View {
        Button {
            HapticManager.light()
            selectedChallenge = challenge
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text("Challenge of the Week")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.yellow)
                    }

                    Spacer()

                    if challenge.isCompleted {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Complete")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.green)
                        }
                    }
                }

                HStack(spacing: 16) {
                    // Challenge icon
                    ZStack {
                        Circle()
                            .fill(challenge.color.opacity(0.2))
                            .frame(width: 60, height: 60)

                        Image(systemName: challenge.iconName)
                            .font(.title2)
                            .foregroundStyle(challenge.color)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(challenge.title)
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text(challenge.challengeDescription)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(2)
                    }

                    Spacer()
                }

                // Progress bar
                VStack(alignment: .leading, spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 10)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [challenge.color, challenge.color.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * challenge.progressPercentage, height: 10)
                        }
                    }
                    .frame(height: 10)

                    HStack {
                        Text("\(challenge.progress)/\(challenge.target)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))

                        Spacer()

                        // Reward
                        HStack(spacing: 4) {
                            Image(systemName: challenge.reward.iconName)
                                .font(.caption)
                                .foregroundStyle(challenge.reward.color)
                            Text(challenge.reward.displayText)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(challenge.reward.color)
                        }
                    }
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [
                        challenge.color.opacity(0.15),
                        Theme.cardBackground
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(challenge.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Time Remaining Banner

    private var timeRemainingBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.fill")
                .foregroundStyle(.orange)

            Text("Challenges reset every Monday")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            Spacer()

            if let firstChallenge = challengeService.activeChallenges.first {
                Text(firstChallenge.timeRemaining)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Active Challenges Section

    private var activeChallengesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("Active Challenges")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Text("\(activeChallenges.count) remaining")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            VStack(spacing: 12) {
                ForEach(activeChallenges) { challenge in
                    ChallengeRow(challenge: challenge) {
                        HapticManager.light()
                        selectedChallenge = challenge
                    }
                }
            }
        }
    }

    // MARK: - Completed Challenges Section

    private var completedChallengesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Completed This Week")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Text("\(completedChallenges.count)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            VStack(spacing: 8) {
                ForEach(completedChallenges) { challenge in
                    CompletedChallengeRow(challenge: challenge)
                }
            }
        }
    }

    // MARK: - XP Stats Card

    private var xpStatsCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "star.circle.fill")
                    .foregroundStyle(.yellow)
                Text("Rewards Earned")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()
            }

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(challengeService.totalXPEarned)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.yellow)
                    Text("Total XP")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1, height: 40)

                VStack(spacing: 4) {
                    Text("\(challengeService.totalCompletedAllTime)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.green)
                    Text("Challenges")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1, height: 40)

                VStack(spacing: 4) {
                    Text(xpLevel)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.purple)
                    Text("Level")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var xpLevel: String {
        let xp = challengeService.totalXPEarned
        switch xp {
        case 0..<100: return "1"
        case 100..<300: return "2"
        case 300..<600: return "3"
        case 600..<1000: return "4"
        case 1000..<1500: return "5"
        case 1500..<2500: return "6"
        case 2500..<4000: return "7"
        case 4000..<6000: return "8"
        case 6000..<10000: return "9"
        default: return "10+"
        }
    }
}

// MARK: - Challenge Row

struct ChallengeRow: View {
    let challenge: Challenge
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(challenge.color.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: challenge.iconName)
                        .font(.body)
                        .foregroundStyle(challenge.color)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(challenge.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)

                        // Difficulty indicator
                        Circle()
                            .fill(challenge.difficulty.color)
                            .frame(width: 6, height: 6)
                    }

                    Text(challenge.challengeDescription)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer()

                // Progress
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(challenge.progress)/\(challenge.target)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)

                    // Mini progress bar
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 50, height: 4)

                        Capsule()
                            .fill(challenge.color)
                            .frame(width: 50 * challenge.progressPercentage, height: 4)
                    }
                }
            }
            .padding(12)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Completed Challenge Row

struct CompletedChallengeRow: View {
    let challenge: Challenge

    var body: some View {
        HStack(spacing: 12) {
            // Completed icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 36, height: 36)

                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.green)
            }

            Text(challenge.title)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            Spacer()

            // Reward earned
            HStack(spacing: 4) {
                Image(systemName: challenge.reward.iconName)
                    .font(.caption2)
                    .foregroundStyle(challenge.reward.color)
                Text(challenge.reward.displayText)
                    .font(.caption)
                    .foregroundStyle(challenge.reward.color)
            }
        }
        .padding(10)
        .background(Color.green.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Challenge Detail Sheet

struct ChallengeDetailSheet: View {
    let challenge: Challenge
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Challenge Icon
            ZStack {
                Circle()
                    .fill(challenge.isCompleted ? Color.green.opacity(0.2) : challenge.color.opacity(0.2))
                    .frame(width: 100, height: 100)

                if challenge.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.green)
                } else {
                    // Progress ring
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 4)
                        .frame(width: 100, height: 100)

                    if challenge.progressPercentage > 0 {
                        Circle()
                            .trim(from: 0, to: challenge.progressPercentage)
                            .stroke(
                                challenge.color,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                    }

                    Image(systemName: challenge.iconName)
                        .font(.system(size: 36))
                        .foregroundStyle(challenge.color)
                }
            }

            // Challenge Info
            VStack(spacing: 8) {
                Text(challenge.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                // Difficulty badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(challenge.difficulty.color)
                        .frame(width: 8, height: 8)
                    Text(challenge.difficulty.displayName)
                        .font(.caption)
                }
                .foregroundStyle(challenge.difficulty.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(challenge.difficulty.color.opacity(0.15))
                .clipShape(Capsule())

                Text(challenge.challengeDescription)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }

            // Progress / Completion Info
            VStack(spacing: 12) {
                if challenge.isCompleted {
                    if let completedDate = challenge.completedDate {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Completed \(completedDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }

                    // Reward earned
                    HStack(spacing: 8) {
                        Image(systemName: challenge.reward.iconName)
                            .font(.title3)
                            .foregroundStyle(challenge.reward.color)
                        Text(challenge.reward.displayText)
                            .font(.headline)
                            .foregroundStyle(challenge.reward.color)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(challenge.reward.color.opacity(0.15))
                    .clipShape(Capsule())
                } else {
                    // Progress bar
                    VStack(spacing: 8) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 8)

                                Capsule()
                                    .fill(challenge.color)
                                    .frame(width: geometry.size.width * challenge.progressPercentage, height: 8)
                            }
                        }
                        .frame(height: 8)

                        HStack {
                            Text("\(challenge.progress)/\(challenge.target)")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)

                            Spacer()

                            Text("\(Int(challenge.progressPercentage * 100))%")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }

                    // Time remaining
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .foregroundStyle(.orange)
                        Text(challenge.timeRemaining)
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }

                    // Reward preview
                    HStack(spacing: 6) {
                        Text("Reward:")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        Image(systemName: challenge.reward.iconName)
                            .font(.caption)
                            .foregroundStyle(challenge.reward.color)
                        Text(challenge.reward.displayText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(challenge.reward.color)
                    }
                }
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(24)
        .padding(.top, 16)
    }
}

// MARK: - Challenge Celebration Overlay

struct ChallengeCelebrationOverlay: View {
    @ObservedObject var challengeService: ChallengeService

    @State private var showContent = false
    @State private var contentScale: CGFloat = 0.5
    @State private var contentOpacity: Double = 0

    var body: some View {
        if challengeService.showCelebration, let challenge = challengeService.recentlyCompletedChallenge {
            ZStack {
                // Dimmed background
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .onTapGesture {
                        challengeService.dismissCelebration()
                    }

                // Celebration content
                VStack(spacing: 24) {
                    // Trophy icon with glow
                    ZStack {
                        // Glow effect
                        Circle()
                            .fill(challenge.color.opacity(0.3))
                            .frame(width: 160, height: 160)
                            .blur(radius: 30)

                        Circle()
                            .fill(challenge.color.opacity(0.2))
                            .frame(width: 120, height: 120)

                        Image(systemName: "trophy.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.yellow)
                    }
                    .scaleEffect(contentScale)
                    .opacity(contentOpacity)

                    VStack(spacing: 8) {
                        Text("Challenge Complete!")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.7))

                        Text(challenge.title)
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)

                        // Reward
                        HStack(spacing: 8) {
                            Image(systemName: challenge.reward.iconName)
                                .font(.title3)
                                .foregroundStyle(challenge.reward.color)
                            Text(challenge.reward.displayText)
                                .font(.headline)
                                .foregroundStyle(challenge.reward.color)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(challenge.reward.color.opacity(0.2))
                        .clipShape(Capsule())
                        .padding(.top, 8)
                    }
                    .opacity(contentOpacity)

                    Button {
                        challengeService.dismissCelebration()
                    } label: {
                        Text("Awesome!")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 48)
                            .padding(.vertical, 16)
                            .background(.white)
                            .clipShape(Capsule())
                    }
                    .opacity(contentOpacity)
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    showContent = true
                    contentScale = 1.0
                    contentOpacity = 1.0
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ChallengesView()
        .modelContainer(for: [
            UserProfile.self,
            MeditationSession.self,
            Content.self
        ], inMemory: true)
}
