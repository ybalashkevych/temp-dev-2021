# Coding Standards

## Overview

This document outlines the coding standards for the LiveAssistant project. These standards ensure code quality, consistency, and maintainability across the codebase.

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

```swift
// ✅ Good
func methodOne() {
    // Implementation
}

func methodTwo() {
    // Implementation
}

// ❌ Bad
func methodOne() {
    // Implementation
}


func methodTwo() {
    // Implementation
}
```

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

### Error Handling

#### Custom Error Types

Define specific error types with localized descriptions:

```swift
enum ChatError: LocalizedError {
    case networkFailure
    case invalidResponse
    case unauthorized(message: String)
    
    var errorDescription: String? {
        switch self {
        case .networkFailure:
            return NSLocalizedString("chat.error.network_failure", comment: "Network connection failed")
        case .invalidResponse:
            return NSLocalizedString("chat.error.invalid_response", comment: "Server returned invalid response")
        case .unauthorized(let message):
            return String(format: NSLocalizedString("chat.error.unauthorized", comment: ""), message)
        }
    }
}
```

#### Error Handling Pattern

Use `async throws` for error propagation:

```swift
// ✅ Good
func loadMessages() async {
    do {
        isLoading = true
        messages = try await repository.fetchMessages()
    } catch let error as ChatError {
        handleChatError(error)
    } catch {
        handleGenericError(error)
    }
    isLoading = false
}

// ❌ Bad
func loadMessages() async {
    isLoading = true
    messages = try! await repository.fetchMessages() // Force try!
    isLoading = false
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

## Testing Standards

### Swift Testing Framework

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

## Code Quality

### Force Unwrapping

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

### Optional Handling

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

### Guard Statements

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

## Localization

### Localizable Strings

All user-facing strings must be localized:

```swift
// ✅ Good
let errorMessage = NSLocalizedString(
    "chat.error.network_failure",
    comment: "Error message when network request fails"
)

// ❌ Bad
let errorMessage = "Network request failed"
```

### String Keys

Use hierarchical keys with dots:

```
chat.error.network_failure
chat.message.sent_confirmation
settings.profile.update_success
```

## Code Review Checklist

Before submitting code for review, ensure:

- [ ] All files have correct headers
- [ ] Code follows naming conventions
- [ ] SwiftLint and SwiftFormat pass without errors
- [ ] Public APIs are documented
- [ ] Error handling is implemented
- [ ] All strings are localized
- [ ] Tests are written and passing
- [ ] No force unwrapping (unless justified)
- [ ] ViewModels use `@Observable` and `@MainActor`
- [ ] Dependencies are injected via protocols
- [ ] Async/await is used for asynchronous operations

## Tools

### Automated Checks

- **SwiftLint**: Enforces style rules and best practices
- **swift-format**: Automatically formats code according to Apple's standards
- **Git Hooks**: Runs checks before commits

### Running Checks Manually

```bash
# Run SwiftLint
swiftlint lint

# Run swift-format (check mode)
swift-format lint --strict --recursive .

# Run swift-format (fix mode)
swift-format format --in-place --recursive .
```

## Resources

- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [Swift Style Guide by Google](https://google.github.io/swift/)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [Swift Testing Documentation](https://developer.apple.com/documentation/testing)


