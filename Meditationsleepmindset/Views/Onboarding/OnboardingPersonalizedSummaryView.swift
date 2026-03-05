//
//  OnboardingPersonalizedSummaryView.swift
//  Meditation Sleep Mindset
//

import SwiftUI

struct OnboardingPersonalizedSummaryView: View {
    let painPoint: PainPoint
    let goals: Set<OnboardingGoal>
    let onContinue: () -> Void
    let onBack: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isRegular: Bool { sizeClass == .regular }

    @State private var animateItems = false

    private var recommendations: [(icon: String, text: String, color: Color)] {
        var items: [(String, String, Color)] = []

        // Sleep-related
        if goals.contains(.fallAsleep) || goals.contains(.stayAsleep) || painPoint == .sleep {
            items.append(("moon.stars.fill", "Nightly sleep story before bed", .purple))
        }
        if goals.contains(.wakeRefreshed) {
            items.append(("sunrise.fill", "Morning wake-up meditation", .orange))
        }

        // Stress / anxiety
        if goals.contains(.reduceStress) || painPoint == .anxiety {
            items.append(("leaf.fill", "5-min stress relief sessions", .green))
        }
        if painPoint == .racing {
            items.append(("brain.head.profile", "Focus & clarity exercises", .cyan))
        }

        // Mindset
        if goals.contains(.improveMindset) {
            items.append(("lightbulb.fill", "Daily mindset coaching", .yellow))
        }

        // Habit
        if goals.contains(.buildHabit) {
            items.append(("flame.fill", "Streak tracking to stay consistent", .orange))
        }

        // Always include mood check-in
        items.append(("heart.text.square.fill", "Daily mood check-in", .pink))

        return items
    }

    // Use the post-breathing mood to create an emotional hook
    private var moodMessage: String? {
        let mood = UserDefaults.standard.integer(forKey: "onboardingPostBreathMood")
        switch mood {
        case 3...5: return "You felt calmer after just seconds — imagine what 10 minutes could do."
        case 2: return "Even a brief pause made a difference. Consistency amplifies the effect."
        default: return nil
        }
    }

    var body: some View {
        ZStack {
            Theme.profileGradient
                .ignoresSafeArea()

            VStack(spacing: 24) {
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
                }
                .padding(.horizontal, 16)

                OnboardingProgressDotsView(current: 5, total: 7)

                Spacer()

                // Header
                VStack(spacing: isRegular ? 16 : 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: isRegular ? 52 : 40))
                        .foregroundStyle(.yellow)

                    Text("Your personalized plan")
                        .font(isRegular ? .title : .title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    if let msg = moodMessage {
                        Text(msg)
                            .font(isRegular ? .body : .subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }

                // Recommendations
                VStack(spacing: 10) {
                    ForEach(Array(recommendations.enumerated()), id: \.offset) { index, rec in
                        HStack(spacing: 14) {
                            Image(systemName: rec.icon)
                                .font(.body)
                                .foregroundStyle(rec.color)
                                .frame(width: 36, height: 36)
                                .background(rec.color.opacity(0.15))
                                .clipShape(Circle())

                            Text(rec.text)
                                .font(.body)
                                .foregroundStyle(.white)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .opacity(animateItems ? 1 : 0)
                        .offset(y: animateItems ? 0 : 12)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.8)
                            .delay(Double(index) * 0.1),
                            value: animateItems
                        )
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                Button {
                    onContinue()
                } label: {
                    HStack {
                        Text("See My Plan")
                        Image(systemName: "arrow.right")
                    }
                    .primaryButton()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: isRegular ? 800 : 500)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                animateItems = true
            }
        }
    }
}

#Preview {
    OnboardingPersonalizedSummaryView(
        painPoint: .sleep,
        goals: [.fallAsleep, .reduceStress],
        onContinue: {},
        onBack: {}
    )
}
