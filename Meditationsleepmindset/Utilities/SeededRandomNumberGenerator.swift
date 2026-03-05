//
//  SeededRandomNumberGenerator.swift
//  Meditation Sleep Mindset
//

import Foundation

/// A deterministic random number generator seeded by a UInt64.
/// Used to produce the same "random" shuffle for a given day.
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        // xorshift64 algorithm
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
