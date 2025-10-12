# SwiftGen Integration Guide

## Overview

This project uses **SwiftGen** to generate type-safe accessors for resources like strings, assets, and colors. This eliminates the need for hardcoded string literals and provides compile-time safety for resource access.

## Benefits

- **Type Safety**: Catch typos at compile time instead of runtime
- **Autocomplete**: Get IDE autocomplete for all resources
- **Refactoring**: Easily rename resources with confidence
- **Documentation**: Auto-generated code serves as documentation

## Generated Files

SwiftGen generates the following files (automatically excluded from Git, SwiftLint, and swift-format):

```
LiveAssistant/Core/Generated/
├── Strings.swift    # Localized strings from Localizable.strings
└── Assets.swift     # Assets from Assets.xcassets (colors, images)
```

### Exclusions

Generated files are automatically excluded from:
- **Git**: Via `.gitignore` - generated files are not committed
- **SwiftLint**: Via `.swiftlint.yml` - generated files are not linted
- **swift-format**: Via exclusion patterns - generated files are not formatted
- **Pre-commit hooks**: Generated files skip all quality checks
- **Xcode Build Phases**: Swift Format build phase excludes Generated/

## Configuration

The project's SwiftGen configuration is defined in `swiftgen.yml`:

- **Strings**: Generates `Strings` enum from `Localizable.strings`
- **Assets**: Generates `Asset` enum from `Assets.xcassets`

## Usage Examples

### Localized Strings

Instead of using `NSLocalizedString` directly:

```swift
// ❌ Old way - prone to typos, no compile-time checking
let message = NSLocalizedString("chat.error.network_failure", comment: "")

// ✅ New way - type-safe and autocomplete-friendly
let message = Strings.Chat.Error.networkFailure
```

### Colors

```swift
// ✅ Type-safe color access
let accentColor = Asset.accentColor.swiftUIColor

// For AppKit
let accentNSColor = Asset.accentColor.color
```

### Error Handling Example

```swift
enum ChatError: LocalizedError {
    case networkFailure
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .networkFailure:
            Strings.Chat.Error.networkFailure
        case .invalidResponse:
            Strings.Chat.Error.invalidResponse
        }
    }
}
```

## Generating Code

SwiftGen runs automatically during builds via an Xcode build phase. The "SwiftGen" build phase executes before compilation to ensure all generated files are up to date.

### Automatic Generation

- **During Xcode Build**: SwiftGen runs automatically as the first build phase
- **Checks Dependencies**: Only regenerates when input files (strings, assets, config) change
- **Incremental**: Uses Xcode's dependency tracking for optimal build performance

### Manual Generation

To manually regenerate without building in Xcode:

```bash
# From project root
swift package --allow-writing-to-package-directory generate-code-for-resources
```

## Adding New Resources

### Adding Strings

1. Add entries to `LiveAssistant/Resources/Localizable.strings`:
   ```
   "feature.action.title" = "Action Title";
   ```

2. Build the project in Xcode (Cmd+B) - SwiftGen will run automatically

3. Use in code:
   ```swift
   let title = Strings.Feature.Action.title
   ```

### Adding Colors/Images

1. Add to `Assets.xcassets` in Xcode
2. Build the project (Cmd+B) - SwiftGen will regenerate automatically
3. Use in code:
   ```swift
   let color = Asset.myNewColor.swiftUIColor
   let image = Asset.myNewImage.image
   ```

## String Key Naming Convention

Use hierarchical, dot-separated keys:

```
feature.section.item
feature.error.type
ui.button.label
```

Examples:
- `chat.error.network_failure`
- `chat.placeholder.message`
- `settings.profile.title`
- `ui.loading`

## Generated Code Structure

### Strings (Strings enum)

```swift
public enum Strings {
    public enum Chat {
        public enum Error {
            public static let networkFailure: String
            public static let invalidResponse: String
        }
    }
}
```

### Assets (Asset enum)

```swift
public enum Asset {
    public static let accentColor: ColorAsset
}

public final class ColorAsset {
    public var swiftUIColor: SwiftUI.Color  // For SwiftUI
    public var color: NSColor                // For AppKit
}
```

## Best Practices

### ✅ Do's

- Use `Strings` for all user-facing strings
- Use `Asset` for all colors and images
- Add comments in `Localizable.strings` for context
- Group related strings with hierarchical keys
- Regenerate after adding new resources
- Let SwiftGen handle file generation automatically

### ❌ Don'ts

- Don't use `NSLocalizedString` directly (use `Strings` instead)
- Don't hardcode color names or image names
- Don't edit generated files (they'll be overwritten)
- Don't commit generated files to Git (already in `.gitignore`)
- Don't lint or format generated files (automatically excluded)
- Don't use flat string keys (use hierarchical structure)

## Troubleshooting

### Generated files are missing

```bash
swift package --allow-writing-to-package-directory generate-code-for-resources
```

### Build fails with "cannot find 'Strings' in scope"

1. Ensure SwiftGen has run successfully (check build logs)
2. Check that generated files exist in `LiveAssistant/Core/Generated/`
3. Clean build folder (Cmd + Shift + K) and rebuild
4. If still failing, manually run: `swift package --allow-writing-to-package-directory generate-code-for-resources`

### Changes to Localizable.strings not reflected

1. Rebuild the project (Cmd+B) - SwiftGen runs as a build phase
2. Check build logs for SwiftGen output
3. If needed, clean and rebuild (Cmd+Shift+K, then Cmd+B)
4. Or manually run: `swift package --allow-writing-to-package-directory generate-code-for-resources`

### SwiftGen not running during build

1. Check Xcode build phases: Project > LiveAssistant > Build Phases
2. Verify "SwiftGen" phase exists and is before "Compile Sources"
3. Check build logs for SwiftGen execution
4. Ensure `swiftgen.yml` configuration file exists

### Verification

Run the setup verification script to check SwiftGen:

```bash
./scripts/verify-setup.sh
```

This will verify:
- ✅ `swiftgen.yml` configuration exists
- ✅ Generated files are present
- ✅ Generated files are up to date

## Integration with CI/CD

In your CI/CD pipeline, ensure SwiftGen runs before building:

```yaml
- name: Generate SwiftGen Code
  run: swift package --allow-writing-to-package-directory generate-code-for-resources

- name: Build Project
  run: xcodebuild build -scheme LiveAssistant
```

## Migration Guide

If you have existing code using `NSLocalizedString`, migrate to SwiftGen:

### Before
```swift
let error = NSLocalizedString("chat.error.network_failure", comment: "Network error")
```

### After
```swift
let error = Strings.Chat.Error.networkFailure
```

## Resources

- [SwiftGen Documentation](https://github.com/SwiftGen/SwiftGen)
- [SwiftGenPlugin](https://github.com/SwiftGen/SwiftGenPlugin)
- Project's `swiftgen.yml` configuration
- Project's `ARCHITECTURE.md` for architectural guidelines

