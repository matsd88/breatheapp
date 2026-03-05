//
//  AppShortcuts.swift
//  Meditation Sleep Mindset
//
//  Siri Shortcuts using the App Intents framework.
//

import AppIntents
import SwiftData

// MARK: - Play Content Intent

struct PlayMeditationIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Meditation"
    static var description = IntentDescription("Play a meditation, sleep story, or other content.")
    static var openAppWhenRun = true

    @Parameter(title: "Content Title")
    var contentTitle: String?

    @Parameter(title: "Content Type")
    var contentType: ShortcutContentType?

    func perform() async throws -> some IntentResult {
        let videoID: String?

        if let title = contentTitle {
            // Try to find content by title (fuzzy match)
            videoID = await findContentVideoID(matching: title)
        } else if let type = contentType {
            // Pick a random content of the specified type
            videoID = await findRandomContent(ofType: type.rawContentType)
        } else {
            // Pick any random content
            videoID = await findRandomContent(ofType: nil)
        }

        if let videoID,
           let encodedID = videoID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
           let url = URL(string: "meditation://content/\(encodedID)") {
            await MainActor.run {
                AppStateManager.shared.handleDeepLink(url)
            }
        }

        return .result()
    }

    @MainActor
    private func findContentVideoID(matching title: String) -> String? {
        guard let container = try? ModelContainer(for: Content.self) else { return nil }
        let context = container.mainContext
        let descriptor = FetchDescriptor<Content>()
        guard let allContent = try? context.fetch(descriptor) else { return nil }
        // Case-insensitive contains match
        let lowered = title.lowercased()
        return allContent.first(where: { $0.title.lowercased().contains(lowered) })?.youtubeVideoID
    }

    @MainActor
    private func findRandomContent(ofType type: String?) -> String? {
        guard let container = try? ModelContainer(for: Content.self) else { return nil }
        let context = container.mainContext
        let descriptor = FetchDescriptor<Content>()
        guard let allContent = try? context.fetch(descriptor) else { return nil }
        let filtered = type.map { t in allContent.filter({ $0.contentType.rawValue == t }) } ?? allContent
        return filtered.randomElement()?.youtubeVideoID
    }
}

// MARK: - Start Timer Intent

struct StartTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Meditation Timer"
    static var description = IntentDescription("Start an unguided meditation timer.")
    static var openAppWhenRun = true

    @Parameter(title: "Duration (minutes)", default: 10)
    var minutes: Int

    func perform() async throws -> some IntentResult {
        // Open the app — the timer view will be triggered
        await MainActor.run {
            NotificationCenter.default.post(
                name: .quickActionTriggered,
                object: nil,
                userInfo: ["action": AppDelegate.QuickAction.unguidedTimer]
            )
        }
        return .result()
    }
}

// MARK: - Shortcut Content Type

enum ShortcutContentType: String, AppEnum {
    case meditation
    case sleepStory = "sleepStory"
    case breathwork
    case music

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Content Type"

    static var caseDisplayRepresentations: [ShortcutContentType: DisplayRepresentation] {
        [
            .meditation: "Meditation",
            .sleepStory: "Sleep Story",
            .breathwork: "Breathwork",
            .music: "Music"
        ]
    }

    var rawContentType: String {
        switch self {
        case .meditation: return "meditation"
        case .sleepStory: return "sleepStory"
        case .breathwork: return "breathwork"
        case .music: return "music"
        }
    }
}

// MARK: - App Shortcuts Provider

struct MeditationShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlayMeditationIntent(),
            phrases: [
                "Play a meditation in \(.applicationName)",
                "Start meditation with \(.applicationName)",
                "Play sleep story in \(.applicationName)",
                "Open \(.applicationName)"
            ],
            shortTitle: "Play Meditation",
            systemImageName: "headphones"
        )
        AppShortcut(
            intent: StartTimerIntent(),
            phrases: [
                "Start timer in \(.applicationName)",
                "Meditation timer with \(.applicationName)"
            ],
            shortTitle: "Meditation Timer",
            systemImageName: "timer"
        )
    }
}
