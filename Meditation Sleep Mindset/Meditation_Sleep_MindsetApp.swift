//
//  Meditation_Sleep_MindsetApp.swift
//  Meditation Sleep Mindset
//
//  Created by Mats Degerstedt on 1/23/26.
//

import SwiftUI
import SwiftData

@main
struct Meditation_Sleep_MindsetApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
