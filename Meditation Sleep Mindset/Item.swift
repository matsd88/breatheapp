//
//  Item.swift
//  Meditation Sleep Mindset
//
//  Created by Mats Degerstedt on 1/23/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
