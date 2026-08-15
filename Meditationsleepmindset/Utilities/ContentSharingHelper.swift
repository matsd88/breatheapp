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
        var timestampSuffix = ""
        if let t = timestamp {
            timestampSuffix = "&t=\(t)"
        }
        let shareURL = "\(content.shareURL.absoluteString)\(timestampSuffix)"
        let shareText = "I'm listening to '\(content.title)' on Breathe\n\(shareURL)"

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
    /// Universal Link URL for sharing — opens the app via Associated Domains if installed,
    /// or shows a branded landing page with App Store link if not.
    var shareURL: URL {
        let encodedID = youtubeVideoID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? youtubeVideoID
        return URL(string: "https://www.meditationandsleepapp.com/content/?v=\(encodedID)")!
    }

    /// Custom URL scheme for in-app deep links (Live Activity, Spotlight, etc.)
    var deepLinkURL: URL {
        let encodedID = youtubeVideoID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? youtubeVideoID
        return URL(string: "meditation://content/\(encodedID)") ?? URL(string: "meditation://home")!
    }

    /// App Store URL for sharing
    var appStoreURL: URL {
        URL(string: "https://apps.apple.com/app/meditation-sleep-mindset/id\(Constants.AppStore.appID)")!
    }
}
