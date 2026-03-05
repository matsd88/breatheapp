//
//  OnboardingView.swift
//  Meditation Sleep Mindset
//
//  Research-backed onboarding flow designed for maximum conversion:
//  - 60%+ of subscribers convert before ever using the app
//  - Personalization questions increase conversion by creating investment
//  - Micro-experience before paywall provides immediate value
//  - Testimonials and personalized summary build trust and urgency
//  - 3 subscription options increase conversion by 44% vs 2 options
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppStateManager

    @State private var currentStep = 0
    @State private var selectedPainPoint: PainPoint?
    @State private var selectedGoals: Set<OnboardingGoal> = []

    // 7 steps: Welcome(0), Goals(1), Breathing(2), Testimonials(3),
    //          Notifications(4), Tracking/ATT(5), Paywall(6)
    private let totalSteps = 7

    var body: some View {
        ZStack {
            // Content based on step
            Group {
                switch currentStep {
                case 0:
                    OnboardingWelcomeView(
                        selectedPainPoint: $selectedPainPoint,
                        onContinue: { advanceStep() }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                case 1:
                    OnboardingGoalSelectionView(
                        painPoint: selectedPainPoint ?? .calm,
                        selectedGoals: $selectedGoals,
                        onContinue: { advanceStep() },
                        onBack: { goBack() },
                        onSkip: { skipStep() }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                case 2:
                    OnboardingBreathingView(
                        onComplete: { advanceStep() },
                        onBack: { goBack() },
                        onSkip: { skipStep() }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                case 3:
                    // Social proof first - builds trust before asking for notification permission
                    OnboardingTestimonialsView(
                        onContinue: { advanceStep() },
                        onBack: { goBack() },
                        onSkip: { skipStep() }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                case 4:
                    // Notifications after social proof - users more likely to say yes
                    NotificationPermissionView(
                        onContinue: { advanceStep() },
                        onBack: { goBack() },
                        onSkip: { skipStep() }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                case 5:
                    OnboardingTrackingPermissionView(
                        onContinue: { advanceStep() },
                        onBack: { goBack() }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                case 6:
                    OnboardingPaywall(
                        painPoint: selectedPainPoint ?? .calm,
                        goals: selectedGoals,
                        onSubscribe: {
                            completeOnboarding()
                        },
                        onRestore: {
                            // Restore handled in paywall, just complete
                        },
                        onDismiss: {
                            completeOnboarding()
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                default:
                    EmptyView()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: currentStep)
        }
        .onAppear {
            // Track first step viewed
            let name = stepName(for: 0)
            FirebaseService.shared.logOnboardingStepViewed(step: 0, stepName: name)
            AppsFlyerService.shared.logOnboardingStep(step: 0, stepName: name, action: "step_viewed")
        }
    }

    private func stepName(for step: Int) -> String {
        switch step {
        case 0: return "welcome_painpoint"
        case 1: return "goal_selection"
        case 2: return "breathing_exercise"
        case 3: return "testimonials"
        case 4: return "notifications"
        case 5: return "tracking_permission"
        case 6: return "paywall"
        default: return "unknown"
        }
    }

    private func advanceStep() {
        withAnimation {
            if currentStep < totalSteps - 1 {
                // Log completion of current step
                let name = stepName(for: currentStep)
                FirebaseService.shared.logOnboardingStepCompleted(step: currentStep, stepName: name)
                AppsFlyerService.shared.logOnboardingStep(step: currentStep, stepName: name, action: "step_completed")

                currentStep += 1

                // Log viewing of next step
                let nextName = stepName(for: currentStep)
                FirebaseService.shared.logOnboardingStepViewed(step: currentStep, stepName: nextName)
                AppsFlyerService.shared.logOnboardingStep(step: currentStep, stepName: nextName, action: "step_viewed")
            }
        }
    }

    private func skipStep() {
        withAnimation {
            if currentStep < totalSteps - 1 {
                // Log skip of current step
                let name = stepName(for: currentStep)
                FirebaseService.shared.logOnboardingStepSkipped(step: currentStep, stepName: name)
                AppsFlyerService.shared.logOnboardingStep(step: currentStep, stepName: name, action: "step_skipped")

                currentStep += 1

                // Log viewing of next step
                let nextName = stepName(for: currentStep)
                FirebaseService.shared.logOnboardingStepViewed(step: currentStep, stepName: nextName)
                AppsFlyerService.shared.logOnboardingStep(step: currentStep, stepName: nextName, action: "step_viewed")
            }
        }
    }

    private func goBack() {
        withAnimation {
            if currentStep > 0 {
                currentStep -= 1
            }
        }
    }

    private func completeOnboarding() {
        // Save user preferences
        saveUserProfile()

        // Track attribution event
        AppsFlyerService.shared.logCompleteRegistration()

        // Track onboarding completed
        FirebaseService.shared.logOnboardingCompleted()

        // Mark onboarding complete
        appState.completeOnboarding()
    }

    private func saveUserProfile() {
        let profile = UserProfile()

        // Map OnboardingGoals to UserGoals for compatibility
        var userGoals: [String] = []
        for goal in selectedGoals {
            switch goal {
            case .fallAsleep, .stayAsleep, .wakeRefreshed:
                userGoals.append(UserGoal.betterSleep.rawValue)
            case .reduceStress:
                userGoals.append(UserGoal.reduceStress.rawValue)
            case .buildHabit:
                userGoals.append(UserGoal.reduceAnxiety.rawValue)
            case .improveMindset:
                userGoals.append(UserGoal.buildSelfEsteem.rawValue)
                userGoals.append(UserGoal.increaseHappiness.rawValue)
            }
        }
        profile.selectedGoals = Array(Set(userGoals)) // Remove duplicates

        // Save pain point for personalization
        if let painPoint = selectedPainPoint {
            UserDefaults.standard.set(painPoint.rawValue, forKey: "userPainPoint")
        }

        // Save onboarding goals for personalization
        let goalStrings = selectedGoals.map { $0.rawValue }
        UserDefaults.standard.set(goalStrings, forKey: "userOnboardingGoals")

        modelContext.insert(profile)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppStateManager.shared)
        .modelContainer(for: UserProfile.self, inMemory: true)
}
