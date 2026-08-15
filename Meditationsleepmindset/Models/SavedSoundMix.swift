//
//  SavedSoundMix.swift
//  Meditation Sleep Mindset
//
//  A user-saved combination of ambient sounds + per-sound volumes, recallable from the mixer.
//

import Foundation
import SwiftData

@Model
final class SavedSoundMix {
    var id: UUID
    var name: String
    /// Sound id → volume (0…1).
    var soundVolumes: [String: Double]
    var createdAt: Date

    init(name: String, soundVolumes: [String: Double]) {
        self.id = UUID()
        self.name = name
        self.soundVolumes = soundVolumes
        self.createdAt = Date()
    }

    var soundCount: Int { soundVolumes.count }
}
