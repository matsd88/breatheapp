//
//  MeditationWatchApp.swift
//  MeditationWatch
//
//  Apple Watch companion app for Meditation Sleep Mindset
//

import SwiftUI
import WatchKit

@main
struct MeditationWatchApp: App {
    @StateObject private var connectivityService = WatchConnectivityService.shared
    @StateObject private var sessionManager = WatchSessionManager.shared

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
            .environmentObject(connectivityService)
            .environmentObject(sessionManager)
        }
    }
}

// MARK: - Content View (Tab Navigation)

struct ContentView: View {
    @EnvironmentObject var connectivityService: WatchConnectivityService
    @EnvironmentObject var sessionManager: WatchSessionManager

    var body: some View {
        TabView {
            WatchHomeView()
                .tag(0)

            WatchBreathingView()
                .tag(1)

            WatchNowPlayingView()
                .tag(2)

            WatchMindfulMinutesView()
                .tag(3)
        }
        .tabViewStyle(.verticalPage)
        .onAppear {
            // Request initial data sync
            connectivityService.requestSync()
            // Load HealthKit data
            sessionManager.loadMindfulMinutes()
        }
    }
}

#Preview {
    NavigationStack {
        ContentView()
    }
    .environmentObject(WatchConnectivityService.shared)
    .environmentObject(WatchSessionManager.shared)
}
