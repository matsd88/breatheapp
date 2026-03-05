//
//  QuickActionsWidget.swift
//  MeditationWidget
//
//  Quick action buttons to launch different app features
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct QuickActionsTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickActionsEntry {
        QuickActionsEntry(
            date: Date(),
            recentContentTitle: "Morning Calm",
            recentContentType: "Meditation",
            recentContentId: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickActionsEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickActionsEntry>) -> Void) {
        let entry = loadEntry()
        // Refresh every hour to keep recent content fresh
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> QuickActionsEntry {
        let defaults = UserDefaults(suiteName: "group.com.meditation.shared") ?? .standard
        let recentTitle = defaults.string(forKey: "widget_recentContentTitle")
        let recentType = defaults.string(forKey: "widget_recentContentType")
        let recentId = defaults.string(forKey: "widget_recentContentId")

        return QuickActionsEntry(
            date: Date(),
            recentContentTitle: recentTitle,
            recentContentType: recentType,
            recentContentId: recentId
        )
    }
}

// MARK: - Entry

struct QuickActionsEntry: TimelineEntry {
    let date: Date
    let recentContentTitle: String?
    let recentContentType: String?
    let recentContentId: String?

    var hasRecentContent: Bool {
        recentContentId != nil && recentContentTitle != nil
    }
}

// MARK: - Action Button Model

struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let urlScheme: String
    let gradientColors: [Color]

    var url: URL? {
        URL(string: urlScheme)
    }
}

// MARK: - Widget Views

struct QuickActionButton: View {
    let action: QuickAction
    let size: CGFloat

    var body: some View {
        if let url = action.url {
            Link(destination: url) {
                VStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: action.gradientColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: size, height: size)

                        Image(systemName: action.icon)
                            .font(.system(size: size * 0.4, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    Text(action.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
        }
    }
}

struct QuickActionsWidgetMediumView: View {
    let entry: QuickActionsEntry

    private let actions: [QuickAction] = [
        QuickAction(
            title: "Meditate",
            icon: "brain.head.profile",
            urlScheme: "meditation://home",
            gradientColors: [Color(red: 0.5, green: 0.3, blue: 0.9), Color(red: 0.6, green: 0.4, blue: 1.0)]
        ),
        QuickAction(
            title: "Breathe",
            icon: "wind",
            urlScheme: "meditation://breathing",
            gradientColors: [Color(red: 0.2, green: 0.6, blue: 0.8), Color(red: 0.3, green: 0.7, blue: 0.9)]
        ),
        QuickAction(
            title: "Sleep",
            icon: "moon.stars.fill",
            urlScheme: "meditation://sleep",
            gradientColors: [Color(red: 0.3, green: 0.2, blue: 0.6), Color(red: 0.4, green: 0.3, blue: 0.7)]
        ),
        QuickAction(
            title: "Focus",
            icon: "timer",
            urlScheme: "meditation://focus",
            gradientColors: [Color(red: 0.9, green: 0.5, blue: 0.3), Color(red: 1.0, green: 0.6, blue: 0.4)]
        )
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(actions) { action in
                QuickActionButton(action: action, size: 44)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .containerBackground(for: .widget) {
            WidgetColors.backgroundGradient
        }
    }
}

struct QuickActionsWidgetLargeView: View {
    let entry: QuickActionsEntry

    private let actions: [QuickAction] = [
        QuickAction(
            title: "Meditate",
            icon: "brain.head.profile",
            urlScheme: "meditation://home",
            gradientColors: [Color(red: 0.5, green: 0.3, blue: 0.9), Color(red: 0.6, green: 0.4, blue: 1.0)]
        ),
        QuickAction(
            title: "Breathe",
            icon: "wind",
            urlScheme: "meditation://breathing",
            gradientColors: [Color(red: 0.2, green: 0.6, blue: 0.8), Color(red: 0.3, green: 0.7, blue: 0.9)]
        ),
        QuickAction(
            title: "Sleep",
            icon: "moon.stars.fill",
            urlScheme: "meditation://sleep",
            gradientColors: [Color(red: 0.3, green: 0.2, blue: 0.6), Color(red: 0.4, green: 0.3, blue: 0.7)]
        ),
        QuickAction(
            title: "Focus",
            icon: "timer",
            urlScheme: "meditation://focus",
            gradientColors: [Color(red: 0.9, green: 0.5, blue: 0.3), Color(red: 1.0, green: 0.6, blue: 0.4)]
        )
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Quick Actions")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
            }

            // 2x2 Action Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(actions) { action in
                    QuickActionButtonLarge(action: action)
                }
            }

            // Recent content section
            if entry.hasRecentContent, let url = URL(string: "meditation://play/\(entry.recentContentId ?? "")") {
                Divider()
                    .background(Color.white.opacity(0.2))

                Link(destination: url) {
                    HStack(spacing: 12) {
                        // Thumbnail placeholder
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(WidgetColors.cardBackground)
                                .frame(width: 50, height: 50)

                            Image(systemName: contentTypeIcon(entry.recentContentType))
                                .font(.system(size: 20))
                                .foregroundStyle(WidgetColors.accentPurple)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Continue")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))

                            Text(entry.recentContentTitle ?? "Recent Session")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            if let type = entry.recentContentType {
                                Text(type)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }

                        Spacer()

                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(WidgetColors.accentPurple)
                    }
                    .padding(10)
                    .background(WidgetColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .containerBackground(for: .widget) {
            WidgetColors.backgroundGradient
        }
    }

    private func contentTypeIcon(_ type: String?) -> String {
        switch type?.lowercased() {
        case "meditation": return "brain.head.profile"
        case "sleep story": return "book.closed.fill"
        case "soundscape": return "waveform"
        case "music": return "music.note"
        case "breathing": return "wind"
        default: return "brain.head.profile"
        }
    }
}

struct QuickActionButtonLarge: View {
    let action: QuickAction

    var body: some View {
        if let url = action.url {
            Link(destination: url) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: action.gradientColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)

                        Image(systemName: action.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    Text(action.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)

                    Spacer()
                }
                .padding(10)
                .background(WidgetColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Widget Definition

struct QuickActionsWidget: Widget {
    let kind = "QuickActionsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickActionsTimelineProvider()) { entry in
            QuickActionsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Quick Actions")
        .description("Quickly start meditation, breathing, sleep, or focus timer.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct QuickActionsWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: QuickActionsEntry

    var body: some View {
        switch family {
        case .systemMedium:
            QuickActionsWidgetMediumView(entry: entry)
        case .systemLarge:
            QuickActionsWidgetLargeView(entry: entry)
        default:
            QuickActionsWidgetMediumView(entry: entry)
        }
    }
}

// MARK: - Previews

#Preview(as: .systemMedium) {
    QuickActionsWidget()
} timeline: {
    QuickActionsEntry(date: .now, recentContentTitle: nil, recentContentType: nil, recentContentId: nil)
}

#Preview(as: .systemLarge) {
    QuickActionsWidget()
} timeline: {
    QuickActionsEntry(date: .now, recentContentTitle: "Deep Sleep Journey", recentContentType: "Sleep Story", recentContentId: "abc123")
    QuickActionsEntry(date: .now, recentContentTitle: nil, recentContentType: nil, recentContentId: nil)
}
