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
    @State private var showQuickActions = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isRegular: Bool { sizeClass == .regular }
    @FocusState private var isInputFocused: Bool

    // Quick prompt suggestions based on time of day
    private var quickPrompts: [(icon: String, text: String)] {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 21 || hour < 5 {
            return [
                ("moon.fill", "Help me fall asleep"),
                ("wind", "Calm my racing thoughts"),
                ("book.fill", "Tell me a bedtime story"),
                ("sparkles", "Gratitude reflection")
            ]
        } else if hour < 12 {
            return [
                ("sun.rise.fill", "Set my intention for today"),
                ("figure.mind.and.body", "Morning meditation"),
                ("bolt.heart.fill", "Boost my energy"),
                ("face.smiling", "I need motivation")
            ]
        } else if hour < 17 {
            return [
                ("brain.head.profile", "Help me focus"),
                ("leaf.fill", "Quick stress relief"),
                ("lungs.fill", "Breathing exercise"),
                ("heart.fill", "Self-compassion check-in")
            ]
        } else {
            return [
                ("sunset.fill", "Wind down my day"),
                ("figure.cooldown", "Release tension"),
                ("cup.and.saucer.fill", "Evening reflection"),
                ("sparkles", "Gratitude practice")
            ]
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                if chatService.needsMoodCheckIn && chatService.chatHistory.isEmpty {
                    // No history — full-screen welcome experience
                    chatWelcomeExperience
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
                    sessionLimitMessage: "You've used all \(Constants.Chat.freeMessageLimit) free messages. Upgrade to continue chatting with Breathe AI.",
                    onSubscribed: { showingPaywall = false }
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

    // MARK: - Welcome Experience (replaces plain mood picker)

    private var chatWelcomeExperience: some View {
        ScrollView {
            VStack(spacing: isRegular ? 36 : 28) {
                Spacer().frame(height: isRegular ? 60 : 40)

                // AI icon
                Image(systemName: "sparkles")
                    .font(.system(size: isRegular ? 52 : 40, weight: .medium))
                    .foregroundStyle(Theme.profileAccent)
                    .padding(.bottom, 4)

                // Title & subtitle
                VStack(spacing: isRegular ? 12 : 8) {
                    Text("Breathe AI")
                        .font(.system(size: isRegular ? 36 : 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Your personal wellness companion")
                        .font(isRegular ? .body : .subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }

                // Mood check-in card
                VStack(spacing: isRegular ? 20 : 16) {
                    Text("How are you feeling right now?")
                        .font(isRegular ? .body.weight(.medium) : .subheadline.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)

                    HStack(spacing: isRegular ? 16 : 12) {
                        ForEach(MoodLevel.allCases) { mood in
                            Button {
                                HapticManager.selection()
                                chatService.startSession(mood: mood, in: modelContext)
                            } label: {
                                VStack(spacing: isRegular ? 8 : 6) {
                                    Text(mood.emoji)
                                        .font(.system(size: isRegular ? 42 : 32))
                                    Text(mood.displayName)
                                        .font(.system(size: isRegular ? 13 : 10, weight: .medium))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, isRegular ? 18 : 14)
                                .background(
                                    RoundedRectangle(cornerRadius: isRegular ? 20 : 16)
                                        .fill(Color.white.opacity(0.06))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: isRegular ? 20 : 16)
                                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .padding(isRegular ? 28 : 20)
                .background(
                    RoundedRectangle(cornerRadius: isRegular ? 24 : 20)
                        .fill(.ultraThinMaterial.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: isRegular ? 24 : 20)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
                .padding(.horizontal)

                // Or skip and jump right in
                Button {
                    HapticManager.light()
                    chatService.startSession(mood: nil, in: modelContext)
                } label: {
                    Text("Skip & start chatting")
                        .font(isRegular ? .body : .subheadline)
                        .foregroundStyle(Theme.textTertiary)
                }

                // Quick start topics
                VStack(alignment: .leading, spacing: isRegular ? 16 : 12) {
                    Text("Or try one of these")
                        .font(isRegular ? .subheadline.weight(.medium) : .caption.weight(.medium))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.leading, 4)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: isRegular ? 14 : 10) {
                        ForEach(quickPrompts, id: \.text) { prompt in
                            Button {
                                HapticManager.medium()
                                chatService.startSession(mood: nil, in: modelContext)
                                // Send prompt after a brief delay for session to initialize
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    messageText = prompt.text
                                    sendMessage()
                                }
                            } label: {
                                HStack(spacing: isRegular ? 10 : 8) {
                                    Image(systemName: prompt.icon)
                                        .font(isRegular ? .subheadline : .caption)
                                        .foregroundStyle(Theme.profileAccent)
                                        .frame(width: isRegular ? 24 : 20)

                                    Text(prompt.text)
                                        .font(isRegular ? .subheadline : .caption)
                                        .foregroundStyle(Theme.textPrimary)
                                        .lineLimit(1)

                                    Spacer()
                                }
                                .padding(.horizontal, isRegular ? 16 : 12)
                                .padding(.vertical, isRegular ? 14 : 11)
                                .background(
                                    RoundedRectangle(cornerRadius: isRegular ? 14 : 12)
                                        .fill(Color.white.opacity(0.06))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal)

                // Capabilities badges
                VStack(spacing: 12) {
                    HStack(spacing: isRegular ? 24 : 16) {
                        capabilityBadge(icon: "brain.head.profile", label: "Evidence-based")
                        capabilityBadge(icon: "lock.shield.fill", label: "Private & safe")
                        capabilityBadge(icon: "clock.fill", label: "Available 24/7")
                    }
                }
                .padding(.top, 8)

                Spacer().frame(height: AudioPlayerManager.shared.currentContent != nil ? 170 : 100)
            }
            .frame(maxWidth: isRegular ? 700 : 600)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private func capabilityBadge(icon: String, label: String) -> some View {
        HStack(spacing: isRegular ? 6 : 4) {
            Image(systemName: icon)
                .font(.system(size: isRegular ? 13 : 10))
                .foregroundStyle(Theme.textTertiary)
            Text(label)
                .font(.system(size: isRegular ? 13 : 10))
                .foregroundStyle(Theme.textTertiary)
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
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(
                                                LinearGradient(
                                                    colors: [mood.color, mood.color.opacity(0.5)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .frame(width: 32, height: barHeight(for: mood))
                                    } else {
                                        Text("—")
                                            .font(.title2)
                                            .foregroundStyle(Theme.textTertiary)
                                        RoundedRectangle(cornerRadius: 6)
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
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
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
            .presentationDetents([.medium, .large])
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

        // Cached DateFormatter for performance
        private static let dayFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter
        }()

        private func dayLabel(_ date: Date) -> String {
            Self.dayFormatter.string(from: date)
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
                    LazyVStack(spacing: 4) {
                        // Full chat history with date dividers
                        ForEach(chatService.chatHistory) { item in
                            switch item {
                            case .dateDivider(_, let date):
                                chatDateDivider(date: date)
                                    .id(item.id)
                            case .message(let message):
                                chatBubbleView(for: message)
                                    .id(item.id)
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                                        removal: .opacity
                                    ))
                            }
                        }

                        if chatService.isLoading {
                            TypingIndicator()
                                .id("typing")
                                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        }

                        // Retry button for failed messages
                        if let _ = chatService.lastFailedMessage, !chatService.isLoading {
                            Button {
                                HapticManager.medium()
                                Task { await chatService.retryLastMessage(in: modelContext) }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Tap to retry")
                                }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.red.opacity(0.3))
                                        .overlay(Capsule().stroke(Color.red.opacity(0.4), lineWidth: 1))
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 44)
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
                    .padding(.top, 8)
                    .padding(.bottom, chatScrollBottomPadding)
                    .frame(maxWidth: 700)
                    .frame(maxWidth: .infinity)
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

            // Quick prompts strip (shown when input is empty and not loading)
            if !chatService.hasReachedFreeLimit && !chatService.needsMoodCheckIn && messageText.isEmpty && !chatService.isLoading && chatService.messages.count <= 2 {
                quickPromptsStrip
            }

            // Input Bar
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

    // MARK: - Quick Prompts Strip

    private var quickPromptsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickPrompts, id: \.text) { prompt in
                    Button {
                        HapticManager.light()
                        messageText = prompt.text
                        sendMessage()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: prompt.icon)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.profileAccent)
                            Text(prompt.text)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Date Divider

    private func chatDateDivider(date: Date) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)
            Text(ChatService.dateDividerLabel(for: date))
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize()
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)
        }
        .padding(.vertical, 12)
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
                            Text(mood.displayName)
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
        HStack(spacing: 12) {
            // AI avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.profileAccent, Color(red: 0.4, green: 0.3, blue: 0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Breathe AI")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)

                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text("Online")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer()

            // Mood trend button
            Button {
                HapticManager.light()
                showingMoodTrend = true
            } label: {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }

            // New chat button
            Button {
                HapticManager.light()
                chatService.endSession(in: modelContext)
            } label: {
                Image(systemName: "plus.message")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }

            if !chatService.chatHistory.isEmpty {
                Menu {
                    Button(role: .destructive) {
                        showingClearConfirmation = true
                    } label: {
                        Label("Clear Chat History", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.3))
                .ignoresSafeArea(edges: .top)
        )
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
            EmptyView()
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
        let tabBarHeight: CGFloat = isRegular ? 90 : 80
        let inputBarHeight: CGFloat = 80
        let miniPlayerHeight: CGFloat = hasMiniPlayer ? 85 : 0
        return tabBarHeight + inputBarHeight + miniPlayerHeight
    }

    /// Bottom padding for the input bar (above tab bar + mini player)
    private var inputBarBottomPadding: CGFloat {
        let tabBarHeight: CGFloat = isRegular ? 85 : 75
        let miniPlayerHeight: CGFloat = hasMiniPlayer ? 85 : 0
        return tabBarHeight + miniPlayerHeight
    }

    // MARK: - Helpers

    private func loadContent(id: UUID?) {
        guard let id = id else { return }
        if !storeManager.isSubscribed && AppStateManager.shared.hasReachedFreeSessionLimit {
            showingPaywall = true
            return
        }
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
