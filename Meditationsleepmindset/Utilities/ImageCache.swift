//
//  ImageCache.swift
//  Meditation Sleep Mindset
//

import SwiftUI
import Foundation

/// Thread-safe memory + disk cache for synchronous access
/// This allows immediate image display without async delays
final class SyncImageMemoryCache {
    static let shared = SyncImageMemoryCache()

    private let cache = NSCache<NSString, UIImage>()
    private let lock = NSLock()
    private let diskCacheDirectory: URL

    private init() {
        cache.countLimit = 200  // Max 200 images in memory
        cache.totalCostLimit = 100 * 1024 * 1024  // 100MB max

        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheDirectory = cacheDir.appendingPathComponent("ThumbnailCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
    }

    func image(for key: String) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        if let memoryImage = cache.object(forKey: key as NSString) {
            return memoryImage
        }
        // Check disk cache synchronously — avoids actor hop for cached images
        let diskURL = diskCacheDirectory.appendingPathComponent(key)
        if let data = try? Data(contentsOf: diskURL),
           let diskImage = UIImage(data: data) {
            cache.setObject(diskImage, forKey: key as NSString)
            return diskImage
        }
        return nil
    }

    func store(_ image: UIImage, for key: String) {
        lock.lock()
        defer { lock.unlock() }
        cache.setObject(image, forKey: key as NSString)
    }

    func storeToDisk(_ image: UIImage, for key: String) {
        let diskURL = diskCacheDirectory.appendingPathComponent(key)
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: diskURL)
        }
    }

    func cacheKey(for url: URL) -> String {
        let urlString = url.absoluteString
        let hash = urlString.hashValue
        return "\(abs(hash)).jpg"
    }
}

/// A simple image cache that stores downloaded images in memory and on disk
/// for instant loading of YouTube thumbnails
actor ImageCache {
    static let shared = ImageCache()

    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    /// Dedicated URLSession with higher concurrency for thumbnail downloads
    nonisolated let thumbnailSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 12  // Default is 4-6, boost for faster parallel loads
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        config.urlCache = nil  // We manage our own cache
        config.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: config)
    }()

    private init() {
        // Set up disk cache directory
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cacheDir.appendingPathComponent("ThumbnailCache", isDirectory: true)

        // Create cache directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Get cached image for URL, checking memory first then disk
    func image(for url: URL) -> UIImage? {
        let key = cacheKey(for: url)
        // SyncImageMemoryCache now checks both memory and disk
        return SyncImageMemoryCache.shared.image(for: key)
    }

    /// Store image in both memory and disk cache
    func store(_ image: UIImage, for url: URL) {
        let key = cacheKey(for: url)

        // Store in sync memory cache
        SyncImageMemoryCache.shared.store(image, for: key)

        // Store on disk in background
        Task.detached(priority: .background) {
            SyncImageMemoryCache.shared.storeToDisk(image, for: key)
        }
    }

    /// Generate a safe cache key from URL
    private nonisolated func cacheKey(for url: URL) -> String {
        return SyncImageMemoryCache.shared.cacheKey(for: url)
    }

    /// Clear all cached images
    func clearCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Preload thumbnails for content array with high concurrency
    func preloadThumbnails(for urls: [URL]) async {
        let session = thumbnailSession
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask {
                    // Skip if already cached (sync check — no actor hop)
                    let key = SyncImageMemoryCache.shared.cacheKey(for: url)
                    if SyncImageMemoryCache.shared.image(for: key) != nil {
                        return
                    }

                    // Download and cache
                    do {
                        let (data, _) = try await session.data(from: url)
                        if let image = UIImage(data: data) {
                            await self.store(image, for: url)
                        }
                    } catch {
                        // Silently fail for preloading
                    }
                }
            }
        }
    }
}

/// Observable image loader that persists across view recreations
/// Uses @StateObject in the view to maintain state when switching tabs
@MainActor
class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isFailed = false
    private let url: URL?
    private var isLoading = false

    init(url: URL?) {
        self.url = url
        // Check sync memory cache immediately on init - this is synchronous
        // This prevents the flash when switching tabs
        if let url = url {
            let key = SyncImageMemoryCache.shared.cacheKey(for: url)
            if let cached = SyncImageMemoryCache.shared.image(for: key) {
                self.image = cached
            }
        }
    }

    func load() {
        guard let url = url, image == nil, !isLoading else { return }
        isLoading = true

        // Synchronous disk cache check first (avoids async hop)
        let key = SyncImageMemoryCache.shared.cacheKey(for: url)
        if let cached = SyncImageMemoryCache.shared.image(for: key) {
            self.image = cached
            self.isLoading = false
            return
        }

        let session = ImageCache.shared.thumbnailSession
        Task {
            // Get fallback URLs and try each one
            let urlsToTry = fallbackURLs(for: url)

            for tryURL in urlsToTry {
                // Check cache for this URL variant (sync — memory + disk)
                let variantKey = SyncImageMemoryCache.shared.cacheKey(for: tryURL)
                if let cached = SyncImageMemoryCache.shared.image(for: variantKey) {
                    self.image = cached
                    self.isLoading = false
                    return
                }

                // Try to download using the optimized session
                do {
                    let (data, response) = try await session.data(from: tryURL)

                    // Check for valid response (YouTube returns 404 for missing thumbnails)
                    if let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode == 200,
                       let downloadedImage = UIImage(data: data) {
                        // Cache with original URL so future requests find it
                        await ImageCache.shared.store(downloadedImage, for: url)
                        self.image = downloadedImage
                        self.isLoading = false
                        return
                    }
                } catch {
                    // Try next URL
                    continue
                }
            }

            // All URLs failed
            self.isFailed = true
            self.isLoading = false
        }
    }

    /// Generate fallback URLs for YouTube thumbnails
    private func fallbackURLs(for url: URL) -> [URL] {
        let urlString = url.absoluteString

        // Check if this is a YouTube thumbnail URL
        if urlString.contains("img.youtube.com/vi/") {
            // Extract video ID from URL pattern: https://img.youtube.com/vi/VIDEO_ID/resolution.jpg
            let components = urlString.components(separatedBy: "/")
            if let videoIDIndex = components.firstIndex(of: "vi"),
               videoIDIndex + 1 < components.count {
                let videoID = components[videoIDIndex + 1]

                // Try different resolutions in order of preference
                let resolutions = ["hqdefault.jpg", "mqdefault.jpg", "sddefault.jpg", "default.jpg"]
                return resolutions.compactMap { resolution in
                    URL(string: "https://img.youtube.com/vi/\(videoID)/\(resolution)")
                }
            }
        }

        // Not a YouTube URL, just return the original
        return [url]
    }
}

/// A cached async image view that uses our ImageCache
/// Supports fallback URLs for YouTube thumbnails (tries multiple resolutions)
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    var failedIconName: String = "photo"

    @StateObject private var loader: ImageLoader

    init(
        url: URL?,
        failedIconName: String = "photo",
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.failedIconName = failedIconName
        self.content = content
        self.placeholder = placeholder
        _loader = StateObject(wrappedValue: ImageLoader(url: url))
    }

    var body: some View {
        Group {
            if let image = loader.image {
                content(Image(uiImage: image))
            } else if loader.isFailed {
                ThumbnailFailedView(iconName: failedIconName)
            } else {
                ThumbnailFailedView(iconName: failedIconName)
                    .overlay(
                        ProgressView()
                            .tint(.white.opacity(0.5))
                            .scaleEffect(0.8)
                    )
                    .onAppear {
                        loader.load()
                    }
            }
        }
    }
}

/// Styled fallback for failed thumbnail loads
struct ThumbnailFailedView: View {
    var iconName: String = "photo"

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.14, green: 0.24, blue: 0.48),
                    Color(red: 0.08, green: 0.16, blue: 0.36)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle radial glow behind icon
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.06), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 60
                    )
                )
                .frame(width: 80, height: 80)

            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(.white.opacity(0.45))
                .shadow(color: .white.opacity(0.1), radius: 4)
        }
    }
}

// Convenience initializer for simple image display
extension CachedAsyncImage where Content == Image, Placeholder == ProgressView<EmptyView, EmptyView> {
    init(url: URL?) {
        self.init(
            url: url,
            content: { $0 },
            placeholder: { ProgressView() }
        )
    }
}
