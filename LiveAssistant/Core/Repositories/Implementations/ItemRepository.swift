//
//  ItemRepository.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 12/10/2025.
//  Copyright © 2025. All rights reserved.
//

import Foundation
import SwiftData

/// Repository implementation for managing items using SwiftData.
///
/// This class provides concrete implementation of ItemRepositoryProtocol
/// using SwiftData for persistence.
///
/// - Note: Uses `@unchecked Sendable` because SwiftData's `ModelContainer` is thread-safe
///   but not marked as `Sendable` in the current SDK version.
final class ItemRepository: ItemRepositoryProtocol, @unchecked Sendable {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func fetchItems() async throws -> [Item] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Item>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])

        do {
            return try context.fetch(descriptor)
        } catch {
            throw RepositoryError.fetchFailed
        }
    }

    func addItem(_ item: Item) async throws {
        let context = ModelContext(modelContainer)

        do {
            context.insert(item)
            try context.save()
        } catch {
            throw RepositoryError.saveFailed
        }
    }

    func deleteItems(_ items: [Item]) async throws {
        let context = ModelContext(modelContainer)

        do {
            for item in items {
                context.delete(item)
            }
            try context.save()
        } catch {
            throw RepositoryError.deleteFailed
        }
    }
}
