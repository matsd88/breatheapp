//
//  MicroMomentsBanner.swift
//  Meditation Sleep Mindset
//
//  Eye-catching banner promoting the Micro Moments feature.
//

import SwiftUI

struct MicroMomentsBanner: View {
    let onTap: () -> Void

    @State private var isAnimating = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        Button(action: {
            HapticManager.medium()
            onTap()
        }) {
            HStack(spacing: isRegular ? 20 : 16) {
                // Animated icon stack
                ZStack {
                    // Background glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.pink.opacity(0.5), .purple.opacity(0.2), .clear],
                                center: .center,
                                startRadius: 5,
                                endRadius: isRegular ? 50 : 40
                            )
                        )
                        .frame(width: isRegular ? 90 : 70, height: isRegular ? 90 : 70)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)

                    // Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.pink, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: isRegular ? 64 : 50, height: isRegular ? 64 : 50)

                        Image(systemName: "bolt.fill")
                            .font(isRegular ? .title : .title2)
                            .foregroundStyle(.white)
                    }
                }

                // Text content
                VStack(alignment: .leading, spacing: isRegular ? 6 : 4) {
                    HStack(spacing: 6) {
                        Text("Micro Moments")
                            .font(isRegular ? .title3.weight(.semibold) : .headline)
                            .foregroundStyle(.white)

                        Text("NEW")
                            .font(isRegular ? .caption.weight(.bold) : .caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, isRegular ? 8 : 6)
                            .padding(.vertical, isRegular ? 3 : 2)
                            .background(
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: [.pink, .orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                            )
                    }

                    Text("30-60 second resets for busy moments")
                        .font(isRegular ? .body : .subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(isRegular ? 20 : 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.3),
                                Color.pink.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [.pink.opacity(0.5), .purple.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    ZStack {
        Theme.profileGradient.ignoresSafeArea()
        MicroMomentsBanner { }
    }
}
