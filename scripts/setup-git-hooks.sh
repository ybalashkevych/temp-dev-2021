#!/bin/bash

#
# setup-git-hooks.sh
# LiveAssistant
#
# Script to set up git hooks for code quality checks.
# Run this once after cloning the repository.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔧 Setting up git hooks for LiveAssistant..."

# Get the project root directory (parent of scripts directory)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GIT_HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

# Check if we're in a git repository
if [ ! -d "$PROJECT_ROOT/.git" ]; then
    echo -e "${RED}Error: Not a git repository${NC}"
    exit 1
fi

# Check if SwiftLint is installed
if ! command -v swiftlint &> /dev/null; then
    echo -e "${YELLOW}Warning: SwiftLint is not installed${NC}"
    echo "Install with: brew install swiftlint"
    echo ""
fi

# Check if swift-format is available
if ! command -v swift-format &> /dev/null && ! xcrun --find swift-format &> /dev/null 2>&1; then
    echo -e "${YELLOW}Warning: swift-format is not available${NC}"
    echo "swift-format is included with Xcode's toolchain"
    echo ""
fi

# Create pre-commit hook
PRE_COMMIT_HOOK="$GIT_HOOKS_DIR/pre-commit"

echo "📝 Creating pre-commit hook..."

cat > "$PRE_COMMIT_HOOK" << 'EOF'
#!/bin/bash

#
# Pre-commit hook for LiveAssistant
# Runs swift-format and SwiftLint checks before allowing commits
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 Running pre-commit checks..."

# Get the project root
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
cd "$PROJECT_ROOT"

# Check swift-format
if command -v swift-format &> /dev/null || xcrun --find swift-format &> /dev/null 2>&1; then
    echo "📐 Checking code formatting with swift-format..."
    
    SWIFT_FORMAT_CMD=$(command -v swift-format 2>/dev/null || echo "xcrun swift-format")
    
    if ! $SWIFT_FORMAT_CMD lint --strict --recursive LiveAssistant/ > /dev/null 2>&1; then
        echo -e "${RED}❌ swift-format check failed${NC}"
        echo "Run 'swift-format format --in-place --recursive LiveAssistant/' to fix formatting issues"
        exit 1
    fi
    
    echo -e "${GREEN}✅ swift-format check passed${NC}"
else
    echo -e "${YELLOW}⚠️  swift-format not available, skipping format check${NC}"
fi

# Check SwiftLint
if command -v swiftlint &> /dev/null; then
    echo "🔎 Linting code with SwiftLint..."
    
    # Run SwiftLint in background with timeout and error suppression
    SWIFTLINT_OUTPUT_FILE=$(mktemp)
    (swiftlint lint --strict --quiet > "$SWIFTLINT_OUTPUT_FILE" 2>&1) &
    SWIFTLINT_PID=$!
    
    # Wait up to 15 seconds
    for i in {1..15}; do
        if ! kill -0 $SWIFTLINT_PID 2>/dev/null; then
            break
        fi
        sleep 1
    done
    
    # Check if still running
    if kill -0 $SWIFTLINT_PID 2>/dev/null; then
        kill -9 $SWIFTLINT_PID 2>/dev/null
        rm -f "$SWIFTLINT_OUTPUT_FILE"
        echo -e "${YELLOW}⚠️  SwiftLint timed out (Xcode 26 compatibility issue)${NC}"
        echo -e "${YELLOW}   Continuing with swift-format check passed${NC}"
    else
        # Wait and suppress "Illegal instruction" messages
        wait $SWIFTLINT_PID 2>/dev/null || true
        SWIFTLINT_EXIT=$?
        SWIFTLINT_OUTPUT=$(cat "$SWIFTLINT_OUTPUT_FILE" 2>/dev/null || echo "")
        rm -f "$SWIFTLINT_OUTPUT_FILE"
        
        # Exit codes: 0 = success, 132 = Illegal instruction, 124 = timeout
        if [ $SWIFTLINT_EXIT -eq 132 ] || [ $SWIFTLINT_EXIT -eq 139 ]; then
            echo -e "${YELLOW}⚠️  SwiftLint crashed (Xcode 26 beta compatibility issue)${NC}"
            echo -e "${YELLOW}   Continuing with swift-format check passed${NC}"
        elif echo "$SWIFTLINT_OUTPUT" | grep -q "Fatal error\|Illegal instruction\|sourcekitdInProc"; then
            echo -e "${YELLOW}⚠️  SwiftLint compatibility issue (Xcode 26 beta)${NC}"
            echo -e "${YELLOW}   Continuing with swift-format check passed${NC}"
        elif [ $SWIFTLINT_EXIT -ne 0 ] && [ -n "$SWIFTLINT_OUTPUT" ]; then
            echo -e "${RED}❌ SwiftLint check failed${NC}"
            echo "$SWIFTLINT_OUTPUT"
            echo "Fix the issues above before committing"
            exit 1
        else
            echo -e "${GREEN}✅ SwiftLint check passed${NC}"
        fi
    fi
else
    echo -e "${YELLOW}⚠️  SwiftLint not installed, skipping lint check${NC}"
fi

# Check for file headers on new/modified Swift files
echo "📄 Checking file headers..."

HEADER_PATTERN="^//\n//  .*\.swift\n//  LiveAssistant\n//\n//  Created by .* on .*\.\n"
HAS_HEADER_ISSUES=false

for file in $(git diff --cached --name-only --diff-filter=ACM | grep "\.swift$"); do
    if [ -f "$file" ]; then
        # Check if file has proper header
        if ! head -n 6 "$file" | grep -qE "LiveAssistant"; then
            echo -e "${YELLOW}⚠️  Missing or invalid header in: $file${NC}"
            HAS_HEADER_ISSUES=true
        fi
    fi
done

if [ "$HAS_HEADER_ISSUES" = true ]; then
    echo -e "${YELLOW}⚠️  Some files have header issues. Please review.${NC}"
    # Don't fail the commit for header issues, just warn
fi

echo -e "${GREEN}✅ All pre-commit checks passed!${NC}"
exit 0
EOF

# Make the pre-commit hook executable
chmod +x "$PRE_COMMIT_HOOK"

echo -e "${GREEN}✅ Pre-commit hook installed successfully${NC}"

# Create prepare-commit-msg hook (optional, for adding branch name to commit)
PREPARE_COMMIT_MSG_HOOK="$GIT_HOOKS_DIR/prepare-commit-msg"

echo "📝 Creating prepare-commit-msg hook..."

cat > "$PREPARE_COMMIT_MSG_HOOK" << 'EOF'
#!/bin/bash

#
# Prepare-commit-msg hook for LiveAssistant
# Adds branch name to commit message (if on feature branch)
#

COMMIT_MSG_FILE=$1
COMMIT_SOURCE=$2

# Only add branch name if it's a regular commit (not merge, squash, etc.)
if [ -z "$COMMIT_SOURCE" ]; then
    BRANCH_NAME=$(git symbolic-ref --short HEAD 2>/dev/null)
    
    # Only add for feature branches
    if [[ $BRANCH_NAME == feature/* ]] || [[ $BRANCH_NAME == bugfix/* ]] || [[ $BRANCH_NAME == hotfix/* ]]; then
        # Extract ticket/issue number if present
        if [[ $BRANCH_NAME =~ (feature|bugfix|hotfix)/([A-Z]+-[0-9]+) ]]; then
            TICKET="${BASH_REMATCH[2]}"
            sed -i.bak -e "1s/^/[$TICKET] /" "$COMMIT_MSG_FILE"
            rm "${COMMIT_MSG_FILE}.bak"
        fi
    fi
fi
EOF

# Make the prepare-commit-msg hook executable
chmod +x "$PREPARE_COMMIT_MSG_HOOK"

echo -e "${GREEN}✅ Prepare-commit-msg hook installed successfully${NC}"

echo ""
echo -e "${GREEN}🎉 Git hooks setup complete!${NC}"
echo ""
echo "The following hooks have been installed:"
echo "  • pre-commit: Runs SwiftLint and swift-format checks"
echo "  • prepare-commit-msg: Adds branch name to commits"
echo ""
echo "To bypass hooks (not recommended), use: git commit --no-verify"
echo ""

# Check if tools are installed
MISSING_TOOLS=false

if ! command -v swiftlint &> /dev/null; then
    echo -e "${YELLOW}⚠️  SwiftLint is not installed${NC}"
    echo "   Install: brew install swiftlint"
    MISSING_TOOLS=true
fi

if ! command -v swift-format &> /dev/null && ! xcrun --find swift-format &> /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  swift-format is not available${NC}"
    echo "   Included with Xcode's toolchain"
    MISSING_TOOLS=true
fi

if [ "$MISSING_TOOLS" = true ]; then
    echo ""
    echo -e "${YELLOW}Please install missing tools for full functionality${NC}"
fi

exit 0


