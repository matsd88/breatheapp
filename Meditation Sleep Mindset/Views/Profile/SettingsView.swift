//
//  SettingsView.swift
//  Meditation Sleep Mindset
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var streakService = StreakService.shared
    @EnvironmentObject var appState: AppStateManager
    @State private var showingRatingDialog = false
    @State private var showingThemeSettings = false
    @State private var showingEmailCopiedAlert = false
    @State private var showingExportSheet = false
    @State private var exportImage: UIImage?

    private let headerSolidColor = Color(red: 0.08, green: 0.15, blue: 0.28)

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Theme.profileGradient.ignoresSafeArea()

                // Scrollable content
                ScrollView {
                    VStack(spacing: 24) {
                        // Spacer so first item clears the fixed header
                        Color.clear.frame(height: 60)

                        // Premium Upsell (if not subscribed)
                        if !storeManager.isSubscribed {
                            PremiumUpsellCard()
                        }

                        // Support Section
                        SettingsSection(title: "Support") {
                            Button {
                                HapticManager.light()
                                openEmail()
                            } label: {
                                SettingsRow(
                                    icon: "envelope.fill",
                                    title: "Contact Support"
                                )
                            }

                            NavigationLink {
                                FAQView()
                            } label: {
                                SettingsRow(
                                    icon: "text.bubble.fill",
                                    title: "FAQ",
                                    showChevron: true
                                )
                            }

                            Button {
                                HapticManager.light()
                                showingRatingDialog = true
                            } label: {
                                SettingsRow(
                                    icon: "star.fill",
                                    title: "Rate the App"
                                )
                            }

                            ShareLink(item: Constants.AppStore.shareURL) {
                                SettingsRow(
                                    icon: "square.and.arrow.up",
                                    title: "Share with Friends"
                                )
                            }
                        }

                        // Preferences Section
                        SettingsSection(title: "Preferences") {
                            NavigationLink {
                                NotificationSettingsView()
                            } label: {
                                NotificationSettingsRow()
                            }

                            Button {
                                HapticManager.light()
                                showingThemeSettings = true
                            } label: {
                                ThemeSettingsRow()
                            }
                        }

                        // Integrations
                        if HealthKitService.isAvailable {
                            SettingsSection(title: "Integrations") {
                                HStack {
                                    Image(systemName: "heart.fill")
                                        .foregroundStyle(.red)
                                        .frame(width: 28, height: 28)
                                        .background(Color.red.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Apple Health")
                                            .font(.subheadline)
                                            .foregroundStyle(.white)
                                        Text("Sync mindful minutes")
                                            .font(.caption)
                                            .foregroundStyle(Theme.textSecondary)
                                    }

                                    Spacer()

                                    Toggle("", isOn: Binding(
                                        get: { HealthKitService.shared.isEnabled },
                                        set: { HealthKitService.shared.isEnabled = $0 }
                                    ))
                                    .tint(Theme.profileAccent)
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        // Accessibility
                        SettingsSection(title: "Accessibility") {
                            NavigationLink {
                                AccessibilitySettingsView()
                            } label: {
                                SettingsRow(
                                    icon: "accessibility",
                                    title: "Accessibility",
                                    showChevron: true
                                )
                            }
                        }

                        // Account Section
                        SettingsSection(title: "Account") {
                            if storeManager.isSubscribed {
                                SettingsRow(
                                    icon: "crown.fill",
                                    title: "Subscription",
                                    subtitle: "Premium Active",
                                    iconColor: .yellow
                                )
                            }

                            NavigationLink {
                                ManageSubscriptionView()
                            } label: {
                                SettingsRow(
                                    icon: "creditcard",
                                    title: "Manage Subscription",
                                    showChevron: true
                                )
                            }

                            Button {
                                guard !storeManager.isRestoring else { return }
                                HapticManager.light()
                                Task {
                                    await storeManager.restorePurchases()
                                    if storeManager.isSubscribed {
                                        HapticManager.success()
                                        ToastManager.shared.show("Purchases restored!", icon: "checkmark.circle.fill", style: .success)
                                    } else {
                                        ToastManager.shared.show("No purchases found", icon: "info.circle", style: .standard)
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    if storeManager.isRestoring {
                                        ProgressView()
                                            .tint(.white)
                                            .frame(width: 28)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 18))
                                            .foregroundStyle(.white)
                                            .frame(width: 28)
                                    }

                                    Text("Restore Purchases")
                                        .foregroundStyle(Theme.textPrimary)

                                    Spacer()
                                }
                                .padding()
                            }
                            .disabled(storeManager.isRestoring)
                        }

                        // Legal Section
                        SettingsSection(title: "Legal") {
                            NavigationLink {
                                PrivacyPolicyView()
                            } label: {
                                SettingsRow(
                                    icon: "hand.raised.fill",
                                    title: "Privacy Policy",
                                    showChevron: true
                                )
                            }

                            NavigationLink {
                                TermsOfServiceView()
                            } label: {
                                SettingsRow(
                                    icon: "doc.text.fill",
                                    title: "Terms of Service",
                                    showChevron: true
                                )
                            }
                        }

                        // Developer Section (for testing)
                        #if DEBUG
                        SettingsSection(title: "Developer") {
                            Button {
                                appState.resetOnboarding()
                                dismiss()
                            } label: {
                                SettingsRow(
                                    icon: "arrow.counterclockwise",
                                    title: "Reset Onboarding",
                                    iconColor: .orange
                                )
                            }
                        }
                        #endif

                        // Bottom padding
                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal)
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                }

                // Fixed header with SOLID background
                HStack {
                    Spacer()
                    Text("Settings")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Spacer()
                }
                .overlay(alignment: .trailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(headerSolidColor)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingRatingDialog) {
                RatingDialogView()
            }
            .sheet(isPresented: $showingThemeSettings) {
                ThemeSettingsView()
            }
            .sheet(isPresented: $showingExportSheet) {
                if let image = exportImage {
                    InsightsShareSheet(items: [image])
                }
            }
            .alert("Email Copied", isPresented: $showingEmailCopiedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("No email app found. The support email address has been copied to your clipboard: \(Constants.Support.email)")
            }
        }
        .presentationBackground(Theme.profileGradient)
    }

    @MainActor
    private func generateInsightsImage() -> UIImage {
        let totalMins = streakService.totalMinutes
        let totalSess = streakService.totalSessions
        let streak = streakService.currentStreak

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 400))
        return renderer.image { ctx in
            let rect = CGRect(x: 0, y: 0, width: 600, height: 400)

            // Background gradient
            let colors = [UIColor(red: 0.08, green: 0.15, blue: 0.28, alpha: 1).cgColor,
                          UIColor(red: 0.12, green: 0.08, blue: 0.30, alpha: 1).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: 400), options: [])

            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            "My Breathe Journey".draw(at: CGPoint(x: 40, y: 40), withAttributes: titleAttrs)

            // Stats
            let statFont = UIFont.systemFont(ofSize: 42, weight: .bold)
            let labelFont = UIFont.systemFont(ofSize: 16, weight: .medium)
            let statColor = UIColor.white
            let labelColor = UIColor.white.withAlphaComponent(0.6)

            let stats: [(value: String, label: String)] = [
                ("\(totalMins)", "Minutes Meditated"),
                ("\(totalSess)", "Sessions Completed"),
                ("\(streak)", "Day Streak")
            ]

            for (i, stat) in stats.enumerated() {
                let x: CGFloat = CGFloat(40 + i * 190)
                let y: CGFloat = 120
                stat.value.draw(at: CGPoint(x: x, y: y), withAttributes: [.font: statFont, .foregroundColor: statColor])
                stat.label.draw(at: CGPoint(x: x, y: y + 52), withAttributes: [.font: labelFont, .foregroundColor: labelColor])
            }

            // Mood history
            let moods = ChatService.getMoodHistory(in: modelContext)
            if !moods.isEmpty {
                let moodTitle = "7-Day Mood"
                moodTitle.draw(at: CGPoint(x: 40, y: 230), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
                    .foregroundColor: UIColor.white
                ])

                let df = DateFormatter()
                df.dateFormat = "EEE"
                for (i, day) in moods.prefix(7).enumerated() {
                    let x = CGFloat(40 + i * 75)
                    let emoji = day.mood?.emoji ?? "-"
                    let dayLabel = df.string(from: day.date)

                    emoji.draw(at: CGPoint(x: x + 8, y: 265), withAttributes: [.font: UIFont.systemFont(ofSize: 28)])
                    dayLabel.draw(at: CGPoint(x: x + 4, y: 300), withAttributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: labelColor])
                }
            }

            // Watermark
            let watermark = "breatheapp.com"
            watermark.draw(at: CGPoint(x: 40, y: 360), withAttributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.3)
            ])
        }
    }

    private func openEmail() {
        let email = Constants.Support.email
        let subject = "Support Request - Meditation App"
        let body = "App Version: \(Bundle.main.fullVersion)\niOS Version: \(UIDevice.current.systemVersion)\n\n"

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]

        if let url = components.url {
            UIApplication.shared.open(url) { success in
                if !success {
                    UIPasteboard.general.string = email
                    showingEmailCopiedAlert = true
                }
            }
        } else {
            UIPasteboard.general.string = email
            showingEmailCopiedAlert = true
        }
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textSecondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content
            }
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge))
        }
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var iconColor: Color = .white
    var showChevron: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(iconColor)
                .frame(width: 28)

            Text(title)
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding()
    }
}

// MARK: - Premium Upsell Card
struct PremiumUpsellCard: View {
    var body: some View {
        NavigationLink {
            PremiumView()
        } label: {
            VStack(spacing: 12) {
                Text("Try Premium Free")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)

                Text("Unlock all meditations, sleep stories & more")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)

                Text("Start Free Trial")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge))
        }
    }
}

// MARK: - Manage Subscription View
struct ManageSubscriptionView: View {
    @StateObject private var storeManager = StoreManager.shared

    var body: some View {
        ZStack {
            Theme.profileGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    if storeManager.isSubscribed {
                        // Active Subscription Info
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.green)

                            Text("Premium Active")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Theme.textPrimary)

                            Text("You have full access to all content")
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.vertical, 32)

                        Button {
                            // Open subscription management
                            if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text("Manage in App Store")
                                .primaryButton()
                        }
                    } else {
                        // Not subscribed
                        VStack(spacing: 16) {
                            Text("Breathe")
                                .font(.system(size: 48, weight: .thin, design: .serif))
                                .italic()
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white.opacity(0.9), .purple.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .tracking(4)

                            Text("No Active Subscription")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Theme.textPrimary)

                            Text("Subscribe to unlock all features")
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.vertical, 32)

                        NavigationLink {
                            PremiumView()
                        } label: {
                            Text("View Plans")
                                .primaryButton()
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Reminder Settings View
struct ReminderSettingsView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var reminderEnabled = true
    @State private var reminderTime = Date()

    var body: some View {
        ZStack {
            Theme.profileGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    SettingsSection(title: "Daily Reminder") {
                        Toggle(isOn: $reminderEnabled) {
                            HStack(spacing: 12) {
                                Image(systemName: "bell.fill")
                                    .foregroundStyle(.white)
                                    .frame(width: 28)

                                Text("Enable Reminder")
                                    .foregroundStyle(Theme.textPrimary)
                            }
                        }
                        .padding()
                        .tint(.white)

                        if reminderEnabled {
                            DatePicker(
                                "Reminder Time",
                                selection: $reminderTime,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .padding()
                            .onChange(of: reminderTime) { _, newValue in
                                Task {
                                    await appState.scheduleDailyReminder(at: newValue)
                                }
                            }
                        }
                    }

                    // Quick presets
                    if reminderEnabled {
                        SettingsSection(title: "Quick Presets") {
                            HStack(spacing: 12) {
                                TimePresetButton(title: "Morning", time: "7:00 AM") {
                                    setTime(hour: 7, minute: 0)
                                }

                                TimePresetButton(title: "Noon", time: "12:00 PM") {
                                    setTime(hour: 12, minute: 0)
                                }

                                TimePresetButton(title: "Evening", time: "8:00 PM") {
                                    setTime(hour: 20, minute: 0)
                                }

                                TimePresetButton(title: "Night", time: "10:00 PM") {
                                    setTime(hour: 22, minute: 0)
                                }
                            }
                            .padding()
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Daily Reminder")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let savedTime = appState.dailyReminderTime {
                reminderTime = savedTime
            }
        }
    }

    private func setTime(hour: Int, minute: Int) {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        if let date = Calendar.current.date(from: components) {
            reminderTime = date
            Task {
                await appState.scheduleDailyReminder(at: date)
            }
        }
    }
}

struct TimePresetButton: View {
    let title: String
    let time: String
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.selection()
            action()
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)

                Text(time)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.textPrimary)
    }
}

// MARK: - Playback Settings View
struct PlaybackSettingsView: View {
    @StateObject private var audioManager = AudioPlayerManager.shared
    @AppStorage(Constants.UserDefaultsKeys.autoPlayNextContent) private var autoPlayNext = true
    @State private var downloadOverCellular = false
    @State private var defaultPlaybackSpeed: Float = 1.0

    private let playbackSpeeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        ZStack {
            Theme.profileGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    SettingsSection(title: "Playback") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                Image(systemName: "speedometer")
                                    .foregroundStyle(.white)
                                    .frame(width: 28)

                                Text("Default Speed")
                                    .foregroundStyle(Theme.textPrimary)

                                Spacer()

                                Text("\(defaultPlaybackSpeed, specifier: "%.2f")x")
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .padding(.horizontal)
                            .padding(.top)

                            Picker("Playback Speed", selection: $defaultPlaybackSpeed) {
                                ForEach(playbackSpeeds, id: \.self) { speed in
                                    Text("\(speed, specifier: "%.2f")x").tag(speed)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                            .padding(.bottom)
                        }

                        Toggle(isOn: $autoPlayNext) {
                            HStack(spacing: 12) {
                                Image(systemName: "play.circle.fill")
                                    .foregroundStyle(.white)
                                    .frame(width: 28)

                                VStack(alignment: .leading) {
                                    Text("Auto-Play Next")
                                        .foregroundStyle(Theme.textPrimary)

                                    Text("Automatically play the next track in queue")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                        .padding()
                        .tint(.white)
                    }

                    SettingsSection(title: "Downloads") {
                        Toggle(isOn: $downloadOverCellular) {
                            HStack(spacing: 12) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .foregroundStyle(.white)
                                    .frame(width: 28)

                                VStack(alignment: .leading) {
                                    Text("Download over Cellular")
                                        .foregroundStyle(Theme.textPrimary)

                                    Text("May use mobile data")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                        .padding()
                        .tint(.white)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Playback")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: defaultPlaybackSpeed) { _, newValue in
            audioManager.setPlaybackRate(newValue)
        }
    }
}

// MARK: - Terms of Service View
struct TermsOfServiceView: View {
    var body: some View {
        ZStack {
            Theme.profileGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Last Updated: January 2026")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)

                    LegalSection(title: "1. Acceptance of Terms") {
                        Text("By downloading, installing, or using Meditation Sleep Mindset (\"the App\"), you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the App.")
                    }

                    LegalSection(title: "2. Description of Service") {
                        Text("Meditation Sleep Mindset provides guided meditations, sleep stories, soundscapes, breathing exercises, body scan experiences, guided multi-day programs, a Pomodoro focus timer, mood tracking and insights, a sleep alarm, AI wellness chat, playlists, post-session reflections, playback speed control, AirPlay support, Siri Shortcuts, and mindfulness content designed to help users relax, sleep better, and improve their mental well-being. The App offers both free and premium subscription-based content, including an AI-powered wellness companion for personalized support.")
                    }

                    LegalSection(title: "3. Subscription and Billing") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("• Premium features require an active subscription")
                            Text("• Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period")
                            Text("• Payment will be charged to your Apple ID account at confirmation of purchase")
                            Text("• You can manage and cancel subscriptions in your App Store account settings")
                            Text("• No refunds will be provided for partial subscription periods")
                        }
                    }

                    LegalSection(title: "4. Free Trial & Preview") {
                        Text("We may offer free trial periods for premium subscriptions. If you do not cancel before the trial ends, you will be automatically charged for the subscription. Trial eligibility is determined by Apple and may be limited to one trial per Apple ID. Free users may preview premium content for a limited duration before being prompted to subscribe.")
                    }

                    LegalSection(title: "5. User Conduct") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("You agree not to:")
                            Text("• Share your account credentials with others")
                            Text("• Attempt to reverse engineer or copy the App's content")
                            Text("• Use the App for any unlawful purpose")
                            Text("• Redistribute or commercially exploit the content")
                        }
                    }

                    LegalSection(title: "6. AI Wellness Chat") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("The App includes an AI-powered wellness chat feature that provides conversational support for mental wellness. By using this feature, you acknowledge that:")
                            Text("• The AI is not a licensed therapist, counselor, or medical professional")
                            Text("• Responses are generated by artificial intelligence and should not be considered professional advice")
                            Text("• The AI chat is intended for general wellness support and is not a substitute for professional mental health care")
                            Text("• If you are in crisis or experiencing a mental health emergency, please contact emergency services (911) or the Suicide & Crisis Lifeline (988)")
                            Text("• Chat messages are processed by our AI service to generate responses and are not stored on external servers")
                            Text("• Free users are limited to \(Constants.Chat.freeMessageLimit) messages per day")
                        }
                    }

                    LegalSection(title: "7. Health & Wellness Features") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("The App includes wellness features such as breathing exercises, body scan meditations, a focus timer (Pomodoro), guided multi-day programs, mood tracking, post-session mood reflections, and a sleep alarm. These features are designed for general wellness and relaxation purposes only.")
                            Text("• Breathing exercises guide you through timed breathing patterns and are not medical respiratory therapy")
                            Text("• The body scan feature provides guided relaxation and is not a diagnostic tool")
                            Text("• The focus timer helps structure work sessions and is not a medical productivity treatment")
                            Text("• Mood tracking and post-session reflections provide personal insights and are not clinical assessments")
                            Text("• The sleep alarm and sleep timer use local notifications and require notification permissions to function")
                        }
                    }

                    LegalSection(title: "8. Apple Health Integration") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("The App may optionally integrate with Apple Health to record your meditation sessions as Mindful Minutes. By enabling this feature, you acknowledge that:")
                            Text("• Health data is written to Apple Health on your device and governed by Apple's privacy policies")
                            Text("• We only write mindful session data; we do not read or access other health data")
                            Text("• You can disable this integration at any time in the App's settings")
                            Text("• This feature requires your explicit permission via the Health app authorization prompt")
                        }
                    }

                    LegalSection(title: "9. Content & Playback") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Audio and video content in the App is streamed from third-party sources. We do not host or own this content. Availability of specific content may change without notice. The App provides playback features including:")
                            Text("• Adjustable playback speed")
                            Text("• Sleep timer with automatic fade-out")
                            Text("• AirPlay streaming to external devices")
                            Text("• Siri Shortcuts for hands-free access")
                            Text("• Sharing content at specific timestamps")
                        }
                    }

                    LegalSection(title: "10. Health Disclaimer") {
                        Text("The App is designed for general wellness and relaxation purposes only, including its AI chat, breathing exercises, body scan, focus timer, mood tracking, and post-session reflection features. It is not intended to diagnose, treat, cure, or prevent any medical or psychological condition. Always consult with a qualified healthcare provider before starting any wellness program or if you have concerns about your mental health. Do not use the App while driving or operating machinery.")
                    }

                    LegalSection(title: "11. Intellectual Property") {
                        Text("The App's software, design, and original content are the property of Meditation Sleep Mindset or its licensors and are protected by copyright and other intellectual property laws. Streamed media content is owned by its respective creators.")
                    }

                    LegalSection(title: "12. Limitation of Liability") {
                        Text("To the maximum extent permitted by law, Meditation Sleep Mindset shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising from your use of the App. Our total liability shall not exceed the amount you paid for the App in the twelve months preceding any claim.")
                    }

                    LegalSection(title: "13. Modifications to Terms") {
                        Text("We reserve the right to modify these terms at any time. Continued use of the App after changes constitutes acceptance of the new terms. We will notify users of significant changes through the App.")
                    }

                    LegalSection(title: "14. Termination") {
                        Text("We may terminate or suspend your access to the App at any time, without prior notice, for conduct that we believe violates these Terms or is harmful to other users, us, or third parties.")
                    }

                    LegalSection(title: "15. Governing Law") {
                        Text("These Terms shall be governed by and construed in accordance with the laws of the United States, without regard to conflict of law principles.")
                    }

                    LegalSection(title: "16. Contact Us") {
                        Text("If you have questions about these Terms, please contact us at \(Constants.Support.email)")
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    var body: some View {
        ZStack {
            Theme.profileGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Last Updated: January 2026")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)

                    LegalSection(title: "Introduction") {
                        Text("Meditation Sleep Mindset (\"we\", \"our\", or \"us\") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application, including our AI wellness chat, breathing exercises, body scan, focus timer, guided programs, mood tracking, post-session reflections, sleep timer, sleep alarm, AirPlay, Siri Shortcuts, home screen widgets, playlist, and content features.")
                    }

                    LegalSection(title: "Information We Collect") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("We may collect the following types of information:")
                                .fontWeight(.medium)

                            Text("Personal Information:")
                                .fontWeight(.medium)
                            Text("• Email address (only if you contact support)")

                            Text("Usage Data (Stored Locally on Your Device):")
                                .fontWeight(.medium)
                                .padding(.top, 8)
                            Text("• Meditation sessions completed and listen duration")
                            Text("• Post-session mood reflections")
                            Text("• Breathing exercise and body scan sessions")
                            Text("• Focus timer sessions and work/break intervals")
                            Text("• Guided program progress and completion")
                            Text("• Mood check-ins and mood tracking history")
                            Text("• App preferences, theme, and playback speed settings")
                            Text("• Favorite content selections and playlists")
                            Text("• Daily reminder and alarm preferences")
                            Text("• Streak and session history")

                            Text("AI Wellness Chat Data:")
                                .fontWeight(.medium)
                                .padding(.top, 8)
                            Text("• Chat messages and conversation history are stored locally on your device")
                            Text("• Messages are sent to our AI service provider to generate responses but are not stored on external servers or used for AI training")

                            Text("Health Data (Optional):")
                                .fontWeight(.medium)
                                .padding(.top, 8)
                            Text("• If you enable Apple Health integration, we write Mindful Minutes to Apple Health")
                            Text("• We do not read or access any other health data from Apple Health")
                            Text("• Health data is never shared with third parties or used for advertising")

                            Text("iCloud Sync Data:")
                                .fontWeight(.medium)
                                .padding(.top, 8)
                            Text("• Favorites, playlists, and session history may sync via iCloud to your other devices")
                            Text("• This data is governed by Apple's iCloud privacy policies")
                        }
                    }

                    LegalSection(title: "How We Use Your Information") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("All usage data is processed locally on your device to:")
                            Text("• Provide and maintain the App's functionality")
                            Text("• Personalize your meditation recommendations")
                            Text("• Power the AI wellness chat with contextual responses")
                            Text("• Track your progress, streaks, and program completion")
                            Text("• Display mood insights, trends, and post-session reflections")
                            Text("• Manage your playlists and favorites")
                            Text("• Send daily reminders and sleep alarms (if enabled)")
                            Text("• Write mindful minutes to Apple Health (if enabled)")
                            Text("• Process subscription transactions through Apple")
                        }
                    }

                    LegalSection(title: "Data Storage and Security") {
                        Text("Your meditation history, mood data, post-session reflections, program progress, and preferences are stored locally on your device using Apple's secure SwiftData storage. iCloud-synced data is encrypted in transit and at rest by Apple. Health data is written to Apple Health and governed by Apple's privacy framework. We do not operate external servers that store your personal data.")
                    }

                    LegalSection(title: "Third-Party Services") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("The App uses the following third-party services:")
                            Text("• Apple App Store (for purchases and subscriptions)")
                            Text("• Apple Health (for optional mindful minutes recording)")
                            Text("• Apple iCloud (for optional data sync across devices)")
                            Text("• Apple Spotlight (for on-device content indexing)")
                            Text("• Apple Siri (for voice-activated shortcuts)")
                            Text("• YouTube (for streaming meditation and sleep content)")
                            Text("• AI service provider (to process chat messages and generate wellness responses)")
                            Text("Chat messages sent to our AI provider are used solely to generate responses and are not retained or used for training.")
                        }
                    }

                    LegalSection(title: "Advertising & Tracking") {
                        Text("We do not display advertisements. We do not use third-party analytics or tracking SDKs. We do not sell, share, or rent your personal information to third parties.")
                    }

                    LegalSection(title: "Your Rights") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("You have the right to:")
                            Text("• Access your personal data (stored on your device)")
                            Text("• Delete all your data by uninstalling the App")
                            Text("• Disable Apple Health integration at any time")
                            Text("• Disable iCloud sync at any time in iOS Settings")
                            Text("• Disable notifications, reminders, and alarms at any time")
                            Text("• Remove Siri Shortcuts in the Shortcuts app")
                        }
                    }

                    LegalSection(title: "Children's Privacy") {
                        Text("The App is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13. If you are a parent or guardian and believe your child has provided us with personal information, please contact us.")
                    }

                    LegalSection(title: "Data Retention") {
                        Text("All data is stored locally on your device and in your personal iCloud account. Uninstalling the App deletes all local data. iCloud data can be managed through iOS Settings. Health data written to Apple Health can be managed through the Health app. We do not retain any data on external servers.")
                    }

                    LegalSection(title: "International Users") {
                        Text("Chat messages are processed by our AI provider which may operate servers in the United States. All other data remains on your device or in your personal iCloud account.")
                    }

                    LegalSection(title: "Changes to This Policy") {
                        Text("We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy in the App and updating the \"Last Updated\" date.")
                    }

                    LegalSection(title: "Contact Us") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("If you have questions or concerns about this Privacy Policy, please contact us at:")
                            Text(Constants.Support.email)
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Legal Section Helper
struct LegalSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            content
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

// MARK: - FAQ View
struct FAQView: View {
    var body: some View {
        ZStack {
            Theme.profileGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    FAQItem(
                        question: "How do I start a meditation?",
                        answer: "Browse the Home or Discover screen to find content that interests you. Tap on any meditation, sleep story, or soundscape to start playing. You can also use the Unguided Timer on the Home screen to meditate in silence or with ambient sounds."
                    )

                    FAQItem(
                        question: "What is the Unguided Timer?",
                        answer: "The Unguided Timer allows you to meditate without guidance for a set duration. You can choose your preferred time and optionally add background sounds. It's perfect for experienced meditators or those who prefer silent practice."
                    )

                    FAQItem(
                        question: "What are Breathing Exercises?",
                        answer: "Breathing Exercises are standalone guided breathing sessions available on the Discover tab. Choose from five techniques including Box Breathing, 4-7-8 Relaxing, Wim Hof, Alternate Nostril, and Energizing Kapalabhati. Each session guides you through timed inhale, hold, and exhale phases with a visual animation. Completed sessions count toward your streak."
                    )

                    FAQItem(
                        question: "What is the Body Scan?",
                        answer: "The Body Scan is a guided relaxation experience on the Discover tab. It walks you through 7 body regions from head to feet, spending about 30 seconds on each with a soothing glow animation. It's a great way to release tension and build body awareness. The full scan takes about 3.5 minutes."
                    )

                    FAQItem(
                        question: "How does the Focus Timer work?",
                        answer: "The Focus Timer is a Pomodoro-style productivity tool on the Home screen. Set your work duration (15–60 minutes) and break duration (3–15 minutes), optionally choose a background sound, and tap Start. The timer alternates between focus and break sessions with a circular progress ring. Sessions are tracked and count toward your streak."
                    )

                    FAQItem(
                        question: "What are Programs?",
                        answer: "Programs are guided multi-day courses on the Discover tab, like '7 Days of Calm' or 'Sleep Better in 5 Days'. Each program has daily sessions that unlock as you progress. Tap a program to see its days, then tap a day to play the session. Your progress is saved automatically. Some programs are Premium-only."
                    )

                    FAQItem(
                        question: "How does Mood Tracking work?",
                        answer: "You can log your mood before and after meditation sessions. Over time, you can view your mood insights from your Profile, including mood trends, improvement rates, and distribution charts. This helps you see how meditation affects your well-being."
                    )

                    FAQItem(
                        question: "How do I set a Sleep Alarm?",
                        answer: "On the Sleep tab, tap the alarm icon in the header. Set your wake-up time, choose a sound, and enable or disable snooze. The alarm uses local notifications, so make sure notifications are allowed for the app. You can toggle the alarm on and off anytime."
                    )

                    FAQItem(
                        question: "How does Apple Health integration work?",
                        answer: "If you enable Apple Health in Settings > Integrations, the app will automatically write your completed meditation sessions as Mindful Minutes to Apple Health. You'll be asked for permission the first time. You can disable it at any time. We only write data — we never read your other health information."
                    )

                    FAQItem(
                        question: "How do I add the home screen widget?",
                        answer: "Long-press your home screen, tap the + button, and search for 'Meditation Streak'. Choose the small widget (streak count) or medium widget (streak + stats + quick start button). The widget updates automatically with your current streak and shows whether you've meditated today."
                    )

                    FAQItem(
                        question: "How does the mini player work?",
                        answer: "When you navigate away from the full player, a mini player appears at the bottom of the screen showing the current track's thumbnail, title, narrator, and play/pause controls. You can also favorite content directly from the mini player. Tap the mini player to return to the full player view."
                    )

                    FAQItem(
                        question: "What is autoplay and how does the queue work?",
                        answer: "When your current meditation finishes, the app automatically plays the next track in your queue. You can see what's coming up next at the bottom of the player screen. The queue is built from related content in the same category to keep your session flowing."
                    )

                    FAQItem(
                        question: "How do I add content to a playlist?",
                        answer: "Tap the more button (three dots) on any content card, then select 'Add to Playlist'. You can add it to an existing playlist or create a new one. You can also add content to a playlist directly from the player's action buttons."
                    )

                    FAQItem(
                        question: "How do I favorite content?",
                        answer: "Tap the heart icon on any content card, in the mini player, or in the full player view. You can also tap the more button (three dots) and select 'Add to Favorites'. All your favorited content can be found in your profile."
                    )

                    FAQItem(
                        question: "How do I report an issue with content?",
                        answer: "Tap the more button (three dots) on any content card and select 'Report an Issue'. This will open an email with details about the content pre-filled so our team can investigate. You can also reach us through Settings > Contact Support."
                    )

                    FAQItem(
                        question: "What happens if content won't play?",
                        answer: "If a video stream fails, the app automatically tries to play the audio version instead. If both fail, you'll see a message letting you know the content is temporarily unavailable, with a button to go back and choose something else. This is usually temporary, so try again later."
                    )

                    FAQItem(
                        question: "How do I set a daily reminder?",
                        answer: "Go to Settings > Daily Reminder to enable notifications. You can choose a specific time or use one of the quick presets (Morning, Noon, Evening, or Night) to receive a gentle reminder to practice."
                    )

                    FAQItem(
                        question: "What's included in Premium?",
                        answer: "Premium unlocks our full library of guided meditations, sleep stories, soundscapes, exclusive programs, and premium content. You'll also get access to new content as it's released and an ad-free experience."
                    )

                    FAQItem(
                        question: "How do I cancel my subscription?",
                        answer: "You can manage or cancel your subscription anytime through your Apple ID settings. Go to Settings > Manage Subscription, then tap 'Manage in App Store' to access your subscription settings."
                    )

                    FAQItem(
                        question: "Can I use the app offline?",
                        answer: "Currently, content requires an internet connection to stream. Features like the Focus Timer, Breathing Exercises, and Body Scan work fully offline. We're working on adding download functionality for offline listening in a future update."
                    )

                    FAQItem(
                        question: "How do I restore my purchases?",
                        answer: "If you've previously subscribed and need to restore your access, go to Settings > Restore Purchases. Make sure you're signed in with the same Apple ID you used for the original purchase."
                    )

                    FAQItem(
                        question: "Is my data private?",
                        answer: "Yes, your privacy is important to us. Your meditation history, mood data, program progress, and preferences are stored locally on your device. Health data is only written to Apple Health with your explicit permission. We don't sell your personal information to third parties. See our Privacy Policy for more details."
                    )

                    FAQItem(
                        question: "How do I contact support?",
                        answer: "You can reach our support team by going to Settings > Contact Support. We typically respond within 24-48 hours."
                    )
                }
                .padding()
            }
        }
        .navigationTitle("FAQ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - FAQ Item
struct FAQItem: View {
    let question: String
    let answer: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                HapticManager.light()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(question)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding()
            }

            if isExpanded {
                Text(answer)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal)
                    .padding(.bottom)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge))
    }
}

// MARK: - Rating Dialog View
struct RatingDialogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRating: Int = 0
    @State private var showFeedbackPrompt = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    if showFeedbackPrompt {
                        // Low-rating feedback view
                        Image(systemName: "envelope.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.white)

                        VStack(spacing: 12) {
                            Text("Thanks for your feedback")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Theme.textPrimary)

                            Text("We'd love to hear how we can improve. Would you like to send us a message?")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        Button {
                            openSupportEmail()
                        } label: {
                            Label("Contact Support", systemImage: "envelope.fill")
                                .font(.headline)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, 40)

                        Button("No Thanks") {
                            dismiss()
                        }
                        .foregroundStyle(.white.opacity(0.6))
                    } else {
                        // Star rating view
                        Image(systemName: "heart.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.white)

                        VStack(spacing: 12) {
                            Text("Enjoying the App?")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Theme.textPrimary)

                            Text("Tap a star to rate your experience")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }

                        HStack(spacing: 12) {
                            ForEach(1...5, id: \.self) { star in
                                Button {
                                    HapticManager.selection()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        selectedRating = star
                                    }
                                } label: {
                                    Image(systemName: star <= selectedRating ? "star.fill" : "star")
                                        .font(.system(size: 40))
                                        .foregroundStyle(star <= selectedRating ? .yellow : Theme.textSecondary)
                                        .scaleEffect(star <= selectedRating ? 1.1 : 1.0)
                                }
                            }
                        }
                        .padding(.vertical, 20)

                        if selectedRating > 0 {
                            Button {
                                submitRating()
                            } label: {
                                Text("Submit")
                                    .font(.headline)
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.horizontal, 40)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }

                    Spacer()
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func submitRating() {
        if selectedRating >= 4 {
            if let url = URL(string: "itms-apps://apps.apple.com/app/id\(Constants.AppStore.appID)?action=write-review") {
                UIApplication.shared.open(url)
            }
            dismiss()
        } else {
            // Low rating — show feedback prompt instead of App Store
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showFeedbackPrompt = true
            }
        }
    }

    private func openSupportEmail() {
        let email = Constants.Support.email
        let subject = "App Feedback (\(selectedRating) stars)"
        let body = "App Version: \(Bundle.main.fullVersion)\niOS: \(UIDevice.current.systemVersion)\n\nI'd like to share the following feedback:\n\n"

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]

        if let url = components.url {
            UIApplication.shared.open(url) { success in
                if !success {
                    UIPasteboard.general.string = email
                    ToastManager.shared.show("Email copied to clipboard", icon: "doc.on.clipboard")
                }
            }
        }
        dismiss()
    }
}

// MARK: - Notification Settings Row
struct NotificationSettingsRow: View {
    @StateObject private var notificationService = NotificationService.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.fill")
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: 28)

            Text("Notifications")
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            // Show status indicator
            if notificationService.dailyReminderEnabled || notificationService.bedtimeReminderEnabled {
                Text("On")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding()
    }
}

// MARK: - Theme Settings Row
struct ThemeSettingsRow: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "paintpalette.fill")
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: 28)

            Text("Player Theme")
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            // Show current theme preview
            Circle()
                .fill(themeManager.currentTheme.gradient)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding()
    }
}

// MARK: - Invite Friends Card
struct InviteFriendsCard: View {
    var body: some View {
        ShareLink(item: Constants.AppStore.shareURL) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Theme.profileAccent.opacity(0.2))
                            .frame(width: 48, height: 48)

                        Image(systemName: "gift.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.profileAccent)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Give a Friend 7 Days Free")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)

                        Text("Share Breathe and they'll get a free week of Premium")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                    }

                    Spacer()
                }

                HStack {
                    Text("Share Invite")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.black)
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline)
                        .foregroundStyle(.black)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge))
        }
    }
}

// MARK: - Insights Share Sheet
struct InsightsShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Accessibility Settings View
struct AccessibilitySettingsView: View {
    @AppStorage("accessibilityLargeText") private var largeText = false
    @AppStorage("accessibilityHighContrast") private var highContrast = false
    @AppStorage("accessibilityReduceMotion") private var reduceMotion = false

    var body: some View {
        ZStack {
            Theme.profileGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    SettingsSection(title: "Display") {
                        Toggle(isOn: $largeText) {
                            HStack(spacing: 12) {
                                Image(systemName: "textformat.size.larger")
                                    .foregroundStyle(.white)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Larger Text")
                                        .foregroundStyle(Theme.textPrimary)

                                    Text("Increase text size throughout the app")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                        .padding()
                        .tint(.white)

                        Toggle(isOn: $highContrast) {
                            HStack(spacing: 12) {
                                Image(systemName: "circle.lefthalf.filled")
                                    .foregroundStyle(.white)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("High Contrast")
                                        .foregroundStyle(Theme.textPrimary)

                                    Text("Increase text and icon contrast for readability")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                        .padding()
                        .tint(.white)
                    }

                    SettingsSection(title: "Motion") {
                        Toggle(isOn: $reduceMotion) {
                            HStack(spacing: 12) {
                                Image(systemName: "hand.raised.slash.fill")
                                    .foregroundStyle(.white)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Reduce Motion")
                                        .foregroundStyle(Theme.textPrimary)

                                    Text("Minimize animations and transitions")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                        .padding()
                        .tint(.white)
                    }

                    // Info card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(Theme.textSecondary)
                            Text("System Accessibility")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(Theme.textPrimary)
                        }

                        Text("For additional accessibility options like VoiceOver, Dynamic Type, and Bold Text, visit your device's Settings > Accessibility.")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)

                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text("Open Device Settings")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .padding(.top, 4)
                    }
                    .padding()
                    .background(Theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge))
                }
                .padding()
            }
        }
        .navigationTitle("Accessibility")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppStateManager.shared)
}
