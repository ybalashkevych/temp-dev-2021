#!/bin/bash

#
# setup.sh
# LiveAssistant
#
# Setup and configuration tool
# Usage: ./scripts/setup.sh [install|update]
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GIT_HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

# Check if we're in a git repository
check_git_repo() {
    if [ ! -d "$PROJECT_ROOT/.git" ]; then
        echo -e "${RED}❌ Error: Not a git repository${NC}"
        exit 1
    fi
}

# Install git hooks
install_git_hooks() {
    echo -e "${BLUE}📝 Creating pre-commit hook...${NC}"
    
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
    
    if ! find LiveAssistant -name "*.swift" -not -path "*/Generated/*" -exec $SWIFT_FORMAT_CMD lint --strict {} + > /dev/null 2>&1; then
        echo -e "${RED}❌ Code formatting issues found${NC}"
        echo "Fix with: find LiveAssistant -name \"*.swift\" -not -path \"*/Generated/*\" -exec swift-format format --in-place {} +"
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
        echo -e "${RED}❌ SwiftLint check failed${NC}"
        exit 1
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
    
    echo -e "${BLUE}📝 Creating prepare-commit-msg hook...${NC}"
    
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
    if [[ $BRANCH_NAME =~ (feature|bugfix|hotfix|feat|fix)/([A-Z]+-[0-9]+|issue-[0-9]+) ]]; then
        TICKET="${BASH_REMATCH[2]}"
        sed -i.bak -e "1s/^/[$TICKET] /" "$COMMIT_MSG_FILE"
        rm "${COMMIT_MSG_FILE}.bak" 2>/dev/null || true
    fi
fi
EOF

    chmod +x "$GIT_HOOKS_DIR/prepare-commit-msg"
    
    echo -e "${GREEN}✅ Git hooks installed${NC}"
}

# Check for missing tools
check_tools() {
    echo ""
    echo -e "${BLUE}📦 Checking development tools...${NC}"
    
    MISSING_TOOLS=false
    
    if ! command -v swiftlint &> /dev/null; then
        echo -e "${YELLOW}⚠️  SwiftLint not installed${NC}"
        echo "   Install: brew install swiftlint"
        MISSING_TOOLS=true
    else
        echo -e "${GREEN}✅ SwiftLint${NC}"
    fi
    
    if ! command -v swift-format &> /dev/null && ! xcrun --find swift-format &> /dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  swift-format not available${NC}"
        echo "   Install: brew install swift-format"
        MISSING_TOOLS=true
    else
        echo -e "${GREEN}✅ swift-format${NC}"
    fi
    
    if ! command -v gh &> /dev/null; then
        echo -e "${YELLOW}⚠️  GitHub CLI not installed${NC}"
        echo "   Install: brew install gh"
        MISSING_TOOLS=true
    else
        echo -e "${GREEN}✅ GitHub CLI${NC}"
        
        if ! gh auth status &> /dev/null; then
            echo -e "${YELLOW}⚠️  GitHub CLI not authenticated${NC}"
            echo "   Run: gh auth login"
        fi
    fi
    
    if [ "$MISSING_TOOLS" = true ]; then
        echo ""
        echo -e "${YELLOW}Some tools are missing. Install them for full functionality.${NC}"
    fi
}

#
# INSTALL command - Initial setup
#
cmd_install() {
    echo -e "${BLUE}🔧 Setting up LiveAssistant development environment...${NC}\n"
    
    check_git_repo
    install_git_hooks
    check_tools
    
    echo ""
    echo -e "${GREEN}🎉 Setup complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Verify setup: ./scripts/cursor-quality.sh verify"
    echo "  2. Open in Xcode: open LiveAssistant.xcodeproj"
    echo "  3. Build and run: Cmd+R"
    echo ""
    echo "Optional: Start background daemon for PR monitoring"
    echo "  cd scripts/automation && cursor-daemon daemon"
    echo ""
    echo "To bypass hooks (not recommended): git commit --no-verify"
    echo ""
}

#
# UPDATE command - Update git hooks and configuration
#
cmd_update() {
    echo -e "${BLUE}🔄 Updating LiveAssistant configuration...${NC}\n"
    
    check_git_repo
    
    # Backup existing hooks
    if [ -f "$GIT_HOOKS_DIR/pre-commit" ]; then
        cp "$GIT_HOOKS_DIR/pre-commit" "$GIT_HOOKS_DIR/pre-commit.backup"
        echo -e "${BLUE}📦 Backed up existing hooks${NC}"
    fi
    
    install_git_hooks
    check_tools
    
    echo ""
    echo -e "${GREEN}✅ Configuration updated!${NC}"
    echo ""
}

# Usage
usage() {
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  install    Initial setup of development environment"
    echo "  update     Update git hooks and configuration"
    echo ""
    echo "Examples:"
    echo "  $0 install    # First time setup"
    echo "  $0 update     # After pulling changes"
}

# Main command dispatcher
case "${1:-}" in
    install)
        cmd_install
        ;;
    update)
        cmd_update
        ;;
    ""|--help|-h)
        usage
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        usage
        exit 1
        ;;
esac

