//
//  ItemRepositoryTests.swift
//  LiveAssistantTests
//
//  Created by Yurii Balashkevych on 18/10/2025.
//  Copyright © 2025. All rights reserved.
//

import Foundation
import SwiftData
import Testing

@testable import LiveAssistant

/// Tests for ItemRepository with in-memory SwiftData container.
@Suite
struct ItemRepositoryTests {
    @Test
    func fetchItemsReturnsEmptyInitially() async throws {
        // Arrange
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Item.self, configurations: config)
        let repository = ItemRepository(modelContainer: container)

        // Act
        let items = try await repository.fetchItems()

        // Assert
        #expect(items.isEmpty)
    }

    @Test
    func addItemSuccessfully() async throws {
        // Arrange
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Item.self, configurations: config)
        let repository = ItemRepository(modelContainer: container)
        let item = Item(timestamp: Date())

        // Act
        try await repository.addItem(item)
        let items = try await repository.fetchItems()

        // Assert
        #expect(items.count == 1)
        #expect(items.first?.timestamp == item.timestamp)
    }

    @Test
    func addMultipleItems() async throws {
        // Arrange
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Item.self, configurations: config)
        let repository = ItemRepository(modelContainer: container)
        let item1 = Item(timestamp: Date())
        let item2 = Item(timestamp: Date().addingTimeInterval(100))

        // Act
        try await repository.addItem(item1)
        try await repository.addItem(item2)
        let items = try await repository.fetchItems()

        // Assert
        #expect(items.count == 2)
    }

    @Test
    func deleteItemsSuccessfully() async throws {
        // Arrange
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Item.self, configurations: config)
        
        // Create a single shared context for this test
        let context = ModelContext(container)
        let item1 = Item(timestamp: Date())
        let item2 = Item(timestamp: Date().addingTimeInterval(100))
        
        context.insert(item1)
        context.insert(item2)
        try context.save()

        // Verify we have 2 items
        let descriptor1 = FetchDescriptor<Item>()
        let allItems = try context.fetch(descriptor1)
        #expect(allItems.count == 2)

        // Act - Delete the first item
        context.delete(item1)
        try context.save()

        // Assert - Verify we have 1 item left
        let descriptor2 = FetchDescriptor<Item>()
        let remainingItems = try context.fetch(descriptor2)
        #expect(remainingItems.count == 1)
        #expect(remainingItems.first?.timestamp == item2.timestamp)
    }

    @Test
    func fetchItemsOrderedByTimestamp() async throws {
        // Arrange
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Item.self, configurations: config)
        let repository = ItemRepository(modelContainer: container)

        let now = Date()
        let item1 = Item(timestamp: now)
        let item2 = Item(timestamp: now.addingTimeInterval(100))
        let item3 = Item(timestamp: now.addingTimeInterval(200))

        // Add in random order
        try await repository.addItem(item2)
        try await repository.addItem(item1)
        try await repository.addItem(item3)

        // Act
        let items = try await repository.fetchItems()

        // Assert - Should be in reverse chronological order
        #expect(items.count == 3)
        #expect(items[0].timestamp > items[1].timestamp)
        #expect(items[1].timestamp > items[2].timestamp)
    }
}
