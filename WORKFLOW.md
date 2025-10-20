# Development Workflow

This document describes the standard development workflow for LiveAssistant. Follow these steps when working on issues, creating features, or fixing bugs.

## Table of Contents

- [Quick Reference](#quick-reference)
- [Branch Naming](#branch-naming)
- [Development Process](#development-process)
- [Commit Conventions](#commit-conventions)
- [Pull Request Process](#pull-request-process)
- [Code Review](#code-review)
- [Common Scenarios](#common-scenarios)
- [Troubleshooting](#troubleshooting)

## Quick Reference

```bash
# 1. Create branch from main
git checkout main
git pull origin main
git checkout -b feat/issue-42-dark-mode

# 2. Make changes and commit
git add .
git commit -m "feat: add dark mode support"

# 3. Run quality checks
swiftlint
xcodebuild test -scheme LiveAssistant

# 4. Push and create PR
git push origin feat/issue-42-dark-mode
gh pr create --title "feat: add dark mode support" --body "Description..."

# 5. After approval, merge via GitHub UI
```

## Background Monitoring (Optional)

For automatic PR monitoring, run the cursor daemon (Python implementation):

```bash
# Start the daemon
cd scripts/automation
cursor-daemon daemon

# Or with custom settings
cursor-daemon daemon --poll-interval 30 --log-file logs/daemon.log
```

The daemon will:
- Check for new PR comments every 60 seconds
- Post analysis as @ybalashkevych
- Wait for `@ybalashkevych implement` or `@ybalashkevych plan` commands

**Legacy Bash Version** (deprecated):
```bash
./scripts/daemon-control.sh start
```

See [scripts/automation/README.md](scripts/automation/README.md) for full automation documentation.
- Execute implementation when requested

**Control commands:**
```bash
./scripts/daemon-control.sh status   # Check if running
./scripts/daemon-control.sh stop     # Stop the daemon
./scripts/daemon-control.sh restart  # Restart the daemon
tail -f logs/cursor-daemon.log       # View logs
```

## Branch Naming

Use this format for all feature branches:

```
<type>/issue-<number>-<short-description>
```

### Types

- `feat` - New feature
- `fix` - Bug fix
- `refactor` - Code restructuring without behavior change
- `test` - Adding or updating tests
- `docs` - Documentation only
- `chore` - Maintenance tasks (dependencies, configs)
- `perf` - Performance improvements
- `style` - Code style changes (formatting, etc.)

### Examples

```
feat/issue-42-dark-mode-support
fix/issue-15-audio-buffer-leak
refactor/issue-23-repository-cleanup
test/issue-8-viewmodel-coverage
docs/issue-19-architecture-guide
```

## Development Process

### 1. Pick an Issue

1. Find an issue assigned to you or claim an unassigned one
2. Read the issue description and all comments thoroughly
3. Ask clarifying questions if needed
4. Check for related issues or dependencies

### 2. Create Branch

```bash
# Always start from updated main
git checkout main
git pull origin main

# Create your feature branch
git checkout -b <type>/issue-<number>-<description>
```

### 3. Implement Changes

Follow these principles:

#### Architecture Compliance

✅ **ViewModels:**
- Use `@Observable` and `@MainActor` macros
- Access data through Repositories only (never Services directly)
- Keep state properties as `private(set)`
- Use `vm` for ViewModel variable names

✅ **Repositories:**
- Define protocol-based interfaces
- Place business logic here
- Coordinate between multiple Services
- Transform service data to domain models

✅ **Services:**
- Handle external interactions only (API, SwiftData, system)
- No business logic
- Protocol-based for testability

✅ **Code Quality:**
- All user-facing strings use SwiftGen's `Strings` enum
- All assets use SwiftGen's `Asset` enum
- No force unwraps without justification
- Functions under 60 lines (warning) / 100 lines (error)
- Type bodies under 300 lines (warning) / 400 lines (error)

See [ARCHITECTURE.md](ARCHITECTURE.md) for complete architecture guidelines.

#### Localization

All user-facing text must be localized:

```swift
// ❌ DON'T hardcode strings
Text("Welcome to the app")

// ✅ DO use Strings enum
Text(Strings.Welcome.title)
```

1. Add strings to `LiveAssistant/Resources/Localizable.strings`
2. Use descriptive keys: `"Feature.Context.specificMessage"`
3. Run SwiftGen: `swiftgen` (generates `Strings.swift`)

#### Testing

Write tests as you develop:

```swift
import Testing

@Test
func testLoadMessages() async throws {
    // Arrange
    let mockRepo = MockChatRepository()
    let vm = ChatViewModel(chatRepository: mockRepo)
    
    // Act
    try await vm.loadMessages()
    
    // Assert
    #expect(vm.messages.count == 2)
    #expect(vm.isLoading == false)
}
```

- Test ViewModels with mock Repositories
- Test Repositories with mock Services
- Use Swift Testing framework (`@Test`, `import Testing`)
- Test both success and failure cases
- Aim for 20%+ code coverage

### 4. Self-Review Checklist

Before creating a PR, verify:

#### ✅ Architecture
- [ ] No ViewModels accessing Services directly
- [ ] All dependencies protocol-based and injected
- [ ] Business logic in Repositories, not Services or Views
- [ ] Proper layer separation

#### ✅ Code Quality
- [ ] SwiftLint passes: `swiftlint`
- [ ] swift-format passes: `xcrun swift-format lint --recursive LiveAssistant`
- [ ] No force unwraps without justification
- [ ] No hardcoded strings (all using `Strings`)
- [ ] No hardcoded colors/assets (all using `Asset`)

#### ✅ Testing
- [ ] All tests pass: `xcodebuild test -scheme LiveAssistant`
- [ ] New code has test coverage
- [ ] Mock implementations for protocols
- [ ] Both success and failure cases tested

#### ✅ Documentation
- [ ] Complex logic has comments
- [ ] Public interfaces documented
- [ ] README updated if needed
- [ ] ARCHITECTURE.md updated if patterns changed

#### ✅ Commits
- [ ] Logical, atomic commits
- [ ] Clear commit messages (see Commit Conventions)
- [ ] No debug code or commented-out code
- [ ] No unnecessary files

### 5. Commit Changes

Use **Conventional Commits** format:

```
<type>: <description>

[optional body]

[optional footer]
```

#### Examples

```bash
# Simple commit
git commit -m "feat: add dark mode toggle to settings"

# With body
git commit -m "fix: resolve audio buffer memory leak

The audio engine wasn't properly deallocating buffers after
transcription sessions ended, causing memory to grow unbounded.

Fixes #15"

# Breaking change
git commit -m "refactor!: change Repository interface

BREAKING CHANGE: Repository methods now return Result types
instead of throwing errors. Update all Repository implementations."
```

#### Commit Types

| Type | Description | Example |
|------|-------------|---------|
| `feat` | New feature | Add dark mode toggle |
| `fix` | Bug fix | Fix memory leak |
| `refactor` | Code restructuring | Simplify repository layer |
| `test` | Add/update tests | Add ViewModel tests |
| `docs` | Documentation | Update ARCHITECTURE.md |
| `chore` | Maintenance | Update dependencies |
| `perf` | Performance | Optimize audio processing |
| `style` | Formatting | Fix SwiftLint warnings |

### 6. Push Branch

```bash
git push origin <branch-name>
```

If this is your first push of the branch:
```bash
git push -u origin <branch-name>
```

## Pull Request Process

### Creating a PR

Use GitHub CLI or web interface:

```bash
# Using gh CLI (recommended)
gh pr create \
  --title "feat: add dark mode support" \
  --body "Implements dark mode throughout the app. Closes #42"

# Or open in browser
gh pr create --web
```

#### PR Title Format

Use Conventional Commits format:

```
<type>: <description>
```

Examples:
- `feat: add dark mode support`
- `fix: resolve audio buffer memory leak`
- `refactor: simplify repository layer`
- `test: add coverage for TranscriptionViewModel`
- `docs: update ARCHITECTURE.md with new patterns`

#### PR Body Template

```markdown
## Description
Brief overview of what this PR does and why.

## Changes
- Specific change 1
- Specific change 2
- Specific change 3

## Testing
- [ ] Unit tests added/updated
- [ ] All tests pass locally
- [ ] Manual testing performed

## Architecture Compliance
- [ ] ViewModels use Repositories only
- [ ] Protocol-based dependency injection
- [ ] Follows MVVM pattern

## Screenshots (if UI changes)
[Add screenshots here]

## Related Issues
Closes #<issue-number>
```

### CI/CD Checks

GitHub Actions will automatically run:

1. **Build** - Compile the project
2. **SwiftLint** - Code style validation
3. **swift-format** - Format validation
4. **Tests** - All unit and integration tests
5. **Coverage** - Must maintain 20%+ coverage

All checks must pass before merge.

### Addressing CI Failures

#### SwiftLint Failures

```bash
# View violations
swiftlint

# Auto-fix what's possible
swiftlint --fix

# Run again to verify
swiftlint
```

#### Test Failures

```bash
# Run all tests
xcodebuild test -scheme LiveAssistant

# Run specific test
xcodebuild test \
  -scheme LiveAssistant \
  -only-testing:LiveAssistantTests/TestClass/testMethod
```

#### Coverage Below Threshold

```bash
# Run tests with coverage
xcodebuild test \
  -scheme LiveAssistant \
  -enableCodeCoverage YES

# Focus on ViewModels and Repositories first
# Add tests for uncovered code
```

## Code Review

### Receiving Feedback

1. **Read all feedback carefully** before responding
2. **Ask clarifying questions** if something is unclear
3. **Make requested changes** in new commits
4. **Push updates** - CI will re-run automatically
5. **Respond to comments** explaining what you changed
6. **Re-request review** when ready

### Making Changes

```bash
# Make the requested changes
# ... edit files ...

# Commit with clear message
git add .
git commit -m "Address review feedback: use system colors"

# Push updates
git push origin <branch-name>
```

### Resolving Discussions

- Mark resolved when you've addressed the feedback
- Reply with "Done" or explanation of what changed
- If you disagree, explain your reasoning politely

## Common Scenarios

### Working on a Feature

```bash
# 1. Create branch
git checkout main
git pull origin main
git checkout -b feat/issue-42-dark-mode

# 2. Implement feature
# ... make changes ...
# ... write tests ...

# 3. Self-review
swiftlint
xcodebuild test -scheme LiveAssistant

# 4. Commit
git add .
git commit -m "feat: add dark mode support

Implements dark mode toggle in settings and applies theme
throughout the app. Uses system preference by default.

Closes #42"

# 5. Push and create PR
git push -u origin feat/issue-42-dark-mode
gh pr create --fill

# 6. After approval, merge via GitHub UI
```

### Fixing a Bug

```bash
# 1. Create branch
git checkout -b fix/issue-15-audio-leak

# 2. Reproduce and fix
# ... make changes ...

# 3. Add regression test
# ... write test to prevent regression ...

# 4. Commit
git commit -m "fix: resolve audio buffer memory leak

Fixes memory leak by properly deallocating audio buffers
after transcription sessions.

Closes #15"

# 5. Push and create PR
git push -u origin fix/issue-15-audio-leak
gh pr create --fill
```

### Updating After Review

```bash
# 1. Make requested changes
# ... edit files ...

# 2. Run checks
swiftlint
xcodebuild test -scheme LiveAssistant

# 3. Commit and push
git add .
git commit -m "Address review feedback: improve error handling"
git push origin <branch-name>

# 4. Respond to reviewer
# Comment on PR: "Updated as requested. Ready for re-review."
```

### Syncing with Main

```bash
# Fetch latest changes
git fetch origin main

# Rebase your branch
git rebase origin/main

# Resolve conflicts if any
# ... edit files to resolve conflicts ...
git add .
git rebase --continue

# Force push (rebase rewrites history)
git push --force-with-lease origin <branch-name>
```

## Troubleshooting

### "SwiftLint won't run"

```bash
# Check SwiftLint is installed
swiftlint version

# If not installed
brew install swiftlint

# Try running from project root
cd /path/to/LiveAssistant
swiftlint
```

### "Tests failing locally"

```bash
# Clean build folder
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Rebuild and test
xcodebuild clean test -scheme LiveAssistant
```

### "Can't push to branch"

```bash
# Check remote URL
git remote -v

# Check branch tracking
git branch -vv

# Re-set upstream
git push -u origin <branch-name>
```

### "Merge conflicts"

```bash
# Update from main
git fetch origin main

# Start rebase
git rebase origin/main

# For each conflict:
# 1. Edit files to resolve
# 2. git add <resolved-files>
# 3. git rebase --continue

# Or abort if needed
git rebase --abort
```

### "PR checks failing but pass locally"

1. Check exact Xcode version matches CI (16.0.1)
2. Check Swift version matches (6.0)
3. Ensure all files are committed and pushed
4. Review CI logs for specific errors
5. Try clean build: `xcodebuild clean`

## Quality Gates

All PRs must pass:

- ✅ SwiftLint validation (zero warnings)
- ✅ swift-format validation
- ✅ All unit tests pass
- ✅ Code coverage ≥ 20%
- ✅ Architecture compliance
- ✅ At least 1 approval from maintainer

## Best Practices

### DO ✅

- Read and understand issues completely before starting
- Follow the architecture patterns strictly
- Write tests as you develop, not after
- Run quality checks before creating PR
- Use conventional commit format consistently
- Keep PRs focused and single-purpose
- Respond promptly to review feedback
- Update documentation when patterns change
- Ask questions when unsure

### DON'T ❌

- Start coding without understanding the issue
- Access Services directly from ViewModels
- Skip writing tests to "save time"
- Create PRs without running checks locally
- Mix multiple unrelated changes in one PR
- Use force unwrap without justification
- Hardcode strings or asset names
- Ignore SwiftLint warnings
- Force push without `--force-with-lease`

## Resources

- [ARCHITECTURE.md](ARCHITECTURE.md) - Complete architecture documentation
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contributing guidelines
- [README.md](README.md) - Project overview
- [.cursor/rules/](. cursor/rules/) - Cursor AI rules for automated assistance

## Getting Help

If you're stuck:

1. Check existing documentation first
2. Search for similar issues/PRs
3. Ask in PR comments or issue discussions
4. Reach out to maintainers

---

**Remember:** Quality over speed. Take time to do it right the first time.

