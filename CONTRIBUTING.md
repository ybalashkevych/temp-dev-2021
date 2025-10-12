# Contributing to LiveAssistant

Thank you for considering contributing to LiveAssistant! This document provides guidelines and best practices for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Architecture Guidelines](#architecture-guidelines)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)
- [Commit Messages](#commit-messages)

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help maintain a positive environment
- Follow professional communication standards

## Getting Started

### Prerequisites

1. macOS 14.0 or later
2. Xcode 16.0.1 or later
3. Swift 6.0
4. SwiftLint: `brew install swiftlint`
5. swift-format: Included with Xcode (`xcrun swift-format --version`)

### Initial Setup

```bash
# Clone the repository
git clone <repository-url>
cd LiveAssistant

# Set up git hooks
./scripts/setup-git-hooks.sh

# Open in Xcode
open LiveAssistant.xcodeproj
```

## Development Workflow

### 1. Create a Feature Branch

```bash
# Create and checkout a new branch
git checkout -b feature/your-feature-name

# Or for bug fixes
git checkout -b bugfix/issue-description
```

### 2. Make Your Changes

- Follow the [ARCHITECTURE.md](./ARCHITECTURE.md) guidelines
- Adhere to [CODING_STANDARDS.md](./CODING_STANDARDS.md)
- Write tests for new functionality
- Update documentation as needed

### 3. Test Your Changes

```bash
# Run tests
xcodebuild test -scheme LiveAssistant -destination 'platform=macOS'

# Or in Xcode: Cmd + U
```

### 4. Code Quality Checks

```bash
# Run SwiftLint
swiftlint lint

# Run swift-format check
swift-format lint --strict --recursive .

# Auto-fix formatting issues
swift-format format --in-place --recursive .
```

### 5. Commit Your Changes

```bash
# Stage your changes
git add .

# Commit (pre-commit hooks will run automatically)
git commit -m "feat: add new feature description"
```

### 6. Push and Create PR

```bash
# Push to your branch
git push origin feature/your-feature-name

# Create a Pull Request on GitHub
```

## Architecture Guidelines

### MVVM Pattern

All features must follow the MVVM architecture:

```
View → ViewModel → Repository → Service
```

### Adding a New Feature

1. **Create Feature Directory Structure**

```bash
Features/
└── YourFeature/
    ├── Views/
    │   └── YourFeatureView.swift
    ├── ViewModels/
    │   └── YourFeatureViewModel.swift
    └── Components/
        └── YourFeatureComponent.swift
```

2. **Create Repository (if needed)**

```swift
// Protocol
protocol YourFeatureRepositoryProtocol: Sendable {
    func fetchData() async throws -> Data
}

// Implementation
final class YourFeatureRepository: YourFeatureRepositoryProtocol {
    // Implementation
}
```

3. **Create ViewModel**

```swift
@Observable
@MainActor
final class YourFeatureViewModel {
    private let repository: YourFeatureRepositoryProtocol
    private(set) var state: State = .idle
    
    init(repository: YourFeatureRepositoryProtocol) {
        self.repository = repository
    }
}
```

4. **Register in DI Container**

Update `AppComponent.swift`:

```swift
private func registerRepositories() {
    container.register(YourFeatureRepositoryProtocol.self) { resolver in
        YourFeatureRepository(/* dependencies */)
    }
}

private func registerViewModels() {
    container.register(YourFeatureViewModel.self) { resolver in
        guard let repository = resolver.resolve(YourFeatureRepositoryProtocol.self) else {
            fatalError("YourFeatureRepositoryProtocol not registered in DI container")
        }
        return YourFeatureViewModel(repository: repository)
    }
}
```

5. **Write Tests**

```swift
import Testing
@testable import LiveAssistant

@Test
func testYourFeature() async throws {
    // Arrange
    let mockRepo = MockYourFeatureRepository()
    let viewModel = YourFeatureViewModel(repository: mockRepo)
    
    // Act
    await viewModel.performAction()
    
    // Assert
    #expect(viewModel.state == .expected)
}
```

## Coding Standards

### File Headers

Every Swift file must have a proper header:

```swift
//
//  FileName.swift
//  LiveAssistant
//
//  Created by [Your Name] on [Date].
//  Copyright © 2025 [Company]. All rights reserved.
//
```

### ViewModels

- Use `@Observable` macro
- Use `@MainActor` for UI-related ViewModels
- Keep state as `private(set)`
- Inject dependencies via protocols

```swift
@Observable
@MainActor
final class MyViewModel {
    private let repository: MyRepositoryProtocol
    private(set) var items: [Item] = []
    private(set) var isLoading = false
    
    init(repository: MyRepositoryProtocol) {
        self.repository = repository
    }
}
```

### Error Handling

- Use specific error types
- Provide localized error messages
- Handle errors gracefully

```swift
enum MyFeatureError: LocalizedError {
    case fetchFailed
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .fetchFailed:
            return NSLocalizedString("my_feature.error.fetch_failed", comment: "")
        case .saveFailed:
            return NSLocalizedString("my_feature.error.save_failed", comment: "")
        }
    }
}
```

### Localization

All user-facing strings must be localized:

```swift
// ✅ Good
let message = NSLocalizedString("key", comment: "Description")

// ❌ Bad
let message = "Hardcoded string"
```

## Testing

### Test Requirements

- All new features must have tests
- Use Swift Testing framework (`@Test` attribute)
- Follow Arrange-Act-Assert pattern
- Test success and failure cases
- Use mock dependencies

### Example Test

```swift
import Testing
@testable import LiveAssistant

@MainActor
struct MyFeatureTests {
    @Test
    func testSuccessfulOperation() async throws {
        // Arrange
        let mockRepo = MockRepository()
        let viewModel = MyViewModel(repository: mockRepo)
        
        // Act
        await viewModel.performAction()
        
        // Assert
        #expect(viewModel.state == .success)
    }
    
    @Test
    func testFailedOperation() async throws {
        // Arrange
        let mockRepo = MockRepository()
        mockRepo.errorToThrow = MyError.failed
        let viewModel = MyViewModel(repository: mockRepo)
        
        // Act
        await viewModel.performAction()
        
        // Assert
        #expect(viewModel.error != nil)
    }
}
```

## Pull Request Process

### Before Submitting

- [ ] Code follows MVVM architecture
- [ ] All tests pass
- [ ] SwiftLint passes without errors
- [ ] swift-format applied
- [ ] Documentation updated
- [ ] File headers present
- [ ] No force unwrapping (unless justified)
- [ ] Strings localized
- [ ] Self-review completed

### PR Description

Use the PR template and include:

1. **Description**: What changes were made and why
2. **Related Issues**: Link to relevant issues
3. **Testing**: How the changes were tested
4. **Screenshots**: For UI changes
5. **Notes**: Any special considerations for reviewers

### Review Process

1. Submit PR with complete description
2. Address CI/CD failures (if any)
3. Respond to reviewer comments
4. Make requested changes
5. Get approval from at least one reviewer
6. Merge after approval

### After Merge

- Delete your feature branch
- Update your local main branch
- Close related issues

## Commit Messages

### Format

```
type(scope): subject

body (optional)

footer (optional)
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

### Examples

```bash
feat(chat): add message deletion functionality

fix(transcription): resolve audio input initialization issue

docs(readme): update setup instructions

refactor(repository): simplify error handling logic

test(viewmodel): add tests for edge cases
```

## Questions?

If you have questions:

1. Check [ARCHITECTURE.md](./ARCHITECTURE.md) and [CODING_STANDARDS.md](./CODING_STANDARDS.md)
2. Search existing issues and discussions
3. Ask in the team chat
4. Create a discussion on GitHub

## Thank You!

Your contributions make this project better. Thank you for taking the time to contribute! 🎉


