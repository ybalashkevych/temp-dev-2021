#!/bin/bash

#
# verify-setup.sh
# LiveAssistant
#
# Verifies that the development environment is properly set up.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Verifying LiveAssistant development setup...${NC}"
echo ""

# Track overall status
ALL_CHECKS_PASSED=true

# Function to check command
check_command() {
    local cmd=$1
    local name=$2
    local install_hint=$3
    
    if command -v "$cmd" &> /dev/null; then
        local version=$($cmd --version 2>&1 | head -n 1)
        echo -e "${GREEN}✅ $name is installed${NC}"
        echo "   Version: $version"
        return 0
    else
        echo -e "${RED}❌ $name is not installed${NC}"
        if [ -n "$install_hint" ]; then
            echo "   Install: $install_hint"
        fi
        ALL_CHECKS_PASSED=false
        return 1
    fi
}

# Function to check file
check_file() {
    local file=$1
    local name=$2
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ $name exists${NC}"
        return 0
    else
        echo -e "${RED}❌ $name is missing${NC}"
        ALL_CHECKS_PASSED=false
        return 1
    fi
}

# Function to check directory
check_directory() {
    local dir=$1
    local name=$2
    
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✅ $name exists${NC}"
        return 0
    else
        echo -e "${RED}❌ $name is missing${NC}"
        ALL_CHECKS_PASSED=false
        return 1
    fi
}

# Get project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${BLUE}📦 Checking required tools...${NC}"
check_command "xcodebuild" "Xcode" ""
check_command "swift" "Swift" ""
check_command "swiftlint" "SwiftLint" "brew install swiftlint"
check_command "swift-format" "swift-format" "Included with Xcode (xcrun swift-format)"
echo ""

echo -e "${BLUE}📁 Checking project structure...${NC}"
cd "$PROJECT_ROOT"

# Check configuration files
check_file ".swiftlint.yml" "SwiftLint configuration"
check_file ".swift-format" "swift-format configuration"
check_file "Package.swift" "Swift Package Manager file"
check_file ".gitignore" "Git ignore file"
echo ""

# Check documentation
echo -e "${BLUE}📚 Checking documentation...${NC}"
check_file "README.md" "README"
check_file "ARCHITECTURE.md" "Architecture documentation"
check_file "CODING_STANDARDS.md" "Coding standards"
check_file "CONTRIBUTING.md" "Contributing guide"
check_file ".github/pull_request_template.md" "PR template"
echo ""

# Check folder structure
echo -e "${BLUE}🏗️  Checking folder structure...${NC}"
check_directory "LiveAssistant/App" "App directory"
check_directory "LiveAssistant/App/DI" "DI directory"
check_directory "LiveAssistant/Core" "Core directory"
check_directory "LiveAssistant/Core/Models" "Models directory"
check_directory "LiveAssistant/Core/Services" "Services directory"
check_directory "LiveAssistant/Core/Repositories" "Repositories directory"
check_directory "LiveAssistant/Features" "Features directory"
check_directory "LiveAssistant/Features/Chat" "Chat feature directory"
check_directory "LiveAssistant/Resources" "Resources directory"
echo ""

# Check git hooks
echo -e "${BLUE}🔧 Checking git hooks...${NC}"
if [ -d ".git" ]; then
    check_file ".git/hooks/pre-commit" "Pre-commit hook"
    if [ -f ".git/hooks/pre-commit" ] && [ -x ".git/hooks/pre-commit" ]; then
        echo -e "${GREEN}✅ Pre-commit hook is executable${NC}"
    elif [ -f ".git/hooks/pre-commit" ]; then
        echo -e "${YELLOW}⚠️  Pre-commit hook is not executable${NC}"
        echo "   Run: chmod +x .git/hooks/pre-commit"
        ALL_CHECKS_PASSED=false
    fi
else
    echo -e "${YELLOW}⚠️  Not a git repository${NC}"
fi
echo ""

# Check key source files
echo -e "${BLUE}💻 Checking key source files...${NC}"
check_file "LiveAssistant/App/LiveAssistantApp.swift" "App entry point"
check_file "LiveAssistant/App/DI/AppComponent.swift" "DI container"
check_file "LiveAssistant/Features/Chat/Views/ContentView.swift" "ContentView"
check_file "LiveAssistant/Features/Chat/ViewModels/ContentViewModel.swift" "ContentViewModel"
check_file "LiveAssistant/Core/Repositories/Protocols/ItemRepositoryProtocol.swift" "Repository protocol"
check_file "LiveAssistant/Core/Repositories/Implementations/ItemRepository.swift" "Repository implementation"
echo ""

# Check test files
echo -e "${BLUE}🧪 Checking test files...${NC}"
check_file "LiveAssistantTests/ContentViewModelTests.swift" "Example test file"
echo ""

# Run SwiftLint check
echo -e "${BLUE}🔍 Running SwiftLint check...${NC}"
if command -v swiftlint &> /dev/null; then
    if swiftlint lint --quiet; then
        echo -e "${GREEN}✅ SwiftLint check passed${NC}"
    else
        echo -e "${YELLOW}⚠️  SwiftLint found issues${NC}"
        echo "   Run 'swiftlint lint' for details"
        ALL_CHECKS_PASSED=false
    fi
else
    echo -e "${YELLOW}⚠️  SwiftLint not installed, skipping${NC}"
fi
echo ""

# Run swift-format check
echo -e "${BLUE}📐 Running swift-format check...${NC}"
if command -v swift-format &> /dev/null || xcrun --find swift-format &> /dev/null 2>&1; then
    SWIFT_FORMAT_CMD=$(command -v swift-format 2>/dev/null || echo "xcrun swift-format")
    if $SWIFT_FORMAT_CMD lint --strict --recursive LiveAssistant/ > /dev/null 2>&1; then
        echo -e "${GREEN}✅ swift-format check passed${NC}"
    else
        echo -e "${YELLOW}⚠️  swift-format found issues${NC}"
        echo "   Run 'swift-format format --in-place --recursive LiveAssistant/' to fix"
        ALL_CHECKS_PASSED=false
    fi
else
    echo -e "${YELLOW}⚠️  swift-format not found, skipping${NC}"
fi
echo ""

# Check Xcode project
echo -e "${BLUE}🔨 Checking Xcode project...${NC}"
if xcodebuild -list -project LiveAssistant.xcodeproj > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Xcode project is valid${NC}"
else
    echo -e "${RED}❌ Xcode project has issues${NC}"
    ALL_CHECKS_PASSED=false
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$ALL_CHECKS_PASSED" = true ]; then
    echo -e "${GREEN}✅ All checks passed! Your development environment is ready.${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Open LiveAssistant.xcodeproj in Xcode"
    echo "  2. Build and run (Cmd + R)"
    echo "  3. Check out ARCHITECTURE.md for development guidelines"
    exit 0
else
    echo -e "${YELLOW}⚠️  Some checks failed. Please address the issues above.${NC}"
    echo ""
    echo "Common fixes:"
    echo "  • Install missing tools: brew install swiftlint"
    echo "  • swift-format is included with Xcode"
    echo "  • Run setup script: ./scripts/setup-git-hooks.sh"
    echo "  • Fix linting issues: swiftlint --fix"
    echo "  • Fix formatting: swift-format format --in-place --recursive LiveAssistant/"
    exit 1
fi


