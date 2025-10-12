//
//  ContentViewModelTests.swift
//  LiveAssistantTests
//
//  Created by Yurii Balashkevych on 12/10/2025.
//  Copyright © 2025. All rights reserved.
//

import Foundation
import SwiftData
import Testing
@testable import LiveAssistant

/// Tests for ContentViewModel demonstrating Swift Testing framework usage.
///
/// These tests showcase the recommended testing patterns:
/// - Swift Testing framework with @Test attribute
/// - Arrange-Act-Assert pattern
/// - Mock dependencies for isolation
/// - Async/await testing
@MainActor
struct ContentViewModelTests {
    // MARK: - Test Load Items

    @Test
    func loadItemsSuccessfully() async throws {
        // Arrange
        let mockRepository = MockItemRepository()
        let item1 = Item(timestamp: Date())
        let item2 = Item(timestamp: Date().addingTimeInterval(100))
        mockRepository.itemsToReturn = [item1, item2]

        let viewModel = ContentViewModel(itemRepository: mockRepository)

        // Act
        await viewModel.loadItems()

        // Assert
        #expect(viewModel.items.count == 2)
        #expect(!viewModel.isLoading)
        #expect(viewModel.error == nil)
        #expect(mockRepository.fetchItemsCallCount == 1)
    }

    @Test
    func loadItemsWithError() async throws {
        // Arrange
        let mockRepository = MockItemRepository()
        mockRepository.errorToThrow = RepositoryError.fetchFailed

        let viewModel = ContentViewModel(itemRepository: mockRepository)

        // Act
        await viewModel.loadItems()

        // Assert
        #expect(viewModel.items.isEmpty)
        #expect(!viewModel.isLoading)
        #expect(viewModel.error != nil)
    }

    // MARK: - Test Add Item

    @Test
    func addItemSuccessfully() async throws {
        // Arrange
        let mockRepository = MockItemRepository()
        let viewModel = ContentViewModel(itemRepository: mockRepository)

        // Act
        await viewModel.addItem()

        // Assert
        #expect(mockRepository.addItemCallCount == 1)
        #expect(mockRepository.fetchItemsCallCount == 1) // Called to reload after add
    }

    @Test
    func addItemWithError() async throws {
        // Arrange
        let mockRepository = MockItemRepository()
        mockRepository.errorToThrow = RepositoryError.saveFailed

        let viewModel = ContentViewModel(itemRepository: mockRepository)

        // Act
        await viewModel.addItem()

        // Assert
        #expect(viewModel.error != nil)
    }

    // MARK: - Test Delete Items

    @Test
    func deleteItemsSuccessfully() async throws {
        // Arrange
        let mockRepository = MockItemRepository()
        let item1 = Item(timestamp: Date())
        let item2 = Item(timestamp: Date().addingTimeInterval(100))
        mockRepository.itemsToReturn = [item1, item2]

        let viewModel = ContentViewModel(itemRepository: mockRepository)
        await viewModel.loadItems()

        // Act
        await viewModel.deleteItems(at: IndexSet(integer: 0))

        // Assert
        #expect(mockRepository.deleteItemsCallCount == 1)
        #expect(mockRepository.fetchItemsCallCount == 2) // Initial load + reload after delete
    }
}

// MARK: - Mock Repository

/// Mock implementation of ItemRepositoryProtocol for testing.
///
/// This mock tracks method calls and allows configuring return values
/// and errors for testing different scenarios.
final class MockItemRepository: ItemRepositoryProtocol {
    var itemsToReturn: [Item] = []
    var errorToThrow: Error?

    var fetchItemsCallCount = 0
    var addItemCallCount = 0
    var deleteItemsCallCount = 0

    func fetchItems() async throws -> [Item] {
        fetchItemsCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        return itemsToReturn
    }

    func addItem(_ item: Item) async throws {
        addItemCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        itemsToReturn.append(item)
    }

    func deleteItems(_ items: [Item]) async throws {
        deleteItemsCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        itemsToReturn.removeAll { itemToRemove in
            items.contains { $0.timestamp == itemToRemove.timestamp }
        }
    }
}

