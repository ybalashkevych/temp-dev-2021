//
//  ItemRepositoryTests.swift
//  LiveAssistantTests
//
//  Created by Yurii Balashkevych on 12/10/2025.
//  Copyright © 2025. All rights reserved.
//

import Foundation
import SwiftData
import Testing

@testable import LiveAssistant

/// Tests for ItemRepository to improve code coverage.
@Suite("ItemRepository Tests")
struct ItemRepositoryTests {
    
    // MARK: - Mock Services
    
    final class MockModelContext: ModelContext {
        var itemsToReturn: [Item] = []
        var errorToThrow: Error?
        var insertCallCount = 0
        var deleteCallCount = 0
        
        func fetch<T>(_ descriptor: FetchDescriptor<T>) throws -> [T] where T : PersistentModel {
            if let error = errorToThrow {
                throw error
            }
            return itemsToReturn as! [T]
        }
        
        func insert(_ model: PersistentModel) {
            insertCallCount += 1
        }
        
        func delete(_ model: PersistentModel) {
            deleteCallCount += 1
        }
        
        func save() throws {
            if let error = errorToThrow {
                throw error
            }
        }
    }
    
    // MARK: - Repository Creation Tests
    
    @Test
    func createItemRepository() {
        let context = MockModelContext()
        let repository = ItemRepository(modelContext: context)
        #expect(repository != nil)
    }
    
    // MARK: - Fetch Items Tests
    
    @Test
    func fetchItemsSuccessfully() async throws {
        // Arrange
        let context = MockModelContext()
        let item1 = Item(timestamp: Date())
        let item2 = Item(timestamp: Date().addingTimeInterval(100))
        context.itemsToReturn = [item1, item2]
        
        let repository = ItemRepository(modelContext: context)
        
        // Act
        let items = try await repository.fetchItems()
        
        // Assert
        #expect(items.count == 2)
        #expect(items.contains { $0.timestamp == item1.timestamp })
        #expect(items.contains { $0.timestamp == item2.timestamp })
    }
    
    @Test
    func fetchItemsWithError() async throws {
        // Arrange
        let context = MockModelContext()
        context.errorToThrow = NSError(domain: "TestError", code: 1, userInfo: nil)
        
        let repository = ItemRepository(modelContext: context)
        
        // Act & Assert
        await #expect(throws: NSError.self) {
            try await repository.fetchItems()
        }
    }
    
    @Test
    func fetchItemsEmpty() async throws {
        // Arrange
        let context = MockModelContext()
        context.itemsToReturn = []
        
        let repository = ItemRepository(modelContext: context)
        
        // Act
        let items = try await repository.fetchItems()
        
        // Assert
        #expect(items.isEmpty)
    }
    
    // MARK: - Add Item Tests
    
    @Test
    func addItemSuccessfully() async throws {
        // Arrange
        let context = MockModelContext()
        let repository = ItemRepository(modelContext: context)
        let item = Item(timestamp: Date())
        
        // Act
        try await repository.addItem(item)
        
        // Assert
        #expect(context.insertCallCount == 1)
    }
    
    @Test
    func addItemWithError() async throws {
        // Arrange
        let context = MockModelContext()
        context.errorToThrow = NSError(domain: "TestError", code: 1, userInfo: nil)
        
        let repository = ItemRepository(modelContext: context)
        let item = Item(timestamp: Date())
        
        // Act & Assert
        await #expect(throws: NSError.self) {
            try await repository.addItem(item)
        }
    }
    
    // MARK: - Delete Items Tests
    
    @Test
    func deleteItemsSuccessfully() async throws {
        // Arrange
        let context = MockModelContext()
        let item1 = Item(timestamp: Date())
        let item2 = Item(timestamp: Date().addingTimeInterval(100))
        context.itemsToReturn = [item1, item2]
        
        let repository = ItemRepository(modelContext: context)
        
        // Act
        try await repository.deleteItems([item1])
        
        // Assert
        #expect(context.deleteCallCount == 1)
    }
    
    @Test
    func deleteItemsWithError() async throws {
        // Arrange
        let context = MockModelContext()
        context.errorToThrow = NSError(domain: "TestError", code: 1, userInfo: nil)
        
        let repository = ItemRepository(modelContext: context)
        let item = Item(timestamp: Date())
        
        // Act & Assert
        await #expect(throws: NSError.self) {
            try await repository.deleteItems([item])
        }
    }
    
    @Test
    func deleteItemsEmpty() async throws {
        // Arrange
        let context = MockModelContext()
        let repository = ItemRepository(modelContext: context)
        
        // Act
        try await repository.deleteItems([])
        
        // Assert
        #expect(context.deleteCallCount == 0)
    }
    
    // MARK: - Item Model Tests
    
    @Test
    func itemModelCreation() {
        let timestamp = Date()
        let item = Item(timestamp: timestamp)
        
        #expect(item.timestamp == timestamp)
    }
    
    @Test
    func itemModelEquality() {
        let timestamp = Date()
        let item1 = Item(timestamp: timestamp)
        let item2 = Item(timestamp: timestamp)
        let item3 = Item(timestamp: Date().addingTimeInterval(100))
        
        #expect(item1 == item2)
        #expect(item1 != item3)
    }
    
    @Test
    func itemModelHashable() {
        let timestamp = Date()
        let item1 = Item(timestamp: timestamp)
        let item2 = Item(timestamp: timestamp)
        let item3 = Item(timestamp: Date().addingTimeInterval(100))
        
        #expect(item1.hashValue == item2.hashValue)
        #expect(item1.hashValue != item3.hashValue)
    }
}