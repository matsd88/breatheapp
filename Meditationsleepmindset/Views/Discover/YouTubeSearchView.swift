//
//  YouTubeSearchView.swift
//  Meditation Sleep Mindset
//

import SwiftUI
import SwiftData

struct YouTubeSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Content.title) private var allContent: [Content]

    @State private var searchText = ""
    @State private var results: [YouTubeSearchService.SearchResult] = []
    @State private var isSearching = false
    @State private var continuation: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var addedVideoIDs: Set<String> = []

    private var existingVideoIDs: Set<String> {
        Set(allContent.map(\.youtubeVideoID))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Theme.textSecondary)

                        TextField("Search YouTube...", text: $searchText)
                            .foregroundStyle(Theme.textPrimary)
                            .autocorrectionDisabled()
                            .onSubmit { performSearch() }

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                results = []
                                continuation = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(Theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Results
                    if isSearching && results.isEmpty {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                        Spacer()
                    } else if results.isEmpty && !searchText.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 48))
                                .foregroundStyle(Theme.textSecondary)
                            Text("No results for \"\(searchText)\"")
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)
                            Text("Try different keywords like \"sleep music\" or \"guided meditation\"")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 32)
                        Spacer()
                    } else if results.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "play.rectangle.on.rectangle")
                                .font(.system(size: 48))
                                .foregroundStyle(Theme.textSecondary)
                            Text("Search YouTube to add content to your library")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 40)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(results) { result in
                                    YouTubeResultRow(
                                        result: result,
                                        isInLibrary: existingVideoIDs.contains(result.videoID) || addedVideoIDs.contains(result.videoID),
                                        onAdd: { addToLibrary(result) }
                                    )
                                }

                                // Load more
                                if continuation != nil {
                                    Button {
                                        loadMore()
                                    } label: {
                                        if isSearching {
                                            ProgressView()
                                                .tint(.white)
                                        } else {
                                            Text("Load More")
                                                .font(.subheadline.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                }

                                Spacer(minLength: 40)
                            }
                            .padding(.horizontal)
                            .padding(.top, 12)
                        }
                    }
                }
            }
            .navigationTitle("Search YouTube")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onDisappear {
            searchTask?.cancel()
        }
        .onChange(of: searchText) { _, newValue in
            // Debounce search
            searchTask?.cancel()
            guard !newValue.isEmpty else {
                results = []
                continuation = nil
                return
            }
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
                guard !Task.isCancelled else { return }
                performSearch()
            }
        }
    }

    private func performSearch() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        results = []
        continuation = nil

        Task {
            do {
                let response = try await YouTubeSearchService.shared.search(query: searchText)
                await MainActor.run {
                    results = response.results
                    continuation = response.continuation
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    ToastManager.shared.show(
                        "Search failed — check your connection",
                        icon: "wifi.slash",
                        style: .standard
                    )
                }
                #if DEBUG
                print("YouTube search error: \(error)")
                #endif
            }
        }
    }

    private func loadMore() {
        guard let token = continuation, !isSearching else { return }
        isSearching = true

        Task {
            do {
                let response = try await YouTubeSearchService.shared.search(query: searchText, continuation: token)
                await MainActor.run {
                    results.append(contentsOf: response.results)
                    continuation = response.continuation
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    ToastManager.shared.show("Failed to load more results", icon: "exclamationmark.triangle", style: .standard)
                }
            }
        }
    }

    private func addToLibrary(_ result: YouTubeSearchService.SearchResult) {
        // Check for duplicates
        let videoID = result.videoID
        guard !existingVideoIDs.contains(videoID) && !addedVideoIDs.contains(videoID) else {
            ToastManager.shared.show("Already in library", icon: "checkmark.circle", style: .standard)
            return
        }

        let contentType = guessContentType(title: result.title, channel: result.channelName)

        let content = Content(
            title: result.title,
            subtitle: result.channelName,
            youtubeVideoID: videoID,
            contentType: contentType,
            durationSeconds: result.durationSeconds,
            narrator: result.channelName,
            tags: [],
            isPremium: false,
            description: result.description,
            isUserAdded: true
        )

        modelContext.insert(content)

        do {
            try modelContext.save()
            addedVideoIDs.insert(videoID)
            ToastManager.shared.show("Added to library", icon: "plus.circle.fill", style: .success)
        } catch {
            #if DEBUG
            print("Failed to save content: \(error)")
            #endif
            ToastManager.shared.show("Failed to add", icon: "xmark.circle", style: .standard)
        }
    }

    private func guessContentType(title: String, channel: String) -> ContentType {
        let text = (title + " " + channel).lowercased()

        if text.contains("sleep story") || text.contains("bedtime story") || text.contains("sleepy story") {
            return .sleepStory
        }
        if text.contains("asmr") || text.contains("tingles") || text.contains("whisper") {
            return .asmr
        }
        if text.contains("rain") || text.contains("thunder") || text.contains("nature sound") || text.contains("ambien") || text.contains("soundscape") || text.contains("white noise") || text.contains("ocean") || text.contains("fireplace") {
            return .soundscape
        }
        if text.contains("hz") || text.contains("frequency") || text.contains("piano") || text.contains("singing bowl") || text.contains("sleep music") || text.contains("relaxing music") || text.contains("solfeggio") {
            return .music
        }
        if text.contains("yoga") || text.contains("qigong") || text.contains("stretch") || text.contains("tai chi") || text.contains("body movement") {
            return .movement
        }
        if text.contains("ted") || text.contains("mindset") || text.contains("stoic") || text.contains("motivation") || text.contains("affirmation") || text.contains("self-love") || text.contains("confidence") {
            return .mindset
        }
        return .meditation
    }
}

// MARK: - Result Row

struct YouTubeResultRow: View {
    let result: YouTubeSearchService.SearchResult
    let isInLibrary: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            AsyncImage(url: URL(string: result.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Theme.cardBackground)
                    .overlay(
                        Image(systemName: "play.rectangle")
                            .foregroundStyle(.white.opacity(0.3))
                    )
            }
            .frame(width: 120, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(result.channelName)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)

                Text(result.durationText)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            // Add button
            Button(action: onAdd) {
                Image(systemName: isInLibrary ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(isInLibrary ? .green : Theme.accentColor)
            }
            .disabled(isInLibrary)
        }
        .padding(10)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
