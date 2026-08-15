//
//  HapticManager.swift
//  Meditation Sleep Mindset
//

import UIKit

enum HapticManager {
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    /// User-controllable haptics switch (defaults to on when never set).
    static let enabledKey = "hapticsEnabled"
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    static func light() {
        guard isEnabled else { return }
        lightGenerator.impactOccurred()
    }

    static func medium() {
        guard isEnabled else { return }
        mediumGenerator.impactOccurred()
    }

    static func heavy() {
        guard isEnabled else { return }
        heavyGenerator.impactOccurred()
    }

    static func selection() {
        guard isEnabled else { return }
        selectionGenerator.selectionChanged()
    }

    static func success() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.success)
    }

    static func error() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.error)
    }

    /// Prepare generators for immediate response (call before expected interaction)
    static func prepare() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        selectionGenerator.prepare()
    }
}
