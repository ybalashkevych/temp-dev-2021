# LiveAssistant Architecture & Standards

This document provides comprehensive architecture patterns and coding standards for LiveAssistant, a macOS application built with modular MVVM architecture.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Architecture Patterns](#architecture-patterns)
- [Project Structure](#project-structure)
- [Coding Standards](#coding-standards)
- [Testing Strategy](#testing-strategy)
- [Best Practices](#best-practices)

---

# Architecture Overview

LiveAssistant is a macOS application that provides real-time transcription during job interviews, meetings, and calls, with AI-powered assistance for communication.

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

---

# Architecture Patterns

## Layer Responsibilities

### View Layer (SwiftUI)
- **Responsibility**: UI rendering and user interaction
- **Rules**:
  - Only SwiftUI views and components
  - No business logic
  - Observes ViewModels
  - Declarative UI with SwiftUI
  - Reusable components in `Components/` subdirectories

### ViewModel Layer
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

### Repository Layer
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

### Service Layer
- **Responsibility**: External interactions and data operations
- **Rules**:
  - API clients (networking)
  - SwiftData model operations
  - AI/ML service integrations
  - System integrations (audio, permissions)
  - Protocol-based for testability
  - No business logic (that belongs in Repositories)

---

# Project Structure

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
│   ├── Generated/                  # SwiftGen auto-generated code
│   │   ├── Strings.swift           # Type-safe localized strings
│   │   └── Assets.swift            # Type-safe assets
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
│   └── Localizable.strings         # Localized strings
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
            return Strings.Chat.Error.networkFailure
        case .invalidResponse:
            return Strings.Chat.Error.invalidResponse
        case .unauthorized:
            return Strings.Chat.Error.unauthorized
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
            await effectHandler.logEvent(.messageSent(message))
        } catch {
            await effectHandler.logError(error)
        }
    }
}
```

---

# Coding Standards

## Swift Style Guide

### File Headers

All Swift files must include a header with the following format:

```swift
//
//  FileName.swift
//  LiveAssistant
//
//  Created by [Author Name] on [Date].
//  Copyright © 2025 [Company Name]. All rights reserved.
//
```

### Naming Conventions

#### Types (Classes, Structs, Enums, Protocols)

- Use PascalCase
- Be descriptive and avoid abbreviations
- Protocols should describe what they are or what they can do

```swift
// ✅ Good
class ChatViewModel { }
struct UserProfile { }
enum NetworkError { }
protocol ChatRepositoryProtocol { }

// ❌ Bad
class chatVM { }
struct UsrProf { }
enum NetErr { }
protocol ChatRepo { }
```

#### Functions and Variables

- Use camelCase
- Be descriptive and use full words
- Boolean variables should read like assertions

```swift
// ✅ Good
func fetchUserMessages() async throws -> [Message]
var isLoading: Bool
let maximumRetryCount = 3
func shouldRetryRequest() -> Bool

// ❌ Bad
func fetchUsrMsg() async throws -> [Message]
var loading: Bool
let maxRetry = 3
func retry() -> Bool
```

#### Constants

- Use camelCase
- Group related constants in enums or nested structures

```swift
// ✅ Good
enum Constants {
    static let apiBaseURL = "https://api.example.com"
    static let defaultTimeout: TimeInterval = 30
}

// ❌ Bad
let API_BASE_URL = "https://api.example.com"
let DEFAULT_TIMEOUT: TimeInterval = 30
```

#### ViewModel Variable Naming

- Always use `vm` for ViewModel variable names (properties, parameters, local variables)

```swift
// ✅ Good
struct ChatView: View {
    @State private var vm: ChatViewModel
}

// ❌ Bad
struct ChatView: View {
    @State private var viewModel: ChatViewModel
}
```

### Code Organization

#### File Structure

Organize code in the following order:

1. Import statements
2. Type declaration
3. Properties (organized: static, stored, computed)
4. Initializers
5. Lifecycle methods
6. Public methods
7. Private methods
8. Extensions (in separate files when substantial)

```swift
import SwiftUI
import Swinject

@Observable
@MainActor
final class ChatViewModel {
    // MARK: - Properties
    
    // Static properties
    static let shared = ChatViewModel()
    
    // Dependencies
    private let repository: ChatRepositoryProtocol
    
    // State properties
    private(set) var messages: [Message] = []
    private(set) var isLoading = false
    
    // Computed properties
    var hasMessages: Bool {
        !messages.isEmpty
    }
    
    // MARK: - Initialization
    
    init(repository: ChatRepositoryProtocol) {
        self.repository = repository
    }
    
    // MARK: - Public Methods
    
    func loadMessages() async throws {
        // Implementation
    }
    
    // MARK: - Private Methods
    
    private func handleError(_ error: Error) {
        // Implementation
    }
}

// MARK: - Equatable

extension ChatViewModel: Equatable {
    static func == (lhs: ChatViewModel, rhs: ChatViewModel) -> Bool {
        lhs.messages == rhs.messages
    }
}
```

#### MARK Comments

Use MARK comments to organize code sections:

```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Public Methods
// MARK: - Private Methods
// MARK: - Protocol Conformance
```

### Formatting

#### Line Length

- Warning at 140 characters
- Error at 150 characters
- Break long lines logically

```swift
// ✅ Good
func processTransaction(
    amount: Decimal,
    currency: Currency,
    sender: User,
    recipient: User
) async throws -> Transaction

// ❌ Bad
func processTransaction(amount: Decimal, currency: Currency, sender: User, recipient: User) async throws -> Transaction
```

#### Indentation

- 4 spaces (no tabs)
- Align multiline expressions logically

```swift
// ✅ Good
let user = User(
    id: UUID(),
    name: "John Doe",
    email: "john@example.com"
)

// ❌ Bad
let user = User(
  id: UUID(),
  name: "John Doe",
  email: "john@example.com")
```

#### Spacing

- One blank line between methods
- No blank line between property declarations (unless logically grouped)
- One blank line before MARK comments

### Swift 6 Best Practices

#### Concurrency

Always use Swift's modern concurrency features:

```swift
// ✅ Good
func fetchData() async throws -> Data {
    try await URLSession.shared.data(from: url).0
}

// ❌ Bad (avoid completion handlers)
func fetchData(completion: @escaping (Result<Data, Error>) -> Void) {
    URLSession.shared.dataTask(with: url) { data, _, error in
        // ...
    }.resume()
}
```

#### Actor Isolation

Use `@MainActor` for UI-related classes:

```swift
// ✅ Good
@Observable
@MainActor
final class ChatViewModel {
    // All properties and methods run on main thread
}

// For non-UI concurrent code, use actors
actor DataCache {
    private var cache: [String: Data] = [:]
    
    func getData(for key: String) -> Data? {
        cache[key]
    }
}
```

#### Sendable Conformance

Mark types as `Sendable` when appropriate:

```swift
// ✅ Good
struct Message: Sendable {
    let id: UUID
    let content: String
    let timestamp: Date
}

protocol ChatRepositoryProtocol: Sendable {
    func fetchMessages() async throws -> [Message]
}
```

### ViewModels

#### Observable Pattern

Always use `@Observable` macro for ViewModels:

```swift
// ✅ Good
@Observable
@MainActor
final class ChatViewModel {
    var messages: [Message] = []
    var isLoading = false
}

// ❌ Bad (outdated pattern)
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
}
```

#### State Management

Keep state properties as `private(set)`:

```swift
// ✅ Good
@Observable
@MainActor
final class ChatViewModel {
    private(set) var messages: [Message] = []
    
    func loadMessages() async throws {
        // Only ViewModel can modify messages
    }
}

// ❌ Bad
@Observable
@MainActor
final class ChatViewModel {
    var messages: [Message] = [] // Can be modified from anywhere
}
```

### Protocols

#### Protocol Naming

- Protocols should describe capabilities or characteristics
- Use `-able` or `-Protocol` suffix when appropriate

```swift
// ✅ Good
protocol Cacheable { }
protocol ChatRepositoryProtocol { }

// ❌ Bad
protocol Chat { }
protocol Repository { }
```

#### Protocol Design

Define focused, single-purpose protocols:

```swift
// ✅ Good
protocol MessageFetchable {
    func fetchMessages() async throws -> [Message]
}

protocol MessagePersistable {
    func saveMessage(_ message: Message) async throws
}

// ❌ Bad
protocol MessageHandler {
    func fetchMessages() async throws -> [Message]
    func saveMessage(_ message: Message) async throws
    func deleteMessage(_ id: UUID) async throws
    func updateMessage(_ message: Message) async throws
    func searchMessages(_ query: String) async throws -> [Message]
}
```

### Documentation

#### Public API Documentation

All public types, methods, and properties should have documentation:

```swift
/// Manages chat messages and user interactions.
///
/// This view model handles loading, sending, and managing chat messages.
/// It coordinates with the chat repository to fetch and persist messages.
@Observable
@MainActor
final class ChatViewModel {
    
    /// Loads messages from the repository.
    ///
    /// This method fetches all available messages and updates the `messages` property.
    /// While loading, the `isLoading` property is set to `true`.
    ///
    /// - Throws: `ChatError` if the messages cannot be loaded.
    func loadMessages() async throws {
        // Implementation
    }
}
```

#### Inline Comments

Use comments sparingly for complex logic:

```swift
// Calculate the weighted average based on user engagement
let weightedScore = messages.reduce(0.0) { total, message in
    let weight = message.reactions.count * 1.5
    return total + (message.score * weight)
} / Double(messages.count)
```

### Code Quality

#### Force Unwrapping

Avoid force unwrapping unless absolutely necessary:

```swift
// ✅ Good
if let message = messages.first {
    process(message)
}

guard let user = currentUser else {
    return
}

// ❌ Bad
let message = messages.first!
process(message)
```

#### Optional Handling

Use optional chaining and nil coalescing:

```swift
// ✅ Good
let userName = user?.profile?.name ?? "Unknown"
user?.profile?.update(name: newName)

// ❌ Bad
var userName = "Unknown"
if user != nil {
    if user!.profile != nil {
        userName = user!.profile!.name
    }
}
```

#### Guard Statements

Use guard for early returns:

```swift
// ✅ Good
func processUser(_ user: User?) {
    guard let user = user else { return }
    guard user.isActive else { return }
    // Process active user
}

// ❌ Bad
func processUser(_ user: User?) {
    if let user = user {
        if user.isActive {
            // Process active user
        }
    }
}
```

### Localization

#### Type-Safe Strings with SwiftGen

All user-facing strings must use SwiftGen's `Strings` enum:

```swift
// ✅ Good
let errorMessage = Strings.Chat.Error.networkFailure

// ❌ Bad
let errorMessage = NSLocalizedString("chat.error.network_failure", comment: "")
let errorMessage = "Network request failed"
```

#### String Keys in Localizable.strings

Use hierarchical keys with dots:

```
chat.error.network_failure
chat.message.sent_confirmation
settings.profile.update_success
```

---

# Testing Strategy

## Swift Testing Framework

Use Swift Testing framework with `@Test` attribute:

```swift
import Testing
@testable import LiveAssistant

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

### Test Naming

- Use descriptive names that explain what is being tested
- Follow pattern: `test[Scenario][ExpectedBehavior]`

```swift
// ✅ Good
@Test func testLoadMessagesWithEmptyRepository() async throws { }
@Test func testSendMessageUpdatesMessagesList() async throws { }
@Test func testLoadMessagesHandlesNetworkError() async throws { }

// ❌ Bad
@Test func test1() async throws { }
@Test func testMessages() async throws { }
```

### Test Structure

Follow Arrange-Act-Assert pattern:

```swift
@Test
func testChatViewModel() async throws {
    // Arrange - Set up test dependencies and state
    let mockRepository = MockChatRepository()
    let viewModel = ChatViewModel(chatRepository: mockRepository)
    
    // Act - Execute the behavior being tested
    try await viewModel.loadMessages()
    
    // Assert - Verify the expected outcome
    #expect(viewModel.messages.count == 2)
    #expect(!viewModel.isLoading)
}
```

### Mocks and Fakes

Create protocol-based mocks for testing:

```swift
final class MockChatRepository: ChatRepositoryProtocol {
    var fetchMessagesCallCount = 0
    var messagesToReturn: [Message] = []
    var errorToThrow: Error?
    
    func fetchMessages() async throws -> [Message] {
        fetchMessagesCallCount += 1
        if let error = errorToThrow {
            throw error
        }
        return messagesToReturn
    }
}
```

## ViewModel Testing

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

## Repository Testing

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

---

# Best Practices

## Do's ✅

- Use `@Observable` and `@MainActor` for ViewModels
- Define protocol-based interfaces for testability
- Use Repository pattern to abstract data sources
- Use async/await for asynchronous operations
- Use SwiftGen for type-safe resources (`Strings`, `Asset`)
- Localize all user-facing strings in `Localizable.strings`
- Handle errors with specific error types
- Inject dependencies via initializers
- Keep Views simple and declarative
- Write tests for ViewModels and Repositories
- Place business logic in Repositories
- Access data through Repositories only

## Don'ts ❌

- Don't access Services directly from ViewModels
- Don't put business logic in Views or Services
- Don't use force unwrapping without explicit justification
- Don't use `@ObservableObject` (use `@Observable` instead)
- Don't use `NSLocalizedString` directly (use `Strings` from SwiftGen)
- Don't hardcode strings or asset/color names
- Don't edit generated files in `Core/Generated/`
- Don't create massive ViewModels (split into smaller ones)
- Don't skip dependency injection
- Don't access SwiftData directly from ViewModels
- Don't mix layer concerns (each layer has its purpose)

## Migration Path

For existing code that doesn't follow this architecture:

1. **Extract business logic** from Views into ViewModels
2. **Create Repository layer** for data access
3. **Move data operations** from ViewModels to Repositories
4. **Define protocols** for Services and Repositories
5. **Set up DI container** and register dependencies
6. **Update ViewModels** to use `@Observable` instead of `@ObservableObject`
7. **Write tests** for new architecture

## Automated Quality Checks

### Tools

- **SwiftLint**: Enforces style rules and best practices
- **swift-format**: Automatically formats code according to Apple's standards
- **Git Hooks**: Runs checks before commits
- **SwiftGen**: Generates type-safe resource accessors

### Running Checks Manually

```bash
# Run SwiftLint
swiftlint lint

# Run swift-format (check mode)
find LiveAssistant -name "*.swift" -not -path "*/Generated/*" -print0 | \
  xargs -0 swift-format lint --strict

# Run swift-format (fix mode)
find LiveAssistant -name "*.swift" -not -path "*/Generated/*" -print0 | \
  xargs -0 swift-format format --in-place

# SwiftGen - Regenerate type-safe resources
swift package --allow-writing-to-package-directory generate-code-for-resources
```

## Code Review Checklist

Before submitting code for review, ensure:

- [ ] All files have correct headers
- [ ] Code follows naming conventions
- [ ] SwiftLint and swift-format pass without errors
- [ ] Public APIs are documented
- [ ] Error handling is implemented
- [ ] All strings are localized using SwiftGen
- [ ] Tests are written and passing (90%+ coverage)
- [ ] No force unwrapping (unless justified)
- [ ] ViewModels use `@Observable` and `@MainActor`
- [ ] Dependencies are injected via protocols
- [ ] Async/await is used for asynchronous operations
- [ ] Business logic is in Repositories, not ViewModels or Views

## Resources

- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [Swinject Documentation](https://github.com/Swinject/Swinject)
- [Swift Testing Documentation](https://developer.apple.com/documentation/testing)
