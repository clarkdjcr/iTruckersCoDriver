//
//  Item.swift
//  iTruckersCoDriver
//
//  Created by Donald Clark on 3/7/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date = Date()

    init(timestamp: Date = Date()) {
        self.timestamp = timestamp
    }
}
