//
//  MeditationLiveActivity.swift
//  MeditationWidget
//
//  Live Activity widget for meditation timer
//

import ActivityKit
import SwiftUI
import WidgetKit

/// Live Activity widget for meditation playback
struct MeditationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeditationActivityAttributes.self) { context in
            // Lock screen / banner UI
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }

                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(context: context)
                }
            } compactLeading: {
                CompactLeadingView(context: context)
            } compactTrailing: {
                CompactTrailingView(context: context)
            } minimal: {
                MinimalView(context: context)
            }
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let context: ActivityViewContext<MeditationActivityAttributes>

    private let accentColor = Color(red: 0.5, green: 0.3, blue: 0.9)
    private let backgroundColor = Color(red: 0.08, green: 0.15, blue: 0.28)

    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail with progress ring
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 56, height: 56)

                // Progress ring
                Circle()
                    .trim(from: 0, to: context.state.progress)
                    .stroke(
                        accentColor,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))

                // Content type icon
                Image(systemName: contentTypeIcon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(accentColor)
            }

            // Title and progress info
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.contentTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(context.state.contentType)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(accentColor)
                            .frame(width: geometry.size.width * context.state.progress, height: 4)
                    }
                }
                .frame(height: 4)
            }

            Spacer()

            // Time remaining and play/pause
            VStack(alignment: .trailing, spacing: 8) {
                Text(context.state.timeRemainingFormatted)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                // Play/Pause button with deep link
                Link(destination: URL(string: "meditation://player/toggle")!) {
                    Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(accentColor)
                        .clipShape(Circle())
                }
            }
        }
        .padding(16)
        .activityBackgroundTint(backgroundColor)
        .activitySystemActionForegroundColor(.white)
    }

    private var contentTypeIcon: String {
        switch context.state.contentType.lowercased() {
        case "meditation": return "brain.head.profile"
        case "sleep story": return "book.closed.fill"
        case "soundscape": return "waveform"
        case "music": return "music.note"
        case "movement": return "figure.mind.and.body"
        case "asmr": return "ear.fill"
        case "mindset": return "lightbulb.fill"
        default: return "brain.head.profile"
        }
    }
}

// MARK: - Dynamic Island Compact Views

private struct CompactLeadingView: View {
    let context: ActivityViewContext<MeditationActivityAttributes>

    var body: some View {
        Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color(red: 0.5, green: 0.3, blue: 0.9))
            .symbolEffect(.variableColor.iterative, isActive: context.state.isPlaying)
    }
}

private struct CompactTrailingView: View {
    let context: ActivityViewContext<MeditationActivityAttributes>

    var body: some View {
        Text(context.state.timeRemainingFormatted)
            .font(.system(size: 14, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white)
            .monospacedDigit()
    }
}

// MARK: - Dynamic Island Minimal View

private struct MinimalView: View {
    let context: ActivityViewContext<MeditationActivityAttributes>

    var body: some View {
        ZStack {
            // Progress ring
            Circle()
                .trim(from: 0, to: context.state.progress)
                .stroke(
                    Color(red: 0.5, green: 0.3, blue: 0.9),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white)
                .symbolEffect(.variableColor.iterative, isActive: context.state.isPlaying)
        }
    }
}

// MARK: - Dynamic Island Expanded Views

private struct ExpandedLeadingView: View {
    let context: ActivityViewContext<MeditationActivityAttributes>

    var body: some View {
        // Skip backward button
        Link(destination: URL(string: "meditation://player/skipBack")!) {
            Image(systemName: "gobackward.15")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}

private struct ExpandedTrailingView: View {
    let context: ActivityViewContext<MeditationActivityAttributes>

    var body: some View {
        // Skip forward button
        Link(destination: URL(string: "meditation://player/skipForward")!) {
            Image(systemName: "goforward.15")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}

private struct ExpandedCenterView: View {
    let context: ActivityViewContext<MeditationActivityAttributes>

    private let accentColor = Color(red: 0.5, green: 0.3, blue: 0.9)

    var body: some View {
        VStack(spacing: 4) {
            Text(context.state.contentTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(context.state.contentType)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

private struct ExpandedBottomView: View {
    let context: ActivityViewContext<MeditationActivityAttributes>

    private let accentColor = Color(red: 0.5, green: 0.3, blue: 0.9)

    var body: some View {
        VStack(spacing: 12) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(accentColor)
                        .frame(width: geometry.size.width * context.state.progress, height: 6)
                }
            }
            .frame(height: 6)

            // Time labels and play/pause
            HStack {
                Text(context.state.currentTimeFormatted)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .monospacedDigit()

                Spacer()

                // Play/Pause button
                Link(destination: URL(string: "meditation://player/toggle")!) {
                    Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(accentColor)
                        .clipShape(Circle())
                }

                Spacer()

                Text(context.state.totalDurationFormatted)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Preview

#Preview("Lock Screen", as: .content, using: MeditationActivityAttributes(
    sessionId: "preview-session",
    videoId: "dQw4w9WgXcQ"
)) {
    MeditationLiveActivity()
} contentStates: {
    MeditationActivityAttributes.ContentState(
        currentTime: 300,
        totalDuration: 600,
        isPlaying: true,
        contentTitle: "Deep Relaxation Meditation",
        contentType: "Meditation"
    )
    MeditationActivityAttributes.ContentState(
        currentTime: 150,
        totalDuration: 600,
        isPlaying: false,
        contentTitle: "Sleep Story: Ocean Waves",
        contentType: "Sleep Story"
    )
}
