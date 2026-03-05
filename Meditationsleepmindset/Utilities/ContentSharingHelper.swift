//
//  ContentSharingHelper.swift
//  Meditation Sleep Mindset
//

import SwiftUI

/// Centralized content sharing to eliminate duplicate shareContent() across views
@MainActor
enum ContentSharingHelper {

    /// Share a content item via the system share sheet, optionally at a specific timestamp
    static func share(_ content: Content, atTimestamp timestamp: Int? = nil) {
        var timestampText = ""
        if let t = timestamp {
            let m = t / 60; let s = t % 60
            timestampText = "\nStart at: \(m):\(String(format: "%02d", s))"
        }
        let deepLink: String
        if let t = timestamp {
            deepLink = "meditation://content/\(content.youtubeVideoID)?t=\(t)"
        } else {
            deepLink = content.deepLinkURL.absoluteString
        }
        let shareText = """
        I'm listening to '\(content.title)' on Meditation Sleep Mindset.\(timestampText)

        Open in app: \(deepLink)
        Get the app: \(content.appStoreURL.absoluteString)
        """

        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        activityVC.completionWithItemsHandler = { _, completed, _, _ in
            if completed {
                Task { @MainActor in
                    ToastManager.shared.show("Shared successfully", icon: "checkmark.circle.fill", style: .success)
                    // Record for badge tracking
                    BadgeService.shared.recordContentShared()
                }
            }
        }

        presentActivityVC(activityVC)
    }

    /// Present a UIActivityViewController from the topmost view controller
    private static func presentActivityVC(_ activityVC: UIActivityViewController) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        // Walk up to the topmost presented controller (needed when in fullScreenCover)
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        topVC.present(activityVC, animated: true)
    }
}

// MARK: - Content URL Extensions
extension Content {
    /// Deep link URL for opening this content directly in the app
    var deepLinkURL: URL {
        let encodedID = youtubeVideoID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? youtubeVideoID
        return URL(string: "meditation://content/\(encodedID)") ?? URL(string: "meditation://home")!
    }

    /// App Store URL for sharing
    var appStoreURL: URL {
        // This URL is constant and will never fail, so force unwrap is safe
        URL(string: "https://apps.apple.com/app/meditation-sleep-mindset/id\(Constants.AppStore.appID)")!
    }
}
