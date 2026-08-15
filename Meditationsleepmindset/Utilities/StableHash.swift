//
//  StableHash.swift
//  Meditation Sleep Mindset
//
//  Swift's built-in `hashValue` is seeded with a per-process random value, so it is
//  NOT stable across app launches. These helpers produce a deterministic hash suitable
//  for cache keys / filenames that must survive relaunches.
//

import Foundation

extension String {
    /// Deterministic FNV-1a 64-bit hash, stable across launches and devices.
    var stableHash: String {
        var hash: UInt64 = 0xcbf29ce484222325
        let prime: UInt64 = 0x100000001b3
        for byte in self.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return String(hash, radix: 16)
    }
}
