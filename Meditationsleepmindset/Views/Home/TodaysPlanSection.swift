//
//  TodaysPlanSection.swift
//  Meditation Sleep Mindset
//
//  "Your Plan for Today" — a deterministic, personalized 3-step daily plan:
//  a short morning meditation, a midday breathing reset, and an evening
//  wind-down (sleep story / soundscape). Selection is seeded by the calendar
//  day (stable within a day, changes daily), informed by the current mood
//  selection, and persisted to UserDefaults so the plan never reshuffles
//  mid-day. Step completion is tracked per-day in UserDefaults and also
//  auto-detected when the step's content was played today.
//

import SwiftUI

struct TodaysPlanSection: View {
    let allContent: [Content]
    let sessions: [MeditationSession]
    let favoriteContents: [Content]
    let selectedMood: Mood?
    let isSubscribed: Bool
    let onPlay: (Content) -> Void

    // Resolved once per render in init — deterministic + persisted, so stable.
    private let morningContent: Content?
    private let eveningContent: Content?

    @State private var completedStepIDs: Set<String>
    @State private var showBreathing = false

    init(
        allContent: [Content],
        sessions: [MeditationSession],
        favoriteContents: [Content],
        selectedMood: Mood?,
        isSubscribed: Bool,
        onPlay: @escaping (Content) -> Void
    ) {
        self.allContent = allContent
        self.sessions = sessions
        self.favoriteContents = favoriteContents
        self.selectedMood = selectedMood
        self.isSubscribed = isSubscribed
        self.onPlay = onPlay

        // resolvePlan clears stale completion state on day rollover,
        // so it must run before loading completed steps.
        let plan = TodaysPlanSection.resolvePlan(
            allContent: allContent,
            sessions: sessions,
            favoriteContents: favoriteContents,
            mood: selectedMood,
            isSubscribed: isSubscribed
        )
        self.morningContent = plan.morning
        self.eveningContent = plan.evening
        _completedStepIDs = State(initialValue: TodaysPlanSection.loadCompletedSteps())
    }

    // MARK: - Step identifiers

    private enum StepID {
        static let morning = "morning"
        static let midday = "midday"
        static let evening = "evening"
    }

    // MARK: - UserDefaults keys (single set of keys, day-stamped)

    private enum Keys {
        static let day = "todaysPlanDay"
        static let morningID = "todaysPlanMorningVideoID"
        static let eveningID = "todaysPlanEveningVideoID"
        static let completed = "todaysPlanCompletedSteps"
    }

    /// Also used by HomeView as the section's `.id` so the whole section's
    /// @State (completion checkmarks) resets at day rollover — @State survives
    /// re-inits, so without an identity change yesterday's checkmarks would
    /// linger after midnight.
    static var todayKey: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: - Completion

    private var playedTodayVideoIDs: Set<String> {
        Set(
            sessions
                .filter { Calendar.current.isDateInToday($0.startedAt) }
                .compactMap { $0.youtubeVideoID }
        )
    }

    private func isComplete(_ stepID: String, videoID: String?) -> Bool {
        if completedStepIDs.contains(stepID) { return true }
        if let videoID, playedTodayVideoIDs.contains(videoID) { return true }
        return false
    }

    private func markComplete(_ stepID: String) {
        guard !completedStepIDs.contains(stepID) else { return }
        completedStepIDs.insert(stepID)
        UserDefaults.standard.set(Array(completedStepIDs), forKey: Keys.completed)
    }

    private static func loadCompletedSteps() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Keys.completed) ?? [])
    }

    private var totalSteps: Int {
        1 + (morningContent != nil ? 1 : 0) + (eveningContent != nil ? 1 : 0)
    }

    private var completedCount: Int {
        var count = 0
        if let m = morningContent, isComplete(StepID.morning, videoID: m.youtubeVideoID) { count += 1 }
        if isComplete(StepID.midday, videoID: nil) { count += 1 }
        if let e = eveningContent, isComplete(StepID.evening, videoID: e.youtubeVideoID) { count += 1 }
        return count
    }

    // MARK: - Body

    var body: some View {
        // Hide gracefully on a fresh install with no library content.
        if morningContent != nil || eveningContent != nil {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Your Plan for Today")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.textPrimary)

                    Spacer()

                    Text("\(completedCount) of \(totalSteps) complete")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.horizontal)

                VStack(spacing: 0) {
                    if let morning = morningContent {
                        planRow(
                            icon: "sunrise.fill",
                            tint: .orange,
                            title: morning.title,
                            subtitle: contentSubtitle(prefix: String(localized: "Morning"), content: morning),
                            isDone: isComplete(StepID.morning, videoID: morning.youtubeVideoID)
                        ) {
                            markComplete(StepID.morning)
                            onPlay(morning)
                        }

                        rowDivider
                    }

                    planRow(
                        icon: "wind",
                        tint: .mint,
                        title: String(localized: "Quick breathing reset"),
                        subtitle: String(localized: "Midday · Haptic guided breathing"),
                        isDone: isComplete(StepID.midday, videoID: nil)
                    ) {
                        markComplete(StepID.midday)
                        showBreathing = true
                    }

                    if let evening = eveningContent {
                        rowDivider

                        planRow(
                            icon: "moon.stars.fill",
                            tint: .indigo,
                            title: evening.title,
                            subtitle: contentSubtitle(prefix: String(localized: "Evening"), content: evening),
                            isDone: isComplete(StepID.evening, videoID: evening.youtubeVideoID)
                        ) {
                            markComplete(StepID.evening)
                            onPlay(evening)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
            .sheet(isPresented: $showBreathing) {
                HapticBreathingView()
            }
        }
    }

    private var rowDivider: some View {
        Divider()
            .overlay(Color.white.opacity(0.08))
    }

    private func contentSubtitle(prefix: String, content: Content) -> String {
        let duration = content.durationFormatted
        if duration.isEmpty {
            return "\(prefix) · \(content.contentType.displayName)"
        }
        return "\(prefix) · \(duration) · \(content.contentType.displayName)"
    }

    private func planRow(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String,
        isDone: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isDone ? Color.white.opacity(0.5) : .white)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isDone ? Color.green : Color.white.opacity(0.3))
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isDone ? "\(title), completed" : title)
    }

    // MARK: - Plan selection (deterministic, seeded by calendar day)

    private static func resolvePlan(
        allContent: [Content],
        sessions: [MeditationSession],
        favoriteContents: [Content],
        mood: Mood?,
        isSubscribed: Bool
    ) -> (morning: Content?, evening: Content?) {
        let defaults = UserDefaults.standard
        let day = todayKey

        // Day rollover: clear yesterday's selection + completion.
        if defaults.string(forKey: Keys.day) != day {
            defaults.set(day, forKey: Keys.day)
            defaults.removeObject(forKey: Keys.morningID)
            defaults.removeObject(forKey: Keys.eveningID)
            defaults.removeObject(forKey: Keys.completed)
        }

        guard !allContent.isEmpty else { return (nil, nil) }

        // Reuse today's persisted picks so the plan never reshuffles mid-day
        // (e.g. after the user plays a step or changes their mood).
        var morning = storedContent(forKey: Keys.morningID, in: allContent)
        var evening = storedContent(forKey: Keys.eveningID, in: allContent)
        if morning != nil && evening != nil { return (morning, evening) }

        let daySeed = UInt64(bitPattern: Int64(Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 1))
        let playedVideoIDs = Set(sessions.compactMap { $0.youtubeVideoID })
        let favoriteTypes = Set(favoriteContents.map { $0.contentType })
        let moodTags = tags(for: mood)
        let allowed: (Content) -> Bool = { isSubscribed || !$0.isPremium }

        if morning == nil {
            // Short guided meditation (≤ ~15 min); relax the duration cap if needed.
            var pool = allContent.filter {
                $0.contentType == .meditation && allowed($0)
                    && $0.durationSeconds > 0 && $0.durationSeconds <= 16 * 60
            }
            if pool.isEmpty {
                pool = allContent.filter { $0.contentType == .meditation && allowed($0) }
            }
            morning = pick(
                from: pool,
                seed: daySeed &* 31 &+ 1,
                playedVideoIDs: playedVideoIDs,
                favoriteTypes: favoriteTypes,
                preferredTags: moodTags.isEmpty ? ["morning", "focus", "calm"] : moodTags,
                boostedType: nil
            )
            if let m = morning { defaults.set(m.youtubeVideoID, forKey: Keys.morningID) }
        }

        if evening == nil {
            // Wind-down: sleep story or soundscape; fall back to ASMR / music.
            var pool = allContent.filter {
                ($0.contentType == .sleepStory || $0.contentType == .soundscape) && allowed($0)
            }
            if pool.isEmpty {
                pool = allContent.filter {
                    ($0.contentType == .asmr || $0.contentType == .music) && allowed($0)
                }
            }
            evening = pick(
                from: pool,
                seed: daySeed &* 31 &+ 2,
                playedVideoIDs: playedVideoIDs,
                favoriteTypes: favoriteTypes,
                preferredTags: ["sleep", "relax", "calm"],
                boostedType: .sleepStory
            )
            if let e = evening { defaults.set(e.youtubeVideoID, forKey: Keys.eveningID) }
        }

        return (morning, evening)
    }

    private static func storedContent(forKey key: String, in allContent: [Content]) -> Content? {
        guard let videoID = UserDefaults.standard.string(forKey: key) else { return nil }
        return allContent.first { $0.youtubeVideoID == videoID }
    }

    /// Score the pool (prefer un-played items, favorited categories, and mood/context
    /// tags), then pick one of the top candidates with a day-seeded RNG.
    private static func pick(
        from pool: [Content],
        seed: UInt64,
        playedVideoIDs: Set<String>,
        favoriteTypes: Set<ContentType>,
        preferredTags: [String],
        boostedType: ContentType?
    ) -> Content? {
        guard !pool.isEmpty else { return nil }

        let lowercasedTags = preferredTags.map { $0.lowercased() }

        func score(_ content: Content) -> Int {
            var s = 0
            if !playedVideoIDs.contains(content.youtubeVideoID) { s += 3 }
            if favoriteTypes.contains(content.contentType) { s += 1 }
            if let boostedType, content.contentType == boostedType { s += 1 }
            for tag in content.tags {
                let lower = tag.lowercased()
                if lowercasedTags.contains(where: { lower.contains($0) }) {
                    s += 2
                    break
                }
            }
            return s
        }

        // Deterministic ordering: score desc, then stable tie-break by video ID.
        let ranked = pool
            .map { (content: $0, score: score($0)) }
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.content.youtubeVideoID < $1.content.youtubeVideoID
            }

        var rng = SeededRandomNumberGenerator(seed: seed)
        let topCandidates = ranked.prefix(5).map { $0.content }
        return topCandidates.randomElement(using: &rng)
    }

    private static func tags(for mood: Mood?) -> [String] {
        switch mood {
        case .anxious, .stressed:
            return ["anxiety", "stress", "calm"]
        case .tired:
            return ["sleep", "relax"]
        case .focused:
            return ["focus", "performance"]
        case .energetic:
            return ["energy", "morning"]
        case .sad:
            return ["happiness", "gratitude"]
        case .happy, .grateful:
            return ["gratitude", "happiness"]
        case .calm:
            return ["calm", "relax"]
        case nil:
            return []
        }
    }
}
