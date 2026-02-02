//
//  OnboardingTestimonialsView.swift
//  Meditation Sleep Mindset
//

import SwiftUI

struct Testimonial: Identifiable {
    let id = UUID()
    let quote: String
    let author: String
    let detail: String
    let rating: Int
}

struct OnboardingTestimonialsView: View {
    let onContinue: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void

    @State private var currentIndex = 0
    @State private var autoScrollTimer: Timer?

    private let testimonials: [Testimonial] = [
        Testimonial(
            quote: "I haven't slept this well in years. The sleep stories are incredible.",
            author: "Sarah M.",
            detail: "Using Breathe for 3 months",
            rating: 5
        ),
        Testimonial(
            quote: "My anxiety has noticeably decreased. I look forward to my daily sessions.",
            author: "James R.",
            detail: "Using Breathe for 6 months",
            rating: 5
        ),
        Testimonial(
            quote: "The mindset coaching changed how I start my mornings. I feel more in control.",
            author: "Priya K.",
            detail: "Using Breathe for 2 months",
            rating: 5
        ),
        Testimonial(
            quote: "I tried other apps but Breathe actually made meditation stick. The streak feature keeps me coming back.",
            author: "David L.",
            detail: "Using Breathe for 4 months",
            rating: 5
        )
    ]

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

                    Button("Skip") {
                        onSkip()
                    }
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 16)

                OnboardingProgressDotsView(current: 4, total: 6)

                Spacer()

                // Header
                VStack(spacing: 8) {
                    Text("Loved by thousands")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("See what our community says")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.7))
                }

                // Testimonial card
                TabView(selection: $currentIndex) {
                    ForEach(Array(testimonials.enumerated()), id: \.element.id) { index, testimonial in
                        TestimonialCard(testimonial: testimonial)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 240)
                .padding(.horizontal, 8)

                // Stars row
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.system(size: 16))
                    }
                }
                .padding(.top, 8)

                Spacer()

                Button {
                    autoScrollTimer?.invalidate()
                    onContinue()
                } label: {
                    HStack {
                        Text("Continue")
                        Image(systemName: "arrow.right")
                    }
                    .primaryButton()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: 500)
        }
        .onAppear {
            // Auto-scroll every 4 seconds
            autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { _ in
                withAnimation(.easeInOut) {
                    currentIndex = (currentIndex + 1) % testimonials.count
                }
            }
        }
        .onDisappear {
            autoScrollTimer?.invalidate()
        }
    }
}

struct TestimonialCard: View {
    let testimonial: Testimonial

    var body: some View {
        VStack(spacing: 16) {
            // Stars
            HStack(spacing: 4) {
                ForEach(0..<testimonial.rating, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.system(size: 14))
                }
            }

            // Quote
            Text("\"\(testimonial.quote)\"")
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            // Author
            VStack(spacing: 2) {
                Text(testimonial.author)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text(testimonial.detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}

struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

#Preview {
    OnboardingTestimonialsView(
        onContinue: {},
        onBack: {},
        onSkip: {}
    )
}
