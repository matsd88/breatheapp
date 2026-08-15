//
//  AccessibilityRootModifier.swift
//  Meditation Sleep Mindset
//
//  Applies the in-app accessibility preferences (Larger Text, High Contrast,
//  Reduce Motion) globally from the app root, so the Settings toggles actually
//  take effect rather than just persisting a value nothing reads.
//
//  NOTE: implemented as a generic View wrapper (not a ViewModifier) on purpose —
//  the app defines a SwiftData `@Model class Content`, which shadows the
//  `ViewModifier.Content` associated type and breaks `body(content: Content)`.
//

import SwiftUI

private struct AccessibilityWrapper<Wrapped: View>: View {
    let wrapped: Wrapped

    @AppStorage("accessibilityLargeText") private var largeText = false
    @AppStorage("accessibilityHighContrast") private var highContrast = false
    @AppStorage("accessibilityReduceMotion") private var reduceMotion = false

    var body: some View {
        largerText(
            wrapped
                // Mild global contrast + saturation lift for readability when High Contrast is on.
                .contrast(highContrast ? 1.18 : 1.0)
                .saturation(highContrast ? 1.12 : 1.0)
        )
        // Reduce Motion: suppress implicit animations across the hierarchy.
        .transaction { txn in
            if reduceMotion { txn.disablesAnimations = true }
        }
    }

    /// Bumps Dynamic Type to an accessibility size when Larger Text is on, and leaves
    /// the system size untouched when off (so users who set a larger size aren't shrunk).
    @ViewBuilder
    private func largerText<V: View>(_ view: V) -> some View {
        if largeText {
            view.dynamicTypeSize(.accessibility1)
        } else {
            view
        }
    }
}

extension View {
    /// Apply the app's accessibility preferences from the root.
    func appAccessibilityPreferences() -> some View {
        AccessibilityWrapper(wrapped: self)
    }
}
