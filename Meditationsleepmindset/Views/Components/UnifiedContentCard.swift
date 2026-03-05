//
//  UnifiedContentCard.swift
//  Meditation Sleep Mindset
//
//  Unified content card component to reduce code duplication across views.
//

import SwiftUI

// MARK: - Card Style Configuration
enum ContentCardStyle {
    case list           // Full-width row with details (like ContentCardView)
    case compact        // Smaller row for lists (like RecentlyPlayedListRow)
    case thumbnail      // Vertical card with thumbnail (like RecentlyPlayedCard)
    case sleep          // Sleep-specific vertical card (like SleepContentCard)
}

// MARK: - Unified Content Card
struct UnifiedContentCard: View {
    let content: Content
    let style: ContentCardStyle
    let onTap: () -> Void

    // Optional configurations
    var isFavorite: Bool = false
    var onFavorite: (() -> Void)? = nil
    var showPlayOverlay: Bool = false
    var onAddToPlaylist: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil

    @Environment(\.horizontalSizeClass) private var sizeClass

    // Adaptive sizes for iPad
    private var listThumbWidth: CGFloat { sizeClass == .regular ? 140 : 100 }
    private var listThumbHeight: CGFloat { sizeClass == .regular ? 100 : 70 }
    private var compactThumbWidth: CGFloat { sizeClass == .regular ? 110 : 80 }
    private var compactThumbHeight: CGFloat { sizeClass == .regular ? 75 : 55 }
    private var thumbnailCardWidth: CGFloat { sizeClass == .regular ? 180 : 140 }
    private var thumbnailCardHeight: CGFloat { sizeClass == .regular ? 115 : 90 }

    var body: some View {
        Button(action: onTap) {
            cardContent
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onFavorite = onFavorite {
                Button {
                    onFavorite()
                } label: {
                    Label(
                        isFavorite ? "Remove from Favorites" : "Add to Favorites",
                        systemImage: isFavorite ? "heart.slash" : "heart"
                    )
                }
            }

            if let onAddToPlaylist = onAddToPlaylist {
                Button {
                    onAddToPlaylist()
                } label: {
                    Label("Add to Playlist", systemImage: "text.badge.plus")
                }
            }

            ShareLink(
                item: content.deepLinkURL,
                subject: Text(content.title),
                message: Text("Check out '\(content.title)' on Meditation Sleep Mindset!")
            ) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        switch style {
        case .list:
            listStyleCard
        case .compact:
            compactStyleCard
        case .thumbnail:
            thumbnailStyleCard
        case .sleep:
            sleepStyleCard
        }
    }

    // MARK: - List Style (Full Row)
    private var listStyleCard: some View {
        HStack(spacing: 12) {
            thumbnailImage(width: listThumbWidth, height: listThumbHeight, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(content.contentType.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.7))

                    if !content.durationFormatted.isEmpty {
                        Text("•")
                            .foregroundStyle(Theme.textTertiary)

                        Text(content.durationFormatted)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                Text(content.title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                if let narrator = content.narrator {
                    Text(narrator)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let onFavorite = onFavorite {
                Button(action: onFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorite ? .white : Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Compact Style (Small Row)
    private var compactStyleCard: some View {
        HStack(spacing: 12) {
            thumbnailImage(width: compactThumbWidth, height: compactThumbHeight, cornerRadius: 8)

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

                    if !content.durationFormatted.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)

                        Text(content.durationFormatted)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundStyle(.white)
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Thumbnail Style (Vertical Card)
    private var thumbnailStyleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                thumbnailImage(width: thumbnailCardWidth, height: thumbnailCardHeight, cornerRadius: 12)

                if showPlayOverlay {
                    Circle()
                        .fill(.black.opacity(0.5))
                        .frame(width: sizeClass == .regular ? 44 : 36, height: sizeClass == .regular ? 44 : 36)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: sizeClass == .regular ? 18 : 14))
                                .foregroundStyle(.white)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(content.title)
                    .font(sizeClass == .regular ? .body : .subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Text(content.durationFormatted)
                    .font(sizeClass == .regular ? .subheadline : .caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(width: thumbnailCardWidth)
    }

    // MARK: - Sleep Style (Vertical with Gradient)
    private var sleepStyleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                CachedAsyncImage(
                    url: URL(string: content.thumbnailURLComputed),
                    failedIconName: content.contentType.iconName,
                    content: { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .scaleEffect(1.15)
                            .clipped()
                    },
                    placeholder: {
                        Rectangle()
                            .fill(Theme.cardBackground)
                            .overlay(
                                Image(systemName: content.contentType.iconName)
                                    .font(.title2)
                                    .foregroundStyle(.white.opacity(0.3))
                            )
                    }
                )
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .overlay(alignment: .bottomLeading) {
                Text(content.durationFormatted)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(8)
            }

            Text(content.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(content.narrator ?? " ")
                .font(.caption)
                .foregroundStyle(content.narrator != nil ? .white.opacity(0.7) : .clear)
                .lineLimit(1)
        }
    }

    // MARK: - Shared Thumbnail Component
    @ViewBuilder
    private func thumbnailImage(width: CGFloat?, height: CGFloat, cornerRadius: CGFloat) -> some View {
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
                    .fill(Theme.cardBackground)
                    .overlay(
                        Image(systemName: content.contentType.iconName)
                            .font(height > 80 ? .title2 : .body)
                            .foregroundStyle(.white.opacity(0.3))
                    )
            }
        )
        .frame(width: width, height: height)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Convenience Initializers
extension UnifiedContentCard {
    /// List style with favorite button
    static func list(
        content: Content,
        isFavorite: Bool,
        onTap: @escaping () -> Void,
        onFavorite: @escaping () -> Void,
        onAddToPlaylist: (() -> Void)? = nil,
        onShare: (() -> Void)? = nil
    ) -> UnifiedContentCard {
        UnifiedContentCard(
            content: content,
            style: .list,
            onTap: onTap,
            isFavorite: isFavorite,
            onFavorite: onFavorite,
            onAddToPlaylist: onAddToPlaylist,
            onShare: onShare
        )
    }

    /// Compact row style
    static func compact(
        content: Content,
        onTap: @escaping () -> Void,
        onAddToPlaylist: (() -> Void)? = nil
    ) -> UnifiedContentCard {
        UnifiedContentCard(
            content: content,
            style: .compact,
            onTap: onTap,
            onAddToPlaylist: onAddToPlaylist
        )
    }

    /// Thumbnail card with optional play overlay
    static func thumbnail(
        content: Content,
        showPlayOverlay: Bool = true,
        onTap: @escaping () -> Void,
        onAddToPlaylist: (() -> Void)? = nil
    ) -> UnifiedContentCard {
        UnifiedContentCard(
            content: content,
            style: .thumbnail,
            onTap: onTap,
            showPlayOverlay: showPlayOverlay,
            onAddToPlaylist: onAddToPlaylist
        )
    }

    /// Sleep-specific style
    static func sleep(
        content: Content,
        onTap: @escaping () -> Void,
        onAddToPlaylist: (() -> Void)? = nil
    ) -> UnifiedContentCard {
        UnifiedContentCard(
            content: content,
            style: .sleep,
            onTap: onTap,
            onAddToPlaylist: onAddToPlaylist
        )
    }
}

#Preview {
    ZStack {
        Theme.profileGradient.ignoresSafeArea()

        ScrollView {
            VStack(spacing: 20) {
                Text("List Style")
                    .foregroundStyle(.white)

                UnifiedContentCard.list(
                    content: Content(
                        title: "Morning Meditation",
                        subtitle: "Start fresh",
                        youtubeVideoID: "test123",
                        contentType: .meditation,
                        durationSeconds: 600,
                        narrator: "Guide Name",
                        tags: ["Calm"],
                        isPremium: false,
                        description: nil
                    ),
                    isFavorite: true,
                    onTap: {},
                    onFavorite: {}
                )

                Text("Compact Style")
                    .foregroundStyle(.white)

                UnifiedContentCard.compact(
                    content: Content(
                        title: "Deep Sleep Story",
                        subtitle: nil,
                        youtubeVideoID: "test456",
                        contentType: .sleepStory,
                        durationSeconds: 1800,
                        narrator: "Narrator",
                        tags: ["Sleep"],
                        isPremium: false,
                        description: nil
                    ),
                    onTap: {}
                )
            }
            .padding()
        }
    }
}
