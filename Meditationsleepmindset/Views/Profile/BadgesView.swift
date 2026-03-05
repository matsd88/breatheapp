//
//  BadgesView.swift
//  Meditation Sleep Mindset
//

import SwiftUI
import SwiftData

struct BadgesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var badgeService = BadgeService.shared
    @StateObject private var streakService = StreakService.shared
    @State private var selectedCategory: BadgeCategory? = nil
    @State private var selectedBadge: Badge? = nil

    private var isRegular: Bool { sizeClass == .regular }

    private var filteredBadges: [Badge] {
        let allBadges = badgeService.allBadgesWithStatus
        if let category = selectedCategory {
            return allBadges.filter { $0.category == category }
        }
        return allBadges
    }

    private var earnedCount: Int {
        badgeService.earnedBadges.count
    }

    private var totalCount: Int {
        Badge.allBadges.count
    }

    private var gridColumns: [GridItem] {
        if isRegular {
            return Array(repeating: GridItem(.flexible(), spacing: 16), count: 5)
        }
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Progress Summary
                        progressSummaryCard

                        // Recently Earned Section
                        if !badgeService.recentlyEarnedBadges.isEmpty {
                            recentlyEarnedSection
                        }

                        // Category Filter
                        categoryFilter

                        // Badges Grid
                        badgesGrid
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Badges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        HapticManager.light()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: isRegular ? 14 : 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: isRegular ? 40 : 30, height: isRegular ? 40 : 30)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(item: $selectedBadge) { badge in
                BadgeDetailSheet(
                    badge: badge,
                    progress: badgeService.progress(
                        for: badge,
                        context: modelContext,
                        streakService: streakService
                    )
                )
                .presentationDetents(isRegular ? [.medium, .large] : [.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Material.ultraThinMaterial)
            }
        }
    }

    // MARK: - Progress Summary Card

    private var progressSummaryCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Circular progress
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 8)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: CGFloat(earnedCount) / CGFloat(totalCount))
                        .stroke(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(earnedCount)")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        Text("/\(totalCount)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Badge Collection")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(progressMessage)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))

                    // Category breakdown
                    HStack(spacing: 8) {
                        ForEach(BadgeCategory.allCases) { category in
                            let count = badgeService.earnedBadges.filter { $0.category == category }.count
                            if count > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: category.iconName)
                                        .font(.caption2)
                                        .foregroundStyle(category.color)
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
        let percentage = Double(earnedCount) / Double(totalCount)
        switch percentage {
        case 0:
            return "Start your journey!"
        case 0..<0.25:
            return "Great start! Keep going!"
        case 0.25..<0.5:
            return "You're making progress!"
        case 0.5..<0.75:
            return "Halfway there! Amazing!"
        case 0.75..<1.0:
            return "Almost complete!"
        default:
            return "Badge Master!"
        }
    }

    // MARK: - Recently Earned Section

    private var recentlyEarnedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.yellow)
                Text("Recently Earned")
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(badgeService.recentlyEarnedBadges) { badge in
                        RecentBadgeCard(badge: badge) {
                            HapticManager.light()
                            selectedBadge = badge
                        }
                    }
                }
            }
        }
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All category
                CategoryChip(
                    title: "All",
                    icon: "square.grid.2x2.fill",
                    color: .white,
                    isSelected: selectedCategory == nil
                ) {
                    HapticManager.selection()
                    withAnimation(.spring(response: 0.3)) {
                        selectedCategory = nil
                    }
                }

                ForEach(BadgeCategory.allCases) { category in
                    let earnedInCategory = badgeService.earnedBadges.filter { $0.category == category }.count
                    let totalInCategory = Badge.allBadges.filter { $0.category == category }.count

                    CategoryChip(
                        title: "\(category.displayName) (\(earnedInCategory)/\(totalInCategory))",
                        icon: category.iconName,
                        color: category.color,
                        isSelected: selectedCategory == category
                    ) {
                        HapticManager.selection()
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategory = category
                        }
                    }
                }
            }
        }
    }

    // MARK: - Badges Grid

    private var badgesGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: isRegular ? 20 : 16) {
            ForEach(filteredBadges) { badge in
                BadgeGridItem(
                    badge: badge,
                    progress: badgeService.progress(
                        for: badge,
                        context: modelContext,
                        streakService: streakService
                    )
                ) {
                    HapticManager.light()
                    selectedBadge = badge
                }
            }
        }
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(isSelected ? .black : .white.opacity(0.8))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color.white.opacity(0.1))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Recent Badge Card

struct RecentBadgeCard: View {
    let badge: Badge
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(badge.color.opacity(0.2))
                        .frame(width: 56, height: 56)

                    Image(systemName: badge.iconName)
                        .font(.title2)
                        .foregroundStyle(badge.color)
                }

                Text(badge.name)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let dateEarned = badge.dateEarned {
                    Text(dateEarned.timeAgo)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(width: 80)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Badge Grid Item

struct BadgeGridItem: View {
    let badge: Badge
    let progress: Double
    let action: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    // Progress ring for unearned badges
                    if !badge.isEarned && progress > 0 {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 3)
                            .frame(width: isRegular ? 64 : 52, height: isRegular ? 64 : 52)

                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                badge.color.opacity(0.5),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(width: isRegular ? 64 : 52, height: isRegular ? 64 : 52)
                            .rotationEffect(.degrees(-90))
                    }

                    // Badge icon
                    Circle()
                        .fill(badge.isEarned ? badge.color.opacity(0.2) : Color.white.opacity(0.06))
                        .frame(width: isRegular ? 56 : 44, height: isRegular ? 56 : 44)

                    if badge.isEarned {
                        Image(systemName: badge.iconName)
                            .font(isRegular ? .title2 : .body)
                            .foregroundStyle(badge.color)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(isRegular ? .body : .caption)
                            .foregroundStyle(.white.opacity(0.2))
                    }
                }

                Text(badge.name)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(badge.isEarned ? .white : .white.opacity(0.4))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 28)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Badge Detail Sheet

struct BadgeDetailSheet: View {
    let badge: Badge
    let progress: Double

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Badge Icon
            ZStack {
                Circle()
                    .fill(badge.isEarned ? badge.color.opacity(0.2) : Color.white.opacity(0.08))
                    .frame(width: 100, height: 100)

                if badge.isEarned {
                    Image(systemName: badge.iconName)
                        .font(.system(size: 44))
                        .foregroundStyle(badge.color)
                } else {
                    // Progress ring
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 4)
                        .frame(width: 100, height: 100)

                    if progress > 0 {
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                badge.color.opacity(0.6),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                    }

                    Image(systemName: "lock.fill")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.3))
                }
            }

            // Badge Info
            VStack(spacing: 8) {
                Text(badge.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                HStack(spacing: 6) {
                    Image(systemName: badge.category.iconName)
                        .font(.caption)
                    Text(badge.category.displayName)
                        .font(.caption)
                }
                .foregroundStyle(badge.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(badge.color.opacity(0.15))
                .clipShape(Capsule())

                Text(badge.description)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }

            // Requirement / Progress
            VStack(spacing: 12) {
                if badge.isEarned {
                    if let dateEarned = badge.dateEarned {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Earned \(dateEarned.formatted(date: .abbreviated, time: .omitted))")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                } else {
                    // Progress bar
                    VStack(spacing: 8) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 8)

                                Capsule()
                                    .fill(badge.color)
                                    .frame(width: geometry.size.width * progress, height: 8)
                            }
                        }
                        .frame(height: 8)

                        Text("\(Int(progress * 100))% complete")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Text(badge.requirement.description)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(24)
        .padding(.top, 16)
    }
}

// MARK: - Badge Celebration Overlay

struct BadgeCelebrationOverlay: View {
    @ObservedObject var badgeService: BadgeService

    @State private var showBadge = false
    @State private var showConfetti = false
    @State private var badgeScale: CGFloat = 0.5
    @State private var badgeOpacity: Double = 0

    var body: some View {
        if badgeService.showCelebration, let badge = badgeService.recentlyEarnedBadge {
            ZStack {
                // Dimmed background
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .onTapGesture {
                        badgeService.dismissCelebration()
                    }

                // Celebration content
                VStack(spacing: 24) {
                    // Badge icon with glow
                    ZStack {
                        // Glow effect
                        Circle()
                            .fill(badge.color.opacity(0.3))
                            .frame(width: 160, height: 160)
                            .blur(radius: 30)

                        Circle()
                            .fill(badge.color.opacity(0.2))
                            .frame(width: 120, height: 120)

                        Image(systemName: badge.iconName)
                            .font(.system(size: 56))
                            .foregroundStyle(badge.color)
                    }
                    .scaleEffect(badgeScale)
                    .opacity(badgeOpacity)

                    VStack(spacing: 8) {
                        Text("Badge Earned!")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.7))

                        Text(badge.name)
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)

                        Text(badge.description)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .opacity(badgeOpacity)

                    Button {
                        badgeService.dismissCelebration()
                    } label: {
                        Text("Awesome!")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 48)
                            .padding(.vertical, 16)
                            .background(.white)
                            .clipShape(Capsule())
                    }
                    .opacity(badgeOpacity)
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    showBadge = true
                    badgeScale = 1.0
                    badgeOpacity = 1.0
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BadgesView()
        .modelContainer(for: [
            UserProfile.self,
            MeditationSession.self,
            FavoriteContent.self,
            Content.self,
            Playlist.self,
            PlaylistItem.self
        ], inMemory: true)
}
