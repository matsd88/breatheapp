//
//  WatchSessionManager.swift
//  MeditationWatch
//
//  Manages breathing sessions and local state on Watch
//

import Foundation
import WatchKit
import HealthKit

@MainActor
class WatchSessionManager: ObservableObject {
    static let shared = WatchSessionManager()

    @Published var isBreathingSessionActive = false
    @Published var breathingSessionDuration: Int = 0
    @Published var todayMindfulMinutes: Int = 0

    private let healthStore = HKHealthStore()
    private var breathingTimer: Timer?
    private var breathingStartTime: Date?

    private init() {
        loadMindfulMinutes()
    }

    // MARK: - Breathing Session

    func startBreathingSession() {
        isBreathingSessionActive = true
        breathingStartTime = Date()
        breathingSessionDuration = 0

        breathingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.breathingSessionDuration += 1
            }
        }
    }

    func endBreathingSession() {
        breathingTimer?.invalidate()
        breathingTimer = nil
        isBreathingSessionActive = false

        let duration = breathingSessionDuration

        // Save to HealthKit
        if let startTime = breathingStartTime {
            saveMindfulMinutes(start: startTime, end: Date())
        }

        // Notify iOS app
        WatchConnectivityService.shared.sendBreathingSessionComplete(durationSeconds: duration)

        // Update local count
        let addedMinutes = max(1, duration / 60)
        todayMindfulMinutes += addedMinutes

        // Play success haptic
        WKInterfaceDevice.current().play(.success)

        breathingStartTime = nil
        breathingSessionDuration = 0
    }

    func cancelBreathingSession() {
        breathingTimer?.invalidate()
        breathingTimer = nil
        isBreathingSessionActive = false
        breathingStartTime = nil
        breathingSessionDuration = 0
    }

    // MARK: - HealthKit

    func loadMindfulMinutes() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession)!
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKSampleQuery(sampleType: mindfulType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, error in
            guard let samples = samples as? [HKCategorySample], error == nil else { return }

            let totalSeconds = samples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            let minutes = Int(totalSeconds / 60)

            Task { @MainActor in
                self?.todayMindfulMinutes = minutes
            }
        }

        healthStore.execute(query)
    }

    func saveMindfulMinutes(start: Date, end: Date) {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession)!

        // Request authorization first
        healthStore.requestAuthorization(toShare: [mindfulType], read: [mindfulType]) { [weak self] success, error in
            guard success else { return }

            let sample = HKCategorySample(
                type: mindfulType,
                value: HKCategoryValue.notApplicable.rawValue,
                start: start,
                end: end
            )

            self?.healthStore.save(sample) { success, error in
                #if DEBUG
                if let error {
                    print("Watch: Failed to save mindful minutes: \(error)")
                }
                #endif
            }
        }
    }

    func requestHealthKitAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }

        let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession)!

        do {
            try await healthStore.requestAuthorization(toShare: [mindfulType], read: [mindfulType])
            return true
        } catch {
            return false
        }
    }
}
