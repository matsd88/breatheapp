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
    @Environment(\.horizontalSizeClass) private var sizeClass

    // Adaptive sizing for iPad
    private var cardWidth: CGFloat { sizeClass == .regular ? 180 : 140 }
    private var cardHeight: CGFloat { sizeClass == .regular ? 130 : 100 }
    private var gridCellWidth: CGFloat { sizeClass == .regular ? 89 : 69 }
    private var gridCellHeightFull: CGFloat { sizeClass == .regular ? 64 : 49 }
    private var gridCellHeightSingle: CGFloat { sizeClass == .regular ? 130 : 100 }

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
                                            .frame(width: gridCellWidth, height: rows == 1 ? gridCellHeightSingle : gridCellHeightFull)
                                            .clipped()
                                        } else {
                                            Rectangle()
                                                .fill(Theme.cardBackground)
                                                .frame(width: gridCellWidth, height: gridCellHeightFull)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(width: cardWidth, height: cardHeight)
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
                        .frame(width: cardWidth, height: cardHeight)
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
                        .frame(width: cardWidth, height: cardHeight)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.cardBackground)
                            .frame(width: cardWidth, height: cardHeight)
                            .overlay(
                                Image(systemName: "rectangle.stack")
                                    .font(.title2)
                                    .foregroundStyle(.white.opacity(0.3))
                            )
                    }
                }

                Text(playlist.name)
                    .font(sizeClass == .regular ? .subheadline : .caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text("\(itemCount) item\(itemCount == 1 ? "" : "s")")
                    .font(sizeClass == .regular ? .caption : .caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(width: cardWidth)
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
