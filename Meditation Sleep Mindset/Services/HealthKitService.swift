//
//  HealthKitService.swift
//  Meditation Sleep Mindset
//

import Foundation
import HealthKit

@MainActor
class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()

    @Published var isAuthorized = false
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "healthKitEnabled")
            if isEnabled && !isAuthorized {
                Task { await requestAuthorization() }
            }
        }
    }

    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "healthKitEnabled")
        checkAuthorizationStatus()
    }

    private func checkAuthorizationStatus() {
        guard Self.isAvailable else { return }
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return }
        let status = healthStore.authorizationStatus(for: mindfulType)
        isAuthorized = status == .sharingAuthorized
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        guard Self.isAvailable else { return false }

        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return false }
        let typesToShare: Set<HKSampleType> = [mindfulType]

        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: [])
            let status = healthStore.authorizationStatus(for: mindfulType)
            isAuthorized = status == .sharingAuthorized
            return isAuthorized
        } catch {
            #if DEBUG
            print("HealthKit authorization failed: \(error)")
            #endif
            return false
        }
    }

    func writeMindfulMinutes(start: Date, end: Date) async {
        guard isEnabled, isAuthorized else { return }
        guard Self.isAvailable else { return }

        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return }

        let sample = HKCategorySample(
            type: mindfulType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: start,
            end: end
        )

        do {
            try await healthStore.save(sample)
            #if DEBUG
            print("HealthKit: Saved \(Int(end.timeIntervalSince(start) / 60)) mindful minutes")
            #endif
        } catch {
            #if DEBUG
            print("HealthKit write failed: \(error)")
            #endif
        }
    }
}
