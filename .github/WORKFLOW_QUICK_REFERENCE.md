# Workflow Quick Reference

## 🚀 Common Commands

### Self-Review (Before PR)
```bash
./scripts/cursor-self-review.sh
```

### Create Pull Request
```bash
./scripts/cursor-create-pr.sh <issue-number> <branch-name> "<title>" "<body>"
```

**Example:**
```bash
./scripts/cursor-create-pr.sh 42 feat/issue-42-dark-mode \
  "#42: (feat): Add dark mode support" \
  "Implements dark mode with system preference support..."
```

### Merge Pull Request
```bash
./scripts/cursor-merge-pr.sh <pr-number>
```

### Run Tests with Coverage
```bash
./scripts/run-tests-with-coverage.sh
```

## 📋 PR Title Format

```
#<issue-number>: (<type>): <description>
```

**Types:** `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`, `style`

**Examples:**
- `#42: (feat): Add dark mode support`
- `#15: (fix): Resolve audio buffer leak`
- `#23: (refactor): Simplify repository layer`

## ✅ Pre-PR Checklist

- [ ] Run self-review script
- [ ] All tests pass
- [ ] SwiftLint passes (zero warnings)
- [ ] swift-format passes
- [ ] Coverage ≥ 90%
- [ ] Architecture rules followed
- [ ] Strings localized

## 🔄 Workflow Steps

1. **Create Issue** (GitHub web/mobile)
2. **Create Branch** (`<type>/issue-<#>-<desc>`)
3. **Implement Changes**
4. **Self-Review** (`./scripts/cursor-self-review.sh`)
5. **Create PR** (`./scripts/cursor-create-pr.sh`)
6. **Wait for CI** (automated checks)
7. **Address Feedback** (if needed)
8. **Merge** (`./scripts/cursor-merge-pr.sh`)

## 🛠️ Quick Fixes

### SwiftLint Errors
```bash
swiftlint --fix
swiftlint lint --strict
```

### Format Code
```bash
swift-format format --in-place --recursive LiveAssistant/
```

### Clean Build
```bash
xcodebuild clean -scheme LiveAssistant
rm -rf .build DerivedData
```

### Run Specific Test
```bash
xcodebuild test -scheme LiveAssistant \
  -only-testing:LiveAssistantTests/ClassName/testMethod
```

## 📊 Coverage

**Minimum:** 90%

**Excluded:**
- SwiftUI Views
- Test files
- Generated files

**Priority:**
1. ViewModels
2. Repositories
3. Services

## 🎯 Architecture Rules

- ✅ ViewModels: `@Observable` + `@MainActor` + Repositories only
- ✅ Repositories: Protocol-based + Business logic
- ✅ Services: External interactions only
- ✅ All strings: Use `Strings` enum
- ✅ All assets: Use `Asset` enum
- ✅ Variable name for ViewModels: `vm`

## 📱 Mobile Workflow

1. Create issue (GitHub app)
2. Assign to Cursor
3. Review PR when notified
4. Approve or request changes
5. Done!

## 🔧 GitHub CLI

```bash
# Auth
gh auth login
gh auth status

# Issues
gh issue create
gh issue list
gh issue view <number>

# PRs
gh pr list
gh pr view <number>
gh pr checks <number>

# Workflows
gh workflow run release.yml -f version=1.2.0
```

## ⚡️ Release

```bash
gh workflow run release.yml -f version=1.2.0
```

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| gh not found | `brew install gh` |
| Not authenticated | `gh auth login` |
| Scripts not executable | `chmod +x scripts/*.sh` |
| Tests fail | Check logs, fix issues |
| Coverage low | Add tests for ViewModels/Repos |
| Build fails | `xcodebuild clean`, check errors |

## 📚 Full Documentation

- **WORKFLOW.md** - Complete workflow guide
- **ARCHITECTURE.md** - Architecture details
- **CODING_STANDARDS.md** - Code standards
- **.ai/rules/workflow-automation.mdc** - Cursor rules

