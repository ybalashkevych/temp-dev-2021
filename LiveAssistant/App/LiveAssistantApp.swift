//
//  LiveAssistantApp.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 12/10/2025.
//  Copyright © 2025. All rights reserved.
//

import SwiftData
import SwiftUI

/// Main application entry point.
///
/// This app uses dependency injection via AppComponent to manage
/// dependencies and ensure proper separation of concerns.
@main
struct LiveAssistantApp: App {
    /// Shared dependency injection container
    private let appComponent = AppComponent.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
