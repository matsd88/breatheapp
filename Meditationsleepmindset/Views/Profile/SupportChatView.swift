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
                            .accessibilityLabel("Close")
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
            .onChange(of: viewModel.shouldDismiss) { _, should in
                if should { dismiss() }
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
    /// Set when an option deep-links into the app — the hosting view dismisses.
    @Published var shouldDismiss = false

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
            options: mainMenuOptions,
            layout: .grid
        )
    }

    func resetChat() {
        startChat()
    }

    private var mainMenuOptions: [SupportOption] {
        [
            SupportOption(id: "subscription", icon: "crown.fill", title: String(localized: "Subscription & Billing"), tint: SupportTint.amber),
            SupportOption(id: "account", icon: "person.crop.circle", title: String(localized: "Account Help"), tint: SupportTint.blue),
            SupportOption(id: "technical", icon: "wrench.and.screwdriver", title: String(localized: "Technical Issues"), tint: SupportTint.coral),
            SupportOption(id: "content", icon: "play.circle", title: String(localized: "Content & Features"), tint: SupportTint.green),
            SupportOption(id: "feedback", icon: "star.bubble", title: String(localized: "Feedback & Suggestions"), tint: SupportTint.pink),
            SupportOption(id: "other", icon: "ellipsis.bubble", title: String(localized: "Something Else"), tint: SupportTint.teal)
        ]
    }

    func handleOptionSelected(_ option: SupportOption) {
        // Direct actions (deep links, external URLs, in-chat fixes)
        if let action = option.action {
            addUserMessage(text: option.title)
            perform(action)
            return
        }

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

    private func perform(_ action: SupportAction) {
        switch action {
        case .route(let route):
            AppStateManager.shared.navigate(to: route)
            shouldDismiss = true

        case .url(let urlString):
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }

        case .restorePurchases:
            runRestorePurchases()
        }
    }

    /// Do the restore for the user right in the chat instead of sending them
    /// on a settings scavenger hunt.
    private func runRestorePurchases() {
        guard !StoreManager.shared.isRestoring else { return }
        isTyping = true
        Task {
            let outcome = await StoreManager.shared.restorePurchases()

            await MainActor.run {
                isTyping = false
                // The bot reports the outcome in-chat; don't leave StoreManager's
                // global alert armed to fire on a future paywall.
                StoreManager.shared.dismissAlert()
                if outcome == .restored {
                    addBotMessage(
                        text: String(localized: "✅ All done — your Premium access is restored and active. Enjoy!"),
                        options: [backToMainOption]
                    )
                } else {
                    addBotMessage(
                        text: String(localized: "I ran the restore but couldn't find an active subscription on this Apple ID.\n\nDouble-check that you're signed into the same Apple ID you purchased with (iPhone Settings → your name), then try again. If you believe this is wrong, email us at \(Constants.Support.email)."),
                        options: [
                            SupportOption(id: "do_restore", icon: "arrow.clockwise", title: String(localized: "Try restore again"), tint: SupportTint.blue, action: .restorePurchases),
                            SupportOption(id: "see_premium", icon: "sparkles", title: String(localized: "See Premium plans"), tint: SupportTint.amber, action: .route(.premium)),
                            backToMainOption
                        ]
                    )
                }
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
                options: subscriptionOptions,
                layout: .grid
            )

        case "account":
            currentContext = .account
            addBotMessage(
                text: String(localized: "I can help with your account. What do you need?"),
                options: accountOptions,
                layout: .grid
            )

        case "technical":
            currentContext = .technical
            addBotMessage(
                text: String(localized: "Let me help you with technical issues. What's happening?"),
                options: technicalOptions,
                layout: .grid
            )

        case "content":
            currentContext = .content
            addBotMessage(
                text: String(localized: "I'd love to help you with our content! What's on your mind?"),
                options: contentOptions,
                layout: .grid
            )

        case "feedback":
            currentContext = .feedback
            addBotMessage(
                text: String(localized: "We value your feedback! What would you like to share?"),
                options: feedbackOptions,
                layout: .grid
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
                text: String(localized: "Subscriptions are managed by Apple. Tap the button below to open your Apple subscriptions page, then select our app and tap 'Cancel Subscription'.\n\nYou'll keep access until the end of your billing period — and your streak, favorites, and progress stay safe if you ever come back. 💜"),
                options: [
                    SupportOption(id: "manage_subs", icon: "creditcard", title: String(localized: "Manage subscriptions"), tint: SupportTint.blue, action: .url("https://apps.apple.com/account/subscriptions")),
                    backToMainOption, wasThisHelpfulOption
                ]
            )

        case "restore_purchase":
            addBotMessage(
                text: String(localized: "I can restore your purchases for you right now — just tap the button below.\n\nOne thing to check first: make sure you're signed into the same Apple ID you used when you purchased."),
                options: [
                    SupportOption(id: "do_restore", icon: "arrow.clockwise", title: String(localized: "Restore my purchases"), tint: SupportTint.green, action: .restorePurchases),
                    backToMainOption
                ]
            )

        case "free_trial":
            addBotMessage(
                text: String(localized: "The trial runs 7 days and unlocks everything — the full library, the AI studio, kids stories and offline downloads.\n\n📅 Today — full access starts straight away.\n🔔 Day 5 — Apple emails you a reminder that the trial is ending.\n💳 Day 7 — your subscription begins.\n\nCancel any time before day 7 and you pay nothing. Cancelling is done in Apple's settings, and you keep access until the trial ends.\n\nOnly one trial per Apple ID — if you've had one before, subscribing starts billing immediately."),
                options: [
                    SupportOption(id: "manage_subscription_apple", icon: "gear", title: String(localized: "Manage in Apple settings"), tint: SupportTint.blue, action: .url("https://apps.apple.com/account/subscriptions")),
                    SupportOption(id: "see_premium", icon: "sparkles", title: String(localized: "See Premium plans"), tint: SupportTint.amber, action: .route(.premium)),
                    backToMainOption, wasThisHelpfulOption
                ]
            )

        case "billing_issue":
            addBotMessage(
                text: String(localized: "All payments are processed securely by Apple through the App Store — we never see or store your payment details.\n\n• To request a refund, use Apple's official page below\n• For other billing questions, contact Apple Support directly"),
                options: [
                    SupportOption(id: "apple_refund", icon: "arrow.uturn.left.circle", title: String(localized: "Request a refund (Apple)"), tint: SupportTint.amber, action: .url("https://reportaproblem.apple.com")),
                    backToMainOption, wasThisHelpfulOption
                ]
            )

        case "subscription_not_working":
            addBotMessage(
                text: String(localized: "Let's fix that. The quickest solution is a restore — I can run it for you right now with the button below.\n\nIf that doesn't do it:\n1. Make sure you're signed into the correct Apple ID\n2. Force close and reopen the app\n3. Check your status in iPhone Settings → Subscriptions"),
                options: [
                    SupportOption(id: "do_restore", icon: "arrow.clockwise", title: String(localized: "Restore my purchases"), tint: SupportTint.green, action: .restorePurchases),
                    SupportOption(id: "still_not_working", icon: "exclamationmark.triangle", title: String(localized: "Still not working")),
                    backToMainOption
                ]
            )

        case "premium_info":
            addBotMessage(
                text: String(localized: "Here's what Premium unlocks:\n\n✨ The full library — every premium meditation, sleep story, and program (free content stays free forever)\n🎙️ Up to 5 AI-generated meditations & kids stories per day\n💬 Unlimited AI coach chat with natural, human-like voices\n📥 Offline downloads for travel and bedtime\n\nPlans: weekly, monthly, or annual (best value) — all with a free trial, cancel anytime."),
                options: [
                    SupportOption(id: "see_premium", icon: "sparkles", title: String(localized: "See Premium plans"), tint: SupportTint.amber, action: .route(.premium)),
                    backToMainOption, wasThisHelpfulOption
                ]
            )

        case "offline_downloads":
            addBotMessage(
                text: String(localized: "Offline packs let you download sessions and play them with no signal — flights, the Underground, a cabin with bad wifi.\n\nGo to the You tab → Offline Packs, choose a pack, and tap download. Once it's on your device it plays without a connection, and it keeps counting toward your streak.\n\nDownloads are part of Premium. Everything you've already downloaded stays available."),
                options: [
                    SupportOption(id: "see_premium", icon: "sparkles", title: String(localized: "See Premium plans"), tint: SupportTint.amber, action: .route(.premium)),
                    backToMainOption, wasThisHelpfulOption
                ]
            )

        case "sleep_tools":
            addBotMessage(
                text: String(localized: "The Sleep tab has three tools:\n\n⏱️ Sleep timer — fades the audio out and stops playback so it doesn't run all night.\n⏰ Alarm — wakes you with a gentle sound rather than a jolt.\n📊 Sleep score — take the short sleep assessment and you'll get a persona and a plan tuned to how you actually sleep.\n\nThe wind-down banner on that tab also suggests the best time to start based on your usual bedtime."),
                options: [backToMainOption, wasThisHelpfulOption]
            )

        case "accessibility_help":
            addBotMessage(
                text: String(localized: "Settings → Accessibility has three options:\n\n🔤 Larger Text — increases type size across the app.\n◐ High Contrast — lifts contrast for easier reading.\n🌊 Reduce Motion — holds the animated backgrounds and the breathing glow still. The app also follows the system Reduce Motion setting from iOS Settings → Accessibility → Motion.\n\nHaptics can be turned off in the same place, and every screen works with VoiceOver."),
                options: [backToMainOption, wasThisHelpfulOption]
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
                text: String(localized: "We take your privacy seriously:\n\n• Your data is stored securely on your device and in your personal iCloud\n• We don't sell or share your personal information\n• Analytics (Firebase, AppsFlyer) are anonymous and used only to improve the app\n• AI chat and meditation requests are processed by OpenAI but not stored or used for training\n• Voice mode is optional — the mic is only active while you record, and your speech is transcribed by Apple. We never store audio\n• The AI's long-term 'memory' is a short summary kept on your device; clearing your chat history erases it\n• You can delete your data anytime\n\nRead our full Privacy Policy in Settings → Legal or at meditationandsleepapp.com/privacy"),
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
                text: String(localized: "Two places control notifications:\n\n• **In the app** — set your daily reminder time and choose which reminders you get (button below)\n• **In iOS Settings** — make sure notifications are allowed for our app (button below)\n\nAlso check that Focus/Do Not Disturb isn't silencing them!"),
                options: [
                    SupportOption(id: "open_reminders", icon: "bell.badge", title: String(localized: "Open reminder settings"), tint: SupportTint.pink, action: .route(.notificationSettings)),
                    SupportOption(id: "open_ios_settings", icon: "gear", title: String(localized: "Open iOS Settings"), tint: SupportTint.blue, action: .url(UIApplication.openSettingsURLString)),
                    backToMainOption, wasThisHelpfulOption
                ]
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
                text: String(localized: "Here's how to get started:\n\n🏠 **Home** — Your Plan for Today (a personal 3-step daily plan), personalized recommendations, your AI Meditation Studio, and daily rituals: Set Intention, Gratitude journal, Haptic Breathing, and Kids bedtime stories\n😴 **Sleep** — Sleep stories, sounds, soundscape mixer, sleep timer, a gentle wake alarm, and your nightly Sleep Score\n🔍 **Discover** — Browse 960+ sessions, multi-day programs, breathing exercises, body scan, focus timer with real nature sounds, AI meditations, and Micro-Moments\n💬 **Chat** — Talk to Breathe AI for wellness guidance. Pick a specialized coach (Stress, Sleep, Relationships, Parenting, Focus), tap the mic to talk hands-free, and tap the speaker on any reply to hear it read aloud (5 free messages, unlimited for premium)\n👤 **Profile** — Your stats, streak & Streak Shield, mood insights, favorites, playlists, and settings\n🎧 **Player** — Tap 'Up next' to see and reorder what's coming, stream to any speaker with AirPlay, set a sleep timer, or layer ambient sounds\n🔔 **Reminders** — Set your daily reminder time in Settings → Notifications. From the reminder on your lock screen you can tap 'Start a session' or 'Play a sleep story' to jump straight in\n⌚ **Apple Watch** — Quick sessions right from your wrist\n\nFree users have unlimited access to non-premium content. Premium content shows a 2-minute preview — subscribe to unlock the full library!"),
                options: [
                    SupportOption(id: "go_home", icon: "house", title: String(localized: "Open Home"), tint: SupportTint.blue, action: .route(.home)),
                    SupportOption(id: "go_sleep", icon: "moon.stars", title: String(localized: "Open Sleep"), tint: SupportTint.indigo, action: .route(.sleep)),
                    SupportOption(id: "go_discover", icon: "sparkles", title: String(localized: "Open Discover"), tint: SupportTint.teal, action: .route(.discover)),
                    SupportOption(id: "go_chat", icon: "bubble.left.and.text.bubble.right", title: String(localized: "Open AI Chat"), tint: SupportTint.pink, action: .route(.chat)),
                    backToMainOption, wasThisHelpfulOption
                ]
            )

        case "programs_plans":
            addBotMessage(
                text: String(localized: "Two great ways to build a practice:\n\n📅 **Your Plan for Today** — At the top of your Home tab. Every day we build you a fresh 3-step plan: a short morning meditation, a midday breathing reset, and an evening wind-down. Complete all three for a perfect day!\n\n🗺️ **Programs** — Guided multi-day journeys in Discover: 7 Days of Calm, 7 Nights of Deep Sleep, 5 Days of Focus, 7 Days of Gratitude, 5 Days of Anxiety Relief, and more. One session a day, with your progress tracked as you go."),
                options: [
                    SupportOption(id: "go_home_plan", icon: "checklist", title: String(localized: "See Today's Plan"), tint: SupportTint.green, action: .route(.home)),
                    SupportOption(id: "go_programs", icon: "map", title: String(localized: "Browse programs"), tint: SupportTint.indigo, action: .route(.discover)),
                    backToMainOption, wasThisHelpfulOption
                ]
            )

        case "streaks_shield":
            addBotMessage(
                text: String(localized: "🔥 **Streaks** — Complete any session (even a 1-minute breathing exercise) to keep your daily streak alive. Your streak syncs to your Apple Watch and home-screen widgets.\n\n🛡️ **Streak Shield** — Life happens! If you miss a day, your shield automatically protects your streak — once every 7 days. No guilt, rest matters. You can see whether your shield is ready on your Profile.\n\nSigning in with Apple backs your streak up to iCloud, so it survives new phones too."),
                options: [
                    SupportOption(id: "go_profile", icon: "flame", title: String(localized: "View my streak"), tint: SupportTint.amber, action: .route(.profile)),
                    backToMainOption, wasThisHelpfulOption
                ]
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
                text: String(localized: "For offline download issues:\n\n1. Make sure you have an active Premium subscription\n2. Check that you have enough storage space on your device\n3. Try downloading on a stable WiFi connection\n4. If a download is stuck, try deleting it and re-downloading\n\nDownloads are stored on your device — manage them with the button below. An active subscription is required to download and play premium content offline."),
                options: [
                    SupportOption(id: "open_offline", icon: "arrow.down.circle", title: String(localized: "Open Offline Packs"), tint: SupportTint.green, action: .route(.offlineDownloads)),
                    backToMainOption, wasThisHelpfulOption
                ]
            )

        // AI Meditations
        case "ai_meditations":
            addBotMessage(
                text: String(localized: "AI Meditations creates personalized sessions just for you!\n\n**How it works:**\n1. Open the AI Meditation Studio (button below, or from Home)\n2. Choose your focus area (e.g., stress, sleep, focus)\n3. Select your preferred duration and voice\n4. The AI generates a unique meditation script and audio\n\n**Limits:**\n• Free users: 1 AI meditation (lifetime)\n• Premium users: Up to 5 per day (resets at midnight)\n\nGenerated meditations are saved to your 'My Creations' playlist. The AI is not a therapist — for serious mental health concerns, please reach out to a professional."),
                options: [
                    SupportOption(id: "go_ai_studio", icon: "sparkles", title: String(localized: "Open AI Studio"), tint: SupportTint.indigo, action: .route(.aiStudio)),
                    backToMainOption, wasThisHelpfulOption
                ]
            )

        // Utility
        case "ai_coaches_voice":
            addBotMessage(
                text: String(localized: "Breathe AI can be tailored to you:\n\n**Coaches** — On the Chat tab, pick a specialized coach: Stress, Sleep, Relationships, Parenting, or Focus. Each one tailors its tone and advice. Your choice is remembered.\n\n**Voice mode** — Tap the microphone in the chat bar to talk instead of type; your words are transcribed on the spot. Tap the speaker icon on any reply (or in the header) to have it read aloud — Premium members hear natural, human-like voices matched to each coach.\n\n**Memory** — The AI keeps a short private summary of past chats (on your device) so it remembers what matters to you. Clear it any time with 'Clear Chat History' from the chat menu.\n\nBreathe AI is for general wellness support, not a substitute for professional care."),
                options: [
                    SupportOption(id: "go_chat2", icon: "bubble.left.and.text.bubble.right", title: String(localized: "Open AI Chat"), tint: SupportTint.pink, action: .route(.chat)),
                    wasThisHelpfulOption, backToMainOption
                ]
            )
        case "kids_stories":
            addBotMessage(
                text: String(localized: "Kids bedtime stories create a soothing, personalized story for your child:\n\n1. Open Kids Stories (button below, or from Home)\n2. Enter your child's first name (optional)\n3. Pick a theme (Sleepy Forest, Ocean Dreams, and more), length, and storyteller voice\n4. Tap 'Create Bedtime Story' — the AI writes and narrates a unique story with your child's name woven in\n\nStories are saved so you can replay favorites. The child's name stays on your device and is only used to personalize the story.\n\n**Limits:** Free users get 1 AI creation; Premium users get up to 5 per day."),
                options: [
                    SupportOption(id: "go_kids", icon: "teddybear", title: String(localized: "Create a story"), tint: SupportTint.amber, action: .route(.kidsStories)),
                    wasThisHelpfulOption, backToMainOption
                ]
            )
        case "back_to_main":
            startChat()

        case "helpful_yes":
            addBotMessage(
                text: String(localized: "Great! Is there anything else I can help you with?"),
                options: mainMenuOptions,
                layout: .grid
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
                options: mainMenuOptions,
                layout: .grid
            )
        }
    }

    private var subscriptionOptions: [SupportOption] {
        [
            SupportOption(id: "premium_info", icon: "sparkles", title: String(localized: "What's in Premium?"), tint: SupportTint.amber),
            SupportOption(id: "free_trial", icon: "clock.badge.checkmark", title: String(localized: "How the free trial works"), tint: SupportTint.green),
            SupportOption(id: "restore_purchase", icon: "arrow.clockwise", title: String(localized: "Restore purchase"), tint: SupportTint.blue),
            SupportOption(id: "subscription_not_working", icon: "exclamationmark.triangle", title: String(localized: "Premium not working"), tint: SupportTint.pink),
            SupportOption(id: "cancel_subscription", icon: "xmark.circle", title: String(localized: "Cancel subscription"), tint: SupportTint.coral),
            SupportOption(id: "billing_issue", icon: "creditcard", title: String(localized: "Billing question"), tint: SupportTint.teal),
            backToMainOption
        ]
    }

    private var accountOptions: [SupportOption] {
        [
            SupportOption(id: "sign_in_help", icon: "person.badge.key", title: String(localized: "Sign in help"), tint: SupportTint.blue),
            SupportOption(id: "delete_account", icon: "trash", title: String(localized: "Delete my account"), tint: SupportTint.coral),
            SupportOption(id: "data_sync", icon: "arrow.triangle.2.circlepath", title: String(localized: "Data sync issues"), tint: SupportTint.teal),
            SupportOption(id: "privacy_data", icon: "lock.shield", title: String(localized: "Privacy & my data"), tint: SupportTint.green),
            backToMainOption
        ]
    }

    private var technicalOptions: [SupportOption] {
        [
            SupportOption(id: "audio_not_playing", icon: "speaker.slash", title: String(localized: "Audio not playing"), tint: SupportTint.coral),
            SupportOption(id: "app_crashing", icon: "exclamationmark.triangle", title: String(localized: "App crashing"), tint: SupportTint.amber),
            SupportOption(id: "video_loading", icon: "hourglass", title: String(localized: "Slow loading"), tint: SupportTint.blue),
            SupportOption(id: "notifications", icon: "bell.slash", title: String(localized: "Notification issues"), tint: SupportTint.pink),
            SupportOption(id: "watch_issues", icon: "applewatch", title: String(localized: "Apple Watch issues"), tint: SupportTint.teal),
            SupportOption(id: "offline_issues", icon: "arrow.down.circle", title: String(localized: "Offline downloads"), tint: SupportTint.green),
            backToMainOption
        ]
    }

    private var contentOptions: [SupportOption] {
        [
            SupportOption(id: "how_to_use", icon: "questionmark.circle", title: String(localized: "How to use the app"), tint: SupportTint.blue),
            SupportOption(id: "programs_plans", icon: "map", title: String(localized: "Programs & Today's Plan"), tint: SupportTint.teal),
            SupportOption(id: "streaks_shield", icon: "flame", title: String(localized: "Streaks & Streak Shield"), tint: SupportTint.amber),
            SupportOption(id: "ai_meditations", icon: "sparkles", title: String(localized: "AI Meditations"), tint: SupportTint.indigo),
            SupportOption(id: "ai_coaches_voice", icon: "bubble.left.and.text.bubble.right", title: String(localized: "AI coaches & voice"), tint: SupportTint.pink),
            SupportOption(id: "kids_stories", icon: "teddybear", title: String(localized: "Kids bedtime stories"), tint: SupportTint.amber),
            SupportOption(id: "offline_downloads", icon: "arrow.down.circle", title: String(localized: "Offline downloads"), tint: SupportTint.indigo),
            SupportOption(id: "sleep_tools", icon: "moon.zzz", title: String(localized: "Sleep timer, alarm & score"), tint: SupportTint.blue),
            SupportOption(id: "accessibility_help", icon: "accessibility", title: String(localized: "Accessibility options"), tint: SupportTint.teal),
            SupportOption(id: "request_content", icon: "plus.bubble", title: String(localized: "Request new content"), tint: SupportTint.green),
            SupportOption(id: "report_content", icon: "flag", title: String(localized: "Report a problem"), tint: SupportTint.coral),
            backToMainOption
        ]
    }

    private var feedbackOptions: [SupportOption] {
        [
            SupportOption(id: "love_app", icon: "heart.fill", title: String(localized: "I love this app!"), tint: SupportTint.pink),
            SupportOption(id: "suggestion", icon: "lightbulb", title: String(localized: "Feature suggestion"), tint: SupportTint.amber),
            SupportOption(id: "report_bug", icon: "ant", title: String(localized: "Report a bug"), tint: SupportTint.coral),
            backToMainOption
        ]
    }

    private var backToMainOption: SupportOption {
        SupportOption(id: "back_to_main", icon: "arrow.uturn.backward", title: String(localized: "Back to main menu"), tint: SupportTint.teal)
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
        } else if lowercased.contains("streak") || lowercased.contains("shield") {
            processOption("streaks_shield")
        } else if lowercased.contains("program") || lowercased.contains("course") || lowercased.contains("plan") {
            processOption("programs_plans")
        } else if lowercased.contains("premium") || lowercased.contains("price") || lowercased.contains("cost") || lowercased.contains("upgrade") || lowercased.contains("trial") {
            processOption("premium_info")
        } else if lowercased.contains("ai meditation") || lowercased.contains("generated meditation") || lowercased.contains("personalized meditation") {
            processOption("ai_meditations")
        } else if lowercased.contains("coach") || lowercased.contains("voice") || lowercased.contains("microphone") || lowercased.contains("talk") || lowercased.contains("memory") {
            processOption("ai_coaches_voice")
        } else if lowercased.contains("kid") || lowercased.contains("child") || lowercased.contains("bedtime") || lowercased.contains("story") {
            processOption("kids_stories")
        } else {
            // Generic response for unrecognized queries
            addBotMessage(
                text: String(localized: "Thank you for your message! I've noted your feedback.\n\nFor complex issues, you can also reach us at \(Constants.Support.email) and we'll get back to you within 24-48 hours.\n\nIs there anything else I can help with?"),
                options: mainMenuOptions,
                layout: .grid
            )
            showFreeFormInput = false
            currentContext = .mainMenu
        }
    }

    private func addBotMessage(text: String, options: [SupportOption], layout: SupportOptionLayout = .list) {
        let message = SupportMessage(
            id: UUID().uuidString,
            role: .bot,
            text: text,
            options: options,
            optionLayout: layout,
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
    var optionLayout: SupportOptionLayout = .list
    let timestamp: Date
}

enum SupportMessageRole {
    case bot
    case user
}

/// How a bot message's options are laid out: a 2-column card grid for top-level
/// category menus, or a slim vertical list for follow-up actions.
enum SupportOptionLayout {
    case list
    case grid
}

struct SupportOption: Identifiable {
    let id: String
    let icon: String
    let title: String
    var tint: Color = Theme.profileAccent
    /// When set, tapping the option performs this instead of showing another
    /// bot message (deep link into the app, external URL, or a direct fix).
    var action: SupportAction? = nil
}

/// Things a support option can do beyond navigating the decision tree.
enum SupportAction {
    /// Close the bot and navigate to a screen in the app.
    case route(AppRoute)
    /// Open an external URL (Apple subscription management, refunds, iOS Settings).
    case url(String)
    /// Run Restore Purchases right here in the chat and report the result.
    case restorePurchases
}

/// Distinct, calm-but-vivid accent colors for the support category cards.
enum SupportTint {
    static let amber = Color(red: 0.98, green: 0.74, blue: 0.28)
    static let blue = Color(red: 0.40, green: 0.58, blue: 0.96)
    static let coral = Color(red: 0.96, green: 0.48, blue: 0.40)
    static let green = Color(red: 0.30, green: 0.80, blue: 0.58)
    static let pink = Color(red: 0.84, green: 0.46, blue: 0.86)
    static let teal = Color(red: 0.36, green: 0.74, blue: 0.82)
    static let indigo = Color(red: 0.52, green: 0.50, blue: 0.95)
}

// MARK: - Message Bubble

struct SupportMessageBubble: View {
    let message: SupportMessage
    let onOptionTap: (SupportOption) -> Void

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        if message.role == .bot {
            VStack(alignment: .leading, spacing: 14) {
                // Greeting / answer bubble with avatar
                HStack(alignment: .top, spacing: 8) {
                    botAvatar
                    Text(message.text)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    Spacer(minLength: 40)
                }

                // Options
                if !message.options.isEmpty {
                    if message.optionLayout == .grid {
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            ForEach(message.options) { option in
                                SupportOptionCard(option: option) { onOptionTap(option) }
                            }
                        }
                    } else {
                        VStack(spacing: 8) {
                            ForEach(message.options) { option in
                                SupportOptionRow(option: option) { onOptionTap(option) }
                            }
                        }
                    }
                }
            }
        } else {
            HStack(alignment: .top, spacing: 8) {
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

    private var botAvatar: some View {
        ZStack {
            Circle()
                .fill(Theme.profileAccent.opacity(0.2))
                .frame(width: 32, height: 32)
            Image(systemName: "headphones.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.profileAccent)
        }
    }
}

// MARK: - Support Option Card (grid)

private struct SupportOptionCard: View {
    let option: SupportOption
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [option.tint.opacity(0.32), option.tint.opacity(0.16)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    Image(systemName: option.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(option.tint)
                }

                Text(option.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 124)
            .padding(.vertical, 16)
            .padding(.horizontal, 10)
            .background(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
    }
}

// MARK: - Support Option Row (list)

private struct SupportOptionRow: View {
    let option: SupportOption
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(option.tint.opacity(0.18))
                        .frame(width: 30, height: 30)
                    Image(systemName: option.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(option.tint)
                }

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
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
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
