//
//  ContentViewModel.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 12/10/2025.
//  Copyright © 2025. All rights reserved.
//

import Foundation
import Observation

/// ViewModel for managing the content view state.
///
/// This ViewModel demonstrates the proper use of @Observable, @MainActor,
/// and the repository pattern for data access.
@Observable
@MainActor
final class ContentViewModel {
    // MARK: - Properties

    private let itemRepository: ItemRepositoryProtocol

    private(set) var items: [Item] = []
    private(set) var isLoading = false
    private(set) var error: Error?

    // MARK: - Initialization

    init(itemRepository: ItemRepositoryProtocol) {
        self.itemRepository = itemRepository
    }

    // MARK: - Public Methods

    /// Loads items from the repository.
    func loadItems() async {
        isLoading = true
        error = nil

        do {
            items = try await itemRepository.fetchItems()
        } catch {
            self.error = error
        }

        isLoading = false
    }

    /// Adds a new item with the current timestamp.
    func addItem() async {
        let newItem = Item(timestamp: Date())

        do {
            try await itemRepository.addItem(newItem)
            // Reload items to reflect the new addition
            await loadItems()
        } catch {
            self.error = error
        }
    }

    /// Deletes items at the specified indices.
    ///
    /// - Parameter offsets: Index set of items to delete
    func deleteItems(at offsets: IndexSet) async {
        let itemsToDelete = offsets.map { items[$0] }

        do {
            try await itemRepository.deleteItems(itemsToDelete)
            // Reload items to reflect the deletion
            await loadItems()
        } catch {
            self.error = error
        }
    }
}
