//
//  ItemRepositoryProtocol.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 12/10/2025.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Protocol defining operations for managing items.
///
/// This protocol abstracts the data layer, allowing ViewModels to work
/// with items without knowing the underlying storage mechanism.
protocol ItemRepositoryProtocol: Sendable {
    /// Fetches all items from storage.
    ///
    /// - Returns: An array of items
    /// - Throws: Repository errors if the operation fails
    func fetchItems() async throws -> [Item]

    /// Adds a new item to storage.
    ///
    /// - Parameter item: The item to add
    /// - Throws: Repository errors if the operation fails
    func addItem(_ item: Item) async throws

    /// Deletes items from storage.
    ///
    /// - Parameter items: The items to delete
    /// - Throws: Repository errors if the operation fails
    func deleteItems(_ items: [Item]) async throws
}

/// Errors that can occur in the repository layer
enum RepositoryError: LocalizedError {
    case fetchFailed
    case saveFailed
    case deleteFailed
    case notFound

    var errorDescription: String? {
        switch self {
        case .fetchFailed:
            Strings.Error.Repository.fetchFailed
        case .saveFailed:
            Strings.Error.Repository.saveFailed
        case .deleteFailed:
            Strings.Error.Repository.deleteFailed
        case .notFound:
            Strings.Error.Repository.notFound
        }
    }
}
