//
//  ShareableCardView.swift
//  Meditation Sleep Mindset
//

import SwiftUI

// MARK: - Shareable Card Types

enum ShareableCardType {
    case streak(days: Int)
    case milestone(totalSessions: Int)
    case minutesMilestone(totalMinutes: Int)
    case sessionComplete(title: String, duration: Int)
}

// MARK: - Card Generator

struct ShareableCardView: View {
    let cardType: ShareableCardType

    private var title: String {
        switch cardType {
        case .streak(let days): return "\(days) Day Streak"
        case .milestone(let sessions): return "\(sessions) Session\(sessions == 1 ? "" : "s")"
        case .minutesMilestone(let mins):
            let hours = mins / 60
            return hours > 0 ? "\(hours) Hour\(hours == 1 ? "" : "s")" : "\(mins) Minute\(mins == 1 ? "" : "s")"
        case .sessionComplete(let title, _): return title
        }
    }

    private var subtitle: String {
        switch cardType {
        case .streak: return "Meditation Streak"
        case .milestone: return "Meditation Milestone"
        case .minutesMilestone: return "Total Mindful Time"
        case .sessionComplete(_, let duration):
            let mins = duration / 60
            return "\(mins) minute session completed"
        }
    }

    private var emoji: String {
        switch cardType {
        case .streak(let days):
            if days >= 30 { return "🏆" }
            if days >= 14 { return "⭐" }
            if days >= 7 { return "🔥" }
            return "🔥"
        case .milestone(let sessions):
            if sessions >= 100 { return "💎" }
            if sessions >= 50 { return "🏆" }
            return "🎯"
        case .minutesMilestone(let mins):
            if mins >= 600 { return "🧘" }
            return "⏱️"
        case .sessionComplete: return "✨"
        }
    }

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.08, blue: 0.25),
                    Color(red: 0.15, green: 0.12, blue: 0.35),
                    Color(red: 0.08, green: 0.15, blue: 0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Decorative circles
            Circle()
                .fill(Color.purple.opacity(0.15))
                .frame(width: 200, height: 200)
                .offset(x: -80, y: -100)

            Circle()
                .fill(Color.cyan.opacity(0.1))
                .frame(width: 150, height: 150)
                .offset(x: 100, y: 80)

            // Content
            VStack(spacing: 20) {
                Spacer()

                Text(emoji)
                    .font(.system(size: 56))

                Text(title)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))

                Spacer()

                // App branding
                HStack(spacing: 6) {
                    Image(systemName: "moon.stars.fill")
                        .font(.caption)
                        .foregroundStyle(.purple.opacity(0.8))
                    Text("Meditation Sleep Mindset")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.bottom, 20)
            }
            .padding()
        }
        .frame(width: 340, height: 440)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    /// Render this view as a UIImage for sharing
    @MainActor
    func renderAsImage() -> UIImage {
        let renderer = ImageRenderer(content: self)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage ?? UIImage()
    }
}

// MARK: - Share Sheet Presenter

struct ShareableCardSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    let cardType: ShareableCardType

    var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()

            VStack(spacing: 24) {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)

                Text("Share Your Achievement")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                // Card preview
                ShareableCardView(cardType: cardType)
                    .shadow(color: .purple.opacity(0.3), radius: 20)

                // Share button
                Button {
                    shareCard()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)

                Spacer()
            }
            .frame(maxWidth: sizeClass == .regular ? 700 : 500)
            .frame(maxWidth: .infinity)
        }
        .presentationDetents([.large])
        .presentationBackground(.clear)
        .presentationDragIndicator(.hidden)
    }

    @MainActor
    private func shareCard() {
        let cardView = ShareableCardView(cardType: cardType)
        let image = cardView.renderAsImage()

        let activityVC = UIActivityViewController(
            activityItems: [image, "Check out my meditation journey on Meditation Sleep Mindset! 🧘"],
            applicationActivities: nil
        )
        activityVC.completionWithItemsHandler = { _, completed, _, _ in
            if completed {
                Task { @MainActor in
                    ToastManager.shared.show("Shared successfully", icon: "checkmark.circle.fill", style: .success)
                }
            }
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        var topVC = rootVC
        while let presented = topVC.presentedViewController { topVC = presented }
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        topVC.present(activityVC, animated: true)
    }
}
