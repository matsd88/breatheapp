//
//  OnboardingGoalSelectionView.swift
//  Meditation Sleep Mindset
//

import SwiftUI

enum OnboardingGoal: String, CaseIterable, Identifiable {
    case fallAsleep = "Fall asleep faster"
    case stayAsleep = "Sleep through the night"
    case wakeRefreshed = "Wake up refreshed"
    case improveMindset = "Improve my mindset"
    case reduceStress = "Reduce daily stress"
    case buildHabit = "Build a meditation habit"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fallAsleep: return String(localized: "Fall asleep faster")
        case .stayAsleep: return String(localized: "Sleep through the night")
        case .wakeRefreshed: return String(localized: "Wake up refreshed")
        case .improveMindset: return String(localized: "Improve my mindset")
        case .reduceStress: return String(localized: "Reduce daily stress")
        case .buildHabit: return String(localized: "Build a meditation habit")
        }
    }

    var emoji: String {
        switch self {
        case .fallAsleep: return "🌙"
        case .stayAsleep: return "💤"
        case .wakeRefreshed: return "🌅"
        case .reduceStress: return "😌"
        case .buildHabit: return "🧘"
        case .improveMindset: return "💪"
        }
    }
}

struct OnboardingGoalSelectionView: View {
    let painPoint: PainPoint
    @Binding var selectedGoals: Set<OnboardingGoal>
    let onContinue: () -> Void
    let onBack: () -> Void
    var onSkip: (() -> Void)? = nil

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        ZStack {
            Theme.profileGradient
                .ignoresSafeArea()

            VStack(spacing: 16) {
                // Navigation
                HStack {
                    Button {
                        onBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    if let onSkip = onSkip {
                        Button("Skip") {
                            onSkip()
                        }
                        .font(isRegular ? .title3 : .body)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, isRegular ? 16 : 0)
                        .padding(.vertical, isRegular ? 8 : 0)
                    }
                }
                .padding(.horizontal, 16)

                // Progress indicator
                OnboardingProgressDotsView(current: 1, total: 7)

                // Header
                Text("Let's personalize your journey")
                    .font(isRegular ? .title : .title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.top, isRegular ? 24 : 12)

                // Question
                VStack(spacing: 4) {
                    Text("What would you like to focus on?")
                        .font(isRegular ? .title3 : .headline)
                        .foregroundStyle(.white)

                    Text("Select all that apply")
                        .font(isRegular ? .body : .subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.bottom, isRegular ? 32 : 24)

                // Goal options - no scroll needed
                VStack(spacing: 10) {
                    ForEach(OnboardingGoal.allCases) { goal in
                        OnboardingGoalOptionButton(
                            goal: goal,
                            isSelected: selectedGoals.contains(goal)
                        ) {
                            withAnimation(.spring(response: 0.2)) {
                                if selectedGoals.contains(goal) {
                                    selectedGoals.remove(goal)
                                } else {
                                    selectedGoals.insert(goal)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Continue button
                Button {
                    onContinue()
                } label: {
                    HStack {
                        Text("Continue")
                        Image(systemName: "arrow.right")
                    }
                    .primaryButton()
                }
                .disabled(selectedGoals.isEmpty)
                .opacity(selectedGoals.isEmpty ? 0.5 : 1)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: isRegular ? 800 : 500)
        }
    }
}

struct OnboardingGoalOptionButton: View {
    let goal: OnboardingGoal
    let isSelected: Bool
    var isRegular: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: isRegular ? 16 : 12) {
                Text(goal.emoji)
                    .font(isRegular ? .title : .title2)

                Text(goal.displayName)
                    .font(isRegular ? .title3 : .body)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
                    .font(isRegular ? .title2 : .title3)
            }
            .padding(isRegular ? 18 : 16)
            .background(
                RoundedRectangle(cornerRadius: isRegular ? 16 : 12)
                    .fill(isSelected ? Color.white.opacity(0.15) : Theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: isRegular ? 16 : 12)
                    .stroke(isSelected ? Color.white.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct OnboardingProgressDotsView: View {
    let current: Int
    let total: Int

    var body: some View {
        GeometryReader { geo in
            let width = min(geo.size.width, 200)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: width, height: 4)

                Capsule()
                    .fill(Color.white)
                    .frame(width: width * CGFloat(current + 1) / CGFloat(total), height: 4)
                    .animation(.easeInOut(duration: 0.4), value: current)
            }
            .frame(width: width)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .frame(height: 12)
    }
}

#Preview {
    OnboardingGoalSelectionView(
        painPoint: .sleep,
        selectedGoals: .constant([]),
        onContinue: {},
        onBack: {},
        onSkip: {}
    )
}
