//
//  SpotlightService.swift
//  Meditation Sleep Mindset
//

import CoreSpotlight
import UniformTypeIdentifiers

final class SpotlightService {
    static let shared = SpotlightService()
    private init() {}

    /// Index all content for Spotlight search
    func indexAllContent(_ content: [Content]) {
        let items = content.map { searchableItem(for: $0) }

        CSSearchableIndex.default().indexSearchableItems(items) { error in
            #if DEBUG
            if let error {
                print("[SpotlightService] Indexing failed: \(error.localizedDescription)")
            } else {
                print("[SpotlightService] Indexed \(items.count) items")
            }
            #endif
        }
    }

    /// Index a single content item (e.g., curator-added)
    func indexContent(_ content: Content) {
        let item = searchableItem(for: content)
        CSSearchableIndex.default().indexSearchableItems([item])
    }

    /// Remove a content item from the index
    func removeContent(videoID: String) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [videoID])
    }

    private func searchableItem(for content: Content) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .audio)
        attributes.title = content.title
        attributes.contentDescription = [
            content.contentType.displayName,
            content.narrator,
            content.durationFormatted
        ].compactMap { $0 }.joined(separator: " · ")
        attributes.keywords = content.tags + [content.contentType.rawValue]

        if let narrator = content.narrator {
            attributes.keywords?.append(narrator)
        }

        if let thumbURL = content.thumbnailURL, let url = URL(string: thumbURL) {
            attributes.thumbnailURL = url
        }

        return CSSearchableItem(
            uniqueIdentifier: content.youtubeVideoID,
            domainIdentifier: "com.meditation.content",
            attributeSet: attributes
        )
    }
}
