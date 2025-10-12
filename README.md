# LiveAssistant

A macOS application that provides real-time transcription during job interviews, meetings, and calls with AI-powered assistance for communication.

## 🏗️ Architecture

LiveAssistant follows a **modular MVVM architecture** with clear separation of concerns:

- **View Layer**: SwiftUI views that observe ViewModels
- **ViewModel Layer**: `@Observable` `@MainActor` classes handling presentation logic
- **Repository Layer**: Protocol-based data abstraction
- **Service Layer**: External integrations (API, SwiftData, AI services)

### Key Principles

- ✅ Dependency Injection using **Swinject**
- ✅ Repository pattern for data access
- ✅ Protocol-based design for testability
- ✅ Swift 6 concurrency with async/await
- ✅ SwiftData for local persistence
- ✅ Type-safe resources with **SwiftGen**

See [ARCHITECTURE.md](./ARCHITECTURE.md) for detailed documentation.

## 📋 Requirements

- **macOS**: 14.0 or later
- **Xcode**: 16.0.1 or later
- **Swift**: 6.0

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone <repository-url>
cd LiveAssistant
```

### 2. Install Dependencies

The project uses Swift Package Manager for dependencies:

```bash
# Dependencies will be resolved automatically when you open the project in Xcode
open LiveAssistant.xcodeproj
```

### 3. Install Development Tools

#### SwiftLint (Required)

```bash
# Using Homebrew
brew install swiftlint

# Or using Mint
mint install realm/SwiftLint
```

#### swift-format (Apple's Formatter - Required)

swift-format is included with Xcode's toolchain. To verify or install:

```bash
# Verify it's available (included with Xcode)
xcrun swift-format --version

# Optional: Install standalone via Homebrew
brew install swift-format
```

### 4. Set Up Git Hooks

Run the setup script to install git hooks for automatic code quality checks:

```bash
./scripts/setup-git-hooks.sh
```

This will:
- Install pre-commit hooks for SwiftLint and swift-format
- Ensure code quality checks run before each commit
- Validate file headers

### 5. Build and Run

1. Open `LiveAssistant.xcodeproj` in Xcode
2. Select your target device/simulator
3. Press `Cmd + R` to build and run

## 📁 Project Structure

```
LiveAssistant/
├── App/                          # Application entry point
│   ├── LiveAssistantApp.swift    # App definition
│   └── DI/                       # Dependency injection
│       └── AppComponent.swift    # Swinject container
│
├── Core/                         # Core business logic
│   ├── Models/                   # Domain models (SwiftData)
│   ├── Services/                 # Service protocols & implementations
│   │   ├── Protocols/
│   │   └── Implementations/
│   ├── Repositories/             # Repository layer
│   │   ├── Protocols/
│   │   └── Implementations/
│   ├── Generated/                # Auto-generated code (SwiftGen)
│   │   ├── Strings.swift         # Type-safe localized strings
│   │   └── Assets.swift          # Type-safe assets
│   └── Utilities/                # Helpers and extensions
│
├── Features/                     # Feature modules
│   ├── Chat/                     # Chat feature
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Components/
│   ├── Transcription/            # Real-time transcription
│   └── Settings/                 # Settings
│
└── Resources/                    # Assets and localization
    ├── Assets.xcassets/
    └── Localizable.strings
```

## 🧪 Testing

The project uses **Swift Testing framework** for all tests.

### Running Tests

```bash
# Run all tests
xcodebuild test -scheme LiveAssistant -destination 'platform=macOS'

# Or use Xcode: Cmd + U
```

### Writing Tests

```swift
import Testing
@testable import LiveAssistant

@Test
func testMyFeature() async throws {
    // Arrange
    let mockRepo = MockRepository()
    let viewModel = MyViewModel(repository: mockRepo)
    
    // Act
    await viewModel.performAction()
    
    // Assert
    #expect(viewModel.state == .expected)
}
```

See [CODING_STANDARDS.md](./CODING_STANDARDS.md) for testing guidelines.

## 🛠️ Development

### Code Quality

The project enforces code quality through:

1. **SwiftLint**: Style and convention enforcement
2. **swift-format**: Automatic code formatting (Apple's official formatter)
3. **Git Hooks**: Pre-commit checks
4. **Code Review**: PR template with quality checklist

### Running Quality Checks Manually

```bash
# SwiftLint (automatically excludes Generated/ via .swiftlint.yml)
swiftlint lint

# swift-format (check mode) - excludes SwiftGen generated files
find LiveAssistant -name "*.swift" -not -path "*/Generated/*" -print0 | xargs -0 swift-format lint --strict

# swift-format (fix mode) - excludes SwiftGen generated files
find LiveAssistant -name "*.swift" -not -path "*/Generated/*" -print0 | xargs -0 swift-format format --in-place

# SwiftGen - Regenerate type-safe resources
swift package --allow-writing-to-package-directory generate-code-for-resources
```

### Coding Standards

- Follow [CODING_STANDARDS.md](./CODING_STANDARDS.md)
- Use `@Observable` and `@MainActor` for ViewModels
- Inject dependencies via protocols
- Use SwiftGen for type-safe resource access (`Strings`, `Asset`)
- Localize all user-facing strings
- Document public APIs
- Write tests for new features

### File Headers

All Swift files must include:

```swift
//
//  FileName.swift
//  LiveAssistant
//
//  Created by [Author] on [Date].
//  Copyright © 2025 [Company]. All rights reserved.
//
```

## 🏛️ Architecture Guidelines

### ViewModels

```swift
@Observable
@MainActor
final class MyViewModel {
    private let repository: MyRepositoryProtocol
    private(set) var state: State = .idle
    
    init(repository: MyRepositoryProtocol) {
        self.repository = repository
    }
    
    func loadData() async throws {
        state = .loading
        let data = try await repository.fetchData()
        state = .loaded(data)
    }
}
```

### Repositories

```swift
protocol MyRepositoryProtocol: Sendable {
    func fetchData() async throws -> Data
}

final class MyRepository: MyRepositoryProtocol {
    private let apiService: APIServiceProtocol
    private let storageService: StorageServiceProtocol
    
    init(apiService: APIServiceProtocol, storageService: StorageServiceProtocol) {
        self.apiService = apiService
        self.storageService = storageService
    }
    
    func fetchData() async throws -> Data {
        // Implementation
    }
}
```

### Dependency Injection

Register dependencies in `AppComponent.swift`:

```swift
private func registerRepositories() {
    container.register(MyRepositoryProtocol.self) { resolver in
        guard let apiService = resolver.resolve(APIServiceProtocol.self),
              let storageService = resolver.resolve(StorageServiceProtocol.self) else {
            fatalError("Required dependencies not registered in DI container")
        }
        return MyRepository(
            apiService: apiService,
            storageService: storageService
        )
    }
}
```

## 📚 Documentation

- [ARCHITECTURE.md](./ARCHITECTURE.md) - Detailed architecture documentation
- [CODING_STANDARDS.md](./CODING_STANDARDS.md) - Coding standards and best practices
- [SWIFTGEN.md](./SWIFTGEN.md) - SwiftGen integration and usage guide
- [CONTRIBUTING.md](./CONTRIBUTING.md) - Contributing guidelines
- `.ai/instructions.md` - Project rules for AI assistants

## 🤝 Contributing

### Pull Request Process

1. Create a feature branch from `main`
2. Make your changes following coding standards
3. Write/update tests
4. Ensure all checks pass (SwiftLint, SwiftFormat, tests)
5. Submit a PR using the provided template
6. Address review feedback

### PR Checklist

- [ ] Code follows MVVM architecture
- [ ] SwiftLint and swift-format pass
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] File headers present
- [ ] No force unwrapping
- [ ] Strings localized

## 📦 Dependencies

- [Swinject](https://github.com/Swinject/Swinject) - Dependency injection framework
- [SwiftGenPlugin](https://github.com/SwiftGen/SwiftGenPlugin) - Type-safe resource access

See [Package.swift](./Package.swift) for the complete list.

## 🔧 Configuration

### SwiftLint

Configuration: `.swiftlint.yml`

Key rules:
- Line length: 140 (warning), 150 (error)
- Function parameters: 6 (warning), 9 (error)
- File headers required

### swift-format

Configuration: `.swift-format`

Key settings:
- Indentation: 4 spaces
- Max line length: 140 characters
- Swift 6 compatible
- Ordered imports enabled

## 🐛 Troubleshooting

### Build Issues

**Problem**: Xcode can't find dependencies
```bash
# Solution: Clean and rebuild
rm -rf .build
xcodebuild clean
```

**Problem**: SwiftLint warnings/errors
```bash
# Solution: Run swift-format to auto-fix
swift-format format --in-place --recursive .
```

### Testing Issues

**Problem**: Tests fail to compile
```bash
# Solution: Ensure test target has access to main target
# Check target membership in Xcode
```

## 📄 License

Copyright © 2025. All rights reserved.

## 👥 Team

- Yurii Balashkevych - Initial work

## 📞 Support

For questions or issues, please:
1. Check existing documentation
2. Search closed issues
3. Create a new issue with detailed information

---

**Happy Coding! 🚀**


