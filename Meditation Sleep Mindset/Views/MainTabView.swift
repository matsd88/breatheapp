//
//  MainTabView.swift
//  Meditation Sleep Mindset
//

import SwiftUI

enum AppTab: String, CaseIterable {
    case home = "Home"
    case sleep = "Sleep"
    case discover = "Discover"
    case profile = "You"
    case chat = "Chat"

    var iconName: String {
        switch self {
        case .home: return "house"
        case .sleep: return "moon.stars"
        case .discover: return "sparkles"
        case .profile: return "person"
        case .chat: return "bubble.left.and.text.bubble.right"
        }
    }

    var selectedIconName: String {
        switch self {
        case .home: return "house.fill"
        case .sleep: return "moon.stars.fill"
        case .discover: return "sparkles"
        case .profile: return "person.fill"
        case .chat: return "bubble.left.and.text.bubble.right.fill"
        }
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    let tabs: [AppTab]
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                CustomTabItem(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    namespace: animation
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            ZStack {
                // Base blur material
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .opacity(0.8)

                // Dark overlay for depth
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.black.opacity(0.1))

                // Subtle border
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 16)
    }
}

struct CustomTabItem: View {
    let tab: AppTab
    let isSelected: Bool
    var namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? tab.selectedIconName : tab.iconName)
                    .font(.system(size: 20))

                Text(tab.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .matchedGeometryEffect(id: "TAB_INDICATOR", in: namespace)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .home
    @State private var showFullPlayer = false
    @StateObject private var playerManager = AudioPlayerManager.shared
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @EnvironmentObject var appState: AppStateManager
    @State private var actionSheetData: ActionSheetManager.SheetData?

    init() {
        // Hide native tab bar
        UITabBar.appearance().isHidden = true
    }

    private var availableTabs: [AppTab] {
        [.home, .sleep, .discover, .chat, .profile]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content views based on selected tab
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .sleep:
                    SleepView()
                case .discover:
                    DiscoverView()
                case .profile:
                    ProfileView()
                case .chat:
                    ChatView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, playerManager.currentContent != nil && !showFullPlayer ? 70 : 0)
            .overlay(alignment: .top) {
                // Offline banner
                if !networkMonitor.isConnected {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .font(.caption)
                        Text("No internet connection")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.85))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.3), value: networkMonitor.isConnected)
                }
            }

            // Bottom fade gradient to hide content behind tab bar (like Calm app)
            VStack {
                Spacer()
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color(red: 0.1, green: 0.2, blue: 0.35).opacity(0.8),
                        Color(red: 0.1, green: 0.2, blue: 0.35)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 160)
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()

            // Solid background color below tab bar to match app theme
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color(red: 0.1, green: 0.2, blue: 0.35))
                    .frame(height: 50)
            }
            .ignoresSafeArea(.all, edges: .bottom)
            .allowsHitTesting(false)

            // Bottom bar stack
            VStack(spacing: 23) {
                // Mini player - shows when content is playing and full player is closed
                if playerManager.currentContent != nil && !showFullPlayer {
                    MiniPlayerView(
                        playerManager: playerManager,
                        showFullPlayer: $showFullPlayer
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.3), value: playerManager.currentContent != nil)
                }

                // Custom tab bar
                CustomTabBar(selectedTab: $selectedTab, tabs: availableTabs)
                    .padding(.bottom, 7)
            }

        }
        .overlay {
            // Global action sheet overlay (above everything)
            if let data = actionSheetData {
                ContentActionSheet(
                    content: data.content,
                    isFavorite: data.isFavorite,
                    onToggleFavorite: data.onToggleFavorite,
                    onAddToPlaylist: data.onAddToPlaylist,
                    onShare: data.onShare,
                    isPresented: Binding(
                        get: { actionSheetData != nil },
                        set: { if !$0 {
                            actionSheetData = nil
                            ActionSheetManager.shared.dismiss()
                        }}
                    )
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: actionSheetData?.id)
        .onReceive(NotificationCenter.default.publisher(for: ActionSheetManager.didChangeNotification)) { _ in
            actionSheetData = ActionSheetManager.shared.sheetData
        }
        .sheet(isPresented: $appState.shouldShowShareSheet, onDismiss: {
            appState.markSharePromptShown()
        }) {
            ShareSheet()
        }
        .fullScreenCover(isPresented: $showFullPlayer) {
            if let content = playerManager.currentContent {
                MeditationPlayerView(content: content)
                    .onAppear { print("[MainTabView] fullScreenCover appeared with content: \(content.title)") }
            } else {
                // Fallback - should never happen, but prevents white screen
                Color.clear.onAppear {
                    print("[MainTabView] fullScreenCover appeared but currentContent is NIL — dismissing")
                    showFullPlayer = false
                }
            }
        }
        .onChange(of: playerManager.shouldPresentPlayer) { _, shouldPresent in
            if shouldPresent {
                print("[MainTabView] shouldPresentPlayer changed to true, setting showFullPlayer=true")
                playerManager.shouldPresentPlayer = false
                showFullPlayer = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dismissAllSheetsAndPlay)) { _ in
            print("[MainTabView] Received dismissAllSheetsAndPlay notification")
            print("[MainTabView] currentContent: \(playerManager.currentContent?.title ?? "nil")")
            print("[MainTabView] showFullPlayer currently: \(showFullPlayer)")
            // Wait for all sheets (including nested) to finish dismissing, then open full player
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("[MainTabView] 1.0s delay complete, setting showFullPlayer=true")
                print("[MainTabView] currentContent at this point: \(playerManager.currentContent?.title ?? "nil")")
                showFullPlayer = true
                print("[MainTabView] showFullPlayer is now: \(showFullPlayer)")
            }
        }
    }
}

struct ShareSheet: View {
    @EnvironmentObject var appState: AppStateManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    // X close button
                    HStack {
                        Spacer()
                        Button {
                            appState.markSharePromptShown()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 4)

                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.white)

                    Text("Enjoying the app?")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("Share it with friends and family who might benefit from daily meditation.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    ShareLink(
                        item: URL(string: "https://apps.apple.com/app/id123456789")!,
                        subject: Text("Check out this meditation app!"),
                        message: Text("I've been using this app for meditation and it's been really helpful. You should try it!")
                    ) {
                        Label("Share App", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    Button("Maybe Later") {
                        appState.markSharePromptShown()
                        dismiss()
                    }
                    .foregroundStyle(.white.opacity(0.6))

                    Spacer()
                }
                .padding()
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.profileGradient)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppStateManager.shared)
}
