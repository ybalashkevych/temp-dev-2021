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
            MainView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

/// Main view with tabbed interface for accessing app features.
struct MainView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TranscriptionView()
                .tabItem {
                    Label(Strings.App.Tab.transcription, systemImage: "waveform")
                }
                .tag(0)

            ContentView()
                .tabItem {
                    Label(Strings.App.Tab.demoItems, systemImage: "list.bullet")
                }
                .tag(1)
        }
    }
}
