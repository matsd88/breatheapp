//
//  UpNextQueueView.swift
//  Meditation Sleep Mindset
//
//  Browsable playback queue — tap to jump, swipe to remove, drag to reorder
//  (via Edit), and "Add similar" to extend the queue.
//

import SwiftUI
import SwiftData

struct UpNextQueueView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var playerManager = AudioPlayerManager.shared
    @Query private var allContent: [Content]
    @State private var editMode: EditMode = .inactive

    var body: some View {
        ZStack {
            Theme.sleepBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                SheetDragIndicator()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Up Next")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)

                        Text(queueSubtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    // Reorder toggle
                    if playerManager.queue.count > 1 {
                        Button {
                            HapticManager.light()
                            withAnimation {
                                editMode = editMode == .active ? .inactive : .active
                            }
                        } label: {
                            Text(editMode == .active ? "Done" : "Reorder")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .accessibilityLabel(editMode == .active ? "Finish reordering" : "Reorder queue")
                    }

                    SheetCloseButton(action: { dismiss() })
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                ScrollViewReader { proxy in
                    List {
                        // Element-based identity: positional identity made
                        // removals/reorders animate as whole-list mutations.
                        ForEach(Array(playerManager.queue.enumerated()), id: \.element.id) { index, item in
                            QueueItemRow(
                                item: item,
                                isCurrent: index == playerManager.currentIndex,
                                isPlayed: index < playerManager.currentIndex,
                                isPlaying: playerManager.isPlaying
                            ) {
                                guard index != playerManager.currentIndex else { return }
                                HapticManager.light()
                                playerManager.playItem(at: index)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                            .deleteDisabled(index == playerManager.currentIndex)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if index != playerManager.currentIndex {
                                    Button(role: .destructive) {
                                        HapticManager.light()
                                        playerManager.removeFromQueue(at: index)
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .onDelete { offsets in
                            for offset in offsets.sorted(by: >) where offset != playerManager.currentIndex {
                                playerManager.removeFromQueue(at: offset)
                            }
                        }
                        .onMove { source, destination in
                            playerManager.moveQueueItems(from: source, to: destination)
                        }

                        // Add similar sessions to keep the queue going
                        if !similarCandidates.isEmpty {
                            Button {
                                HapticManager.medium()
                                playerManager.appendToQueue(similarCandidates)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add similar sessions")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .foregroundStyle(Theme.profileAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 24, trailing: 20))
                            .accessibilityHint("Appends a few sessions like the current one to the queue")
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .environment(\.editMode, $editMode)
                    .onAppear {
                        // Land with the current track visible. List rows aren't
                        // materialized yet at onAppear for long queues — retry
                        // after first layout so the scroll lands.
                        guard playerManager.queue.indices.contains(playerManager.currentIndex) else { return }
                        let currentID = playerManager.queue[playerManager.currentIndex].id
                        proxy.scrollTo(currentID, anchor: .center)
                        DispatchQueue.main.async {
                            withAnimation(.none) {
                                proxy.scrollTo(currentID, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    private var queueSubtitle: String {
        let remaining = playerManager.queue.count - playerManager.currentIndex - 1
        if remaining <= 0 {
            return "Last session in the queue"
        }
        return remaining == 1 ? "1 session remaining" : "\(remaining) sessions remaining"
    }

    /// Up to 5 not-yet-queued items of the same type as the current session,
    /// picked deterministically per day so repeated taps don't reshuffle.
    private var similarCandidates: [Content] {
        guard let current = playerManager.currentContent else { return [] }
        let queuedIDs = Set(playerManager.queue.map { $0.youtubeVideoID })
        let pool = allContent.filter {
            $0.contentType == current.contentType
                && !queuedIDs.contains($0.youtubeVideoID)
                && (!$0.isPremium || StoreManager.shared.isSubscribed)
        }
        guard !pool.isEmpty else { return [] }
        let daySeed = UInt64(bitPattern: Int64(Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 1))
        var rng = SeededRandomNumberGenerator(seed: daySeed &* 131 &+ UInt64(queuedIDs.count))
        return Array(pool.shuffled(using: &rng).prefix(5))
    }
}

private struct QueueItemRow: View {
    let item: Content
    let isCurrent: Bool
    let isPlayed: Bool
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                CachedAsyncImage(
                    url: URL(string: item.thumbnailURLComputed),
                    failedIconName: item.contentType.iconName,
                    content: { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .scaleEffect(1.15)
                    },
                    placeholder: {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundStyle(.white.opacity(0.3))
                            )
                    }
                )
                .frame(width: 52, height: 52)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                        .foregroundStyle(isPlayed ? .white.opacity(0.45) : .white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 5) {
                        if isCurrent {
                            Text(isPlaying ? "Now Playing" : "Paused")
                                .foregroundStyle(Theme.profileAccent)
                        } else if !item.durationFormatted.isEmpty {
                            Text(item.durationFormatted)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                if isCurrent {
                    Image(systemName: isPlaying ? "waveform" : "pause.fill")
                        .font(.body)
                        .foregroundStyle(Theme.profileAccent)
                        .symbolEffect(.variableColor.iterative, options: .repeating, isActive: isPlaying)
                }
            }
            .padding(10)
            .background(isCurrent ? Color.white.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCurrent ? "Now playing: \(item.title)" : item.title)
        .accessibilityHint(isCurrent ? "" : "Plays this session")
    }
}

#Preview {
    UpNextQueueView()
}
