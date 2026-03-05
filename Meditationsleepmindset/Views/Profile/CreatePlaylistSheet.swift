//
//  CreatePlaylistSheet.swift
//  Meditation Sleep Mindset
//

import SwiftUI

struct CreatePlaylistSheet: View {
    @Binding var playlistName: String
    let onCreate: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @FocusState private var isNameFocused: Bool
    @State private var appeared = false
    @State private var iconPulse = false

    private var canCreate: Bool {
        !playlistName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                VStack(spacing: 28) {
                    Spacer()

                    // Animated icon with glow
                    ZStack {
                        // Glow effect
                        Circle()
                            .fill(Theme.profileAccent.opacity(0.2))
                            .frame(width: 100, height: 100)
                            .blur(radius: 20)
                            .scaleEffect(iconPulse ? 1.2 : 1.0)

                        // Icon background
                        Circle()
                            .fill(Theme.profileAccent.opacity(0.15))
                            .frame(width: 80, height: 80)

                        Image(systemName: "rectangle.stack.badge.plus")
                            .font(.system(size: 36))
                            .foregroundStyle(Theme.profileAccent)
                    }
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.8)

                    VStack(spacing: 8) {
                        Text("New Playlist")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        Text("Organize your favorite meditations")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                    // Text field with improved styling
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("", text: $playlistName, prompt: Text("Playlist name").foregroundStyle(.white.opacity(0.4)))
                            .font(.body)
                            .foregroundStyle(.white)
                            .tint(.white)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(isNameFocused ? Theme.profileAccent.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .focused($isNameFocused)
                            .onSubmit {
                                if canCreate {
                                    HapticManager.success()
                                    onCreate()
                                    dismiss()
                                }
                            }

                        // Character count
                        Text("\(playlistName.count)/50")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.3))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, 4)
                    }
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                    // Create button with gradient
                    Button {
                        HapticManager.success()
                        onCreate()
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.body)
                            Text("Create Playlist")
                                .font(.headline)
                        }
                        .foregroundStyle(canCreate ? .white : .white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(canCreate ? Theme.profileAccent : Theme.profileAccent.opacity(0.3))
                        )
                        .shadow(color: canCreate ? Theme.profileAccent.opacity(0.3) : .clear, radius: 12, y: 4)
                    }
                    .disabled(!canCreate)
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                    Button {
                        HapticManager.light()
                        playlistName = ""
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 24)
                    }

                    Spacer()
                }
                .frame(maxWidth: sizeClass == .regular ? 700 : 500)
                .frame(maxWidth: .infinity)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents(sizeClass == .regular ? [.large] : [.medium, .large])
        .presentationBackground(Theme.profileGradient)
        .presentationDragIndicator(.visible)
        .onAppear {
            isNameFocused = true
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                iconPulse = true
            }
        }
    }
}
