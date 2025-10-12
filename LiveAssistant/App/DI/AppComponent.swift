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

        // Permission Service
        container.register(PermissionServiceProtocol.self) { _ in
            PermissionService()
        }.inObjectScope(.container)

        // Microphone Audio Service
        container.register(MicrophoneAudioServiceProtocol.self) { _ in
            MicrophoneAudioService()
        }.inObjectScope(.container)

        // System Audio Service
        container.register(SystemAudioServiceProtocol.self) { _ in
            SystemAudioService()
        }.inObjectScope(.container)

        // Transcription Service
        container.register(TranscriptionServiceProtocol.self) { _ in
            TranscriptionService()
        }.inObjectScope(.container)

        // Text Analysis Service
        container.register(TextAnalysisServiceProtocol.self) { _ in
            TextAnalysisService()
        }.inObjectScope(.container)
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

        // Transcription Repository
        container.register(TranscriptionRepositoryProtocol.self) { resolver in
            guard
                let microphoneService = resolver.resolve(MicrophoneAudioServiceProtocol.self),
                let systemAudioService = resolver.resolve(SystemAudioServiceProtocol.self),
                let transcriptionService = resolver.resolve(TranscriptionServiceProtocol.self),
                let textAnalysisService = resolver.resolve(TextAnalysisServiceProtocol.self)
            else {
                fatalError("Required services not registered in DI container")
            }
            return TranscriptionRepository(
                microphoneService: microphoneService,
                systemAudioService: systemAudioService,
                transcriptionService: transcriptionService,
                textAnalysisService: textAnalysisService
            )
        }
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

        // Transcription ViewModel
        container.register(TranscriptionViewModel.self) { resolver in
            guard
                let transcriptionRepository = resolver.resolve(TranscriptionRepositoryProtocol.self),
                let permissionService = resolver.resolve(PermissionServiceProtocol.self)
            else {
                fatalError("Required dependencies not registered in DI container")
            }
            return TranscriptionViewModel(
                transcriptionRepository: transcriptionRepository,
                permissionService: permissionService
            )
        }
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
