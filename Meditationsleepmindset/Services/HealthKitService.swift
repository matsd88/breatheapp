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
                Task {
                    await requestAuthorization()
                    await loadWeeklyMindfulMinutes()
                }
            }
        }
    }

    struct DayMinutes: Identifiable {
        let id = UUID()
        let date: Date
        let minutes: Int
    }

    struct DaySleepData: Identifiable {
        let id = UUID()
        let date: Date
        let hoursSlept: Double
    }

    @Published var todayMindfulMinutes: Int = 0
    @Published var weeklyMindfulMinutes: [DayMinutes] = []
    @Published var sleepData: [DaySleepData] = []
    @Published var sleepHoursToday: Double = 0

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

        var typesToRead: Set<HKObjectType> = [mindfulType]
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            typesToRead.insert(sleepType)
        }
        if let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) {
            typesToRead.insert(heartRateType)
        }

        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
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

    func loadWeeklyMindfulMinutes() async {
        guard Self.isAvailable, isEnabled else { return }
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return }

        let calendar = Calendar.current
        let now = Date()
        guard let startOfWeek = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startOfWeek, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        do {
            let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
                let query = HKSampleQuery(
                    sampleType: mindfulType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: samples ?? [])
                    }
                }
                healthStore.execute(query)
            }

            // Group by day
            var dailyMinutes: [Date: Int] = [:]
            for sample in samples {
                let dayStart = calendar.startOfDay(for: sample.startDate)
                let minutes = Int(sample.endDate.timeIntervalSince(sample.startDate) / 60)
                dailyMinutes[dayStart, default: 0] += minutes
            }

            // Build 7-day array
            var weekly: [DayMinutes] = []
            for dayOffset in 0...6 {
                if let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) {
                    let dayStart = calendar.startOfDay(for: date)
                    weekly.append(DayMinutes(date: dayStart, minutes: dailyMinutes[dayStart] ?? 0))
                }
            }

            weeklyMindfulMinutes = weekly
            todayMindfulMinutes = dailyMinutes[calendar.startOfDay(for: now)] ?? 0
        } catch {
            #if DEBUG
            print("HealthKit read failed: \(error)")
            #endif
        }
    }

    func loadWeeklySleepData() async {
        guard Self.isAvailable, isEnabled else { return }
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: now)) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        do {
            let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
                let query = HKSampleQuery(
                    sampleType: sleepType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: samples ?? [])
                    }
                }
                healthStore.execute(query)
            }

            // Group by day, sum non-awake sleep hours
            var dailySeconds: [Date: TimeInterval] = [:]
            for sample in samples {
                guard let categorySample = sample as? HKCategorySample else { continue }
                // Skip "in bed" and "awake" categories — only count actual sleep
                let value = HKCategoryValueSleepAnalysis(rawValue: categorySample.value)
                if value == .inBed || value == .awake {
                    continue
                }
                let dayStart = calendar.startOfDay(for: categorySample.startDate)
                let duration = categorySample.endDate.timeIntervalSince(categorySample.startDate)
                dailySeconds[dayStart, default: 0] += duration
            }

            var result: [DaySleepData] = []
            for (date, seconds) in dailySeconds {
                result.append(DaySleepData(date: date, hoursSlept: seconds / 3600.0))
            }
            result.sort { $0.date < $1.date }

            sleepData = result
            sleepHoursToday = dailySeconds[calendar.startOfDay(for: now)] ?? 0
            sleepHoursToday /= 3600.0
        } catch {
            #if DEBUG
            print("HealthKit sleep read failed: \(error)")
            #endif
        }
    }

    func getHeartRateDuringSession(start: Date, end: Date) async -> (startHR: Int?, endHR: Int?, avgHR: Int?) {
        guard Self.isAvailable, isEnabled else { return (nil, nil, nil) }
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return (nil, nil, nil) }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        do {
            let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
                let query = HKSampleQuery(
                    sampleType: heartRateType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: samples ?? [])
                    }
                }
                healthStore.execute(query)
            }

            guard !samples.isEmpty else { return (nil, nil, nil) }

            let bpmUnit = HKUnit.count().unitDivided(by: .minute())
            let hrValues = samples.compactMap { sample -> Int? in
                guard let quantitySample = sample as? HKQuantitySample else { return nil }
                return Int(quantitySample.quantity.doubleValue(for: bpmUnit))
            }

            guard !hrValues.isEmpty else { return (nil, nil, nil) }

            let startHR = hrValues.first
            let endHR = hrValues.last
            let avgHR = hrValues.reduce(0, +) / hrValues.count

            return (startHR, endHR, avgHR)
        } catch {
            #if DEBUG
            print("HealthKit heart rate read failed: \(error)")
            #endif
            return (nil, nil, nil)
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
            // Refresh the weekly data after writing
            await loadWeeklyMindfulMinutes()
        } catch {
            #if DEBUG
            print("HealthKit write failed: \(error)")
            #endif
        }
    }
}
