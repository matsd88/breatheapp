//
//  ChatService.swift
//  Meditation Sleep Mindset
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
class ChatService: ObservableObject {
    static let shared = ChatService()

    // MARK: - Published State
    @Published var currentSession: ChatSession?
    @Published var messages: [ChatMessage] = []           // Current session messages
    @Published var chatHistory: [ChatHistoryItem] = []    // All messages with date dividers
    @Published var isLoading: Bool = false
    @Published var showCrisisAlert: Bool = false
    @Published var error: String?
    @Published var showError: Bool = false
    @Published var needsMoodCheckIn: Bool = true
    @Published var messagesSentCount: Int

    /// Selected domain-specific coach persona (persisted).
    @Published var selectedCoach: WellnessCoach {
        didSet { UserDefaults.standard.set(selectedCoach.rawValue, forKey: "selectedWellnessCoach") }
    }

    /// Long-term memory summary about the user, built from past conversations.
    private var userMemory: String {
        get { UserDefaults.standard.string(forKey: "aiUserMemory") ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: "aiUserMemory")
            cloudStore.set(newValue, forKey: "cloud_aiUserMemory")
        }
    }

    // MARK: - Chat History Item (messages + date dividers)
    enum ChatHistoryItem: Identifiable {
        case dateDivider(id: String, date: Date)
        case message(ChatMessage)

        var id: String {
            switch self {
            case .dateDivider(let id, _): return id
            case .message(let msg): return msg.id.uuidString
            }
        }
    }

    // MARK: - Private
    private var conversationHistory: [OpenAIProxyService.MessagePayload] = []
    private var currentAPITask: Task<Void, Never>?
    private var revealTimer: Timer?
    /// Bumped whenever memory is cleared, so an in-flight summarization can't repopulate it.
    private var memoryGeneration = 0
    /// Stores the last failed message text for retry
    @Published var lastFailedMessage: String?

    private let cloudStore = NSUbiquitousKeyValueStore.default

    private init() {
        // Load from iCloud first, fall back to local
        let localCount = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.chatMessagesSentCount)
        let cloudCount = Int(cloudStore.longLong(forKey: "cloud_chatMessagesSentCount"))
        self.messagesSentCount = max(localCount, cloudCount)

        // Restore selected coach
        let savedCoach = UserDefaults.standard.string(forKey: "selectedWellnessCoach")
        self.selectedCoach = savedCoach.flatMap { WellnessCoach(rawValue: $0) } ?? .general

        // Merge cloud memory into local if the device has none yet
        if (UserDefaults.standard.string(forKey: "aiUserMemory") ?? "").isEmpty,
           let cloudMemory = cloudStore.string(forKey: "cloud_aiUserMemory"), !cloudMemory.isEmpty {
            UserDefaults.standard.set(cloudMemory, forKey: "aiUserMemory")
        }
    }

    /// Switch coach persona. Takes effect on the next session.
    func setCoach(_ coach: WellnessCoach) {
        selectedCoach = coach
    }

    /// Switch coach mid-conversation: persists the choice and rebuilds the active
    /// session's system prompt so the new persona applies immediately, keeping history.
    func switchCoach(to coach: WellnessCoach, in context: ModelContext) {
        selectedCoach = coach
        guard currentSession != nil else { return }
        lastHealthContext = buildHealthContext(in: context)
        rebuildConversationHistory(mood: currentSession?.moodLevel)
    }

    // MARK: - Computed Properties

    var hasReachedFreeLimit: Bool {
        !StoreManager.shared.isSubscribed && messagesSentCount >= Constants.Chat.freeMessageLimit
    }

    var remainingFreeMessages: Int {
        max(0, Constants.Chat.freeMessageLimit - messagesSentCount)
    }

    // MARK: - Session Management

    func startSession(mood: MoodLevel?, in context: ModelContext) {
        // End previous active session if any
        if let previous = currentSession {
            previous.endSession()
        }

        let session = ChatSession()
        if let mood = mood {
            session.moodLevelRaw = mood.rawValue
        }
        context.insert(session)
        currentSession = session
        messages = []
        needsMoodCheckIn = false

        // Build system prompt with mood context, coach persona, long-term memory, and live data.
        lastHealthContext = buildHealthContext(in: context)
        let systemPrompt = OpenAIProxyService.buildSystemPrompt(
            moodLevel: mood,
            coach: selectedCoach,
            memory: userMemory,
            healthContext: lastHealthContext
        )
        conversationHistory = [
            .init(role: "system", content: systemPrompt)
        ]

        // Add welcome message from assistant
        let welcomeText = buildWelcomeMessage(mood: mood)
        let welcomeMessage = ChatMessage(
            sessionID: session.id,
            role: .assistant,
            type: .text,
            content: welcomeText
        )
        context.insert(welcomeMessage)
        messages.append(welcomeMessage)
        conversationHistory.append(.init(role: "assistant", content: welcomeText))

        session.messageCount = messages.count
        try? context.save()

        // Rebuild full history including new session
        buildChatHistory(in: context)
    }

    func endSession(in context: ModelContext) {
        currentAPITask?.cancel()
        currentAPITask = nil
        revealTimer?.invalidate()
        revealTimer = nil
        isLoading = false
        lastFailedMessage = nil
        currentSession?.endSession()
        currentSession = nil
        messages = []
        // Fold this conversation into long-term memory before discarding it.
        updateMemory(from: conversationHistory)
        conversationHistory = []
        needsMoodCheckIn = true
        try? context.save()
        // Keep chatHistory intact — history stays visible behind mood picker
    }

    /// Summarize the just-ended conversation into durable long-term memory (fire-and-forget).
    private func updateMemory(from history: [OpenAIProxyService.MessagePayload]) {
        let userTurns = history.filter { $0.role == "user" }.count
        guard userTurns >= 2 else { return } // skip trivial sessions
        let existing = userMemory
        let snapshot = history
        let generation = memoryGeneration
        Task { [weak self] in
            guard let self else { return }
            if let updated = try? await OpenAIProxyService.summarizeMemory(existingMemory: existing, conversation: snapshot) {
                // Bail if the user cleared their memory while we were summarizing.
                guard generation == self.memoryGeneration else { return }
                self.userMemory = updated
            }
        }
    }

    func clearAllHistory(in context: ModelContext) {
        // End current session
        currentSession?.endSession()
        currentSession = nil
        messages = []
        conversationHistory = []
        chatHistory = []
        needsMoodCheckIn = true

        // Clearing history also wipes long-term memory (user's explicit reset).
        memoryGeneration += 1
        revealTimer?.invalidate()
        revealTimer = nil
        userMemory = ""

        // Delete all sessions and messages
        let sessionDescriptor = FetchDescriptor<ChatSession>()
        if let sessions = try? context.fetch(sessionDescriptor) {
            for session in sessions {
                deleteSessionMessages(sessionID: session.id, in: context)
                context.delete(session)
            }
        }
        try? context.save()
    }

    // MARK: - Send Message

    func sendMessage(_ text: String, in context: ModelContext) async {
        guard let session = currentSession else { return }
        guard !hasReachedFreeLimit else { return }

        lastFailedMessage = nil

        // Check crisis keywords (show alert but still process message)
        if CrisisKeywords.containsCrisisKeyword(text) {
            showCrisisAlert = true
        }

        // Create and persist user message
        let userMessage = ChatMessage(
            sessionID: session.id,
            role: .user,
            type: .text,
            content: text
        )
        context.insert(userMessage)
        messages.append(userMessage)

        // Add to conversation history
        conversationHistory.append(.init(role: "user", content: text))

        // Trim conversation history to sliding window
        trimConversationHistory()

        // Show typing indicator
        isLoading = true

        // Call API (cancellable)
        let task = Task {
            do {
                let responseText = try await OpenAIProxyService.sendMessage(
                    messages: conversationHistory
                )

                guard !Task.isCancelled else { return }

                // Create assistant message. When voice output is on, show it in full
                // immediately (so it's spoken correctly); otherwise stream it in with a
                // typewriter reveal for a more alive feel.
                let speakingAloud = VoiceManager.shared.voiceOutputEnabled
                let assistantMessage = ChatMessage(
                    sessionID: session.id,
                    role: .assistant,
                    type: .text,
                    content: speakingAloud ? responseText : ""
                )
                context.insert(assistantMessage)
                messages.append(assistantMessage)
                conversationHistory.append(.init(role: "assistant", content: responseText))

                // Increment message count only on success and sync to iCloud
                messagesSentCount += 1
                UserDefaults.standard.set(messagesSentCount, forKey: Constants.UserDefaultsKeys.chatMessagesSentCount)
                cloudStore.set(Int64(messagesSentCount), forKey: "cloud_chatMessagesSentCount")

                // Check for content suggestions in response
                checkForContentSuggestions(responseText, sessionID: session.id, in: context)

                // Update session message count
                session.messageCount = messages.count
                try? context.save()

                // Typewriter reveal when not reading aloud.
                if !speakingAloud {
                    revealText(responseText, into: assistantMessage, context: context)
                }

            } catch {
                guard !Task.isCancelled else { return }

                self.error = error.localizedDescription
                self.showError = true
                self.lastFailedMessage = text

                // Remove the failed user message from conversation history so retry works
                if conversationHistory.last?.content == text {
                    conversationHistory.removeLast()
                }

                // Add error message to chat with retry hint
                let errorMessage = ChatMessage(
                    sessionID: session.id,
                    role: .assistant,
                    type: .text,
                    content: "I'm having trouble connecting right now. Tap retry or type again."
                )
                context.insert(errorMessage)
                messages.append(errorMessage)
            }

            isLoading = false
            buildChatHistory(in: context)
        }
        currentAPITask = task
        await task.value
    }

    /// Typewriter-reveal the assistant's reply into the (initially empty) message for a
    /// streaming feel. SwiftData @Model is Observable, so mutating `content` updates the UI live.
    private func revealText(_ full: String, into message: ChatMessage, context: ModelContext) {
        revealTimer?.invalidate()
        let chars = Array(full)
        guard !chars.isEmpty else { return }
        // ~120 ticks total max, so long replies finish in ~2.4s; short ones reveal per character.
        let chunk = max(1, chars.count / 120)
        var idx = 0
        revealTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                idx = min(chars.count, idx + chunk)
                message.content = String(chars[0..<idx])
                if idx >= chars.count {
                    timer.invalidate()
                    self.revealTimer = nil
                    message.content = full
                    try? context.save()
                }
            }
        }
    }

    /// Retry the last failed message
    func retryLastMessage(in context: ModelContext) async {
        guard let failedText = lastFailedMessage else { return }
        lastFailedMessage = nil
        await sendMessage(failedText, in: context)
    }

    // MARK: - Content Suggestion Detection

    private func checkForContentSuggestions(_ responseText: String, sessionID: UUID, in context: ModelContext) {
        let descriptor = FetchDescriptor<Content>()
        guard let allContent = try? context.fetch(descriptor) else { return }

        // Find the best (longest title) match to avoid short false positives like "Sleep"
        var bestMatch: Content?
        for content in allContent {
            guard content.title.count > 5,
                  responseText.localizedCaseInsensitiveContains(content.title) else { continue }
            if content.title.count > (bestMatch?.title.count ?? 0) {
                bestMatch = content
            }
        }

        if let content = bestMatch {
            let suggestionMessage = ChatMessage(
                sessionID: sessionID,
                role: .assistant,
                type: .contentSuggestion,
                content: content.title,
                suggestedContentID: content.id,
                suggestedContentTitle: content.title
            )
            context.insert(suggestionMessage)
            messages.append(suggestionMessage)
        }
    }

    // MARK: - History Management

    func loadSessionHistory(in context: ModelContext) {
        // Load active session for continuing conversation
        let activeDescriptor = FetchDescriptor<ChatSession>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )

        // Refresh the wellness-data summary for grounding before rebuilding the prompt.
        lastHealthContext = buildHealthContext(in: context)

        if let activeSession = try? context.fetch(activeDescriptor).first {
            currentSession = activeSession
            needsMoodCheckIn = false

            // Load messages for active session
            let sessionID = activeSession.id
            let messageDescriptor = FetchDescriptor<ChatMessage>(
                predicate: #Predicate { $0.sessionID == sessionID },
                sortBy: [SortDescriptor(\.timestamp)]
            )
            messages = (try? context.fetch(messageDescriptor)) ?? []

            // Rebuild conversation history for API context
            rebuildConversationHistory(mood: activeSession.moodLevel)
        } else {
            // No active session — show mood check-in but preserve history
            needsMoodCheckIn = true
        }

        // Build full chat history with date dividers
        buildChatHistory(in: context)
    }

    func cleanupOldSessions(in context: ModelContext) {
        let isPremium = StoreManager.shared.isSubscribed
        let retentionDays = isPremium
            ? Constants.Chat.historyRetentionDaysPremium
            : 7  // Free users keep 7 days of history

        guard let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) else { return }

        let descriptor = FetchDescriptor<ChatSession>(
            predicate: #Predicate { $0.isActive == false && $0.startedAt < cutoffDate }
        )

        if let oldSessions = try? context.fetch(descriptor) {
            for session in oldSessions {
                deleteSessionMessages(sessionID: session.id, in: context)
                context.delete(session)
            }
            try? context.save()
        }
    }

    // MARK: - Full History Builder

    func buildChatHistory(in context: ModelContext) {
        // Fetch all sessions ordered by date
        let sessionDescriptor = FetchDescriptor<ChatSession>(
            sortBy: [SortDescriptor(\.startedAt)]
        )
        guard let sessions = try? context.fetch(sessionDescriptor), !sessions.isEmpty else {
            chatHistory = []
            return
        }

        var items: [ChatHistoryItem] = []
        var lastDateKey: String?

        for session in sessions {
            let sessionID = session.id
            let msgDescriptor = FetchDescriptor<ChatMessage>(
                predicate: #Predicate { $0.sessionID == sessionID },
                sortBy: [SortDescriptor(\.timestamp)]
            )
            guard let sessionMessages = try? context.fetch(msgDescriptor), !sessionMessages.isEmpty else { continue }

            // Add date divider if this session is on a new day
            let dateKey = Self.dateDividerKey(for: session.startedAt)
            if dateKey != lastDateKey {
                items.append(.dateDivider(id: "divider_\(dateKey)_\(session.id)", date: session.startedAt))
                lastDateKey = dateKey
            }

            for message in sessionMessages {
                items.append(.message(message))
            }
        }

        chatHistory = items
    }

    private static func dateDividerKey(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "today" }
        if calendar.isDateInYesterday(date) { return "yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func dateDividerLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    // MARK: - Mood History

    /// Returns the most recent mood check-in for each of the last 7 days
    static func getMoodHistory(in context: ModelContext) -> [DayMood] {
        let calendar = Calendar.current
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date())) else {
            return []
        }

        let descriptor = FetchDescriptor<ChatSession>(
            predicate: #Predicate { $0.startedAt >= sevenDaysAgo && $0.moodLevelRaw != nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )

        guard let sessions = try? context.fetch(descriptor) else { return [] }

        // Group by day, take latest per day
        var moodByDay: [String: (date: Date, mood: MoodLevel)] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for session in sessions {
            guard let mood = session.moodLevel else { continue }
            let key = formatter.string(from: session.startedAt)
            if moodByDay[key] == nil {
                moodByDay[key] = (session.startedAt, mood)
            }
        }

        // Build 7-day array (today first, oldest last)
        let today = calendar.startOfDay(for: Date())
        var result: [DayMood] = []
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let key = formatter.string(from: date)
            let mood = moodByDay[key]?.mood
            result.append(DayMood(date: date, mood: mood))
        }

        return result
    }

    struct DayMood: Identifiable {
        let date: Date
        let mood: MoodLevel?
        var id: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }
    }

    // MARK: - Private Helpers

    /// Most recently computed wellness-data summary, injected into the system prompt
    /// so the coach can ground advice in the user's own numbers.
    private var lastHealthContext: String?

    /// Builds a compact summary of the user's recent wellness data (streak, sleep score,
    /// last night's sleep, heart-rate dip) from the on-device sources.
    func buildHealthContext(in context: ModelContext) -> String? {
        var parts: [String] = []

        let streak = StreakService.shared.currentStreak
        if streak > 0 { parts.append("meditation streak: \(streak) day\(streak == 1 ? "" : "s")") }

        let descriptor = FetchDescriptor<MeditationSession>()
        if let sessions = try? context.fetch(descriptor), !sessions.isEmpty {
            let score = SleepAnalyticsService.shared.calculateSleepScore(from: sessions)
            if score.overall > 0 { parts.append("sleep score: \(score.overall) (\(score.label))") }
        }

        let health = HealthKitService.shared
        if health.sleepHoursToday > 0 {
            parts.append(String(format: "last night ~%.1fh sleep", health.sleepHoursToday))
        }
        if let dip = health.heartRateDip, dip > 0 {
            parts.append(String(format: "heart-rate dip %.0f%%", dip))
        }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "; ") + "."
    }

    private func rebuildConversationHistory(mood: MoodLevel?) {
        let systemPrompt = OpenAIProxyService.buildSystemPrompt(
            moodLevel: mood,
            coach: selectedCoach,
            memory: userMemory,
            healthContext: lastHealthContext
        )
        conversationHistory = [.init(role: "system", content: systemPrompt)]

        for message in messages where message.messageType == .text {
            conversationHistory.append(.init(
                role: message.role.rawValue,
                content: message.content
            ))
        }

        trimConversationHistory()
    }

    private func trimConversationHistory() {
        // Keep system prompt (first element) + last N messages
        let maxHistory = Constants.Chat.maxConversationHistory
        guard conversationHistory.count > maxHistory + 1,
              let systemPrompt = conversationHistory.first else { return }
        let recentMessages = Array(conversationHistory.suffix(maxHistory))
        conversationHistory = [systemPrompt] + recentMessages
    }

    private func deleteInactiveSessions(in context: ModelContext) {
        let descriptor = FetchDescriptor<ChatSession>(
            predicate: #Predicate { $0.isActive == false }
        )
        if let sessions = try? context.fetch(descriptor) {
            for session in sessions {
                deleteSessionMessages(sessionID: session.id, in: context)
                context.delete(session)
            }
            try? context.save()
        }
    }

    private func deleteSessionMessages(sessionID: UUID, in context: ModelContext) {
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.sessionID == sessionID }
        )
        if let messages = try? context.fetch(descriptor) {
            for message in messages {
                context.delete(message)
            }
        }
    }

    private func buildWelcomeMessage(mood: MoodLevel?) -> String {
        // A specialized coach greets in-character (still warm if the user shared a low mood).
        if selectedCoach != .general, mood == nil || mood == .great || mood == .good || mood == .okay {
            return selectedCoach.welcomeLine
        }
        if let mood = mood {
            switch mood {
            case .great:
                return "Wonderful to hear you're feeling great! How can I help you make the most of this positive energy today?"
            case .good:
                return "Glad you're doing well! Is there anything specific you'd like to explore -- maybe a meditation technique or just chat about how your day is going?"
            case .okay:
                return "Thanks for checking in. Sometimes 'okay' is perfectly fine. Would you like to talk about what's on your mind, or try a quick breathing exercise?"
            case .low:
                return "I'm here for you. It takes courage to acknowledge when things feel tough. Would you like to share what's going on, or shall I guide you through a calming exercise?"
            case .struggling:
                return "I hear you, and I'm glad you're here. You don't have to go through this alone. Would you like to talk about what you're experiencing? I'm here to listen."
            }
        }
        return "Hi, I'm here to support your mental wellness journey. How are you feeling today?"
    }
}
