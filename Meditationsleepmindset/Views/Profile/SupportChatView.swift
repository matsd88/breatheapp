//
//  SupportChatView.swift
//  Meditation Sleep Mindset
//
//  Customer support chatbot with preset issues and AI assistance
//

import SwiftUI
import StoreKit

struct SupportChatView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SupportChatViewModel()
    @FocusState private var isInputFocused: Bool
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Messages
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.messages) { message in
                                    SupportMessageBubble(message: message, onOptionTap: { option in
                                        viewModel.handleOptionSelected(option)
                                    })
                                    .id(message.id)
                                }

                                if viewModel.isTyping {
                                    SupportTypingIndicator()
                                        .id("typing")
                                }
                            }
                            .padding()
                            .frame(maxWidth: isRegular ? 700 : .infinity)
                            .frame(maxWidth: .infinity)
                        }
                        .onChange(of: viewModel.messages.count) { _, _ in
                            withAnimation {
                                proxy.scrollTo(viewModel.messages.last?.id ?? "typing", anchor: .bottom)
                            }
                        }
                        .onChange(of: viewModel.isTyping) { _, isTyping in
                            if isTyping {
                                withAnimation {
                                    proxy.scrollTo("typing", anchor: .bottom)
                                }
                            }
                        }
                    }

                    // Input bar (only shown when in free-form chat mode)
                    if viewModel.showFreeFormInput {
                        inputBar
                    }
                }
            }
            .navigationTitle("Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.resetChat()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .onAppear {
                viewModel.startChat()
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Type your question...", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .foregroundStyle(.white)
                .focused($isInputFocused)
                .lineLimit(1...4)
                .submitLabel(.send)
                .onSubmit {
                    viewModel.sendMessage()
                }

            Button {
                viewModel.sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .white.opacity(0.3) : Theme.profileAccent)
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isTyping)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.3))
    }
}

// MARK: - View Model

@MainActor
class SupportChatViewModel: ObservableObject {
    @Published var messages: [SupportMessage] = []
    @Published var isTyping = false
    @Published var inputText = ""
    @Published var showFreeFormInput = false

    private var currentContext: SupportContext = .mainMenu

    enum SupportContext {
        case mainMenu
        case subscription
        case account
        case technical
        case content
        case feedback
        case freeForm
    }

    func startChat() {
        messages = []
        currentContext = .mainMenu
        showFreeFormInput = false

        addBotMessage(
            text: String(localized: "Hi! I'm here to help. What can I assist you with today?"),
            options: mainMenuOptions
        )
    }

    func resetChat() {
        startChat()
    }

    private var mainMenuOptions: [SupportOption] {
        [
            SupportOption(id: "subscription", icon: "crown.fill", title: String(localized: "Subscription & Billing")),
            SupportOption(id: "account", icon: "person.crop.circle", title: String(localized: "Account Help")),
            SupportOption(id: "technical", icon: "wrench.and.screwdriver", title: String(localized: "Technical Issues")),
            SupportOption(id: "content", icon: "play.circle", title: String(localized: "Content & Features")),
            SupportOption(id: "feedback", icon: "star.bubble", title: String(localized: "Feedback & Suggestions")),
            SupportOption(id: "other", icon: "ellipsis.bubble", title: String(localized: "Something Else"))
        ]
    }

    func handleOptionSelected(_ option: SupportOption) {
        // Add user's selection as a message
        addUserMessage(text: option.title)

        // Process based on option
        isTyping = true

        Task {
            try? await Task.sleep(nanoseconds: 600_000_000) // Typing delay

            await MainActor.run {
                isTyping = false
                processOption(option.id)
            }
        }
    }

    private func processOption(_ optionId: String) {
        switch optionId {
        // Main Menu
        case "subscription":
            currentContext = .subscription
            addBotMessage(
                text: String(localized: "I can help with subscription questions. What would you like to know?"),
                options: subscriptionOptions
            )

        case "account":
            currentContext = .account
            addBotMessage(
                text: String(localized: "I can help with your account. What do you need?"),
                options: accountOptions
            )

        case "technical":
            currentContext = .technical
            addBotMessage(
                text: String(localized: "Let me help you with technical issues. What's happening?"),
                options: technicalOptions
            )

        case "content":
            currentContext = .content
            addBotMessage(
                text: String(localized: "I'd love to help you with our content! What's on your mind?"),
                options: contentOptions
            )

        case "feedback":
            currentContext = .feedback
            addBotMessage(
                text: String(localized: "We value your feedback! What would you like to share?"),
                options: feedbackOptions
            )

        case "other":
            currentContext = .freeForm
            showFreeFormInput = true
            addBotMessage(
                text: String(localized: "No problem! Type your question below and I'll do my best to help."),
                options: []
            )

        // Subscription Options
        case "cancel_subscription":
            addBotMessage(
                text: String(localized: "To cancel your subscription:\n\n1. Open the Settings app on your device\n2. Tap your name at the top\n3. Tap 'Subscriptions'\n4. Find and tap our app\n5. Tap 'Cancel Subscription'\n\nYou'll keep access until the end of your billing period."),
                options: [backToMainOption, wasThisHelpfulOption]
            )

        case "restore_purchase":
            addBotMessage(
                text: String(localized: "To restore your purchase:\n\n1. Go to Settings in the app (Profile tab → gear icon)\n2. Scroll to the Account section\n3. Tap 'Restore Purchases'\n\nIf it doesn't work, make sure you're signed into the same Apple ID you used to purchase."),
                options: [backToMainOption, wasThisHelpfulOption]
            )

        case "billing_issue":
            addBotMessage(
                text: String(localized: "For billing issues:\n\n• All payments are processed by Apple through the App Store\n• To request a refund, visit reportaproblem.apple.com\n• For billing questions, contact Apple Support directly\n\nWe don't have access to your payment information for security reasons."),
                options: [backToMainOption, wasThisHelpfulOption]
            )

        case "subscription_not_working":
            addBotMessage(
                text: String(localized: "If your premium features aren't working:\n\n1. Try 'Restore Purchases' in Settings → Account\n2. Make sure you're signed into the correct Apple ID\n3. Force close and reopen the app\n4. Check your subscription status in iPhone Settings → Subscriptions\n\nIf it still doesn't work, let me know!"),
                options: [SupportOption(id: "still_not_working", icon: "exclamationmark.triangle", title: String(localized: "Still not working")), backToMainOption]
            )

        // Account Options
        case "sign_in_help":
            addBotMessage(
                text: String(localized: "To sign in with Apple:\n\n1. Go to Settings (Profile tab → gear icon)\n2. In the Account section, tap 'Sign in with Apple'\n3. Follow the prompts\n\nSign in with Apple keeps your data synced across all your devices and protects your streak!"),
                options: [backToMainOption, wasThisHelpfulOption]
            )

        case "delete_account":
            addBotMessage(
                text: String(localized: "To delete your account:\n\n1. Go to Settings → Account section\n2. Make sure you're signed in\n3. Tap 'Delete Account'\n\n⚠️ This will permanently delete your cloud data. Local data on your device will be kept.\n\nYou can also email us at \(Constants.Support.email) to request complete data deletion."),
                options: [backToMainOption, wasThisHelpfulOption]
            )

        case "data_sync":
            addBotMessage(
                text: String(localized: "Your data syncs automatically when you sign in with Apple!\n\n• Favorites, playlists, and sessions sync across devices\n• Your streak is protected even if you switch phones\n• Sync happens when the app goes to background\n\nMake sure you're signed in on all devices with the same Apple ID."),
                options: [backToMainOption, wasThisHelpfulOption]
            )

        case "privacy_data":
            addBotMessage(
                text: String(localized: "We take your privacy seriously:\n\n• Your data is stored securely in your personal iCloud\n• We don't sell or share your personal information\n• Analytics are anonymous and used only to improve the app\n• You can delete your data anytime\n\nRead our full Privacy Policy in Settings → Legal."),
                options: [backToMainOption, wasThisHelpfulOption]
            )

        // Technical Options
        case "audio_not_playing":
            addBotMessage(
                text: String(localized: "If audio isn't playing:\n\n1. Check your device isn't on silent mode (flip the switch on the side)\n2. Make sure volume is turned up\n3. Try closing and reopening the app\n4. Check if other apps play audio\n5. Restart your device\n\nSome content requires internet — check your connection too!"),
                options: [SupportOption(id: "still_no_audio", icon: "speaker.slash", title: String(localized: "Still no audio")), backToMainOption]
            )

        case "app_crashing":
            addBotMessage(
                text: String(localized: "If the app is crashing:\n\n1. Make sure you have the latest app version (check App Store)\n2. Restart your device\n3. Check you have enough storage space\n4. Try deleting and reinstalling the app\n\nYour data will be restored from iCloud if you're signed in!"),
                options: [backToMainOption, wasThisHelpfulOption]
            )

        case "video_loading":
            addBotMessage(
                text: String(localized: "If videos are loading slowly:\n\n• Check your internet connection\n• Try switching between WiFi and cellular\n• Close other apps using bandwidth\n• The first play may take a moment to buffer\n\nTip: Content loads faster after playing once — we cache it for you!"),
                options: [backToMainOption, wasThisHelpfulOption]
            )

        case "notifications":
            addBotMessage(
                text: String(localized: "To fix notification issues:\n\n1. Go to iPhone Settings → Notifications\n2. Find our app and make sure notifications are ON\n3. Check that 'Allow Notifications' is enabled\n4. In our app, go to Settings and set your reminder time\n\nMake sure Do Not Disturb isn't blocking notifications!"),
                options: [backToMainOption, wasThisHelpfulOption]
            )

        // Content Options
        case "request_content":
            currentContext = .freeForm
            showFreeFormInput = true
            addBotMessage(
                text: String(localized: "We'd love to hear your content ideas! What type of meditation, sleep story, or feature would you like to see? Type below:"),
                options: []
            )

        case "report_content":
            currentContext = .freeForm
            showFreeFormInput = true
            addBotMessage(
                text: String(localized: "I'm sorry something's not right. Please describe the issue with the content (which meditation/story, what's wrong):"),
                options: []
            )

        case "how_to_use":
            addBotMessage(
                text: String(localized: "Here's how to get started:\n\n🏠 **Home** — Personalized recommendations, daily mix, and continue listening\n😴 **Sleep** — Sleep stories, sounds, soundscape mixer, and sleep timer\n🔍 **Discover** — Browse all content, breathing exercises, body scan, programs, focus timer, AI meditations, and Micro-Moments\n💬 **Chat** — Talk to Breathe AI for wellness guidance\n👤 **Profile** — Your stats, mood insights, favorites, playlists, and settings\n⌚ **Apple Watch** — Quick sessions right from your wrist\n\nTry the daily recommendation on the Home screen!"),
                options: [backToMainOption, wasThisHelpfulOption]
            )

        // Feedback Options
        case "love_app":
            addBotMessage(
                text: String(localized: "That makes us so happy! 🎉\n\nIf you have a moment, a 5-star review on the App Store helps others discover mindfulness too. It really means a lot to our small team!\n\nThank you for being part of our community. 💜"),
                options: [SupportOption(id: "rate_app", icon: "star.fill", title: String(localized: "Rate on App Store")), backToMainOption]
            )

        case "rate_app":
            // Trigger app rating
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
            addBotMessage(
                text: String(localized: "Thank you! Your support means everything. 🙏"),
                options: [backToMainOption]
            )

        case "suggestion":
            currentContext = .freeForm
            showFreeFormInput = true
            addBotMessage(
                text: String(localized: "We're always looking to improve! What feature or improvement would make the app better for you?"),
                options: []
            )

        case "report_bug":
            currentContext = .freeForm
            showFreeFormInput = true
            addBotMessage(
                text: String(localized: "Sorry you ran into a bug! Please describe what happened and what you expected to happen:"),
                options: []
            )

        // Apple Watch
        case "watch_issues":
            addBotMessage(
                text: String(localized: "For Apple Watch issues:\n\n1. Make sure the Watch app is installed (open the Watch app on your iPhone)\n2. Both devices need to be on the same Apple ID\n3. Try restarting both your iPhone and Apple Watch\n4. Check that Bluetooth and WiFi are enabled\n\nThe Watch app syncs your sessions and streak with the iPhone app automatically. If sync seems stuck, open the main app on your iPhone — this triggers a fresh sync."),
                options: [backToMainOption, wasThisHelpfulOption]
            )

        // Offline Downloads
        case "offline_issues":
            addBotMessage(
                text: String(localized: "For offline download issues:\n\n1. Make sure you have an active Premium subscription\n2. Check that you have enough storage space on your device\n3. Try downloading on a stable WiFi connection\n4. If a download is stuck, try deleting it and re-downloading\n\nDownloaded content is stored locally on your device. You can manage your downloads in Settings. An active subscription is required to play downloaded content."),
                options: [backToMainOption, wasThisHelpfulOption]
            )

        // AI Meditations
        case "ai_meditations":
            addBotMessage(
                text: String(localized: "AI Meditations creates personalized sessions just for you!\n\n**How it works:**\n1. Go to the Discover tab\n2. Look for 'AI Meditation' or the sparkles icon\n3. Choose your focus area (e.g., stress, sleep, focus)\n4. Select your preferred duration\n5. The AI generates a unique meditation script\n\nEach session is one-of-a-kind and tailored to your needs. Free users can try it too! The AI is not a therapist — for serious mental health concerns, please reach out to a professional."),
                options: [backToMainOption, wasThisHelpfulOption]
            )

        // Utility
        case "back_to_main":
            startChat()

        case "helpful_yes":
            addBotMessage(
                text: String(localized: "Great! Is there anything else I can help you with?"),
                options: mainMenuOptions
            )

        case "helpful_no", "still_not_working", "still_no_audio":
            currentContext = .freeForm
            showFreeFormInput = true
            addBotMessage(
                text: String(localized: "I'm sorry that didn't help. Please describe your issue in more detail and I'll do my best to assist, or you can email us at \(Constants.Support.email) for personalized help."),
                options: []
            )

        default:
            addBotMessage(
                text: String(localized: "I'm not sure about that. Let me connect you with more options."),
                options: mainMenuOptions
            )
        }
    }

    private var subscriptionOptions: [SupportOption] {
        [
            SupportOption(id: "cancel_subscription", icon: "xmark.circle", title: String(localized: "Cancel subscription")),
            SupportOption(id: "restore_purchase", icon: "arrow.clockwise", title: String(localized: "Restore purchase")),
            SupportOption(id: "billing_issue", icon: "creditcard", title: String(localized: "Billing question")),
            SupportOption(id: "subscription_not_working", icon: "exclamationmark.triangle", title: String(localized: "Premium not working")),
            backToMainOption
        ]
    }

    private var accountOptions: [SupportOption] {
        [
            SupportOption(id: "sign_in_help", icon: "person.badge.key", title: String(localized: "Sign in help")),
            SupportOption(id: "delete_account", icon: "trash", title: String(localized: "Delete my account")),
            SupportOption(id: "data_sync", icon: "arrow.triangle.2.circlepath", title: String(localized: "Data sync issues")),
            SupportOption(id: "privacy_data", icon: "lock.shield", title: String(localized: "Privacy & my data")),
            backToMainOption
        ]
    }

    private var technicalOptions: [SupportOption] {
        [
            SupportOption(id: "audio_not_playing", icon: "speaker.slash", title: String(localized: "Audio not playing")),
            SupportOption(id: "app_crashing", icon: "exclamationmark.triangle", title: String(localized: "App crashing")),
            SupportOption(id: "video_loading", icon: "hourglass", title: String(localized: "Slow loading")),
            SupportOption(id: "notifications", icon: "bell.slash", title: String(localized: "Notification issues")),
            SupportOption(id: "watch_issues", icon: "applewatch", title: String(localized: "Apple Watch issues")),
            SupportOption(id: "offline_issues", icon: "arrow.down.circle", title: String(localized: "Offline downloads")),
            backToMainOption
        ]
    }

    private var contentOptions: [SupportOption] {
        [
            SupportOption(id: "request_content", icon: "plus.bubble", title: String(localized: "Request new content")),
            SupportOption(id: "report_content", icon: "flag", title: String(localized: "Report a problem")),
            SupportOption(id: "how_to_use", icon: "questionmark.circle", title: String(localized: "How to use the app")),
            SupportOption(id: "ai_meditations", icon: "sparkles", title: String(localized: "AI Meditations")),
            backToMainOption
        ]
    }

    private var feedbackOptions: [SupportOption] {
        [
            SupportOption(id: "love_app", icon: "heart.fill", title: String(localized: "I love this app!")),
            SupportOption(id: "suggestion", icon: "lightbulb", title: String(localized: "Feature suggestion")),
            SupportOption(id: "report_bug", icon: "ant", title: String(localized: "Report a bug")),
            backToMainOption
        ]
    }

    private var backToMainOption: SupportOption {
        SupportOption(id: "back_to_main", icon: "arrow.uturn.backward", title: String(localized: "Back to main menu"))
    }

    private var wasThisHelpfulOption: SupportOption {
        SupportOption(id: "helpful_yes", icon: "hand.thumbsup", title: String(localized: "Yes, this helped!"))
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        addUserMessage(text: text)
        inputText = ""
        isTyping = true

        // Simulate AI response (in production, this would call your API)
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            await MainActor.run {
                isTyping = false
                handleFreeFormMessage(text)
            }
        }
    }

    private func handleFreeFormMessage(_ text: String) {
        // Simple keyword-based responses for common questions
        let lowercased = text.lowercased()

        if lowercased.contains("cancel") && lowercased.contains("subscri") {
            processOption("cancel_subscription")
        } else if lowercased.contains("restore") || lowercased.contains("purchase") {
            processOption("restore_purchase")
        } else if lowercased.contains("refund") || lowercased.contains("money back") {
            processOption("billing_issue")
        } else if lowercased.contains("delete") && (lowercased.contains("account") || lowercased.contains("data")) {
            processOption("delete_account")
        } else if lowercased.contains("not play") || lowercased.contains("no sound") || lowercased.contains("no audio") {
            processOption("audio_not_playing")
        } else if lowercased.contains("crash") || lowercased.contains("freeze") || lowercased.contains("stuck") {
            processOption("app_crashing")
        } else if lowercased.contains("slow") || lowercased.contains("loading") || lowercased.contains("buffer") {
            processOption("video_loading")
        } else if lowercased.contains("notification") || lowercased.contains("reminder") {
            processOption("notifications")
        } else if lowercased.contains("sign in") || lowercased.contains("login") || lowercased.contains("log in") {
            processOption("sign_in_help")
        } else if lowercased.contains("sync") || lowercased.contains("device") || lowercased.contains("transfer") {
            processOption("data_sync")
        } else if lowercased.contains("watch") || lowercased.contains("apple watch") || lowercased.contains("wrist") {
            processOption("watch_issues")
        } else if lowercased.contains("offline") || lowercased.contains("download") {
            processOption("offline_issues")
        } else if lowercased.contains("ai meditation") || lowercased.contains("generated meditation") || lowercased.contains("personalized meditation") {
            processOption("ai_meditations")
        } else {
            // Generic response for unrecognized queries
            addBotMessage(
                text: String(localized: "Thank you for your message! I've noted your feedback.\n\nFor complex issues, you can also reach us at \(Constants.Support.email) and we'll get back to you within 24-48 hours.\n\nIs there anything else I can help with?"),
                options: mainMenuOptions
            )
            showFreeFormInput = false
            currentContext = .mainMenu
        }
    }

    private func addBotMessage(text: String, options: [SupportOption]) {
        let message = SupportMessage(
            id: UUID().uuidString,
            role: .bot,
            text: text,
            options: options,
            timestamp: Date()
        )
        messages.append(message)
    }

    private func addUserMessage(text: String) {
        let message = SupportMessage(
            id: UUID().uuidString,
            role: .user,
            text: text,
            options: [],
            timestamp: Date()
        )
        messages.append(message)
    }
}

// MARK: - Models

struct SupportMessage: Identifiable {
    let id: String
    let role: SupportMessageRole
    let text: String
    let options: [SupportOption]
    let timestamp: Date
}

enum SupportMessageRole {
    case bot
    case user
}

struct SupportOption: Identifiable {
    let id: String
    let icon: String
    let title: String
}

// MARK: - Message Bubble

struct SupportMessageBubble: View {
    let message: SupportMessage
    let onOptionTap: (SupportOption) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .bot {
                // Bot avatar
                ZStack {
                    Circle()
                        .fill(Theme.profileAccent.opacity(0.2))
                        .frame(width: 32, height: 32)

                    Image(systemName: "headphones.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.profileAccent)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(message.text)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Options
                    if !message.options.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(message.options) { option in
                                Button {
                                    HapticManager.light()
                                    onOptionTap(option)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: option.icon)
                                            .font(.system(size: 14))
                                            .foregroundStyle(Theme.profileAccent)
                                            .frame(width: 20)

                                        Text(option.title)
                                            .font(.subheadline)
                                            .foregroundStyle(.white)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.white.opacity(0.4))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)

                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Theme.profileAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

// MARK: - Support Typing Indicator

private struct SupportTypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ZStack {
                Circle()
                    .fill(Theme.profileAccent.opacity(0.2))
                    .frame(width: 32, height: 32)

                Image(systemName: "headphones.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.profileAccent)
            }

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(.white.opacity(0.5))
                        .frame(width: 8, height: 8)
                        .offset(y: animating ? -4 : 4)
                        .animation(
                            .easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer()
        }
        .onAppear { animating = true }
    }
}

#Preview {
    SupportChatView()
}
