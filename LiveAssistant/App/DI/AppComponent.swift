//
//  AppComponent.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 12/10/2025.
//  Copyright © 2025. All rights reserved.
//

import Foundation
import SwiftData
import Swinject

/// Main dependency injection container for the application.
///
/// This class manages all dependencies using Swinject, ensuring proper
/// lifecycle management and easy testing with mock implementations.
@MainActor
final class AppComponent {
    /// Shared instance of the dependency container
    static let shared = AppComponent()

    /// Swinject container holding all registered dependencies
    let container = Container()

    /// Private initializer to enforce singleton pattern
    private init() {
        registerServices()
        registerRepositories()
        registerViewModels()
    }

    // MARK: - Service Registration

    /// Registers all service dependencies
    private func registerServices() {
        // SwiftData ModelContainer
        container.register(ModelContainer.self) { _ in
            let schema = Schema([
                Item.self
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }.inObjectScope(.container)

        // Add other services here as they are implemented:
        // - API Service
        // - Transcription Service
        // - Storage Service
        // etc.
    }

    // MARK: - Repository Registration

    /// Registers all repository dependencies
    private func registerRepositories() {
        // Item Repository
        container.register(ItemRepositoryProtocol.self) { resolver in
            guard let modelContainer = resolver.resolve(ModelContainer.self) else {
                fatalError("ModelContainer not registered in DI container")
            }
            return ItemRepository(modelContainer: modelContainer)
        }

        // Add other repositories here as they are implemented
    }

    // MARK: - ViewModel Registration

    /// Registers all ViewModel dependencies
    private func registerViewModels() {
        // Content ViewModel
        container.register(ContentViewModel.self) { resolver in
            guard let itemRepository = resolver.resolve(ItemRepositoryProtocol.self) else {
                fatalError("ItemRepositoryProtocol not registered in DI container")
            }
            return ContentViewModel(itemRepository: itemRepository)
        }

        // Add other ViewModels here as they are implemented
    }

    // MARK: - Resolver Methods

    /// Resolves a dependency from the container
    /// - Parameter serviceType: The type of service to resolve
    /// - Returns: The resolved service instance, or nil if not registered
    func resolve<Service>(_ serviceType: Service.Type) -> Service? {
        container.resolve(serviceType)
    }

    /// Resolves a dependency from the container (non-optional)
    /// - Parameter serviceType: The type of service to resolve
    /// - Returns: The resolved service instance
    /// - Important: Crashes with fatalError if dependency is not registered
    func require<Service>(_ serviceType: Service.Type) -> Service {
        guard let service = container.resolve(serviceType) else {
            fatalError("Failed to resolve dependency: \(serviceType). Make sure it's registered in AppComponent.")
        }
        return service
    }
}
