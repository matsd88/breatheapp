//
//  HeartRateMonitor.swift
//  MeditationWatch
//
//  Monitors heart rate and suggests breathing exercises when elevated.
//

import Foundation
import HealthKit
import WatchKit
import Combine

@MainActor
class HeartRateMonitor: ObservableObject {
    static let shared = HeartRateMonitor()

    @Published var currentHeartRate: Int = 0
    @Published var shouldSuggestBreathing: Bool = false
    @Published var isAuthorized: Bool = false

    private let healthStore = HKHealthStore()
    private var query: HKAnchoredObjectQuery?
    private var suggestionDismissedUntil: Date?

    // Thresholds
    private let elevatedHeartRateThreshold = 90 // bpm
    private let suggestionCooldown: TimeInterval = 30 * 60 // 30 minutes

    init() {
        checkAuthorization()
    }

    // MARK: - Authorization

    private func checkAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            isAuthorized = false
            return
        }

        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

        healthStore.getRequestStatusForAuthorization(toShare: [], read: [heartRateType]) { status, error in
            Task { @MainActor in
                self.isAuthorized = (status == .unnecessary)
            }
        }
    }

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }

        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

        do {
            try await healthStore.requestAuthorization(toShare: [], read: [heartRateType])
            isAuthorized = true
            return true
        } catch {
            print("HealthKit authorization failed: \(error)")
            return false
        }
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

        // Check authorization first
        healthStore.getRequestStatusForAuthorization(toShare: [], read: [heartRateType]) { [weak self] status, error in
            guard status == .unnecessary else { return }

            Task { @MainActor in
                self?.startHeartRateQuery()
            }
        }
    }

    private func startHeartRateQuery() {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

        // Get recent heart rate samples
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-60), // Last minute
            end: Date(),
            options: .strictStartDate
        )

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else { return }

            let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
            let heartRate = Int(sample.quantity.doubleValue(for: heartRateUnit))

            Task { @MainActor in
                self?.updateHeartRate(heartRate)
            }
        }

        healthStore.execute(query)

        // Also set up anchored query for real-time updates
        setupAnchoredQuery()
    }

    private func setupAnchoredQuery() {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, error in
            guard let sample = samples?.last as? HKQuantitySample else { return }

            let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
            let heartRate = Int(sample.quantity.doubleValue(for: heartRateUnit))

            Task { @MainActor in
                self?.updateHeartRate(heartRate)
            }
        }

        query.updateHandler = { [weak self] _, samples, _, _, error in
            guard let sample = samples?.last as? HKQuantitySample else { return }

            let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
            let heartRate = Int(sample.quantity.doubleValue(for: heartRateUnit))

            Task { @MainActor in
                self?.updateHeartRate(heartRate)
            }
        }

        self.query = query
        healthStore.execute(query)
    }

    func stopMonitoring() {
        if let query = query {
            healthStore.stop(query)
            self.query = nil
        }
    }

    // MARK: - Heart Rate Updates

    private func updateHeartRate(_ heartRate: Int) {
        currentHeartRate = heartRate

        // Check if we should suggest breathing
        if heartRate >= elevatedHeartRateThreshold {
            // Check cooldown
            if let dismissedUntil = suggestionDismissedUntil, Date() < dismissedUntil {
                shouldSuggestBreathing = false
            } else {
                shouldSuggestBreathing = true
                // Play haptic to alert user
                WKInterfaceDevice.current().play(.notification)
            }
        } else {
            shouldSuggestBreathing = false
        }
    }

    func dismissSuggestion() {
        shouldSuggestBreathing = false
        suggestionDismissedUntil = Date().addingTimeInterval(suggestionCooldown)
    }
}
