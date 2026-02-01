//
//  MiniPlayerView.swift
//  Meditation Sleep Mindset
//

import SwiftUI
import SwiftData

struct MiniPlayerView: View {
    @ObservedObject var playerManager: AudioPlayerManager
    @Binding var showFullPlayer: Bool
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [FavoriteContent]

    private func isFavorite(for content: Content) -> Bool {
        favorites.contains { $0.contentID == content.id || $0.youtubeVideoID == content.youtubeVideoID }
    }

    private func toggleFavorite(for content: Content) {
        // Check by both contentID and youtubeVideoID for robustness
        if let existing = favorites.first(where: { $0.contentID == content.id || $0.youtubeVideoID == content.youtubeVideoID }) {
            modelContext.delete(existing)
        } else {
            let favorite = FavoriteContent(from: content)
            modelContext.insert(favorite)
            AppStateManager.shared.onContentFavorited()
        }
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("Failed to save favorite: \(error)")
            #endif
        }
    }

    var body: some View {
        if let content = playerManager.currentContent {
            let favorite = isFavorite(for: content)

            HStack(spacing: 12) {
                // Thumbnail
                CachedAsyncImage(
                    url: URL(string: content.thumbnailURLComputed),
                    failedIconName: content.contentType.iconName,
                    content: { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .scaleEffect(1.15)
                    },
                    placeholder: {
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundStyle(.white.opacity(0.3))
                            )
                    }
                )
                .frame(width: 48, height: 48)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Title and narrator
                VStack(alignment: .leading, spacing: 2) {
                    Text(content.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if let narrator = content.narrator {
                        Text(narrator)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Favorite button
                Button {
                    toggleFavorite(for: content)
                } label: {
                    Image(systemName: favorite ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundStyle(favorite ? .white : .white.opacity(0.7))
                        .frame(width: 44, height: 44)
                }
                .animation(.spring(response: 0.3), value: favorite)

                // Play/Pause button
                Button {
                    playerManager.togglePlayPause()
                } label: {
                    ZStack {
                        if playerManager.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 44, height: 44)
                }

            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                // Frosted glass effect with rounded corners to match tab bar
                ZStack {
                    // Base blur material
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .opacity(0.8)

                    // Dark overlay for depth
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.black.opacity(0.1))

                    // Subtle border
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            .frame(maxWidth: 500)
            .padding(.horizontal, 16)
            .contentShape(RoundedRectangle(cornerRadius: 24))
            .onTapGesture {
                showFullPlayer = true
            }
        }
    }
}

#Preview {
    ZStack {
        Theme.primaryGradient
            .ignoresSafeArea()

        VStack {
            Spacer()
            MiniPlayerView(
                playerManager: AudioPlayerManager.shared,
                showFullPlayer: .constant(false)
            )
            .padding(.bottom, 100)
        }
    }
}
