//
//  MeditationWidget.swift
//  MeditationWidget
//

import WidgetKit
import SwiftUI

@main
struct MeditationWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Streak tracking widget (Small, Medium)
        StreakWidget()

        // Quick action buttons (Medium, Large)
        QuickActionsWidget()

        // Daily inspirational quotes (Small, Medium)
        DailyQuoteWidget()

        // Weekly progress tracking (Medium)
        ProgressWidget()

        // Live Activity for active meditation sessions
        MeditationLiveActivity()
    }
}
