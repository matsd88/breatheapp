//
//  GratitudeJournalView.swift
//  Meditation Sleep Mindset
//
//  A simple, calming gratitude journal. Rotating reflective prompts, quick entry,
//  and a history of past entries. Free for everyone (a habit/retention driver).
//

import SwiftUI
import SwiftData

struct GratitudeJournalView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \GratitudeEntry.createdAt, order: .reverse) private var entries: [GratitudeEntry]

    /// Optional prompt to pre-seed the entry (e.g. coming from a post-session flow).
    var initialPrompt: String? = nil

    @State private var entryText: String = ""
    @State private var activePrompt: String = GratitudeJournalView.prompts.first ?? "What are you grateful for today?"
    @FocusState private var isEditorFocused: Bool

    static let prompts: [String] = [
        String(localized: "What are three things you're grateful for today?"),
        String(localized: "Who made your day a little brighter?"),
        String(localized: "What is something small that brought you joy?"),
        String(localized: "What is a challenge you're thankful you got through?"),
        String(localized: "What part of your body or health are you grateful for?"),
        String(localized: "What is something you're looking forward to?"),
        String(localized: "What is a comfort you sometimes take for granted?")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Prompt card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "heart.text.square.fill")
                                    .foregroundStyle(Theme.profileAccent)
                                Text("Today's reflection")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                                Spacer()
                                Button {
                                    HapticManager.light()
                                    shufflePrompt()
                                } label: {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.6))
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .accessibilityLabel("New prompt")
                            }

                            Text(activePrompt)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding()
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Editor
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Write freely...", text: $entryText, axis: .vertical)
                                .lineLimit(4...10)
                                .focused($isEditorFocused)
                                .padding()
                                .background(Theme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)

                            Button {
                                saveEntry()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark")
                                    Text("Save entry")
                                }
                                .font(.headline)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(entryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .opacity(entryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                        }

                        // Past entries
                        if !entries.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Your gratitude")
                                    .font(.headline)
                                    .foregroundStyle(.white)

                                ForEach(entries) { entry in
                                    GratitudeEntryRow(entry: entry) {
                                        modelContext.delete(entry)
                                        try? modelContext.save()
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding()
                    .frame(maxWidth: sizeClass == .regular ? 720 : 600)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Gratitude")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .onAppear {
                if let initialPrompt {
                    activePrompt = initialPrompt
                }
            }
        }
    }

    private func shufflePrompt() {
        let candidates = Self.prompts.filter { $0 != activePrompt }
        if let next = candidates.randomElement() {
            withAnimation { activePrompt = next }
        }
    }

    private func saveEntry() {
        let trimmed = entryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let entry = GratitudeEntry(text: trimmed, prompt: activePrompt)
        modelContext.insert(entry)
        try? modelContext.save()
        HapticManager.success()
        ToastManager.shared.show("Gratitude saved", icon: "heart.fill", style: .success)
        entryText = ""
        isEditorFocused = false
        shufflePrompt()
    }
}

struct GratitudeEntryRow: View {
    let entry: GratitudeEntry
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.dayString)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.profileAccent)
                Spacer()
                Menu {
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 28, height: 28)
                }
            }

            if let prompt = entry.prompt {
                Text(prompt)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }

            Text(entry.text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    GratitudeJournalView()
        .modelContainer(for: [GratitudeEntry.self], inMemory: true)
}
