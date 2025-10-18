# LiveAssistant Setup Guide

Complete guide for setting up the LiveAssistant development environment.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Development Tools](#development-tools)
- [Configuration](#configuration)
- [Verification](#verification)
- [Advanced Setup](#advanced-setup)

## Prerequisites

### System Requirements

- **macOS:** 14.0 or later
- **Xcode:** 16.0.1 or later  
- **Swift:** 6.0
- **Homebrew:** Latest version (for package management)

### Required Accounts

- GitHub account with repository access
- GitHub Personal Access Token with `repo` scope

## Initial Setup

### 1. Clone the Repository

```bash
# Clone the repository
git clone <repository-url>
cd LiveAssistant
```

### 2. Install Dependencies

Dependencies are managed via Swift Package Manager and will be resolved automatically:

```bash
# Open in Xcode (dependencies resolve automatically)
open LiveAssistant.xcodeproj

# Or resolve manually
swift package resolve
```

### 3. Initial Build

```bash
# Build from command line
xcodebuild build -project LiveAssistant.xcodeproj -scheme LiveAssistant

# Or build in Xcode: Cmd+B
```

## Development Tools

### 1. SwiftLint (Required)

**What it does:** Enforces code style and best practices

**Installation:**
```bash
# Using Homebrew (recommended)
brew install swiftlint

# Verify installation
swiftlint version
```

**Configuration:**
- Configuration file: `.swiftlint.yml`
- Line length: 140 (warning), 150 (error)
- Function parameters: 6 (warning), 9 (error)
- File headers enforced

**Usage:**
```bash
# Lint all files
swiftlint lint

# Auto-fix issues where possible
swiftlint --fix

# Lint specific file
swiftlint lint --path LiveAssistant/Core/Models/Item.swift
```

---

### 2. swift-format (Required)

**What it does:** Automatically formats Swift code

**Installation:**
```bash
# Included with Xcode
xcrun swift-format --version

# Or install standalone
brew install swift-format
```

**Configuration:**
- Configuration file: `.swift-format`
- Indentation: 4 spaces
- Max line length: 140 characters
- Swift 6 compatible

**Usage:**
```bash
# Check formatting (excludes Generated/)
find LiveAssistant -name "*.swift" -not -path "*/Generated/*" -print0 | \
  xargs -0 swift-format lint --strict

# Auto-format files (excludes Generated/)
find LiveAssistant -name "*.swift" -not -path "*/Generated/*" -print0 | \
  xargs -0 swift-format format --in-place
```

---

### 3. SwiftGen (Automatic)

**What it does:** Generates type-safe accessors for resources

**Installation:**
Included as Swift Package Plugin - no manual installation needed.

**Configuration:**
- Configuration file: `swiftgen.yml`
- Generates: `Core/Generated/Strings.swift` and `Core/Generated/Assets.swift`

**Usage:**
```bash
# Generate code (automatic during build)
swift package --allow-writing-to-package-directory generate-code-for-resources

# Generated files location
ls -la LiveAssistant/Core/Generated/
```

**Important:** Never edit generated files - they're recreated on each build.

---

### 4. GitHub CLI (Required for automation)

**What it does:** Enables GitHub API access for PR automation

**Installation:**
```bash
# Install
brew install gh

# Authenticate
gh auth login

# Verify
gh auth status
```

**Required scopes:**
- `repo` - Full repository access
- `workflow` - Update GitHub Actions

**Usage:**
```bash
# View PRs
gh pr list

# View PR details
gh pr view 123

# Add label
gh pr edit 123 --add-label "needs-changes"
```

---

### 5. Additional Tools

**jq - JSON processor (for automation scripts):**
```bash
brew install jq
```

**Python 3 (for inline comment posting):**
```bash
# Already included with macOS
python3 --version

# Install requests library
pip3 install requests
```

## Configuration

### 1. Git Hooks Setup

Install pre-commit hooks to enforce quality checks:

```bash
# Run setup script
./scripts/setup.sh install
```

**What this does:**
- Installs pre-commit hook (runs SwiftLint and swift-format)
- Installs prepare-commit-msg hook (adds branch name to commits)
- Validates file headers

**Hooks location:** `.git/hooks/`

**To skip hooks temporarily** (not recommended):
```bash
git commit --no-verify -m "message"
```

---

### 2. Xcode Configuration

**Build Settings:**

1. **Open project:** `LiveAssistant.xcodeproj`

2. **Select target:** LiveAssistant

3. **Verify settings:**
   - **Deployment Target:** macOS 14.0
   - **Swift Version:** 6.0
   - **Enable App Sandbox:** NO (for development)
   - **Enable Hardened Runtime:** YES
   - **Code Sign Entitlements:** LiveAssistant/LiveAssistant.entitlements
   - **Info.plist File:** LiveAssistant/Info.plist
   - **Generate Info.plist:** NO

---

### 3. Entitlements Configuration

**File:** `LiveAssistant/LiveAssistant.entitlements`

**Required entitlements for development:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Hardened Runtime - Development -->
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    
    <!-- Required for Microphone Access -->
    <key>com.apple.security.device.audio-input</key>
    <true/>
    <key>com.apple.security.device.microphone</key>
    <true/>
    
    <!-- Debug Access -->
    <key>com.apple.security.get-task-allow</key>
    <true/>
</dict>
</plist>
```

**Note:** For App Store distribution, you'll need to re-enable App Sandbox and adjust entitlements.

---

### 4. Info.plist Configuration

**File:** `LiveAssistant/Info.plist`

**Required privacy usage descriptions:**

```xml
<key>NSMicrophoneUsageDescription</key>
<string>LiveAssistant needs access to your microphone to transcribe your voice during interviews.</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>LiveAssistant uses speech recognition to convert your speech and system audio into text for real-time transcription.</string>

<key>NSSystemExtensionUsageDescription</key>
<string>LiveAssistant needs access to system audio to transcribe the interviewer's voice and questions.</string>
```

**Verify Info.plist is not auto-generated:**
- Build Settings → `GENERATE_INFOPLIST_FILE = NO`

---

### 5. SwiftData Configuration

**Location:** `App/LiveAssistantApp.swift`

SwiftData is configured with the model container:

```swift
.modelContainer(for: [Item.self, TranscriptionSession.self])
```

**Models location:** `Core/Models/`

**Access:** Always through Repository layer (never direct from ViewModels)

## Verification

### Run Verification Script

```bash
./scripts/cursor-quality.sh verify
```

**Checks:**
- ✅ SwiftLint installed and working
- ✅ swift-format installed and working  
- ✅ GitHub CLI authenticated
- ✅ Git hooks installed
- ✅ Project builds successfully
- ✅ SwiftGen generates files

---

### Manual Verification

**1. Build succeeds:**
```bash
xcodebuild build -project LiveAssistant.xcodeproj -scheme LiveAssistant
```

**2. Tests run:**
```bash
xcodebuild test -project LiveAssistant.xcodeproj -scheme LiveAssistant
```

**3. Linting passes:**
```bash
swiftlint lint
```

**4. Formatting is correct:**
```bash
find LiveAssistant -name "*.swift" -not -path "*/Generated/*" -print0 | \
  xargs -0 swift-format lint --strict
```

---

### Common Issues

**Issue:** SwiftLint command not found  
**Solution:** `brew install swiftlint`

**Issue:** swift-format command not found  
**Solution:** `brew install swift-format` or use `xcrun swift-format`

**Issue:** GitHub CLI authentication failed  
**Solution:** `gh auth login` and follow prompts

**Issue:** Build fails with sandbox error  
**Solution:** See [Troubleshooting Guide](../troubleshooting/TROUBLESHOOTING.md#app-crashes-on-launch-with-sandbox-error)

**Issue:** Permission crash when running  
**Solution:** See [Troubleshooting Guide](../troubleshooting/TROUBLESHOOTING.md#app-crashes-when-requesting-permissions)

## Advanced Setup

### Background Automation Setup

For automatic PR monitoring and response, see [Automation Setup Guide](automation.md).

**Quick start:**
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Install launch agent
cp scripts/com.liveassistant.cursor-monitor.plist.template \
   ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist

# Edit paths in plist to match your setup
nano ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist

# Start daemon
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist
```

---

### IDE Integration

**Xcode:**
- SwiftLint runs automatically via Build Phase
- Use Run Script phase for custom checks
- Install Xcode extensions for formatting

**VS Code / Cursor:**
- Install Swift extension
- Configure SwiftLint integration
- Use swift-format extension

---

### Testing Setup

**Test target:** LiveAssistantTests

**Framework:** Swift Testing (preferred)

**Run tests:**
```bash
# All tests
xcodebuild test -project LiveAssistant.xcodeproj -scheme LiveAssistant

# Specific test
xcodebuild test -project LiveAssistant.xcodeproj -scheme LiveAssistant -only-testing:LiveAssistantTests/ContentViewModelTests

# In Xcode: Cmd+U
```

**Coverage:**
- Minimum coverage: 90%
- Coverage report in Xcode: Product → Test → Show Code Coverage
- Command line coverage tracked via xcodebuild

---

### CI/CD Setup

**GitHub Actions workflows:**
- `.github/workflows/pr-checks.yml` - Quality checks on PRs
- `.github/workflows/pr-comment-monitor.yml` - PR comment automation

**Required secrets:**
- `GITHUB_TOKEN` - Automatically provided
- Add custom secrets in repository settings if needed

**Workflow runs:**
- Automatically on PR creation
- Automatically on push to PR branch
- Posts results as PR comments

## Project Structure Overview

After setup, your project structure should look like:

```
LiveAssistant/
├── LiveAssistant/
│   ├── App/                         # Application layer
│   ├── Core/                        # Business logic
│   │   ├── Generated/               # ⚠️ Auto-generated (don't edit)
│   │   ├── Models/                  # Domain models
│   │   ├── Services/                # Service layer
│   │   ├── Repositories/            # Repository layer
│   │   └── Utilities/               # Helpers
│   ├── Features/                    # Feature modules
│   │   ├── Chat/
│   │   ├── Transcription/
│   │   └── Settings/
│   └── Resources/                   # Assets, strings
├── LiveAssistantTests/              # Unit tests
├── scripts/                         # Automation scripts
├── docs/                            # Documentation
├── .swiftlint.yml                   # SwiftLint config
├── .swift-format                    # swift-format config
├── swiftgen.yml                     # SwiftGen config
└── Package.swift                    # Dependencies
```

## Next Steps

After setup is complete:

1. **Read architecture docs:** [ARCHITECTURE.md](../../ARCHITECTURE.md)
2. **Review coding standards:** [CODING_STANDARDS.md](../../CODING_STANDARDS.md)
3. **Understand workflow:** [WORKFLOW.md](../../WORKFLOW.md)
4. **Start developing:** Create a feature branch and begin work

## Getting Help

- **Documentation:** Check `docs/` folder
- **Troubleshooting:** See [Troubleshooting Guide](../troubleshooting/TROUBLESHOOTING.md)
- **Issues:** Create a GitHub issue with details
- **Team:** Ask in team chat or PR comments

---

**Setup completed successfully!** 🎉

You're now ready to develop LiveAssistant.

**Last Updated:** October 2025


