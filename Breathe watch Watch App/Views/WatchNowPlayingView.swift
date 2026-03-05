//
//  WatchNowPlayingView.swift
//  MeditationWatch
//
//  Remote control for meditation playback on iPhone
//

import SwiftUI
import WatchKit

struct WatchNowPlayingView: View {
    @EnvironmentObject var connectivityService: WatchConnectivityService

    @State private var showVolumeControl = false

    private var syncData: WatchSyncData {
        connectivityService.syncData
    }

    private var isPlaying: Bool {
        syncData.playbackState == .playing
    }

    private var hasContent: Bool {
        syncData.playbackState != .stopped && syncData.currentContentTitle != nil
    }

    var body: some View {
        Group {
            if hasContent {
                nowPlayingContent
            } else {
                noContentView
            }
        }
        .navigationTitle("Now Playing")
        .onAppear {
            connectivityService.requestSync()
        }
    }

    // MARK: - Now Playing Content

    private var nowPlayingContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Content info
                VStack(spacing: 6) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text(syncData.currentContentTitle ?? "Meditation")
                        .font(.footnote.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    if let duration = syncData.currentContentDuration,
                       let currentTime = syncData.currentPlaybackTime {
                        ProgressView(value: Double(currentTime), total: Double(duration))
                            .tint(.purple)
                            .padding(.horizontal, 20)

                        Text("\(formatTime(currentTime)) / \(formatTime(duration))")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                // Playback controls
                HStack(spacing: 20) {
                    // Skip backward
                    Button {
                        connectivityService.sendPlaybackCommand(.skipBackward)
                    } label: {
                        Image(systemName: "gobackward.15")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)

                    // Play/Pause
                    Button {
                        connectivityService.sendPlaybackCommand(isPlaying ? .pause : .play)
                    } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    // Skip forward
                    Button {
                        connectivityService.sendPlaybackCommand(.skipForward)
                    } label: {
                        Image(systemName: "goforward.15")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 8)

                // Stop button
                Button {
                    connectivityService.sendPlaybackCommand(.stop)
                } label: {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Connection status
                if !connectivityService.isReachable {
                    HStack(spacing: 4) {
                        Image(systemName: "iphone.slash")
                            .font(.caption2)
                        Text("iPhone not reachable")
                            .font(.caption2)
                    }
                    .foregroundStyle(.orange)
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - No Content View

    private var noContentView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.3))

            Text("Nothing Playing")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))

            Text("Start a meditation on your iPhone")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            if connectivityService.isReachable {
                NavigationLink(destination: WatchBreathingView()) {
                    HStack {
                        Image(systemName: "wind")
                        Text("Breathe")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

#Preview {
    WatchNowPlayingView()
        .environmentObject(WatchConnectivityService.shared)
}
