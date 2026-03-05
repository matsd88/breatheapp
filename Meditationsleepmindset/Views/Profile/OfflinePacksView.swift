//
//  OfflinePacksView.swift
//  Meditation Sleep Mindset
//
//  UI for browsing and downloading offline content packs for travelers.
//

import SwiftUI
import SwiftData

struct OfflinePacksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \Content.title) private var allContent: [Content]
    @StateObject private var packManager = OfflinePackManager.shared
    @StateObject private var storeManager = StoreManager.shared

    @State private var selectedCategory: OfflinePack.PackCategory? = nil
    @State private var showingPaywall = false
    @State private var packToDownload: OfflinePack?

    private var isRegular: Bool { sizeClass == .regular }

    private var filteredPacks: [OfflinePack] {
        if let category = selectedCategory {
            return packManager.allPacks.filter { $0.category == category }
        }
        return packManager.allPacks
    }

    private var downloadedPacks: [OfflinePack] {
        packManager.allPacks.filter { packManager.isDownloaded($0.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.profileGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: isRegular ? 28 : 24) {
                        // Header stats
                        headerStats

                        // Downloaded section
                        if !downloadedPacks.isEmpty {
                            downloadedSection
                        }

                        // Category filter
                        categoryFilter

                        // Available packs
                        availablePacksGrid
                    }
                    .padding(.horizontal, isRegular ? 32 : 16)
                    .padding(.top, isRegular ? 16 : 8)
                    .padding(.bottom, 100)
                    .frame(maxWidth: isRegular ? 800 : .infinity)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Offline Packs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: isRegular ? 14 : 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: isRegular ? 40 : 32, height: isRegular ? 40 : 32)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingPaywall) {
                PremiumPaywallView(
                    storeManager: storeManager,
                    onSubscribed: {
                        showingPaywall = false
                        if let pack = packToDownload {
                            packManager.downloadPack(pack, content: allContent)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Header Stats

    private var headerStats: some View {
        HStack(spacing: isRegular ? 20 : 16) {
            // Total downloaded
            VStack(spacing: isRegular ? 8 : 4) {
                Text("\(downloadedPacks.count)")
                    .font(isRegular ? .title.bold() : .title2.bold())
                    .foregroundStyle(.white)
                Text("Packs")
                    .font(isRegular ? .subheadline : .caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, isRegular ? 24 : 16)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: isRegular ? 16 : 12))

            // Total size
            VStack(spacing: isRegular ? 8 : 4) {
                Text(formatSize(packManager.totalOfflineSizeMB))
                    .font(isRegular ? .title.bold() : .title2.bold())
                    .foregroundStyle(.white)
                Text("Downloaded")
                    .font(isRegular ? .subheadline : .caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, isRegular ? 24 : 16)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: isRegular ? 16 : 12))

            // Airplane mode indicator
            VStack(spacing: isRegular ? 8 : 4) {
                Image(systemName: "airplane")
                    .font(isRegular ? .title : .title2)
                    .foregroundStyle(.cyan)
                Text("Ready")
                    .font(isRegular ? .subheadline : .caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, isRegular ? 24 : 16)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: isRegular ? 16 : 12))
        }
    }

    // MARK: - Downloaded Section

    private var downloadedSection: some View {
        VStack(alignment: .leading, spacing: isRegular ? 16 : 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(isRegular ? .title3 : .body)
                    .foregroundStyle(.green)
                Text("Downloaded")
                    .font(isRegular ? .title3.weight(.semibold) : .headline)
                    .foregroundStyle(.white)
                Spacer()
            }

            if isRegular {
                // iPad: grid layout for downloaded packs
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(downloadedPacks) { pack in
                        DownloadedPackRow(
                            pack: pack,
                            state: packManager.state(for: pack.id),
                            onDelete: {
                                withAnimation {
                                    packManager.deletePack(pack.id)
                                }
                            }
                        )
                    }
                }
            } else {
                ForEach(downloadedPacks) { pack in
                    DownloadedPackRow(
                        pack: pack,
                        state: packManager.state(for: pack.id),
                        onDelete: {
                            withAnimation {
                                packManager.deletePack(pack.id)
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                PackCategoryChip(
                    title: "All",
                    icon: "square.grid.2x2",
                    isSelected: selectedCategory == nil
                ) {
                    withAnimation { selectedCategory = nil }
                }

                ForEach(OfflinePack.PackCategory.allCases, id: \.self) { category in
                    PackCategoryChip(
                        title: category.rawValue,
                        icon: iconFor(category),
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation { selectedCategory = category }
                    }
                }
            }
        }
    }

    // MARK: - Available Packs Grid

    private var availablePacksGrid: some View {
        VStack(alignment: .leading, spacing: isRegular ? 16 : 12) {
            Text("Available Packs")
                .font(isRegular ? .title3.weight(.semibold) : .headline)
                .foregroundStyle(.white)

            LazyVGrid(
                columns: isRegular
                    ? [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)]
                    : [GridItem(.flexible())],
                spacing: isRegular ? 20 : 16
            ) {
                ForEach(filteredPacks) { pack in
                    OfflinePackCard(
                        pack: pack,
                        state: packManager.state(for: pack.id),
                        isSubscribed: storeManager.isSubscribed,
                        onDownload: {
                            if !storeManager.isSubscribed {
                                packToDownload = pack
                                showingPaywall = true
                            } else {
                                packManager.downloadPack(pack, content: allContent)
                            }
                        },
                        onCancel: {
                            packManager.cancelDownload(pack.id)
                        },
                        onDelete: {
                            packManager.deletePack(pack.id)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatSize(_ mb: Int) -> String {
        if mb >= 1000 {
            return String(format: "%.1f GB", Double(mb) / 1000)
        }
        return "\(mb) MB"
    }

    private func iconFor(_ category: OfflinePack.PackCategory) -> String {
        switch category {
        case .travel: return "airplane"
        case .sleep: return "moon.zzz"
        case .anxiety: return "heart.circle"
        case .focus: return "brain.head.profile"
        case .wellness: return "leaf"
        }
    }
}

// MARK: - Pack Category Chip

struct PackCategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(isSelected ? .white : Theme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Theme.profileAccent : Color.white.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Offline Pack Card

struct OfflinePackCard: View {
    let pack: OfflinePack
    let state: PackDownloadState
    let isSubscribed: Bool
    let onDownload: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(pack.color.opacity(0.2))
                        .frame(width: isRegular ? 56 : 48, height: isRegular ? 56 : 48)

                    Image(systemName: pack.icon)
                        .font(isRegular ? .title2 : .title3)
                        .foregroundStyle(pack.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(pack.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text("\(pack.targetCount) items • ~\(pack.estimatedSizeMB) MB")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()
            }

            // Description
            Text(pack.description)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)

            // Action button / progress
            actionView
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(state.isDownloaded ? pack.color.opacity(0.5) : Color.clear, lineWidth: 2)
                )
        )
    }

    @ViewBuilder
    private var actionView: some View {
        switch state {
        case .notDownloaded:
            Button(action: onDownload) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Download")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(pack.color)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

        case .downloading(let progress):
            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .tint(pack.color)

                HStack {
                    Text("\(Int(progress * 100))% downloaded")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)

                    Spacer()

                    Button("Cancel", action: onCancel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.red)
                }
            }

        case .downloaded(let date, let sizeMB):
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Downloaded")
                            .foregroundStyle(.green)
                    }
                    .font(.subheadline.weight(.medium))

                    Text("\(sizeMB) MB • \(date.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red.opacity(0.7))
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
            }

        case .failed(let error):
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Failed: \(error)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Button(action: onDownload) {
                    Text("Retry")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(pack.color)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

// MARK: - Downloaded Pack Row

struct DownloadedPackRow: View {
    let pack: OfflinePack
    let state: PackDownloadState
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(pack.color.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: pack.icon)
                    .foregroundStyle(pack.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(pack.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)

                if case .downloaded(_, let sizeMB) = state {
                    Text("\(sizeMB) MB")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .foregroundStyle(.red.opacity(0.7))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    OfflinePacksView()
}
