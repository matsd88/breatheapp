//
//  AddToPlaylistSheet.swift
//  Meditation Sleep Mindset
//

import SwiftUI
import SwiftData

struct AddToPlaylistSheet: View {
    let content: Content
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \Playlist.updatedAt, order: .reverse) private var playlists: [Playlist]
    @Query private var playlistItems: [PlaylistItem]
    @State private var showNewPlaylistField = false
    @State private var newPlaylistName = ""
    @FocusState private var isNameFieldFocused: Bool

    private let sheetBackground = Color(red: 0.09, green: 0.17, blue: 0.31)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Create new playlist
                    if showNewPlaylistField {
                        HStack(spacing: 12) {
                            TextField("Playlist name", text: $newPlaylistName)
                                .foregroundStyle(.white)
                                .tint(.white)
                                .focused($isNameFieldFocused)
                                .onSubmit { createPlaylistAndAdd() }

                            Button("Add") {
                                createPlaylistAndAdd()
                            }
                            .disabled(newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty)
                            .foregroundStyle(.white)
                            .fontWeight(.semibold)

                            Button {
                                showNewPlaylistField = false
                                newPlaylistName = ""
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    } else {
                        Button {
                            showNewPlaylistField = true
                            isNameFieldFocused = true
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.15))
                                        .frame(width: 50, height: 50)
                                    Image(systemName: "plus")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                }

                                Text("New Playlist")
                                    .font(.headline)
                                    .foregroundStyle(.white)

                                Spacer()
                            }
                            .padding()
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Existing playlists
                    ForEach(playlists) { playlist in
                        PlaylistRowForAdd(
                            playlist: playlist,
                            isAlreadyAdded: isContentInPlaylist(playlist),
                            itemCount: itemCount(for: playlist)
                        ) {
                            addToPlaylist(playlist)
                        }
                    }

                    if playlists.isEmpty && !showNewPlaylistField {
                        Text("No playlists yet. Create one to get started!")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 24)
                    }
                }
                .padding()
                .frame(maxWidth: sizeClass == .regular ? 700 : 600)
                .frame(maxWidth: .infinity)
            }
            .background(sheetBackground)
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(sheetBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SheetCloseButton { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.4), .medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(sheetBackground)
    }

    // MARK: - Helpers

    private func isContentInPlaylist(_ playlist: Playlist) -> Bool {
        playlistItems.contains {
            $0.playlistID == playlist.id &&
            ($0.contentID == content.id || $0.youtubeVideoID == content.youtubeVideoID)
        }
    }

    private func itemCount(for playlist: Playlist) -> Int {
        playlistItems.filter { $0.playlistID == playlist.id }.count
    }

    private func createPlaylistAndAdd() {
        let trimmed = newPlaylistName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let playlist = Playlist(name: trimmed)
        modelContext.insert(playlist)
        addToPlaylist(playlist)
    }

    private func addToPlaylist(_ playlist: Playlist) {
        guard !isContentInPlaylist(playlist) else {
            dismiss()
            return
        }

        let currentMaxOrder = playlistItems
            .filter { $0.playlistID == playlist.id }
            .map { $0.orderIndex }
            .max() ?? -1

        let item = PlaylistItem(playlistID: playlist.id, from: content, orderIndex: currentMaxOrder + 1)
        modelContext.insert(item)

        // Set cover to first item's thumbnail
        if playlist.coverYoutubeVideoID == nil {
            playlist.coverYoutubeVideoID = content.youtubeVideoID
        }
        playlist.updatedAt = Date()

        try? modelContext.save()
        let playlistName = playlist.name
        dismiss()
        ToastManager.shared.show("Added to \(playlistName)", icon: "text.badge.checkmark", style: .success)
    }
}

// MARK: - Playlist Row for Add Sheet

struct PlaylistRowForAdd: View {
    let playlist: Playlist
    let isAlreadyAdded: Bool
    let itemCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Cover thumbnail
                if let url = playlist.coverThumbnailURL {
                    CachedAsyncImage(
                        url: URL(string: url),
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
                    .frame(width: 50, height: 50)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "rectangle.stack")
                                .foregroundStyle(.white.opacity(0.4))
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(playlist.name)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("\(itemCount) item\(itemCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                if isAlreadyAdded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding()
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isAlreadyAdded)
        .opacity(isAlreadyAdded ? 0.6 : 1)
    }
}
