//
//  ContentView.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 12/10/2025.
//  Copyright © 2025. All rights reserved.
//

import SwiftData
import SwiftUI

/// Main content view demonstrating MVVM architecture with dependency injection.
///
/// This view observes a ContentViewModel and delegates all business logic
/// to the ViewModel, maintaining a clean separation of concerns.
struct ContentView: View {
    @State private var vm: ContentViewModel

    init(vm: ContentViewModel? = nil) {
        let viewModel = vm ?? AppComponent.shared.require(ContentViewModel.self)
        _vm = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(vm.items) { item in
                    NavigationLink {
                        Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                    } label: {
                        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                    }
                }
                .onDelete { offsets in
                    Task {
                        await vm.deleteItems(at: offsets)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .toolbar {
                ToolbarItem {
                    Button {
                        Task {
                            await vm.addItem()
                        }
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .overlay {
                if vm.isLoading {
                    ProgressView()
                }
            }
            .task {
                await vm.loadItems()
            }
        } detail: {
            Text("Select an item")
        }
        .alert("Error", isPresented: .constant(vm.error != nil)) {
            Button("OK") {
                // Error handling
            }
        } message: {
            if let error = vm.error {
                Text(error.localizedDescription)
            }
        }
    }
}

#Preview {
    func makePreviewContainer() -> ModelContainer {
        do {
            return try ModelContainer(
                for: Item.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }

    let repository = ItemRepository(modelContainer: makePreviewContainer())
    let vm = ContentViewModel(itemRepository: repository)

    return ContentView(vm: vm)
}
