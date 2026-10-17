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
    /// One branch on purpose: an if/else here gave the whole app a new view
    /// identity on toggle, which dismissed Settings and reset every tab.
    /// Off = the full range, i.e. the system size untouched.
    private func largerText<V: View>(_ view: V) -> some View {
        view.dynamicTypeSize(largeText ? DynamicTypeSize.accessibility1...DynamicTypeSize.accessibility5
                                       : DynamicTypeSize.xSmall...DynamicTypeSize.accessibility5)
    }
}

extension View {
    /// Apply the app's accessibility preferences from the root.
    func appAccessibilityPreferences() -> some View {
        AccessibilityWrapper(wrapped: self)
    }
}
