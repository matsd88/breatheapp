//
//  AppLogger.swift
//  Meditation Sleep Mindset
//
//  Unified logging using os.Logger. Debug logs only appear in debug builds.
//

import Foundation
import os

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.meditation"

    static let player = Logger(subsystem: subsystem, category: "Player")
    static let youtube = Logger(subsystem: subsystem, category: "YouTube")
    static let cache = Logger(subsystem: subsystem, category: "Cache")
    static let health = Logger(subsystem: subsystem, category: "ContentHealth")
    static let sync = Logger(subsystem: subsystem, category: "iCloudSync")
    static let general = Logger(subsystem: subsystem, category: "General")
}
