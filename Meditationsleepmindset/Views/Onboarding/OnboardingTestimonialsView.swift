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

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isRegular: Bool { sizeClass == .regular }

    @State private var currentIndex = 0
    @State private var autoScrollTimer: Timer?

    private let testimonials: [Testimonial] = [
        Testimonial(
            quote: "The AI meditations feel like they were made just for me. I haven't slept this well in years.",
            author: "Sarah M.",
            detail: "Using Breathe for 3 months",
            rating: 5
        ),
        Testimonial(
            quote: "Micro-Moments are a game changer — a quick 2-minute reset between meetings and my anxiety melts away.",
            author: "James R.",
            detail: "Using Breathe for 6 months",
            rating: 5
        ),
        Testimonial(
            quote: "The offline packs and Apple Watch support mean I can meditate anywhere — even on flights.",
            author: "Priya K.",
            detail: "Using Breathe for 2 months",
            rating: 5
        ),
        Testimonial(
            quote: "Breathe AI is like having a wellness coach in my pocket. The guided programs changed my mornings completely.",
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
                    .font(isRegular ? .title3 : .body)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, isRegular ? 16 : 0)
                    .padding(.vertical, isRegular ? 8 : 0)
                }
                .padding(.horizontal, 16)

                OnboardingProgressDotsView(current: 3, total: 7)

                Spacer()

                // Header
                VStack(spacing: isRegular ? 12 : 8) {
                    Text("Loved by thousands")
                        .font(isRegular ? .title : .title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("See what our community says")
                        .font(isRegular ? .title3 : .body)
                        .foregroundStyle(.white.opacity(0.7))
                }

                // Testimonial card
                TabView(selection: $currentIndex) {
                    ForEach(Array(testimonials.enumerated()), id: \.element.id) { index, testimonial in
                        TestimonialCard(testimonial: testimonial, isRegular: isRegular)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: isRegular ? 300 : 240)
                .padding(.horizontal, 8)

                // Stars row
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.system(size: isRegular ? 20 : 16))
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
            .frame(maxWidth: isRegular ? 800 : 500)
        }
        .onAppear {
            // Auto-scroll every 4 seconds
            autoScrollTimer?.invalidate()
            autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { _ in
                withAnimation(.easeInOut) {
                    currentIndex = (currentIndex + 1) % testimonials.count
                }
            }
        }
        .onDisappear {
            autoScrollTimer?.invalidate()
            autoScrollTimer = nil
        }
    }
}

struct TestimonialCard: View {
    let testimonial: Testimonial
    var isRegular: Bool = false

    var body: some View {
        VStack(spacing: isRegular ? 20 : 16) {
            // Stars
            HStack(spacing: 4) {
                ForEach(0..<testimonial.rating, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.system(size: isRegular ? 18 : 14))
                }
            }

            // Quote
            Text("\"\(testimonial.quote)\"")
                .font(isRegular ? .title3 : .body)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(isRegular ? 6 : 4)

            // Author
            VStack(spacing: 2) {
                Text(testimonial.author)
                    .font(isRegular ? .body : .subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text(testimonial.detail)
                    .font(isRegular ? .subheadline : .caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(isRegular ? 32 : 24)
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
