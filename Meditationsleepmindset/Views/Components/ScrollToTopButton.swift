//
//  ScrollToTopButton.swift
//  Meditation Sleep Mindset
//

import SwiftUI

/// Reusable scroll-to-top floating button
struct ScrollToTopButton: View {
    let scrollProxy: ScrollViewProxy
    let targetID: String
    @Binding var isVisible: Bool
    @ObservedObject private var playerManager = AudioPlayerManager.shared

    var body: some View {
        Button {
            // Hide the button first, then scroll
            withAnimation(.easeOut(duration: 0.2)) {
                isVisible = false
            }
            // Small delay so button removal doesn't interfere with scroll
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    scrollProxy.scrollTo(targetID, anchor: .top)
                }
            }
        } label: {
            Image(systemName: "arrow.up")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, playerManager.currentContent != nil ? 170 : 100)
        .transition(.scale.combined(with: .opacity))
    }
}
