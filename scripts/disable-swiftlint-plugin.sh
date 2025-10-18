#!/bin/bash

# Disable SwiftLint Build Tool Plugin for CI builds
# This script removes SwiftLintBuildToolPlugin references from the Xcode project file
# to prevent build failures while maintaining the separate SwiftLint linting step

set -e

PROJECT_FILE="LiveAssistant.xcodeproj/project.pbxproj"

echo "🔧 Disabling SwiftLint Build Tool Plugin for CI..."

if [ ! -f "$PROJECT_FILE" ]; then
    echo "❌ Error: $PROJECT_FILE not found"
    exit 1
fi

# Create backup
cp "$PROJECT_FILE" "${PROJECT_FILE}.backup"

# Remove SwiftLintBuildToolPlugin PBXTargetDependency entries
# These are the three sections that reference the plugin as a target dependency
perl -i -pe 'BEGIN{undef $/;} s/\t\t[A-F0-9]+ \/\* PBXTargetDependency \*\/ = \{\n\t\t\tisa = PBXTargetDependency;\n\t\t\tproductRef = [A-F0-9]+ \/\* SwiftLintBuildToolPlugin \*\/;\n\t\t\};\n//g' "$PROJECT_FILE"

# Remove SwiftLintBuildToolPlugin XCSwiftPackageProductDependency entries
# These are the three sections that define the plugin package product dependencies
perl -i -pe 'BEGIN{undef $/;} s/\t\t[A-F0-9]+ \/\* SwiftLintBuildToolPlugin \*\/ = \{\n\t\t\tisa = XCSwiftPackageProductDependency;\n\t\t\tpackage = [A-F0-9]+ \/\* XCRemoteSwiftPackageReference "SwiftLint" \*\/;\n\t\t\tproductName = "plugin:SwiftLintBuildToolPlugin";\n\t\t\};\n//g' "$PROJECT_FILE"

echo "✅ SwiftLint Build Tool Plugin disabled"
echo "   - PBXTargetDependency references removed"
echo "   - XCSwiftPackageProductDependency references removed"
echo "   - Backup saved to: ${PROJECT_FILE}.backup"

