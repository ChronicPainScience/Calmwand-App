//
//  Item.swift
//  Calmwand App
//
//  Created by Paraparamid on 2024/9/3.
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

