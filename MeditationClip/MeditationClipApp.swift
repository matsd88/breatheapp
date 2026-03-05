//
//  MeditationClipApp.swift
//  MeditationClip
//

import SwiftUI

@main
struct MeditationClipApp: App {
    var body: some Scene {
        WindowGroup {
            ClipTechniquePickerView()
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    handleInvocation(activity)
                }
        }
    }

    private func handleInvocation(_ activity: NSUserActivity) {
        guard let url = activity.webpageURL else { return }

        // Parse technique from URL path
        // e.g. /breathe/box-breathing → .boxBreathing
        let path = url.lastPathComponent.lowercased()

        if let technique = techniqueFromSlug(path) {
            // Post notification for ClipTechniquePickerView to navigate directly
            NotificationCenter.default.post(
                name: .clipDirectTechnique,
                object: technique
            )
        }
    }

    private func techniqueFromSlug(_ slug: String) -> BreathingTechnique? {
        switch slug {
        case "box-breathing": return .boxBreathing
        case "4-7-8", "relaxing": return .relaxing
        case "wim-hof": return .wimHof
        case "alternate-nostril": return .alternateNostril
        case "energizing": return .energizing
        default: return nil
        }
    }
}

extension Notification.Name {
    static let clipDirectTechnique = Notification.Name("clipDirectTechnique")
}
