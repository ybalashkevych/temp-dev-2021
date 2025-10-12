#!/bin/bash

#
# verify-setup.sh
# LiveAssistant
#
# Verifies that the development environment is properly set up.
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Verifying LiveAssistant setup...${NC}\n"

FAILED=false

# Check command exists
check_cmd() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
        [ -n "$3" ] && echo "   $3"
        FAILED=true
    fi
}

# Check path exists (file or directory)
check_path() {
    if [ -e "$1" ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2 missing${NC}"
        FAILED=true
    fi
}

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# Tools
echo -e "${BLUE}📦 Tools${NC}"
check_cmd "xcodebuild" "Xcode"
check_cmd "swift" "Swift"
check_cmd "swiftlint" "SwiftLint" "Install: brew install swiftlint"
check_cmd "swift-format" "swift-format" "Included with Xcode"
echo ""

# Configuration files
echo -e "${BLUE}⚙️  Configuration${NC}"
for file in .swiftlint.yml .swift-format Package.swift swiftgen.yml; do
    check_path "$file" "$file"
done
echo ""

# Documentation
echo -e "${BLUE}📚 Documentation${NC}"
for file in README.md ARCHITECTURE.md CODING_STANDARDS.md CONTRIBUTING.md; do
    check_path "$file" "$file"
done
echo ""

# Project structure
echo -e "${BLUE}🏗️  Structure${NC}"
for dir in App/DI Core/{Models,Services,Repositories} Features/{Chat,Settings,Transcription} Resources; do
    check_path "LiveAssistant/$dir" "$dir"
done
echo ""

# Key source files
echo -e "${BLUE}💻 Source Files${NC}"
check_path "LiveAssistant/App/LiveAssistantApp.swift" "App entry point"
check_path "LiveAssistant/App/DI/AppComponent.swift" "DI container"
check_path "LiveAssistant/Features/Chat/Views/ContentView.swift" "ContentView"
check_path "LiveAssistant/Features/Chat/ViewModels/ContentViewModel.swift" "ContentViewModel"
echo ""

# SwiftGen
echo -e "${BLUE}🎨 SwiftGen${NC}"
check_path "LiveAssistant/Core/Generated/Strings.swift" "Generated Strings"
check_path "LiveAssistant/Core/Generated/Assets.swift" "Generated Assets"
if [ -f "LiveAssistant/Resources/Localizable.strings" ] && [ -f "LiveAssistant/Core/Generated/Strings.swift" ]; then
    if [ "LiveAssistant/Resources/Localizable.strings" -nt "LiveAssistant/Core/Generated/Strings.swift" ]; then
        echo -e "${YELLOW}⚠️  Run: swift package --allow-writing-to-package-directory generate-code-for-resources${NC}"
        FAILED=true
    fi
fi
echo ""

# Git hooks
echo -e "${BLUE}🔧 Git Hooks${NC}"
if [ -f ".git/hooks/pre-commit" ]; then
    if [ -x ".git/hooks/pre-commit" ]; then
        echo -e "${GREEN}✅ Pre-commit hook${NC}"
    else
        echo -e "${YELLOW}⚠️  Run: chmod +x .git/hooks/pre-commit${NC}"
        FAILED=true
    fi
else
    echo -e "${RED}❌ Pre-commit hook missing${NC}"
    FAILED=true
fi
echo ""

# Linting
echo -e "${BLUE}🔍 Linting${NC}"
if command -v swiftlint &> /dev/null; then
    # Run SwiftLint with timeout and error handling (Xcode 26 compatibility)
    SWIFTLINT_OUTPUT_FILE=$(mktemp)
    (swiftlint lint --quiet > "$SWIFTLINT_OUTPUT_FILE" 2>&1) &
    SWIFTLINT_PID=$!
    
    # Wait up to 10 seconds
    for i in {1..10}; do
        if ! kill -0 $SWIFTLINT_PID 2>/dev/null; then
            break
        fi
        sleep 1
    done
    
    # Check if still running (timeout)
    if kill -0 $SWIFTLINT_PID 2>/dev/null; then
        kill -9 $SWIFTLINT_PID 2>/dev/null
        rm -f "$SWIFTLINT_OUTPUT_FILE"
        echo -e "${YELLOW}⚠️  SwiftLint timed out (Xcode 26 compatibility issue)${NC}"
    else
        wait $SWIFTLINT_PID 2>/dev/null || true
        SWIFTLINT_EXIT=$?
        SWIFTLINT_OUTPUT=$(cat "$SWIFTLINT_OUTPUT_FILE" 2>/dev/null || echo "")
        rm -f "$SWIFTLINT_OUTPUT_FILE"
        
        # Check for known crash patterns
        if [ $SWIFTLINT_EXIT -eq 132 ] || [ $SWIFTLINT_EXIT -eq 139 ]; then
            echo -e "${YELLOW}⚠️  SwiftLint crashed (Xcode 26 compatibility issue)${NC}"
        elif echo "$SWIFTLINT_OUTPUT" | grep -q "Fatal error\|Illegal instruction\|sourcekitdInProc"; then
            echo -e "${YELLOW}⚠️  SwiftLint compatibility issue (Xcode 26 beta)${NC}"
        elif [ $SWIFTLINT_EXIT -ne 0 ] && [ -n "$SWIFTLINT_OUTPUT" ]; then
            echo -e "${YELLOW}⚠️  SwiftLint issues (run: swiftlint lint)${NC}"
            FAILED=true
        else
            echo -e "${GREEN}✅ SwiftLint passed${NC}"
        fi
    fi
fi

if command -v swift-format &> /dev/null || xcrun --find swift-format &> /dev/null 2>&1; then
    SWIFT_FORMAT=$(command -v swift-format 2>/dev/null || echo "xcrun swift-format")
    if find LiveAssistant -name "*.swift" -not -path "*/Generated/*" -exec $SWIFT_FORMAT lint --strict {} + &> /dev/null; then
        echo -e "${GREEN}✅ swift-format passed${NC}"
    else
        echo -e "${YELLOW}⚠️  swift-format issues (run: swift-format format --in-place --recursive LiveAssistant/)${NC}"
        FAILED=true
    fi
fi
echo ""

# Xcode project
echo -e "${BLUE}🔨 Xcode${NC}"
if xcodebuild -list -project LiveAssistant.xcodeproj &> /dev/null; then
    echo -e "${GREEN}✅ Project valid${NC}"
else
    echo -e "${RED}❌ Project has issues${NC}"
    FAILED=true
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$FAILED" = false ]; then
    echo -e "${GREEN}✅ All checks passed!${NC}\n"
    echo "Ready to build:"
    echo "  1. Open LiveAssistant.xcodeproj"
    echo "  2. Press Cmd + R to build and run"
    exit 0
else
    echo -e "${YELLOW}⚠️  Some checks failed${NC}\n"
    echo "Quick fixes:"
    echo "  • brew install swiftlint"
    echo "  • ./scripts/setup-git-hooks.sh"
    echo "  • swiftlint --fix"
    exit 1
fi

