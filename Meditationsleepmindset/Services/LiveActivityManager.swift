//
//  LiveActivityManager.swift
//  Meditation Sleep Mindset
//
//  Manages Live Activities for meditation playback
//

import ActivityKit
import Foundation
import UIKit

/// Manages Live Activities for the meditation timer
/// Handles starting, updating, and ending activities based on playback state
@MainActor
final class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    /// The current active Live Activity
    private var currentActivity: Activity<MeditationActivityAttributes>?

    /// Timer for periodic updates
    private var updateTimer: Timer?

    /// Tracks whether Live Activities are supported on this device
    var areActivitiesSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    private init() {}

    // MARK: - Start Activity

    /// Starts a new Live Activity for the given meditation session
    /// - Parameters:
    ///   - sessionId: Unique identifier for the session
    ///   - videoId: YouTube video ID for thumbnail
    ///   - title: Content title
    ///   - contentType: Type of content (e.g., "Meditation")
    ///   - duration: Total duration in seconds
    func startActivity(
        sessionId: String,
        videoId: String,
        title: String,
        contentType: String,
        duration: TimeInterval
    ) {
        // Check if Live Activities are supported and enabled
        guard areActivitiesSupported else {
            #if DEBUG
            print("[LiveActivityManager] Live Activities not supported or disabled")
            #endif
            return
        }

        // End any existing activity first
        Task {
            await endActivity()
        }

        let attributes = MeditationActivityAttributes(
            sessionId: sessionId,
            videoId: videoId
        )

        let initialState = MeditationActivityAttributes.ContentState(
            currentTime: 0,
            totalDuration: duration,
            isPlaying: true,
            contentTitle: title,
            contentType: contentType
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            #if DEBUG
            print("[LiveActivityManager] Started Live Activity: \(activity.id)")
            #endif
        } catch {
            #if DEBUG
            print("[LiveActivityManager] Failed to start Live Activity: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Update Activity

    /// Updates the Live Activity with current playback state
    /// - Parameters:
    ///   - currentTime: Current playback position in seconds
    ///   - duration: Total duration in seconds
    ///   - isPlaying: Whether playback is active
    ///   - title: Content title
    ///   - contentType: Type of content
    func updateActivity(
        currentTime: TimeInterval,
        duration: TimeInterval,
        isPlaying: Bool,
        title: String,
        contentType: String
    ) {
        guard let activity = currentActivity else { return }

        let updatedState = MeditationActivityAttributes.ContentState(
            currentTime: currentTime,
            totalDuration: duration,
            isPlaying: isPlaying,
            contentTitle: title,
            contentType: contentType
        )

        Task {
            await activity.update(
                ActivityContent(
                    state: updatedState,
                    staleDate: Date.now.addingTimeInterval(120) // Mark as stale after 2 minutes
                )
            )
        }
    }

    // MARK: - End Activity

    /// Ends the current Live Activity
    /// - Parameter showFinalState: If true, shows a completion state briefly before dismissing
    func endActivity(showFinalState: Bool = false) async {
        guard let activity = currentActivity else { return }

        // Stop update timer
        updateTimer?.invalidate()
        updateTimer = nil

        if showFinalState {
            // Show final state with completion indication
            let finalState = MeditationActivityAttributes.ContentState(
                currentTime: activity.content.state.totalDuration,
                totalDuration: activity.content.state.totalDuration,
                isPlaying: false,
                contentTitle: activity.content.state.contentTitle,
                contentType: activity.content.state.contentType
            )

            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .after(.now.addingTimeInterval(5))
            )
        } else {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        currentActivity = nil
        #if DEBUG
        print("[LiveActivityManager] Ended Live Activity")
        #endif
    }

    /// Ends all meditation Live Activities
    func endAllActivities() async {
        for activity in Activity<MeditationActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
        updateTimer?.invalidate()
        updateTimer = nil
    }

    // MARK: - Background Updates

    /// Starts periodic background updates for the Live Activity
    /// Call this when the app goes to background with active playback
    func startBackgroundUpdates(
        startTime: TimeInterval,
        duration: TimeInterval,
        title: String,
        contentType: String
    ) {
        updateTimer?.invalidate()

        var currentTime = startTime

        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                currentTime += 1

                if currentTime >= duration {
                    await self.endActivity(showFinalState: true)
                    return
                }

                self.updateActivity(
                    currentTime: currentTime,
                    duration: duration,
                    isPlaying: true,
                    title: title,
                    contentType: contentType
                )
            }
        }
    }

    /// Stops periodic background updates
    func stopBackgroundUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    // MARK: - Activity State

    /// Returns whether there's an active Live Activity
    var hasActiveActivity: Bool {
        currentActivity != nil
    }

    /// Returns the ID of the current activity's session
    var currentSessionId: String? {
        currentActivity?.attributes.sessionId
    }
}
