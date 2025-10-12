# LiveAssistant Architecture

## Overview

LiveAssistant is a macOS application built with a modular MVVM (Model-View-ViewModel) architecture. The app provides real-time transcription during job interviews, meetings, and calls, with AI-powered assistance for communication.

## Architecture Pattern

### MVVM with Repository Pattern

The application follows MVVM architecture with clear separation of concerns:

```
┌──────────────┐
│     View     │ SwiftUI Views
└──────┬───────┘
       │ observes
       ↓
┌──────────────┐
│  ViewModel   │ @Observable @MainActor
└──────┬───────┘
       │ uses
       ↓
┌──────────────┐
│  Repository  │ Data abstraction layer
└──────┬───────┘
       │ uses
       ↓
┌──────────────┐
│   Service    │ API clients, AI services, SwiftData
└──────────────┘
```

### Layer Responsibilities

#### View Layer (SwiftUI)
- **Responsibility**: UI rendering and user interaction
- **Rules**:
  - Only SwiftUI views and components
  - No business logic
  - Observes ViewModels
  - Declarative UI with SwiftUI
  - Reusable components in `Components/` subdirectories

#### ViewModel Layer
- **Responsibility**: Presentation logic and state management
- **Rules**:
  - Must use `@Observable` macro for state observation
  - Must use `@MainActor` for UI-related ViewModels
  - No direct dependency on SwiftUI
  - No direct access to Services (use Repositories)
  - Handle user actions and transform data for Views
  - Coordinate between multiple repositories if needed

**Example:**
```swift
@Observable
@MainActor
final class ChatViewModel {
    private let chatRepository: ChatRepositoryProtocol
    private(set) var messages: [Message] = []
    private(set) var isLoading = false
    
    init(chatRepository: ChatRepositoryProtocol) {
        self.chatRepository = chatRepository
    }
    
    func loadMessages() async throws {
        isLoading = true
        defer { isLoading = false }
        messages = try await chatRepository.fetchMessages()
    }
}
```

#### Repository Layer
- **Responsibility**: Data abstraction and business logic
- **Rules**:
  - Define protocol-based interfaces
  - Abstract away data source details (SwiftData, network, etc.)
  - Coordinate between multiple services
  - Transform service data to domain models
  - Handle caching and data consistency
  - Business logic belongs here

**Example:**
```swift
protocol ChatRepositoryProtocol: Sendable {
    func fetchMessages() async throws -> [Message]
    func sendMessage(_ content: String) async throws -> Message
}

final class ChatRepository: ChatRepositoryProtocol {
    private let apiService: APIServiceProtocol
    private let storageService: StorageServiceProtocol
    
    init(apiService: APIServiceProtocol, storageService: StorageServiceProtocol) {
        self.apiService = apiService
        self.storageService = storageService
    }
    
    func fetchMessages() async throws -> [Message] {
        // Try cache first
        if let cached = try? await storageService.fetchMessages() {
            return cached
        }
        // Fetch from network and cache
        let messages = try await apiService.getMessages()
        try await storageService.saveMessages(messages)
        return messages
    }
}
```

#### Service Layer
- **Responsibility**: External interactions and data operations
- **Rules**:
  - API clients (networking)
  - SwiftData model operations
  - AI/ML service integrations
  - System integrations (audio, permissions)
  - Protocol-based for testability
  - No business logic (that belongs in Repositories)

## Project Structure

```
LiveAssistant/
├── App/
│   ├── LiveAssistantApp.swift      # App entry point
│   ├── AppDelegate.swift           # AppKit integration (if needed)
│   └── DI/
│       └── AppComponent.swift      # Dependency injection container
│
├── Core/
│   ├── Models/                     # Domain models and SwiftData entities
│   │   ├── Message.swift
│   │   ├── Transcript.swift
│   │   └── User.swift
│   │
│   ├── Services/                   # Service protocols and implementations
│   │   ├── Protocols/
│   │   │   ├── APIServiceProtocol.swift
│   │   │   ├── StorageServiceProtocol.swift
│   │   │   └── TranscriptionServiceProtocol.swift
│   │   └── Implementations/
│   │       ├── APIService.swift
│   │       ├── SwiftDataService.swift
│   │       └── TranscriptionService.swift
│   │
│   ├── Repositories/               # Repository implementations
│   │   ├── Protocols/
│   │   │   ├── ChatRepositoryProtocol.swift
│   │   │   └── TranscriptRepositoryProtocol.swift
│   │   └── Implementations/
│   │       ├── ChatRepository.swift
│   │       └── TranscriptRepository.swift
│   │
│   └── Utilities/                  # Extensions, helpers, constants
│       ├── Extensions/
│       ├── Helpers/
│       └── Constants.swift
│
├── Features/                       # Feature modules
│   ├── Chat/
│   │   ├── Views/
│   │   │   ├── ChatView.swift
│   │   │   └── ChatHistoryView.swift
│   │   ├── ViewModels/
│   │   │   └── ChatViewModel.swift
│   │   └── Components/
│   │       ├── MessageBubble.swift
│   │       └── InputField.swift
│   │
│   ├── Transcription/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Components/
│   │
│   └── Settings/
│       ├── Views/
│       ├── ViewModels/
│       └── Components/
│
├── Resources/
│   ├── Assets.xcassets/
│   └── Localizable.strings         # Localized strings (error messages, UI text)
│
└── Supporting Files/
```

## Dependency Injection

### Swinject Container

The application uses **Swinject** for dependency injection to ensure:
- Loose coupling between components
- Easy testing with mock dependencies
- Clear dependency graphs
- Lifecycle management

### Container Setup

All dependencies are registered in `AppComponent.swift`:

```swift
import Swinject

final class AppComponent {
    static let shared = AppComponent()
    let container = Container()
    
    private init() {
        registerServices()
        registerRepositories()
        registerViewModels()
    }
    
    private func registerServices() {
        container.register(APIServiceProtocol.self) { _ in
            APIService()
        }.inObjectScope(.container)
        
        container.register(StorageServiceProtocol.self) { _ in
            SwiftDataService()
        }.inObjectScope(.container)
    }
    
    private func registerRepositories() {
        container.register(ChatRepositoryProtocol.self) { resolver in
            guard let apiService = resolver.resolve(APIServiceProtocol.self),
                  let storageService = resolver.resolve(StorageServiceProtocol.self) else {
                fatalError("Required dependencies not registered in DI container")
            }
            return ChatRepository(
                apiService: apiService,
                storageService: storageService
            )
        }
    }
    
    private func registerViewModels() {
        container.register(ChatViewModel.self) { resolver in
            guard let chatRepository = resolver.resolve(ChatRepositoryProtocol.self) else {
                fatalError("ChatRepositoryProtocol not registered in DI container")
            }
            return ChatViewModel(chatRepository: chatRepository)
        }
    }
}
```

### Using Dependency Injection in Views

```swift
struct ChatView: View {
    @State private var vm: ChatViewModel
    
    init(vm: ChatViewModel? = nil) {
        let viewModel = vm ?? AppComponent.shared.require(ChatViewModel.self)
        _vm = State(initialValue: viewModel)
    }
    
    var body: some View {
        // View implementation
    }
}
```

## SwiftData Integration

### Model Definition

SwiftData models are defined in `Core/Models/`:

```swift
import SwiftData

@Model
final class Message {
    @Attribute(.unique) var id: UUID
    var content: String
    var timestamp: Date
    var role: MessageRole
    
    init(id: UUID = UUID(), content: String, timestamp: Date = Date(), role: MessageRole) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.role = role
    }
}
```

### Repository Abstraction

SwiftData is accessed through the Repository layer, not directly from ViewModels:

```swift
final class SwiftDataService: StorageServiceProtocol {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
    }
    
    func saveMessage(_ message: Message) async throws {
        modelContext.insert(message)
        try modelContext.save()
    }
}
```

## Async/Await Patterns

### Asynchronous Operations

All asynchronous operations use Swift's modern concurrency:

```swift
// In ViewModel
@MainActor
func loadData() async {
    do {
        isLoading = true
        let data = try await repository.fetchData()
        self.data = data
    } catch {
        self.error = error
    }
    isLoading = false
}

// In View
.task {
    await viewModel.loadData()
}
```

### Error Handling

Errors should be specific types and handled gracefully:

```swift
enum ChatError: LocalizedError {
    case networkFailure
    case invalidResponse
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .networkFailure:
            return NSLocalizedString("network.error.failure", comment: "")
        case .invalidResponse:
            return NSLocalizedString("network.error.invalid_response", comment: "")
        case .unauthorized:
            return NSLocalizedString("auth.error.unauthorized", comment: "")
        }
    }
}
```

## Effect Patterns

For side effects (logging, analytics, notifications), use explicit effect handlers:

```swift
@MainActor
final class ChatViewModel {
    private let effectHandler: EffectHandler
    
    func sendMessage(_ content: String) async {
        do {
            let message = try await repository.sendMessage(content)
            // Trigger effect
            await effectHandler.logEvent(.messageSent(message))
        } catch {
            await effectHandler.logError(error)
        }
    }
}
```

## Testing Strategy

### ViewModel Testing

ViewModels should be tested with mock repositories:

```swift
import Testing

@Test
func testLoadMessages() async throws {
    // Arrange
    let mockRepository = MockChatRepository()
    let viewModel = ChatViewModel(chatRepository: mockRepository)
    
    // Act
    try await viewModel.loadMessages()
    
    // Assert
    #expect(viewModel.messages.count == 2)
    #expect(viewModel.isLoading == false)
}
```

### Repository Testing

Repositories should be tested with mock services:

```swift
@Test
func testChatRepository() async throws {
    // Arrange
    let mockAPI = MockAPIService()
    let mockStorage = MockStorageService()
    let repository = ChatRepository(apiService: mockAPI, storageService: mockStorage)
    
    // Act
    let messages = try await repository.fetchMessages()
    
    // Assert
    #expect(messages.count == 2)
    #expect(mockStorage.saveWasCalled)
}
```

## Best Practices

### Do's ✅

- Use `@Observable` and `@MainActor` for ViewModels
- Define protocol-based interfaces for testability
- Use Repository pattern to abstract data sources
- Use async/await for asynchronous operations
- Localize all user-facing strings
- Handle errors with specific error types
- Inject dependencies via initializers
- Keep Views simple and declarative
- Write tests for ViewModels and Repositories

### Don'ts ❌

- Don't access Services directly from ViewModels
- Don't put business logic in Views
- Don't use force unwrapping without explicit justification
- Don't use `@ObservableObject` (use `@Observable` instead)
- Don't hardcode strings (use Localizable.strings)
- Don't create massive ViewModels (split into smaller ones)
- Don't skip dependency injection

## Migration Path

For existing code that doesn't follow this architecture:

1. **Extract business logic** from Views into ViewModels
2. **Create Repository layer** for data access
3. **Move data operations** from ViewModels to Repositories
4. **Define protocols** for Services and Repositories
5. **Set up DI container** and register dependencies
6. **Update ViewModels** to use `@Observable` instead of `@ObservableObject`
7. **Write tests** for new architecture

## Resources

- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [Swinject Documentation](https://github.com/Swinject/Swinject)
- [Swift Testing Documentation](https://developer.apple.com/documentation/testing)


