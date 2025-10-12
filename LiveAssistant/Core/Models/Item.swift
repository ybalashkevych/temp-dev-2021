//
//  Item.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 12/10/2025.
//  Copyright © 2025. All rights reserved.
//

import Foundation
import SwiftData

/// A simple data model representing an item with a timestamp.
///
/// This model uses SwiftData for persistence and serves as an example
/// of domain model implementation in the Core/Models layer.
@Model
final class Item {
    var timestamp: Date

    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
