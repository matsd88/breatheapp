//
//  PlaylistDetailView.swift
//  Meditation Sleep Mindset
//

import SwiftUI
import SwiftData

struct PlaylistDetailView: View {
    let playlist: Playlist
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var playlistItems: [PlaylistItem]
    @Query private var allContent: [Content]
    @State private var selectedContent: Content?
    @State private var showRenameAlert = false
    @State private var editedName = ""
    @State private var showDeleteConfirmation = false

    private var itemsForPlaylist: [PlaylistItem] {
        playlistItems
            .filter { $0.playlistID == playlist.id }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    private func contentFor(item: PlaylistItem) -> Content? {
        allContent.first { $0.id == item.contentID || $0.youtubeVideoID == item.youtubeVideoID }
    }

    private var totalDuration: String {
        let totalSeconds = itemsForPlaylist.reduce(0) { $0 + $1.durationSeconds }
        let minutes = totalSeconds / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remaining = minutes % 60
            return remaining > 0 ? "\(hours)h \(remaining)m" : "\(hours)h"
        }
        return "\(minutes) min"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 12) {
                            // Cover image
                            if let coverURL = playlist.coverThumbnailURL {
                                CachedAsyncImage(
                                    url: URL(string: coverURL),
                                    failedIconName: "rectangle.stack",
                                    content: { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .scaleEffect(1.15)
                                    },
                                    placeholder: {
                                        Rectangle().fill(Theme.cardBackground)
                                    }
                                )
                                .frame(width: 180, height: 120)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Theme.cardBackground)
                                    .frame(width: 180, height: 120)
                                    .overlay(
                                        Image(systemName: "rectangle.stack")
                                            .font(.largeTitle)
                                            .foregroundStyle(.white.opacity(0.3))
                                    )
                            }

                            Text(playlist.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)

                            Text("\(itemsForPlaylist.count) item\(itemsForPlaylist.count == 1 ? "" : "s")  ·  \(totalDuration)")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)

                            // Play button
                            if let firstItem = itemsForPlaylist.first, let firstContent = contentFor(item: firstItem) {
                                Button {
                                    playFromPlaylist(firstContent)
                                } label: {
                                    HStack {
                                        Image(systemName: "play.fill")
                                        Text("Play")
                                    }
                                    .font(.headline)
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top, 16)

                        // Items list
                        if itemsForPlaylist.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "rectangle.stack")
                                    .font(.largeTitle)
                                    .foregroundStyle(.white.opacity(0.3))

                                Text("This playlist is empty")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textSecondary)

                                Text("Add content from the player or by long-pressing any content card")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxHeight: .infinity)
                            .padding(.top, 80)
                            .padding(.horizontal)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(itemsForPlaylist) { item in
                                    if let content = contentFor(item: item) {
                                        PlaylistItemRow(content: content) {
                                            playFromPlaylist(content)
                                        }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                removeItem(item)
                                            } label: {
                                                Label("Remove from Playlist", systemImage: "minus.circle")
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Spacer(minLength: 100)
                    }
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.3), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            editedName = playlist.name
                            showRenameAlert = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Playlist", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .rotationEffect(.degrees(90))
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
            }
            .alert("Rename Playlist", isPresented: $showRenameAlert) {
                TextField("Playlist name", text: $editedName)
                Button("Save") {
                    let trimmed = editedName.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        playlist.name = trimmed
                        playlist.updatedAt = Date()
                        try? modelContext.save()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Delete Playlist?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deletePlaylist()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete \"\(playlist.name)\" and cannot be undone.")
            }
            .fullScreenCover(item: $selectedContent) { content in
                MeditationPlayerView(content: content)
            }
        }
        .presentationBackground(Theme.profileGradient)
    }

    /// Build queue from ordered playlist items and play
    private func playFromPlaylist(_ content: Content) {
        let orderedContent = itemsForPlaylist.compactMap { contentFor(item: $0) }
        let startIndex = orderedContent.firstIndex(where: { $0.id == content.id }) ?? 0
        AudioPlayerManager.shared.queue = orderedContent
        AudioPlayerManager.shared.currentIndex = startIndex
        selectedContent = content
    }

    private func deletePlaylist() {
        // Delete all items in the playlist
        for item in itemsForPlaylist {
            modelContext.delete(item)
        }
        modelContext.delete(playlist)
        try? modelContext.save()
        dismiss()
    }

    private func removeItem(_ item: PlaylistItem) {
        withAnimation {
            modelContext.delete(item)

            // Update cover if we removed the cover item
            if item.youtubeVideoID == playlist.coverYoutubeVideoID {
                let remaining = itemsForPlaylist.filter { $0.id != item.id }
                playlist.coverYoutubeVideoID = remaining.first?.youtubeVideoID
            }

            try? modelContext.save()
        }
    }
}

// MARK: - Playlist Item Row

struct PlaylistItemRow: View {
    let content: Content
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
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
                        Rectangle().fill(Theme.cardBackground)
                    }
                )
                .frame(width: 80, height: 55)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(content.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(content.contentType.displayName)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))

                        Text("·")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)

                        Text(content.durationFormatted)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}
