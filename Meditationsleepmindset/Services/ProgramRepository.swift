//
//  ProgramRepository.swift
//  Meditation Sleep Mindset
//

import Foundation
import SwiftData

@MainActor
class ProgramRepository {
    static let shared = ProgramRepository()

    private init() {}

    /// Seed programs if none exist
    func seedIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<Program>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        seedPrograms(in: context)
    }

    private func seedPrograms(in context: ModelContext) {
        // Program 1: 7 Days of Calm
        let calm7 = Program(
            name: "7 Days of Calm",
            description: "Build a daily meditation habit with gentle guided sessions that reduce stress and bring inner peace.",
            totalDays: 7,
            category: .meditation,
            iconName: "leaf.fill"
        )
        context.insert(calm7)

        let calm7Days: [(String, String)] = [
            ("Day 1: Arriving", "qJPyuTQOkfk"),
            ("Day 2: Breath Focus", "3Eq1tetWUeM"),
            ("Day 3: Body Awareness", "69o0P7s8GHE"),
            ("Day 4: Letting Go", "DdL9-NhXL6k"),
            ("Day 5: Gratitude", "3RxXiFgkxGc"),
            ("Day 6: Inner Peace", "2K4T9HmEhWE"),
            ("Day 7: Integration", "yg3CJ7Zb55o"),
        ]
        for (i, (title, videoID)) in calm7Days.enumerated() {
            let day = ProgramDay(programID: calm7.id, dayNumber: i + 1, youtubeVideoID: videoID, title: title)
            context.insert(day)
        }

        // Program 2: Sleep Better in 5 Days
        let sleep5 = Program(
            name: "Sleep Better in 5 Days",
            description: "Transform your sleep with nightly guided meditations designed to help you fall asleep faster and sleep deeper.",
            totalDays: 5,
            category: .sleepStory,
            iconName: "moon.stars.fill"
        )
        context.insert(sleep5)

        let sleep5Days: [(String, String)] = [
            ("Night 1: Release the Day", "Pn5xH3zu0Sc"),
            ("Night 2: Deep Relaxation", "U6Ay9v7gK9w"),
            ("Night 3: Sleep Journey", "4BWgI64GM4A"),
            ("Night 4: Peaceful Dreams", "6arfMc9Aj4k"),
            ("Night 5: Deep Rest", "5mOZMxVKmiY"),
        ]
        for (i, (title, videoID)) in sleep5Days.enumerated() {
            let day = ProgramDay(programID: sleep5.id, dayNumber: i + 1, youtubeVideoID: videoID, title: title)
            context.insert(day)
        }

        // Program 3: Stress Relief Foundations
        let stress = Program(
            name: "Stress Relief Foundations",
            description: "Learn essential techniques to manage stress, reduce anxiety, and build resilience in just 5 sessions.",
            totalDays: 5,
            category: .meditation,
            iconName: "heart.fill"
        )
        context.insert(stress)

        let stressDays: [(String, String)] = [
            ("Day 1: Grounding", "g0jfhRcXtLQ"),
            ("Day 2: Stress Release", "2FnFXq6Z13Q"),
            ("Day 3: Anxiety Calm", "4jiMhmGInJ8"),
            ("Day 4: Tension Release", "5mOZMxVKmiY"),
            ("Day 5: Inner Strength", "3SutlEy_MT8"),
        ]
        for (i, (title, videoID)) in stressDays.enumerated() {
            let day = ProgramDay(programID: stress.id, dayNumber: i + 1, youtubeVideoID: videoID, title: title)
            context.insert(day)
        }

        // Program 4: Self-Love Journey
        let selfLove = Program(
            name: "Self-Love Journey",
            description: "Cultivate self-compassion, build confidence, and develop a loving relationship with yourself.",
            totalDays: 5,
            category: .meditation,
            iconName: "sparkle",
            isPremium: true
        )
        context.insert(selfLove)

        let selfLoveDays: [(String, String)] = [
            ("Day 1: Self-Acceptance", "7Ep5mKuRmAA"),
            ("Day 2: Self-Love", "0y1DrTURM2Q"),
            ("Day 3: Loving Kindness", "lE38ONyzTLQ"),
            ("Day 4: Confidence", "3SutlEy_MT8"),
            ("Day 5: Heart Opening", "5aBmmH97JGQ"),
        ]
        for (i, (title, videoID)) in selfLoveDays.enumerated() {
            let day = ProgramDay(programID: selfLove.id, dayNumber: i + 1, youtubeVideoID: videoID, title: title)
            context.insert(day)
        }

        // Program 5: Energy & Focus
        let energy = Program(
            name: "Energy & Focus",
            description: "Boost your energy, sharpen focus, and perform at your best with these activating practices.",
            totalDays: 5,
            category: .meditation,
            iconName: "bolt.fill",
            isPremium: true
        )
        context.insert(energy)

        let energyDays: [(String, String)] = [
            ("Day 1: Morning Energy", "1vx8iUvfyCY"),
            ("Day 2: Focus", "Jyy0ra2WcQQ"),
            ("Day 3: Intention Setting", "4jNV1FV-_Os"),
            ("Day 4: Recharge", "4vpQNYthrIc"),
            ("Day 5: Peak Performance", "6p_yaNFSYao"),
        ]
        for (i, (title, videoID)) in energyDays.enumerated() {
            let day = ProgramDay(programID: energy.id, dayNumber: i + 1, youtubeVideoID: videoID, title: title)
            context.insert(day)
        }

        try? context.save()
    }
}
