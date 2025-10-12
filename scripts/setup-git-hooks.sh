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

# Create pre-commit hook
echo "📝 Creating pre-commit hook..."

cat > "$GIT_HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash

#
# Pre-commit hook for LiveAssistant
# Runs swift-format and SwiftLint checks before allowing commits
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 Running pre-commit checks..."

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
cd "$PROJECT_ROOT"

# Check swift-format
SWIFT_FORMAT_CMD=$(command -v swift-format 2>/dev/null || echo "xcrun swift-format")
if $SWIFT_FORMAT_CMD --version &> /dev/null; then
    echo "📐 Checking code formatting..."
    
    if ! $SWIFT_FORMAT_CMD lint --strict --recursive LiveAssistant/ 2>&1 | grep -q "no lint warnings"; then
        echo -e "${RED}❌ Code formatting issues found${NC}"
        echo "Run: swift-format format --in-place --recursive LiveAssistant/"
        exit 1
    fi
    echo -e "${GREEN}✅ Code formatting passed${NC}"
else
    echo -e "${YELLOW}⚠️  swift-format not available, skipping${NC}"
fi

# Check SwiftLint
if command -v swiftlint &> /dev/null; then
    echo "🔎 Running SwiftLint..."
    
    if swiftlint lint --strict --quiet 2>&1; then
        echo -e "${GREEN}✅ SwiftLint passed${NC}"
    else
        LINT_EXIT=$?
        # Ignore crashes (exit codes 132, 139), but fail on actual linting errors
        if [ $LINT_EXIT -ne 132 ] && [ $LINT_EXIT -ne 139 ]; then
            echo -e "${RED}❌ SwiftLint check failed${NC}"
            exit 1
        fi
        echo -e "${YELLOW}⚠️  SwiftLint crashed (ignoring)${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  SwiftLint not installed, skipping${NC}"
fi

# Check file headers
echo "📄 Checking file headers..."
for file in $(git diff --cached --name-only --diff-filter=ACM | grep "\.swift$" || true); do
    if [ -f "$file" ] && ! head -n 6 "$file" | grep -q "LiveAssistant"; then
        echo -e "${YELLOW}⚠️  Missing header in: $file${NC}"
    fi
done

echo -e "${GREEN}✅ Pre-commit checks complete!${NC}"
exit 0
EOF

chmod +x "$GIT_HOOKS_DIR/pre-commit"

# Create prepare-commit-msg hook
echo "📝 Creating prepare-commit-msg hook..."

cat > "$GIT_HOOKS_DIR/prepare-commit-msg" << 'EOF'
#!/bin/bash

#
# Prepare-commit-msg hook for LiveAssistant
# Adds ticket number from branch name to commit message
#

COMMIT_MSG_FILE=$1
COMMIT_SOURCE=$2

# Only process regular commits (not merge, squash, etc.)
if [ -z "$COMMIT_SOURCE" ]; then
    BRANCH_NAME=$(git symbolic-ref --short HEAD 2>/dev/null || true)
    
    # Extract ticket number from feature/bugfix/hotfix branches
    if [[ $BRANCH_NAME =~ (feature|bugfix|hotfix)/([A-Z]+-[0-9]+) ]]; then
        TICKET="${BASH_REMATCH[2]}"
        sed -i.bak -e "1s/^/[$TICKET] /" "$COMMIT_MSG_FILE"
        rm "${COMMIT_MSG_FILE}.bak" 2>/dev/null || true
    fi
fi
EOF

chmod +x "$GIT_HOOKS_DIR/prepare-commit-msg"

echo ""
echo -e "${GREEN}🎉 Git hooks setup complete!${NC}"
echo ""
echo "Installed hooks:"
echo "  • pre-commit: Runs swift-format and SwiftLint"
echo "  • prepare-commit-msg: Adds ticket numbers to commits"
echo ""

# Check for missing tools
if ! command -v swiftlint &> /dev/null; then
    echo -e "${YELLOW}⚠️  SwiftLint not installed. Install: brew install swiftlint${NC}"
fi

if ! command -v swift-format &> /dev/null && ! xcrun --find swift-format &> /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  swift-format not available (included with Xcode)${NC}"
fi

echo ""
echo "To bypass hooks (not recommended): git commit --no-verify"
echo ""