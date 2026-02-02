//
//  ToastView.swift
//  Meditation Sleep Mindset
//

import SwiftUI

// MARK: - Toast Manager

@MainActor
final class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published var currentToast: ToastItem?
    private var dismissTask: Task<Void, Never>?

    private init() {}

    func show(_ message: String, icon: String, style: ToastItem.Style = .standard) {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            currentToast = ToastItem(message: message, icon: icon, style: style)
        }
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                currentToast = nil
            }
        }
    }
}

// MARK: - Toast Item

struct ToastItem: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let icon: String
    let style: Style

    enum Style: Equatable {
        case standard
        case success
    }
}

// MARK: - Toast Overlay View

struct ToastOverlay: View {
    @ObservedObject var toastManager = ToastManager.shared

    var body: some View {
        VStack {
            if let toast = toastManager.currentToast {
                HStack(spacing: 10) {
                    Image(systemName: toast.icon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(toast.style == .success ? .green : .white)

                    Text(toast.message)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 8)
            }

            Spacer()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toastManager.currentToast)
        .allowsHitTesting(false)
    }
}
