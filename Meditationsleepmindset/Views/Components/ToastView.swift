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

        // Haptic feedback based on style
        switch style {
        case .success:
            HapticManager.success()
        case .error:
            HapticManager.error()
        case .standard:
            HapticManager.light()
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            currentToast = ToastItem(message: message, icon: icon, style: style)
        }

        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                currentToast = nil
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            currentToast = nil
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
        case error
    }

    var iconColor: Color {
        switch style {
        case .standard: return .white
        case .success: return .green
        case .error: return .red
        }
    }

    var backgroundColor: Color {
        switch style {
        case .standard: return Color(white: 0.15)
        case .success: return Color(red: 0.1, green: 0.2, blue: 0.15)
        case .error: return Color(red: 0.2, green: 0.1, blue: 0.1)
        }
    }
}

// MARK: - Toast Overlay View

struct ToastOverlay: View {
    @ObservedObject var toastManager = ToastManager.shared
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        Group {
            if let toast = toastManager.currentToast {
                HStack(spacing: 12) {
                    // Icon with background circle
                    ZStack {
                        Circle()
                            .fill(toast.iconColor.opacity(0.15))
                            .frame(width: 28, height: 28)

                        Image(systemName: toast.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(toast.iconColor)
                    }

                    Text(toast.message)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    ZStack {
                        // Blur background
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)

                        // Colored overlay
                        RoundedRectangle(cornerRadius: 16)
                            .fill(toast.backgroundColor.opacity(0.8))

                        // Subtle border
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    }
                )
                .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
                .shadow(color: toast.iconColor.opacity(0.15), radius: 8, y: 2)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .offset(y: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.height < 0 {
                                dragOffset = value.translation.height
                            }
                        }
                        .onEnded { value in
                            if value.translation.height < -30 {
                                toastManager.dismiss()
                            }
                            withAnimation(.spring(response: 0.3)) {
                                dragOffset = 0
                            }
                        }
                )
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                        removal: .move(edge: .top).combined(with: .opacity)
                    )
                )
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: toastManager.currentToast)
        .allowsHitTesting(toastManager.currentToast != nil)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 20) {
            Button("Show Standard Toast") {
                ToastManager.shared.show("This is a standard message", icon: "info.circle.fill")
            }
            Button("Show Success Toast") {
                ToastManager.shared.show("Added to playlist!", icon: "checkmark.circle.fill", style: .success)
            }
            Button("Show Error Toast") {
                ToastManager.shared.show("Something went wrong", icon: "exclamationmark.circle.fill", style: .error)
            }
        }
        .foregroundStyle(.white)

        ToastOverlay()
    }
}
