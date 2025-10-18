# SwiftLint Build Plugin: Removed from CI

## Summary

SwiftLint build plugin has been **removed from Package.swift** for CI reliability. SwiftLint is still comprehensively enforced in CI through a separate lint job that runs before build.

**For local development**, developers can optionally add SwiftLint as an Xcode Run Script Build Phase to get inline violations while coding. See `XCODE_SWIFTLINT_SETUP.md` for instructions.

## Problem History

### Attempt 1: Use Plugin in CI with Artifact Sharing
Initially tried to use SwiftLint build plugin for all targets to get build-time linting in both local Xcode and CI.

**Issue:** When sharing build artifacts between GitHub Actions jobs, the SwiftLint binary artifact bundle wasn't accessible:
```
ArtifactsArchive info.json not found at '.../SourcePackages/artifacts/swiftlint/SwiftLintBinary/SwiftLintBinary.artifactbundle'
```

### Attempt 2: Upload Package Artifacts
Tried uploading both `DerivedData` and `SourcePackages/artifacts` to preserve the SwiftLint binary bundle.

**Issue:** The artifacts were stored at different paths during build vs. download, causing the plugin to still fail looking for the binary bundle.

### Attempt 3: Use -skipPackagePluginValidation Flag
The workflows already use `-skipPackagePluginValidation` flag, which is supposed to skip plugin validation.

**Issue:** This flag only skips **validation**, not **execution**. The plugin still attempts to run and fails when it can't find its binary artifact bundle.

## Final Solution: Remove Plugin from Package.swift

Since:
1. **CI Already Has Comprehensive SwiftLint Coverage**: The separate `lint-and-format` job runs SwiftLint on all code before build even starts
2. **Plugin Adds No Value in CI**: All violations are caught in the lint job anyway
3. **Artifact Sharing Complexity**: Plugin binary bundles don't work reliably with GitHub Actions artifact sharing
4. **Local Development**: Developers can add SwiftLint as a Run Script Build Phase if they want inline violations

**Decision**: Remove SwiftLint plugin from `Package.swift` entirely.

## Current Architecture

### CI Pipeline (GitHub Actions)

**lint-and-format job** (runs first):
```yaml
- name: Install SwiftLint
  run: brew install swiftlint

- name: Run SwiftLint
  run: swiftlint lint
```

**build job** (runs after lint passes):
- Builds without SwiftLint plugin
- Uses `-skipPackagePluginValidation` flag (no longer needed but harmless)
- Uploads `DerivedData` for test job

**test-and-coverage job** (runs after build):
- Downloads `DerivedData` artifact
- Runs tests with coverage

### Local Development (Xcode)

Developers have two options for inline SwiftLint violations:

**Option 1: Run Script Build Phase** (Recommended)
- Add SwiftLint as an Xcode Run Script Build Phase
- Shows violations inline as you code
- See `XCODE_SWIFTLINT_SETUP.md` for step-by-step instructions

**Option 2: Xcode SwiftLint Extension**
- Install SwiftLint Xcode extension from Mac App Store
- Provides similar inline violation display

**Option 3: No Local Plugin**
- Rely on CI lint job to catch violations
- Simpler setup, slower feedback loop

## Benefits of This Approach

### ✅ Advantages

1. **Reliable CI**: No artifact path issues or plugin failures
2. **Comprehensive Linting**: Separate lint job catches all violations
3. **Fast Feedback**: Lint job fails fast before expensive build
4. **Simple Setup**: No complex artifact management
5. **Performance**: No plugin overhead in CI builds
6. **Flexibility**: Developers choose their local linting setup

### ❌ Trade-offs

1. **Manual Local Setup**: Developers must manually add Run Script if they want inline violations
2. **No Build-Time Linting in CI**: But violations already caught in separate lint job

## Why Not Keep the Plugin?

### SPM Plugin Limitations with CI Artifact Sharing

Swift Package Manager plugins with binary artifacts (like SwiftLint 0.62+) store their binaries in:
```
SourcePackages/artifacts/[package]/[binary]/[binary].artifactbundle
```

When using Xcode projects (not pure SPM), this path is relative to the project root. When GitHub Actions uploads/downloads artifacts:

1. **Build Job**: Plugin downloads binary to `SourcePackages/artifacts/swiftlint/...`
2. **Upload**: Attempts to upload both `DerivedData` and `SourcePackages/artifacts`
3. **Download**: Artifacts restored but path relationships broken
4. **Test Job**: Plugin looks for binary but can't find it at expected path

**Root Cause**: GitHub Actions artifacts don't preserve directory structure relationships across jobs when uploading multiple separate paths.

**Fix Complexity**: Would require complex scripting to reconstruct exact paths or tarball the entire workspace (defeating the purpose of artifact sharing optimization).

## Alternative Approaches Considered

### ❌ Rebuild Everything in Test Job
- **Con**: Wastes ~5-10 minutes rebuilding
- **Con**: Defeats the purpose of artifact sharing

### ❌ Custom Script to Fix Paths
- **Con**: Complex, brittle
- **Con**: Still requires uploading large binary artifacts
- **Con**: Not maintainable long-term

### ❌ Use tar to Preserve Structure
- **Con**: Large archive sizes
- **Con**: Slower upload/download
- **Con**: More complex than necessary

### ✅ Remove Plugin + Separate Lint Job (Chosen)
- **Pro**: Simple, reliable
- **Pro**: Already have comprehensive linting
- **Pro**: Developers can still use plugin locally
- **Pro**: No CI complexity

## Migration Guide for Developers

### Before (Package.swift had plugin)
```swift
targets: [
    .target(
        name: "LiveAssistant",
        plugins: [
            .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint"),
        ]
    ),
]
```

### After (Plugin removed)
```swift
targets: [
    .target(
        name: "LiveAssistant",
        plugins: [
            .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin"),
        ]
    ),
]
```

### To Get Inline Violations Locally

See `XCODE_SWIFTLINT_SETUP.md` for instructions on adding SwiftLint as a Run Script Build Phase.

## Files Modified

1. **Package.swift**
   - Removed SwiftLint dependency
   - Removed SwiftLintBuildToolPlugin from all targets

2. **.github/workflows/pr-checks.yml**
   - Reverted artifact upload to just `DerivedData`
   - Lint job still runs SwiftLint separately (unchanged)

3. **.github/workflows/ci.yml**
   - Reverted artifact upload to just `DerivedData`

4. **SWIFTLINT_PLUGIN_FIX.md** (this file)
   - Documents the decision and rationale

5. **XCODE_SWIFTLINT_SETUP.md** (new)
   - Instructions for adding SwiftLint to Xcode locally

## Verification

After this change, CI should:
1. ✅ Pass lint job (separate SwiftLint via brew)
2. ✅ Build successfully without plugin errors
3. ✅ Share artifacts efficiently
4. ✅ Run tests successfully

## References

- [SwiftLint Package Plugin](https://github.com/realm/SwiftLint#swift-package-manager-plugin)
- [GitHub Actions Artifacts Limitations](https://github.com/actions/upload-artifact/issues/38)
- Local setup guide: `XCODE_SWIFTLINT_SETUP.md`
