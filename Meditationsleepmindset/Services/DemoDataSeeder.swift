//
//  DemoDataSeeder.swift
//  Meditation Sleep Mindset
//
//  Seeds fake user data for App Store screenshots.
//  Activated by Constants.isDemoMode flag.
//

import Foundation
import SwiftData

@MainActor
enum DemoDataSeeder {

    private static let seededKey = "DemoDataSeeded"

    static func seed(
        in context: ModelContext,
        streakService: StreakService
    ) {
        // Only seed once per demo session
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }

        seedUserProfile(in: context)
        seedStreakData(streakService: streakService)
        seedSessions(in: context)
        seedFavorites(in: context)
        seedPlaylists(in: context)
        seedMoodHistory(in: context)
        seedBadges()
        seedChallenges()
        seedOnboardingDefaults()

        try? context.save()
        UserDefaults.standard.set(true, forKey: seededKey)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: seededKey)
    }

    // MARK: - User Profile

    private static func seedUserProfile(in context: ModelContext) {
        let descriptor = FetchDescriptor<UserProfile>()
        let profiles = (try? context.fetch(descriptor)) ?? []
        let profile = profiles.first ?? UserProfile()

        profile.selectedGoals = [
            UserGoal.reduceStress.rawValue,
            UserGoal.betterSleep.rawValue,
            UserGoal.increaseHappiness.rawValue
        ]
        profile.experienceLevel = ExperienceLevel.intermediate.rawValue
        profile.hasCompletedOnboarding = true
        profile.appOpenCount = 47
        profile.hasShownSharePrompt = true
        profile.hasShownRatingPrompt = true
        profile.totalMinutesMeditated = 1426
        profile.currentStreak = 12
        profile.longestStreak = 28
        profile.lastMeditationDate = Date()
        profile.isPremiumSubscriber = true
        profile.subscriptionExpiryDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())

        if profiles.isEmpty {
            context.insert(profile)
        }
    }

    // MARK: - Streak Service

    private static func seedStreakData(streakService: StreakService) {
        let defaults = UserDefaults.standard
        let calendar = Calendar.current
        let today = Date()

        // Persist to UserDefaults so loadStreakData() doesn't overwrite
        defaults.set(12, forKey: "currentStreak")
        defaults.set(28, forKey: "longestStreak")
        defaults.set(1426, forKey: "totalMinutes")
        defaults.set(86, forKey: "totalSessions")
        defaults.set(Date(), forKey: "lastSessionDate")

        // Build realistic weekly minutes keyed by date string
        let dailyMinutes = [15, 20, 8, 12, 18, 25, 10]  // 7 days, oldest first
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var weeklyMinutesDict: [String: Int] = [:]
        for i in (0..<7).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let key = dateFormatter.string(from: date)
            let minutes = dailyMinutes[6 - i]
            if minutes > 0 {
                weeklyMinutesDict[key] = minutes
            }
        }
        defaults.set(weeklyMinutesDict, forKey: "weeklyMinutes")

        // Now reload StreakService from the persisted data
        streakService.loadStreakData()
        streakService.meditatedToday = true
    }

    // MARK: - Sessions

    private static func seedSessions(in context: ModelContext) {
        let descriptor = FetchDescriptor<Content>()
        guard let allContent = try? context.fetch(descriptor), !allContent.isEmpty else { return }

        let calendar = Calendar.current
        let today = Date()
        let moods: [Mood] = [.calm, .happy, .energetic, .focused, .grateful]

        // Create ~30 sessions over the past 30 days
        let sessionDays = [0, 1, 2, 3, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 17, 18, 19, 20, 21, 22, 24, 25, 26, 27, 28, 29]
        for (index, daysAgo) in sessionDays.enumerated() {
            let content = allContent[index % allContent.count]
            let sessionDate = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            let hour = [7, 8, 12, 18, 21, 22][index % 6]
            let dateWithTime = calendar.date(bySettingHour: hour, minute: 30, second: 0, of: sessionDate) ?? sessionDate
            let duration = [300, 600, 900, 1200, 1500][index % 5]
            let listened = Int(Double(duration) * Double.random(in: 0.75...1.0))

            let session = MeditationSession(
                contentID: content.id,
                youtubeVideoID: content.youtubeVideoID,
                contentTitle: content.title,
                durationSeconds: duration,
                listenedSeconds: listened,
                wasCompleted: listened > Int(Double(duration) * 0.8),
                sessionType: "guided",
                completedAt: dateWithTime
            )

            // Add moods to recent sessions
            if daysAgo < 10 {
                session.preMood = Mood.stressed.rawValue
                session.postMood = moods[index % moods.count].rawValue
            }

            context.insert(session)
        }
    }

    // MARK: - Favorites

    private static func seedFavorites(in context: ModelContext) {
        let descriptor = FetchDescriptor<Content>()
        guard let allContent = try? context.fetch(descriptor), allContent.count >= 8 else { return }

        // Pick 8 varied content items as favorites
        let indices = [0, 5, 12, 20, 35, 50, 65, 80].map { min($0, allContent.count - 1) }
        for i in indices {
            let content = allContent[i]
            let fav = FavoriteContent(from: content)
            context.insert(fav)
        }
    }

    // MARK: - Playlists

    private static func seedPlaylists(in context: ModelContext) {
        let descriptor = FetchDescriptor<Content>()
        guard let allContent = try? context.fetch(descriptor), allContent.count >= 15 else { return }

        let sleepContent = allContent.filter { $0.contentType == .sleepStory || $0.contentType == .soundscape }
        let meditationContent = allContent.filter { $0.contentType == .meditation }
        let focusContent = allContent.filter { $0.contentType == .music || $0.contentType == .soundscape }

        // Playlist 1: Bedtime Wind Down
        let bedtime = Playlist(name: "Bedtime Wind Down")
        context.insert(bedtime)
        for (i, content) in sleepContent.prefix(5).enumerated() {
            let item = PlaylistItem(playlistID: bedtime.id, from: content, orderIndex: i)
            context.insert(item)
        }
        bedtime.coverYoutubeVideoID = sleepContent.first?.youtubeVideoID

        // Playlist 2: Morning Calm
        let morning = Playlist(name: "Morning Calm")
        context.insert(morning)
        for (i, content) in meditationContent.prefix(4).enumerated() {
            let item = PlaylistItem(playlistID: morning.id, from: content, orderIndex: i)
            context.insert(item)
        }
        morning.coverYoutubeVideoID = meditationContent.first?.youtubeVideoID

        // Playlist 3: Work Focus
        let focus = Playlist(name: "Work Focus")
        context.insert(focus)
        for (i, content) in focusContent.prefix(3).enumerated() {
            let item = PlaylistItem(playlistID: focus.id, from: content, orderIndex: i)
            context.insert(item)
        }
        focus.coverYoutubeVideoID = focusContent.first?.youtubeVideoID

        // Playlist 4: Stress Relief
        let stressRelief = Playlist(name: "Stress Relief")
        context.insert(stressRelief)
        let stressContent = meditationContent.dropFirst(4).prefix(4)
        for (i, content) in stressContent.enumerated() {
            let item = PlaylistItem(playlistID: stressRelief.id, from: content, orderIndex: i)
            context.insert(item)
        }
        stressRelief.coverYoutubeVideoID = stressContent.first?.youtubeVideoID
    }

    // MARK: - Mood History (Chat Sessions)

    private static func seedMoodHistory(in context: ModelContext) {
        let calendar = Calendar.current
        let today = Date()

        // Historical conversations (completed sessions)
        let pastConversations: [(MoodLevel, Int, [(ChatMessageRole, String)])] = [
            (.good, 1, [
                (.user, "Pretty good day so far"),
                (.assistant, "Glad to hear you're having a good day! 🙂 Is there anything specific you'd like to work on today — maybe some focus, relaxation, or gratitude?"),
                (.user, "I think some focus would be nice, I have a big presentation tomorrow"),
                (.assistant, "I've got you! Try a short mindfulness session to sharpen your focus. Before your presentation, take 3 deep breaths — in for 4, hold for 4, out for 6. It activates your parasympathetic nervous system and calms pre-presentation nerves. You're going to do great! 💪"),
            ]),
            (.great, 2, [
                (.user, "Really peaceful morning"),
                (.assistant, "There's something magical about a peaceful morning, isn't there? ☀️ Did you start with a meditation, or did the calm find you naturally today?"),
                (.user, "I woke up early and just sat with my coffee in silence for a while"),
                (.assistant, "That's a beautiful mindfulness practice in itself — being fully present with your coffee, the warmth, the quiet. Those small moments of intentional stillness can set the tone for your entire day. Maybe we can build on that peaceful energy with a short gratitude reflection?"),
            ]),
            (.good, 3, [
                (.user, "Feeling calm after a stressful day"),
                (.assistant, "It takes real strength to find calm after a stressful day. I'm proud of you for checking in! What helped you decompress?"),
                (.user, "I did the evening wind-down meditation you suggested last time"),
                (.assistant, "That's amazing that you came back to it! Consistency is where the real transformation happens. You're building a powerful habit — 12 days and counting on your streak! 🔥 How about we try a sleep story tonight to carry this calm into a restful sleep?"),
            ]),
            (.okay, 5, [
                (.user, "Just checking in"),
                (.assistant, "Hey, I appreciate you showing up even on a neutral day. That consistency matters more than you might think. 💜 Is there anything on your mind, or would you like a quick breathing exercise to reset?"),
                (.user, "A breathing exercise sounds nice"),
                (.assistant, "Let's do a simple 4-7-8 breath together. Breathe in through your nose for 4 counts, hold for 7, then exhale slowly through your mouth for 8. Try it 3 times. This technique was designed to calm your nervous system in under a minute. You've got this! 🌬️"),
            ]),
            (.great, 6, [
                (.user, "Best I've felt in weeks!"),
                (.assistant, "That's absolutely wonderful! 🎉 Your dedication to your practice is clearly paying off. What do you think has been making the difference?"),
                (.user, "I think meditating every morning is finally becoming a habit"),
                (.assistant, "That's the breakthrough moment! When meditation shifts from something you do to just part of who you are. Research shows it takes about 66 days to form a habit, and with your 12-day streak, you're well on your way. Keep nurturing this — your future self will thank you! ✨"),
            ]),
        ]

        // Seed completed past conversations
        for (mood, daysAgo, messages) in pastConversations {
            let sessionDate = calendar.date(byAdding: .day, value: -daysAgo, to: today)!

            let session = ChatSession()
            session.startedAt = sessionDate
            session.moodLevelRaw = mood.rawValue
            session.messageCount = messages.count
            session.isActive = false
            session.endedAt = sessionDate
            context.insert(session)

            for (msgIndex, (role, content)) in messages.enumerated() {
                let msg = ChatMessage(
                    sessionID: session.id,
                    role: role,
                    type: .text,
                    content: content
                )
                msg.timestamp = sessionDate.addingTimeInterval(TimeInterval(msgIndex * 30))
                context.insert(msg)
            }
        }

        // Seed today's ACTIVE conversation (shows as current chat)
        let todaySession = ChatSession()
        todaySession.startedAt = today
        todaySession.moodLevelRaw = MoodLevel.good.rawValue
        todaySession.isActive = true
        todaySession.endedAt = nil
        context.insert(todaySession)

        let todayMessages: [(ChatMessageRole, String)] = [
            (.assistant, "Glad you're doing well today! 🙂 Is there anything specific on your mind, or would you like a recommendation?"),
            (.user, "I've been having trouble sleeping lately, any tips?"),
            (.assistant, "Absolutely — sleep is so important for your wellbeing. Here are a few things that can help:\n\n1. Try a **body scan meditation** before bed to release physical tension\n2. Keep a consistent bedtime, even on weekends\n3. Put screens away 30 minutes before sleep\n\nI'd recommend starting with the Bedtime Wind Down playlist tonight. Would you like me to suggest a specific sleep story?"),
            (.user, "Yes please! Something calming with nature sounds"),
            (.assistant, "Great choice! Nature sounds are wonderful for sleep. I'd suggest trying \"Ocean Tide\" — it combines gentle wave sounds with a soothing narration that helps your mind drift off. Many people find that ocean sounds sync with their breathing naturally.\n\nYou could also pair it with the sleep timer so it fades out after you fall asleep. Would you like to explore some breathing exercises to do beforehand? 🌊"),
            (.user, "That sounds perfect, I'll try it tonight"),
            (.assistant, "You've got a great plan! Here's your wind-down routine for tonight:\n\n🌙 30 min before bed — put screens away\n🫁 4-7-8 breathing — 3 rounds\n🌊 Play \"Ocean Tide\" with the sleep timer set to 45 min\n\nI'll check in with you tomorrow to see how it went. Sweet dreams! 💤"),
        ]

        todaySession.messageCount = todayMessages.count

        for (msgIndex, (role, content)) in todayMessages.enumerated() {
            let msg = ChatMessage(
                sessionID: todaySession.id,
                role: role,
                type: .text,
                content: content
            )
            msg.timestamp = today.addingTimeInterval(TimeInterval(msgIndex * 45))
            context.insert(msg)
        }
    }

    // MARK: - Badges

    private static func seedBadges() {
        let badgeIDs = [
            "first_step", "week_warrior", "two_week_triumph",
            "getting_started", "dedicated",
            "first_hour", "five_hours",
            "night_owl", "music_lover", "explorer", "early_bird",
            "curator", "collector", "sharing_is_caring"
        ]

        var dates: [String: Date] = [:]
        let calendar = Calendar.current
        let today = Date()
        for (i, id) in badgeIDs.enumerated() {
            dates[id] = calendar.date(byAdding: .day, value: -(badgeIDs.count - i) * 2, to: today)!
        }

        UserDefaults.standard.set(badgeIDs, forKey: "earnedBadgeIDs")
        UserDefaults.standard.set(dates, forKey: "badgeDates")

        // Reload badges
        BadgeService.shared.reloadBadges()
    }

    // MARK: - Challenges

    private static func seedChallenges() {
        let weekStart = Challenge.currentWeekStart()
        let weekEnd = Challenge.currentWeekEnd()

        // Use existing templates and set progress
        var consistent = Challenge.consistent(weekStart: weekStart, weekEnd: weekEnd)
        consistent.progress = 3

        var deepDive = Challenge.deepDive(weekStart: weekStart, weekEnd: weekEnd)
        deepDive.progress = 42

        var explorer = Challenge.explorer(weekStart: weekStart, weekEnd: weekEnd)
        explorer.progress = 2

        var melodySeeker = Challenge.melodySeeker(weekStart: weekStart, weekEnd: weekEnd)
        melodySeeker.progress = 3

        let challenges = [consistent, deepDive, explorer, melodySeeker]

        if let data = try? JSONEncoder().encode(challenges) {
            UserDefaults.standard.set(data, forKey: "challenge_active")
        }
        UserDefaults.standard.set(485, forKey: "challenge_totalXP")

        // One completed challenge
        var morningPerson = Challenge.morningPerson(weekStart: weekStart, weekEnd: weekEnd)
        morningPerson.progress = morningPerson.target
        morningPerson.isCompleted = true

        if let data = try? JSONEncoder().encode([morningPerson]) {
            UserDefaults.standard.set(data, forKey: "challenge_completed")
        }

        ChallengeService.shared.reloadChallenges()
    }

    // MARK: - Onboarding Defaults

    private static func seedOnboardingDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "hasCompletedOnboarding")
        defaults.set(47, forKey: "appOpenCount")
        defaults.set("I can't sleep", forKey: "userPainPoint")
        defaults.set(true, forKey: "showMoodCheckIn")

        // Set premium state
        AppStateManager.shared.hasCompletedOnboarding = true
    }
}
