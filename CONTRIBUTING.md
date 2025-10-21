# Contributing to LiveAssistant

This document provides comprehensive guidelines for contributing to LiveAssistant, including development workflow, coding standards, and pull request processes.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Architecture Guidelines](#architecture-guidelines)
- [Pull Request Process](#pull-request-process)
- [Automated Workflow](#automated-workflow)
- [Scripts Reference](#scripts-reference)
- [Troubleshooting](#troubleshooting)

---

# Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help maintain a positive environment
- Follow professional communication standards

---

# Getting Started

## Prerequisites

1. **macOS** 14.0 or later
2. **Xcode** 16.0.1 or later
3. **Swift** 6.0
4. **SwiftLint**: `brew install swiftlint`
5. **swift-format**: Included with Xcode (`xcrun swift-format --version`)
6. **GitHub CLI**: `brew install gh` (for automation)

## Initial Setup

```bash
# Clone the repository
git clone <repository-url>
cd LiveAssistant

# Install development tools
brew install gh swiftlint

# Authenticate GitHub CLI
gh auth login

# Set up git hooks
./scripts/setup.sh install

# Verify setup
swiftlint --version
gh auth status
xcodebuild -version

# Open in Xcode
open LiveAssistant.xcodeproj
```

## Verify Setup

Ensure all required tools are installed and configured:

```bash
# Check SwiftLint
swiftlint --version

# Check GitHub CLI authentication
gh auth status

# Check Xcode
xcodebuild -version
```

---

# Development Workflow

## Quick Overview

The LiveAssistant project uses a fully automated development workflow:

- **Issue-driven development** - All work starts from GitHub Issues
- **Automated quality checks** - CI/CD via GitHub Actions
- **Code coverage tracking** - Minimum 20% coverage required
- **Conventional commits** - Consistent PR formatting
- **Self-review process** - Comprehensive checks before PR creation
- **Mobile-friendly** - Review and manage from anywhere

## Workflow Steps

### 1. Create an Issue

Issues can be created from:
- GitHub web interface
- GitHub mobile app
- GitHub CLI: `gh issue create`

Choose the appropriate template:
- 🐛 **Bug Report** - For bugs and unexpected behavior
- ✨ **Feature Request** - For new features
- 🔨 **Code Improvement** - For refactoring and optimization

### 2. Create a Feature Branch

```bash
# Create and checkout a new branch
git checkout -b <type>/issue-<number>-<description>

# Examples:
git checkout -b feat/issue-42-dark-mode
git checkout -b fix/issue-15-audio-leak
git checkout -b refactor/issue-23-simplify-repo
```

### 3. Implement Changes

- Follow the [ARCHITECTURE.md](./ARCHITECTURE.md) guidelines
- Write tests for new functionality
- Ensure 20%+ code coverage
- Update documentation as needed
- Use type-safe resources (SwiftGen's `Strings` and `Asset`)

#### Example Implementation Flow:

**Create Feature Directory:**
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

**Create Repository:**
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

**Create ViewModel:**
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

**Register in DI Container (`AppComponent.swift`):**
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

**Write Tests:**
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

### 4. Run Self-Review

Before creating a PR, run comprehensive quality checks:

```bash
# SwiftLint (strict mode - zero warnings)
swiftlint lint --strict

# swift-format validation
find LiveAssistant -name "*.swift" -not -path "*/Generated/*" -exec swift-format lint --strict {} +

# Build verification
xcodebuild -scheme LiveAssistant -destination 'platform=macOS' clean build

# Run all tests
xcodebuild test -scheme LiveAssistant -destination 'platform=macOS'

# Check coverage (must be >= 20%)
xcodebuild test -scheme LiveAssistant -destination 'platform=macOS' -enableCodeCoverage YES
```

### 5. Create Pull Request

Use GitHub CLI with conventional commit format:

```bash
gh pr create --title "<title>" --body "<body>"

# Example:
gh pr create \
  --title "#42: (feat): Add dark mode support" \
  --body "Implements dark mode with system preference support..."

# Or use interactive mode
gh pr create --web
```

**PR Title Format:**
```
#<issue-number>: (<type>): <description>
```

**Types:**
- `feat` - New feature
- `fix` - Bug fix
- `refactor` - Code restructuring
- `test` - Add/update tests
- `docs` - Documentation
- `chore` - Maintenance
- `perf` - Performance
- `style` - Code style

### 6. Automated CI Checks

GitHub Actions automatically runs optimized workflows:

**PR Checks Workflow:**

**Job 1 - Code Quality:**
- SwiftLint strict validation (zero warnings)
- swift-format validation
- Upload lint results

**Job 2 - Build** (depends on Job 1):
- Build with artifact caching
- **Skipped if lint fails** (fail-fast)

**Job 3 - Tests & Coverage** (depends on Job 2):
- Download build artifacts (no rebuild!)
- Run tests with coverage
- Calculate coverage (20% minimum)
- Post combined comment with all results
- **Skipped if build fails** (fail-fast)

**Performance:** ~66% reduction in build time (1 build instead of 3)

All checks must pass before merge.

### 7. Review & Feedback

**From Web/Mobile:**
1. Open PR on GitHub
2. Review changes
3. Check CI status
4. Leave comments for changes needed
5. Approve when satisfied

**Responding to feedback:**
1. Read review comments
2. Make requested changes
3. Run quality checks again: `swiftlint lint --strict && xcodebuild test -scheme LiveAssistant`
4. Push updates
5. Respond to PR comments on GitHub

### 8. Merge

Once approved and all checks pass:

```bash
gh pr merge <pr-number>

# Or merge via GitHub UI
```

**What happens:**
- ✅ Verifies approval
- ✅ Checks CI status
- ✅ Merges using rebase and squash
- ✅ Deletes branch automatically
- ✅ Closes linked issues
- ✅ Updates project board

### 9. After Merge

- Delete your feature branch (done automatically)
- Update your local main branch:
  ```bash
  git checkout main
  git pull origin main
  ```
- Close related issues (done automatically if "Closes #X" in PR)

---

# Architecture Guidelines

All code must follow MVVM architecture with clear separation of concerns.

## Layer Rules

### ViewModels
- ✅ Use `@Observable` and `@MainActor`
- ✅ Access data through Repositories only (never Services)
- ✅ Protocol-based dependency injection
- ✅ Variable name must be `vm`
- ✅ State properties as `private(set)`

### Repositories
- ✅ Protocol-based interfaces
- ✅ Business logic lives here
- ✅ Coordinate multiple services
- ✅ Abstract data sources

### Services
- ✅ Protocol-based interfaces
- ✅ Handle external interactions only
- ✅ No business logic

### Code Quality
- ✅ SwiftLint passes (strict, zero warnings)
- ✅ swift-format validation passes
- ✅ All strings use `Strings` enum (SwiftGen)
- ✅ All assets use `Asset` enum (SwiftGen)
- ✅ No force unwraps without justification

### Testing
- ✅ Swift Testing framework (`@Test`)
- ✅ 20%+ code coverage
- ✅ Mock dependencies using protocols
- ✅ Test both success and failure cases

For detailed architecture documentation, see [ARCHITECTURE.md](./ARCHITECTURE.md).

---

# Pull Request Process

## Before Submitting

- [ ] Code follows MVVM architecture
- [ ] All tests pass
- [ ] SwiftLint passes without errors
- [ ] swift-format applied
- [ ] Documentation updated
- [ ] File headers present
- [ ] No force unwrapping (unless justified)
- [ ] Strings localized using SwiftGen
- [ ] Self-review completed
- [ ] Coverage >= 20%

## PR Description

Use the PR template and include:

1. **Description**: What changes were made and why
2. **Related Issues**: Link using "Closes #X"
3. **Testing**: How the changes were tested
4. **Screenshots**: For UI changes
5. **Notes**: Any special considerations for reviewers

## Review Process

1. Submit PR with complete description
2. Address CI/CD failures (if any)
3. Respond to reviewer comments
4. Make requested changes
5. Run self-review again
6. Get approval from at least one reviewer
7. Merge using script

## Commit Message Format

```
type(scope): subject

body (optional)

footer (optional)
```

**Examples:**
```bash
feat(chat): add message deletion functionality

fix(transcription): resolve audio input initialization issue

docs(readme): update setup instructions

refactor(repository): simplify error handling logic

test(viewmodel): add tests for edge cases
```

---

# Automated Workflow

## Mobile-Friendly Development

### From Mobile Device

1. **Create issue** - Use GitHub mobile app
2. **Review PR** - Check changes, CI status
3. **Request changes** - Leave review comments
4. **Approve** - Once satisfied
5. **Merge** - Can be done from mobile or via comments

### GitHub.dev (Web Editor)

Access from any browser:
1. Navigate to repository on GitHub
2. Press `.` key
3. Full VSCode experience in browser
4. Make small edits, commits

## Release Process

### Creating a Release

1. **Trigger release workflow**:
   ```bash
   gh workflow run release.yml -f version=1.2.0
   ```

2. **What happens automatically**:
   - Updates version in `Info.plist`
   - Commits version change
   - Runs tests
   - Builds release archive
   - Generates release notes from commits
   - Creates Git tag
   - Creates GitHub release
   - Uploads build artifacts

3. **Release notes** are automatically generated by commit type:
   - 🎉 Features (feat)
   - 🐛 Bug Fixes (fix)
   - 🔨 Refactoring (refactor)
   - 📝 Documentation (docs)
   - ⚡️ Performance (perf)
   - 🧪 Tests (test)
   - 🔧 Chores (chore)

## Project Board

The GitHub Project board tracks issue status:

| Column | Description |
|--------|-------------|
| **Backlog** | New issues, not yet groomed |
| **Ready** | Groomed and ready for work |
| **In Progress** | Currently being worked on |
| **In Review** | PR created, awaiting review |
| **Done** | Merged and closed |

Automation rules:
- New issue → Backlog
- Issue assigned → Ready
- PR created → In Review
- PR merged → Done

---

# Scripts Reference

## setup.sh

Setup and configuration tool.

**Install (first time):**
```bash
./scripts/setup.sh install
```

Installs:
- Git hooks
- Development dependencies
- Configures environment

**Update (after changes):**
```bash
./scripts/setup.sh update
```

Updates:
- Git hooks
- Dependencies
- Configuration files

---

# Troubleshooting

## GitHub CLI Not Authenticated

```bash
gh auth status
gh auth login
```

## SwiftLint Failures

```bash
# View violations
swiftlint lint

# Auto-fix
swiftlint --fix

# Verify
swiftlint lint --strict
```

## swift-format Failures

```bash
# Fix all files (excludes Generated/)
find LiveAssistant -name "*.swift" -not -path "*/Generated/*" -print0 | \
  xargs -0 swift-format format --in-place

# Verify
find LiveAssistant -name "*.swift" -not -path "*/Generated/*" -print0 | \
  xargs -0 swift-format lint --strict
```

## Tests Failing

```bash
# Run all tests
xcodebuild test -scheme LiveAssistant -testPlan LiveAssistant

# Run specific test
xcodebuild test -scheme LiveAssistant \
  -only-testing:LiveAssistantTests/TestClass/testMethod
```

## Coverage Below Threshold

```bash
# Run tests with coverage
xcodebuild test -scheme LiveAssistant -destination 'platform=macOS' -enableCodeCoverage YES

# Focus on adding tests for:
# - ViewModels (highest priority)
# - Repositories
# - Services
# - Utilities

# Views and Components are excluded from coverage requirements
```

## Build Failures

```bash
# Clean build
xcodebuild clean -scheme LiveAssistant

# Rebuild
xcodebuild build -scheme LiveAssistant

# Check for:
# - Syntax errors
# - Missing imports
# - Type mismatches
# - Unresolved dependencies
```

## PR Can't Be Created

```bash
# Ensure branch is pushed
git push origin <branch-name>

# Verify gh is authenticated
gh auth status

# Try creating PR via GitHub CLI
gh pr create --web
```

---

# Best Practices

## For Contributors

- ✅ Always run self-review before creating PR
- ✅ Use conventional commit format in PR titles
- ✅ Link issues using "Closes #X"
- ✅ Keep PRs focused and single-purpose
- ✅ Write meaningful commit messages
- ✅ Update documentation when needed
- ✅ Respond to review feedback promptly

## For Reviewers

- ✅ Review from mobile when convenient
- ✅ Provide specific, actionable feedback
- ✅ Check architecture compliance
- ✅ Verify test coverage
- ✅ Approve when ready

## For Everyone

- ✅ Start with an issue
- ✅ Use descriptive branch names
- ✅ Keep commits atomic and logical
- ✅ Follow the architecture patterns
- ✅ Write tests for all new code

---

# Resources

- [ARCHITECTURE.md](ARCHITECTURE.md) - Architecture patterns and coding standards
- [CHANGELOG.md](CHANGELOG.md) - Project changelog
- [CONTRIBUTING.md](CONTRIBUTING.md) - This file - contributing guidelines
- [.cursor/rules/workflow-automation.mdc](.cursor/rules/workflow-automation.mdc) - Cursor automation rules
- [GitHub Actions](.github/workflows/) - CI/CD workflows
- [Scripts](scripts/) - Automation scripts

---

# Support

For questions or issues:

1. Check this document
2. Review [ARCHITECTURE.md](./ARCHITECTURE.md) and [CONTRIBUTING.md](./CONTRIBUTING.md)
3. Search existing issues
5. Create a new issue with details

---

# Thank You!

Your contributions make this project better. Thank you for taking the time to contribute! 🎉
