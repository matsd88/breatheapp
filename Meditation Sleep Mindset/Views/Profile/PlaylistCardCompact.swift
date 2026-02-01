//
//  PlaylistCardCompact.swift
//  Meditation Sleep Mindset
//

import SwiftUI

struct PlaylistCardCompact: View {
    let playlist: Playlist
    let itemCount: Int
    let thumbnailURLs: [String]
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    if thumbnailURLs.count >= 2 {
                        // 2x2 grid of thumbnails (or partial grid)
                        let gridURLs = Array(thumbnailURLs.prefix(4))
                        let columns = 2
                        let rows = gridURLs.count <= 2 ? 1 : 2
                        VStack(spacing: 2) {
                            ForEach(0..<rows, id: \.self) { row in
                                HStack(spacing: 2) {
                                    ForEach(0..<columns, id: \.self) { col in
                                        let index = row * columns + col
                                        if index < gridURLs.count {
                                            CachedAsyncImage(
                                                url: URL(string: gridURLs[index]),
                                                failedIconName: "play.rectangle",
                                                content: { image in
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                },
                                                placeholder: {
                                                    Rectangle().fill(Theme.cardBackground)
                                                }
                                            )
                                            .frame(width: 69, height: rows == 1 ? 100 : 49)
                                            .clipped()
                                        } else {
                                            Rectangle()
                                                .fill(Theme.cardBackground)
                                                .frame(width: 69, height: 49)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(width: 140, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else if let url = thumbnailURLs.first {
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
                        .frame(width: 140, height: 100)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else if let url = playlist.coverThumbnailURL {
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
                        .frame(width: 140, height: 100)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.cardBackground)
                            .frame(width: 140, height: 100)
                            .overlay(
                                Image(systemName: "rectangle.stack")
                                    .font(.title2)
                                    .foregroundStyle(.white.opacity(0.3))
                            )
                    }
                }

                Text(playlist.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text("\(itemCount) item\(itemCount == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(width: 140)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Playlist", systemImage: "trash")
            }
        }
    }
}
