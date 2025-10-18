# Changelog

All notable changes to the LiveAssistant project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Consolidated script tools: `cursor-pr.sh`, `cursor-quality.sh`, `setup.sh`
- Organized documentation structure with consolidated guides
- Comprehensive troubleshooting guide
- Detailed setup and automation guides
- Historical documentation archive

### Changed
- **Extreme consolidation of project files:**
  - Root docs: 6 → 4 files (merged CODING_STANDARDS into ARCHITECTURE, WORKFLOW into CONTRIBUTING)
  - Scripts: 12 → 6 files (50% reduction with multi-purpose tools)
  - All script functionality preserved in new consolidated tools
- Reorganized documentation into logical folders (setup, troubleshooting, features, history)
- Updated README and all documentation references to use new consolidated files
- Moved status and fix reports to docs/history/

### Improved
- Project organization significantly improved
- Documentation discoverability and maintainability
- Root directory clutter massively reduced (36+ files → 4 essential files)
- Script usage simplified with subcommands (e.g., `cursor-pr.sh create|merge|process|respond`)
- Setup and quality checks streamlined

## [0.1.0] - 2025-10-16

### Added
- Background daemon for automated PR monitoring
- GitHub Actions workflow for PR checks (optimized multi-job)
- CI check integration (SwiftLint, swift-format, tests, coverage)
- Automated PR comment monitoring and labeling
- Inline SwiftLint comment posting
- Intelligent conflict resolution during PR processing
- Comprehensive logging system for daemon and PR processing

### Improved
- CI workflow optimization (~66% reduction in build time)
- System audio transcription confidence thresholds
- Real-time partial transcription updates

### Fixed
- Launch daemon path issues and macOS permissions
- Launchd configuration for modern macOS versions
- App sandbox and entitlements configuration
- Permission request crashes with TCC privacy violations
- Microphone permission dialogs not appearing
- System audio transcription not working

## [0.0.1] - 2025-10-12

### Added
- Initial project setup with MVVM architecture
- Repository pattern implementation
- Dependency injection using Swinject
- SwiftData integration for local persistence
- Real-time transcription feature (microphone and system audio)
- Permission management system
- SwiftLint and swift-format configuration
- Git hooks for code quality enforcement
- Swift Testing framework with example tests
- SwiftGen integration for type-safe resources
- Comprehensive architecture and coding standards documentation
- GitHub PR templates and automation rules

### Technical
- macOS 14.0+ deployment target
- Swift 6.0 with strict concurrency checking
- Xcode 16.0.1+ required
- @Observable ViewModels with @MainActor
- Protocol-based service and repository layers

---

## Version History Summary

- **0.1.0** - Background automation, CI optimization, bug fixes
- **0.0.1** - Initial project setup and core features

## Migration Guide

### From Pre-organized Documentation (2025-10-17)

If you have bookmarks or references to old documentation files:

**Old Location** → **New Location**
- `SWIFTGEN.md` → `docs/setup/swiftgen.md`
- `TRANSCRIPTION_USAGE.md` → `docs/features/transcription.md`
- All fix/status docs → `docs/history/`
- Setup summaries → Consolidated in `docs/setup/SETUP.md`
- Troubleshooting info → Consolidated in `docs/troubleshooting/TROUBLESHOOTING.md`
- Automation docs → Consolidated in `docs/setup/automation.md`

## Contributing

When adding entries to this changelog:

1. **Add to [Unreleased]** section during development
2. **Use categories:** Added, Changed, Deprecated, Removed, Fixed, Security, Improved
3. **Write for users:** Describe what changed, not implementation details
4. **Link issues/PRs:** Reference related GitHub issues
5. **Be specific:** "Added microphone permission support" not "Added permissions"
6. **Bump version** when releasing:
   - Major (1.0.0): Breaking changes
   - Minor (0.1.0): New features, backward compatible
   - Patch (0.0.1): Bug fixes, backward compatible

## Links

- [Repository](https://github.com/your-username/LiveAssistant)
- [Issue Tracker](https://github.com/your-username/LiveAssistant/issues)
- [Pull Requests](https://github.com/your-username/LiveAssistant/pulls)
- [Releases](https://github.com/your-username/LiveAssistant/releases)

---

**Note:** This changelog was created on 2025-10-17. Previous changes are documented in `docs/history/` for reference.


