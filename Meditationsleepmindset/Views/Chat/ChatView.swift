//
//  ChatView.swift
//  Meditation Sleep Mindset
//

import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var chatService = ChatService.shared
    @StateObject private var storeManager = StoreManager.shared
    @State private var messageText: String = ""
    @State private var showingPaywall: Bool = false
    @State private var selectedContent: Content?
    @State private var isKeyboardVisible = false
    @State private var showingClearConfirmation = false
    @State private var showingMoodTrend = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                if chatService.needsMoodCheckIn && chatService.chatHistory.isEmpty {
                    // No history at all — full screen mood picker
                    ChatMoodPickerView(onMoodSelected: { mood in
                        chatService.startSession(mood: mood, in: modelContext)
                    }, hasMiniPlayer: AudioPlayerManager.shared.currentContent != nil)
                } else {
                    chatInterface
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert("Are You Okay?", isPresented: $chatService.showCrisisAlert) {
                Button("Call 988") {
                    if let url = URL(string: "tel://\(Constants.CrisisResources.suicidePreventionHotline)") {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Text Crisis Line") {
                    if let url = URL(string: "sms:\(Constants.CrisisResources.crisisTextLine)&body=HELLO") {
                        UIApplication.shared.open(url)
                    }
                }
                Button("I'm Safe", role: .cancel) { }
            } message: {
                Text("If you're in crisis, please reach out for help. You are not alone.\n\n988 - Suicide & Crisis Lifeline\nText HOME to 741741 - Crisis Text Line")
            }
            .sheet(isPresented: $showingPaywall) {
                PremiumPaywallView(
                    storeManager: storeManager,
                    sessionLimitMessage: "You've used all \(Constants.Chat.freeMessageLimit) free messages. Upgrade to continue chatting with Breathe AI."
                )
            }
            .fullScreenCover(item: $selectedContent) { content in
                MeditationPlayerView(content: content)
            }
            .onAppear {
                chatService.loadSessionHistory(in: modelContext)
                chatService.cleanupOldSessions(in: modelContext)
            }
            .onChange(of: chatService.hasReachedFreeLimit) { _, reachedLimit in
                if reachedLimit {
                    showingPaywall = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                isKeyboardVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                isKeyboardVisible = false
            }
            .alert("Clear Chat History", isPresented: $showingClearConfirmation) {
                Button("Clear", role: .destructive) {
                    chatService.clearAllHistory(in: modelContext)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all your chat history. This cannot be undone.")
            }
            .sheet(isPresented: $showingMoodTrend) {
                MoodTrendSheet(moodHistory: ChatService.getMoodHistory(in: modelContext))
            }
        }
    }

    // MARK: - Mood Trend Sheet
    struct MoodTrendSheet: View {
        let moodHistory: [ChatService.DayMood]
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            NavigationStack {
                ZStack {
                    Theme.profileGradient.ignoresSafeArea()

                    VStack(spacing: 24) {
                        Text("Your Mood This Week")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .padding(.top, 24)

                        // Mood trend chart
                        HStack(alignment: .bottom, spacing: 0) {
                            ForEach(moodHistory) { day in
                                VStack(spacing: 8) {
                                    if let mood = day.mood {
                                        Text(mood.emoji)
                                            .font(.title2)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(mood.color)
                                            .frame(width: 32, height: barHeight(for: mood))
                                    } else {
                                        Text("—")
                                            .font(.title2)
                                            .foregroundStyle(Theme.textTertiary)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.white.opacity(0.1))
                                            .frame(width: 32, height: 20)
                                    }

                                    Text(dayLabel(day.date))
                                        .font(.caption2)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal)
                        .frame(height: 180)

                        if moodHistory.allSatisfy({ $0.mood == nil }) {
                            Text("Start a chat session with a mood check-in\nto see your trend here.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }

                        Spacer()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationBackground(Color(red: 0.09, green: 0.17, blue: 0.31))
        }

        private func barHeight(for mood: MoodLevel) -> CGFloat {
            switch mood {
            case .great: return 100
            case .good: return 80
            case .okay: return 60
            case .low: return 40
            case .struggling: return 20
            }
        }

        private func dayLabel(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
        }
    }

    // MARK: - Chat Interface

    private var chatInterface: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader

            // Messages ScrollView
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Full chat history with date dividers
                        ForEach(chatService.chatHistory) { item in
                            switch item {
                            case .dateDivider(_, let date):
                                chatDateDivider(date: date)
                                    .id(item.id)
                            case .message(let message):
                                chatBubbleView(for: message)
                                    .id(item.id)
                            }
                        }

                        if chatService.isLoading {
                            TypingIndicator()
                                .id("typing")
                        }

                        // Retry button for failed messages
                        if let _ = chatService.lastFailedMessage, !chatService.isLoading {
                            Button {
                                HapticManager.medium()
                                Task { await chatService.retryLastMessage(in: modelContext) }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Retry")
                                }
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Theme.profileAccent)
                                .clipShape(Capsule())
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("retry")
                        }

                        // Inline mood check-in when returning with history
                        if chatService.needsMoodCheckIn && !chatService.chatHistory.isEmpty {
                            inlineMoodCheckIn
                                .id("moodCheckIn")
                        }

                        if chatService.hasReachedFreeLimit {
                            ChatPaywallPrompt {
                                showingPaywall = true
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, chatScrollBottomPadding)
                }
                .onChange(of: chatService.chatHistory.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: chatService.isLoading) { _, loading in
                    if loading { scrollToBottom(proxy: proxy) }
                }
                .onChange(of: chatService.needsMoodCheckIn) { _, needsCheckIn in
                    if needsCheckIn {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo("moodCheckIn", anchor: .bottom)
                            }
                        }
                    }
                }
                .onTapGesture {
                    isInputFocused = false
                }
            }

            Spacer(minLength: 0)

            // Input Bar - positioned above the tab bar
            if !chatService.hasReachedFreeLimit && !chatService.needsMoodCheckIn {
                ChatInputBar(
                    text: $messageText,
                    isFocused: $isInputFocused,
                    remainingMessages: storeManager.isSubscribed ? nil : chatService.remainingFreeMessages,
                    isLoading: chatService.isLoading,
                    onSend: sendMessage
                )
                .padding(.bottom, isKeyboardVisible ? 0 : inputBarBottomPadding)
            }
        }
    }

    // MARK: - Date Divider

    private func chatDateDivider(date: Date) -> some View {
        HStack {
            VStack { Divider().background(Color.white.opacity(0.15)) }
            Text(ChatService.dateDividerLabel(for: date))
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .fixedSize()
            VStack { Divider().background(Color.white.opacity(0.15)) }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Inline Mood Check-In

    private var inlineMoodCheckIn: some View {
        VStack(spacing: 16) {
            Text("Welcome back! How are you feeling?")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 16)

            HStack(spacing: 12) {
                ForEach(MoodLevel.allCases) { mood in
                    Button {
                        HapticManager.selection()
                        chatService.startSession(mood: mood, in: modelContext)
                    } label: {
                        VStack(spacing: 4) {
                            Text(mood.emoji)
                                .font(.title2)
                            Text(mood.rawValue)
                                .font(.caption2)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.06))
                        )
                    }
                }
            }

            Button {
                chatService.startSession(mood: nil, in: modelContext)
            } label: {
                Text("Skip")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Breathe AI")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)

                Text("AI Wellness Chat")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Button {
                HapticManager.light()
                chatService.endSession(in: modelContext)
            } label: {
                Image(systemName: "plus.message")
                    .font(.title3)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 36, height: 36)
            }

            if !chatService.chatHistory.isEmpty {
                Menu {
                    Button {
                        showingMoodTrend = true
                    } label: {
                        Label("Mood Trend", systemImage: "chart.line.uptrend.xyaxis")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showingClearConfirmation = true
                    } label: {
                        Label("Clear Chat History", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 36, height: 36)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Send Message

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if chatService.hasReachedFreeLimit {
            showingPaywall = true
            return
        }

        messageText = ""

        Task {
            await chatService.sendMessage(text, in: modelContext)
        }
    }

    // MARK: - Chat Bubble Router

    @ViewBuilder
    private func chatBubbleView(for message: ChatMessage) -> some View {
        switch message.messageType {
        case .text:
            ChatBubble(message: message)
        case .contentSuggestion:
            SuggestedContentCard(
                title: message.suggestedContentTitle ?? "Meditation",
                onTap: {
                    loadContent(id: message.suggestedContentID)
                }
            )
        case .therapistReferral:
            TherapistReferralCard()
        case .crisisAlert:
            CrisisResourceView()
        case .moodCheckIn:
            EmptyView()
        }
    }

    // MARK: - Layout Constants

    private var hasMiniPlayer: Bool {
        AudioPlayerManager.shared.currentContent != nil
    }

    /// Bottom padding for the ScrollView content area
    private var chatScrollBottomPadding: CGFloat {
        if isKeyboardVisible { return 80 }
        let tabBarHeight: CGFloat = 80
        let inputBarHeight: CGFloat = 80
        let miniPlayerHeight: CGFloat = hasMiniPlayer ? 85 : 0
        return tabBarHeight + inputBarHeight + miniPlayerHeight
    }

    /// Bottom padding for the input bar (above tab bar + mini player)
    private var inputBarBottomPadding: CGFloat {
        let tabBarHeight: CGFloat = 75
        let miniPlayerHeight: CGFloat = hasMiniPlayer ? 85 : 0
        return tabBarHeight + miniPlayerHeight
    }

    // MARK: - Helpers

    private func loadContent(id: UUID?) {
        guard let id = id else { return }
        let descriptor = FetchDescriptor<Content>(
            predicate: #Predicate { $0.id == id }
        )
        selectedContent = try? modelContext.fetch(descriptor).first
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if chatService.isLoading {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo("typing", anchor: .bottom)
            }
        } else if let lastItem = chatService.chatHistory.last {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(lastItem.id, anchor: .bottom)
            }
        }
    }
}

#Preview {
    ChatView()
        .modelContainer(for: [Content.self, ChatSession.self, ChatMessage.self], inMemory: true)
}
