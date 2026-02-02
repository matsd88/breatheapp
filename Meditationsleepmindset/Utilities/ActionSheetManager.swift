//
//  ActionSheetManager.swift
//  Meditation Sleep Mindset
//

import SwiftUI
import Combine

/// Shared manager for presenting a single action sheet above the tab bar.
/// Uses NotificationCenter to reliably signal MainTabView, since
/// @ObservedObject / @Published on a singleton can silently fail.
final class ActionSheetManager {
    static let shared = ActionSheetManager()

    static let didChangeNotification = Notification.Name("ActionSheetManagerDidChange")

    struct SheetData: Identifiable {
        let id: UUID
        let content: Content
        let isFavorite: Bool
        let onToggleFavorite: () -> Void
        let onAddToPlaylist: (() -> Void)?
        let onShare: () -> Void
    }

    var sheetData: SheetData?

    func show(
        content: Content,
        isFavorite: Bool,
        onToggleFavorite: @escaping () -> Void,
        onAddToPlaylist: (() -> Void)? = nil,
        onShare: @escaping () -> Void
    ) {
        sheetData = SheetData(
            id: UUID(),
            content: content,
            isFavorite: isFavorite,
            onToggleFavorite: onToggleFavorite,
            onAddToPlaylist: onAddToPlaylist,
            onShare: onShare
        )
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    func dismiss() {
        sheetData = nil
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    var isPresented: Bool {
        sheetData != nil
    }
}
