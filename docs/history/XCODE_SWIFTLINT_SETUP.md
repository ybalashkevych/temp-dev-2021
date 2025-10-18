# Adding SwiftLint to Xcode (Optional Local Setup)

This guide shows how to add SwiftLint as a Run Script Build Phase in Xcode to get inline violation warnings while coding locally.

**Note:** This is **optional**. SwiftLint is already enforced in CI through a separate lint job, so you'll catch violations before merging. This local setup just provides faster feedback while you code.

## Prerequisites

Install SwiftLint via Homebrew:

```bash
brew install swiftlint
```

## Setup Instructions

### 1. Open Your Project in Xcode

Open `LiveAssistant.xcodeproj` in Xcode.

### 2. Select the LiveAssistant Target

1. In the Project Navigator (left sidebar), click on the **LiveAssistant** project (blue icon at top)
2. In the main editor, select the **LiveAssistant** target from the TARGETS list

### 3. Add Run Script Build Phase

1. Click the **Build Phases** tab at the top
2. Click the **+** button in the top left
3. Select **New Run Script Phase**
4. A new "Run Script" phase will appear at the bottom

### 4. Configure the Run Script

1. **Drag the Run Script** phase to run **after "Dependencies"** but **before "Compile Sources"**
   - This ensures SwiftLint runs early and shows violations during compilation

2. **Expand the Run Script** phase by clicking the disclosure triangle

3. **Set the script name** (optional but recommended):
   - Click "Run Script" and rename it to **"SwiftLint"**

4. **Add the script**:
   - In the script text field, paste:
   ```bash
   if which swiftlint >/dev/null; then
     swiftlint
   else
     echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
   fi
   ```

5. **Configure Input Files** (optional, improves build performance):
   - Expand "Input Files" section
   - Add: `$(SRCROOT)/.swiftlint.yml`
   
   This tells Xcode to only run SwiftLint when the config file or source files change.

6. **Set "Based on dependency analysis"** checkbox:
   - ✅ Check this box to avoid running on every build when nothing changed

### 5. Build the Project

Press **⌘B** to build. SwiftLint will now run and show violations as warnings in Xcode.

## What You'll See

- **Inline Warnings**: SwiftLint violations appear as yellow warnings in your code
- **Issue Navigator**: Click the ⚠️ icon in the left sidebar to see all violations
- **Build Log**: Full SwiftLint output appears in the build log

## Repeat for Test Targets (Optional)

If you want SwiftLint to also lint your test files:

1. Select **LiveAssistantTests** target
2. Go to **Build Phases** tab
3. Add the same Run Script as above
4. Repeat for **LiveAssistantUITests** target

## Troubleshooting

### "SwiftLint not installed" Warning

**Solution:** Install SwiftLint:
```bash
brew install swiftlint
```

### SwiftLint Runs on Every Build (Slow)

**Solution:** Make sure you:
1. Added `.swiftlint.yml` to Input Files
2. Checked "Based on dependency analysis"

### Too Many Violations

The CI uses the same `.swiftlint.yml` config, so any violations shown locally will also fail in CI. Fix them as you go, or temporarily disable specific rules in `.swiftlint.yml` if needed.

### SwiftLint Version Mismatch

To ensure you're using the same SwiftLint version as CI:

```bash
# Check your version
swiftlint version

# CI uses the latest from Homebrew, update yours:
brew upgrade swiftlint
```

## Alternative: Xcode SwiftLint Extension

Instead of a Run Script, you can use the SwiftLint Xcode extension:

1. Download from Mac App Store or GitHub
2. Enable in Xcode → Settings → Extensions
3. Violations appear in the editor as you type

**Pros:**
- Real-time feedback (no need to build)
- Cleaner Xcode integration

**Cons:**
- Requires separate installation
- May have version sync issues with CI

## Removing SwiftLint from Xcode

If you want to remove the Run Script later:

1. Select target → **Build Phases**
2. Find the **SwiftLint** run script
3. Right-click → **Delete**

## Why Not Use the SPM Plugin?

The SwiftLint SPM plugin has compatibility issues with GitHub Actions artifact sharing in CI. By using a Run Script Build Phase instead:

- ✅ Works reliably in both Xcode and CI
- ✅ Same SwiftLint binary from Homebrew everywhere
- ✅ No complex artifact management
- ✅ Developers can opt-in as needed

See `SWIFTLINT_PLUGIN_FIX.md` for details on why the SPM plugin was removed.

## Configuration

SwiftLint uses the `.swiftlint.yml` file in the project root. Any changes to this config affect both:
- Your local Xcode builds (if you added the Run Script)
- The CI lint job

Keep the config in sync to ensure consistent enforcement.

## Summary

**With this setup:**
- 🟡 Yellow warnings appear in Xcode as you code
- ⚡ Fast feedback loop (catch violations before committing)
- 🔄 Same rules enforced locally and in CI
- 👍 Optional - works great without it too!

**Without this setup:**
- ✅ CI still catches all violations in the lint job
- 📧 You'll see violations in PR comments
- 🐌 Slightly slower feedback (only during PR)

