//
//  ProgramRepository.swift
//  Meditation Sleep Mindset
//

import Foundation
import SwiftData

@MainActor
class ProgramRepository {
    static let shared = ProgramRepository()

    /// Bump this whenever programs are added to `programSpecs` so existing
    /// installs (which already have programs seeded) pick up the new ones.
    private static let currentProgramsVersion = 2
    private static let programsVersionKey = "programsVersion"

    private init() {}

    // MARK: - Program Specs

    private struct ProgramSpec {
        let name: String
        let description: String
        let category: ContentType
        let iconName: String
        let isPremium: Bool
        /// (day title, youtubeVideoID) — IDs must exist in ContentRepository's active sampleContent.
        let days: [(String, String)]
    }

    private var programSpecs: [ProgramSpec] {
        [
            ProgramSpec(
                name: "7 Days of Calm",
                description: "Build a daily meditation habit with gentle guided sessions that reduce stress and bring inner peace.",
                category: .meditation,
                iconName: "leaf.fill",
                isPremium: false,
                days: [
                    ("Day 1: Arriving", "qJPyuTQOkfk"),
                    ("Day 2: Breath Focus", "3Eq1tetWUeM"),
                    ("Day 3: Body Awareness", "69o0P7s8GHE"),
                    ("Day 4: Letting Go", "DdL9-NhXL6k"),
                    ("Day 5: Gratitude", "3RxXiFgkxGc"),
                    ("Day 6: Inner Peace", "2K4T9HmEhWE"),
                    ("Day 7: Integration", "yg3CJ7Zb55o"),
                ]
            ),
            ProgramSpec(
                name: "Sleep Better in 5 Days",
                description: "Transform your sleep with nightly guided meditations designed to help you fall asleep faster and sleep deeper.",
                category: .sleepStory,
                iconName: "moon.stars.fill",
                isPremium: false,
                days: [
                    ("Night 1: Release the Day", "Pn5xH3zu0Sc"),
                    ("Night 2: Deep Relaxation", "U6Ay9v7gK9w"),
                    ("Night 3: Sleep Journey", "4BWgI64GM4A"),
                    ("Night 4: Peaceful Dreams", "6arfMc9Aj4k"),
                    ("Night 5: Deep Rest", "5mOZMxVKmiY"),
                ]
            ),
            ProgramSpec(
                name: "Stress Relief Foundations",
                description: "Learn essential techniques to manage stress, reduce anxiety, and build resilience in just 5 sessions.",
                category: .meditation,
                iconName: "heart.fill",
                isPremium: false,
                days: [
                    ("Day 1: Grounding", "g0jfhRcXtLQ"),
                    ("Day 2: Stress Release", "2FnFXq6Z13Q"),
                    ("Day 3: Anxiety Calm", "4jiMhmGInJ8"),
                    ("Day 4: Tension Release", "5mOZMxVKmiY"),
                    ("Day 5: Inner Strength", "3SutlEy_MT8"),
                ]
            ),
            ProgramSpec(
                name: "Self-Love Journey",
                description: "Cultivate self-compassion, build confidence, and develop a loving relationship with yourself.",
                category: .meditation,
                iconName: "sparkle",
                isPremium: true,
                days: [
                    ("Day 1: Self-Acceptance", "7Ep5mKuRmAA"),
                    ("Day 2: Self-Love", "0y1DrTURM2Q"),
                    ("Day 3: Loving Kindness", "lE38ONyzTLQ"),
                    ("Day 4: Confidence", "3SutlEy_MT8"),
                    ("Day 5: Heart Opening", "5aBmmH97JGQ"),
                ]
            ),
            ProgramSpec(
                name: "Energy & Focus",
                description: "Boost your energy, sharpen focus, and perform at your best with these activating practices.",
                category: .meditation,
                iconName: "bolt.fill",
                isPremium: true,
                days: [
                    ("Day 1: Morning Energy", "1vx8iUvfyCY"),
                    ("Day 2: Focus", "Jyy0ra2WcQQ"),
                    ("Day 3: Intention Setting", "4jNV1FV-_Os"),
                    ("Day 4: Recharge", "4vpQNYthrIc"),
                    ("Day 5: Peak Performance", "6p_yaNFSYao"),
                ]
            ),

            // MARK: v2 programs

            ProgramSpec(
                name: "7 Nights of Deep Sleep",
                description: "A week of nightly practices that guide you from winding down to the deepest, most restorative sleep of your life.",
                category: .sleepStory,
                iconName: "moon.zzz.fill",
                isPremium: false,
                days: [
                    ("Night 1: Wind Down", "7WnZisfYMsE"),
                    ("Night 2: Body at Rest", "n4F55PPwC-U"),
                    ("Night 3: Breathe Into Sleep", "Uhb4RfUvHTE"),
                    ("Night 4: Quiet the Mind", "COhxZBvTHp0"),
                    ("Night 5: Drift Away", "FU8E7GeGs1Y"),
                    ("Night 6: Sleep Sanctuary", "h-joLSBALrs"),
                    ("Night 7: Among the Stars", "54MvgUqkHlo"),
                ]
            ),
            ProgramSpec(
                name: "5 Days of Focus",
                description: "Train your attention like a muscle. Five short daily sessions to cut through mental fog and sharpen deep concentration.",
                category: .meditation,
                iconName: "scope",
                isPremium: true,
                days: [
                    ("Day 1: Morning Clarity", "QHkXvPq2pQE"),
                    ("Day 2: The Power of Breath", "n6RbW2LtdFs"),
                    ("Day 3: Laser Focus", "6TH2hY1s-Oc"),
                    ("Day 4: Midday Reset", "DFEnruF-dts"),
                    ("Day 5: The Clear Mind", "5FLEs8UirNA"),
                ]
            ),
            ProgramSpec(
                name: "7 Days of Gratitude",
                description: "Rewire your mind for happiness. A week of gratitude practices proven to lift mood, deepen joy, and improve sleep.",
                category: .meditation,
                iconName: "sun.max.fill",
                isPremium: true,
                days: [
                    ("Day 1: A Grateful Morning", "E5NsiC7OaQ8"),
                    ("Day 2: Finding Joy", "9taYu6VdhJM"),
                    ("Day 3: Compassion for Others", "DbDoBzGY3vo"),
                    ("Day 4: Greeting the Day", "ENYYb5vIMkU"),
                    ("Day 5: Opening to Abundance", "6AkEAKtL7a8"),
                    ("Day 6: Positive Energy", "6W31vHDjyng"),
                    ("Day 7: Grateful Rest", "pgpk3NSrkuc"),
                ]
            ),
            ProgramSpec(
                name: "5 Days of Anxiety Relief",
                description: "Gentle, practical sessions to calm a worried mind, soothe your nervous system, and return to the present moment.",
                category: .meditation,
                iconName: "wind",
                isPremium: false,
                days: [
                    ("Day 1: Meeting the Worry", "c0aqDu8Dmvo"),
                    ("Day 2: Quick Calm", "9TBpGiTrra8"),
                    ("Day 3: Back to Now", "FGO8IWiusJo"),
                    ("Day 4: Dissolving Anxiety", "MR57rug8NsM"),
                    ("Day 5: Deepest Calm", "_0SKuDcvszU"),
                ]
            ),
        ]
    }

    // MARK: - Seeding

    /// Seed programs on first launch, and insert any newly-added programs
    /// (by name) on existing installs when the programs version bumps.
    /// Idempotent: never duplicates programs, never touches ProgramProgress.
    func seedIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<Program>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        let storedVersion = UserDefaults.standard.integer(forKey: Self.programsVersionKey)

        guard count == 0 || storedVersion < Self.currentProgramsVersion else { return }

        // Only stamp the version when seeding actually succeeded — stamping
        // after a failed fetch/save would permanently skip the new programs
        // (or duplicate everything on a blind retry).
        if insertMissingPrograms(in: context) {
            UserDefaults.standard.set(Self.currentProgramsVersion, forKey: Self.programsVersionKey)
        }
    }

    /// Returns true when the catalog reached the desired state (the existing
    /// check succeeded and any needed inserts were saved).
    private func insertMissingPrograms(in context: ModelContext) -> Bool {
        guard let existing = try? context.fetch(FetchDescriptor<Program>()) else {
            // Can't tell what exists — inserting blindly would duplicate.
            return false
        }
        let existingNames = Set(existing.map { $0.name })

        var insertedAny = false
        for spec in programSpecs where !existingNames.contains(spec.name) {
            let program = Program(
                name: spec.name,
                description: spec.description,
                totalDays: spec.days.count,
                category: spec.category,
                iconName: spec.iconName,
                isPremium: spec.isPremium
            )
            context.insert(program)

            for (i, (title, videoID)) in spec.days.enumerated() {
                let day = ProgramDay(programID: program.id, dayNumber: i + 1, youtubeVideoID: videoID, title: title)
                context.insert(day)
            }
            insertedAny = true
        }

        if insertedAny {
            do {
                try context.save()
            } catch {
                return false
            }
        }
        return true
    }
}
