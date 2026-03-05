//
//  ContentMoreMenu.swift
//  Meditation Sleep Mindset
//

import SwiftUI

// MARK: - Content Action Sheet
struct ContentActionSheet: View {
    let content: Content
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let onAddToPlaylist: (() -> Void)?
    let onShare: () -> Void
    @Binding var isPresented: Bool
    @State private var actionTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dimmed background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isPresented = false
                    }
                }

            // Bottom sheet
            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                // Content header — centered title + narrator
                VStack(spacing: 4) {
                    Text(content.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)

                    if let narrator = content.narrator {
                        Text(narrator)
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                // Subtle divider
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 0.5)

                // Action rows
                VStack(spacing: 0) {
                    // 1. Favorites
                    ActionRow(
                        icon: isFavorite ? "heart.fill" : "heart",
                        title: isFavorite ? "Remove from Favorites" : "Add to Favorites",
                        iconColor: isFavorite ? .red : .white
                    ) {
                        isPresented = false
                        actionTask?.cancel()
                        actionTask = Task {
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            guard !Task.isCancelled else { return }
                            onToggleFavorite()
                        }
                    }

                    // 2. Add to Playlist
                    if let onAddToPlaylist {
                        ActionRow(
                            icon: "text.badge.plus",
                            title: "Add to Playlist",
                            iconColor: .white
                        ) {
                            isPresented = false
                            actionTask?.cancel()
                            actionTask = Task {
                                try? await Task.sleep(nanoseconds: 300_000_000)
                                guard !Task.isCancelled else { return }
                                onAddToPlaylist()
                            }
                        }
                    }

                    // 3. Share
                    ActionRow(
                        icon: "square.and.arrow.up",
                        title: "Share with Friends",
                        iconColor: .white
                    ) {
                        isPresented = false
                        actionTask?.cancel()
                        actionTask = Task {
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            guard !Task.isCancelled else { return }
                            onShare()
                        }
                    }

                }
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.10, green: 0.17, blue: 0.32),
                                Color(red: 0.08, green: 0.14, blue: 0.27)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.4), radius: 30, y: -8)
            )
            .padding(.bottom, -24) // Extend past safe area
            .transition(.move(edge: .bottom))
        }
        .onDisappear {
            actionTask?.cancel()
        }
    }
}

// MARK: - Action Row
private struct ActionRow: View {
    let icon: String
    let title: String
    var iconColor: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(.body)
                    .foregroundStyle(Theme.textPrimary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View Extension for presenting the action sheet
extension View {
    func contentActionSheet(
        content mediaContent: Content,
        isFavorite: Bool,
        isPresented: Binding<Bool>,
        onToggleFavorite: @escaping () -> Void,
        onAddToPlaylist: (() -> Void)? = nil,
        onShare: @escaping () -> Void
    ) -> some View {
        self
            .overlay {
                if isPresented.wrappedValue {
                    ContentActionSheet(
                        content: mediaContent,
                        isFavorite: isFavorite,
                        onToggleFavorite: onToggleFavorite,
                        onAddToPlaylist: onAddToPlaylist,
                        onShare: onShare,
                        isPresented: isPresented
                    )
                    .transition(.opacity)
                    .zIndex(999)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isPresented.wrappedValue)
    }
}

// MARK: - Content More Menu (legacy component kept for compatibility)
struct ContentMoreMenu: View {
    let content: Content
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let onAddToPlaylist: () -> Void
    let onShare: () -> Void
    @State private var showActions = false

    var body: some View {
        Button {
            showActions = true
        } label: {
            Image(systemName: "ellipsis")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .rotationEffect(.degrees(90))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .contentActionSheet(
            content: content,
            isFavorite: isFavorite,
            isPresented: $showActions,
            onToggleFavorite: onToggleFavorite,
            onAddToPlaylist: onAddToPlaylist,
            onShare: onShare
        )
    }
}
