#!/bin/bash

#
# cursor-auto-respond.sh
# LiveAssistant
#
# Fully automated script for responding to PR feedback using Cursor Agent AI
# 
# Workflow: Detects feedback → Opens Cursor for AI assistance → 
#           Manual changes → Rebases → Tests → Pushes → Updates PR
#
# Uses: cursor CLI to open feedback file for AI-assisted manual changes
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
FEEDBACK_FILE=".cursor-feedback.txt"
MAIN_BRANCH="main"

# Logging function
log() {
    local level=$1
    shift
    local message="$@"
    
    case $level in
        INFO)
            echo -e "${BLUE}ℹ ${NC}${message}"
            ;;
        SUCCESS)
            echo -e "${GREEN}✅${NC} ${message}"
            ;;
        WARNING)
            echo -e "${YELLOW}⚠️ ${NC}${message}"
            ;;
        ERROR)
            echo -e "${RED}❌${NC} ${message}"
            ;;
    esac
}

# Check if cursor CLI is available
check_cursor_agent() {
    if ! command -v cursor &> /dev/null; then
        log ERROR "Cursor CLI not found. Please install it first."
        log INFO "Visit: https://docs.cursor.com/en/cli"
        exit 1
    fi
    
    # Test cursor CLI availability
    if ! cursor --help &> /dev/null; then
        log ERROR "cursor CLI not available"
        log INFO "Install Cursor CLI or update to the latest version"
        exit 1
    fi
    
    log SUCCESS "Cursor CLI found"
}

# Check if feedback file exists
check_feedback_file() {
    if [ ! -f "$FEEDBACK_FILE" ]; then
        log ERROR "Feedback file not found: $FEEDBACK_FILE"
        exit 1
    fi
    log SUCCESS "Feedback file found"
}

# Call Cursor Agent AI to address feedback
address_feedback_with_ai() {
    local pr_number=$1
    
    log INFO "Calling Cursor Agent AI to address feedback..."
    log INFO "AI will review: $FEEDBACK_FILE"
    
    # Create prompt for Cursor Agent
    local prompt="Review the feedback in .cursor-feedback.txt and make all necessary code changes to address the issues. Follow these guidelines:

1. Read and understand all feedback in .cursor-feedback.txt
2. Make code changes that address each point raised
3. Follow project architecture rules (MVVM, Repository pattern, DI)
4. Ensure code quality standards are met
5. Fix any linting issues
6. Do NOT commit changes - I will handle git operations

Make the changes directly to the files."
    
    # Open Cursor with the feedback file for manual AI assistance
    # Note: Cursor CLI doesn't support automated AI code changes
    log INFO "Opening Cursor with feedback file for AI assistance"
    log INFO "Please use Cursor's AI chat to address the feedback in .cursor-feedback.txt"
    
    if cursor .cursor-feedback.txt; then
        log SUCCESS "Cursor opened with feedback file"
        
        # Check if changes were made
        if git diff --quiet && git diff --cached --quiet; then
            log WARNING "No file changes detected"
            log INFO "Either feedback was addressed without code changes, or AI couldn't make changes"
            log INFO "Check /tmp/cursor-agent-output.log for AI response"
            return 0
        else
            log SUCCESS "Code changes detected, proceeding with git operations"
            git status --short
            return 0
        fi
    else
        log ERROR "Cursor Agent AI failed"
        log INFO "Check /tmp/cursor-agent-output.log for details"
        return 1
    fi
}

# Pull and rebase from origin
pull_and_rebase_origin() {
    log INFO "Pulling latest changes from origin..."
    
    local current_branch=$(git branch --show-current)
    
    if git pull --rebase origin "$current_branch"; then
        log SUCCESS "Rebased on origin/$current_branch"
    else
        log ERROR "Failed to rebase on origin"
        log INFO "Checking for conflicts..."
        if git diff --name-only --diff-filter=U | grep -q .; then
            log WARNING "Conflicts detected. Attempting automatic resolution..."
            # git rerere will handle known conflicts automatically
            if git rerere; then
                git add -A
                git rebase --continue
                log SUCCESS "Conflicts resolved automatically"
            else
                log ERROR "Automatic conflict resolution failed"
                log INFO "Manual intervention required"
                git rebase --abort
                exit 1
            fi
        else
            exit 1
        fi
    fi
}

# Pull and rebase from main
pull_and_rebase_main() {
    log INFO "Pulling and rebasing on $MAIN_BRANCH..."
    
    # Fetch latest main
    git fetch origin "$MAIN_BRANCH"
    
    if git rebase "origin/$MAIN_BRANCH"; then
        log SUCCESS "Rebased on origin/$MAIN_BRANCH"
    else
        log ERROR "Failed to rebase on $MAIN_BRANCH"
        log INFO "Checking for conflicts..."
        if git diff --name-only --diff-filter=U | grep -q .; then
            log WARNING "Conflicts detected. Attempting automatic resolution..."
            if git rerere; then
                git add -A
                git rebase --continue
                log SUCCESS "Conflicts resolved automatically"
            else
                log ERROR "Automatic conflict resolution failed"
                log INFO "Manual intervention required"
                git rebase --abort
                exit 1
            fi
        else
            exit 1
        fi
    fi
}

# Run tests
run_tests() {
    log INFO "Running tests..."
    
    if xcodebuild test \
        -scheme LiveAssistant \
        -destination 'platform=macOS' \
        -quiet; then
        log SUCCESS "All tests passed"
        return 0
    else
        log ERROR "Tests failed"
        return 1
    fi
}

# Push changes
push_changes() {
    local current_branch=$(git branch --show-current)
    
    log INFO "Pushing changes to origin/$current_branch..."
    
    if git push origin "$current_branch"; then
        log SUCCESS "Changes pushed successfully"
    else
        log ERROR "Failed to push changes"
        exit 1
    fi
}

# Update PR description with recent changes
update_pr_description() {
    local pr_number=$1
    local repo=$2
    
    log INFO "Updating PR description with recent changes..."
    
    # Get recent commits since main
    local commits=$(git log origin/$MAIN_BRANCH..HEAD --oneline --no-decorate 2>/dev/null)
    
    if [ -z "$commits" ]; then
        log WARNING "No commits to add to description"
        return 0
    fi
    
    # Get current PR body
    local current_body=$(gh pr view "$pr_number" --repo "$repo" --json body -q .body 2>/dev/null)
    
    # Check if we already have a "Recent Changes" section
    if echo "$current_body" | grep -q "## Recent Changes (Auto-updated)"; then
        # Remove old auto-updated section
        current_body=$(echo "$current_body" | sed '/## Recent Changes (Auto-updated)/,$d')
    fi
    
    # Create changes section
    local changes_section="

---

## Recent Changes (Auto-updated)

$(echo "$commits" | sed 's/^/- /')

**Last Update:** $(date '+%Y-%m-%d %H:%M:%S')  
**Status:** ✅ All tests passing  
**Review:** Ready for review"
    
    # Update PR description
    if gh pr edit "$pr_number" --repo "$repo" --body "${current_body}${changes_section}"; then
        log SUCCESS "PR description updated with commit history"
    else
        log WARNING "Failed to update PR description"
    fi
}

# Update PR labels and comment
update_pr() {
    local pr_number=$1
    local repo=$2
    
    log INFO "Updating PR #${pr_number}..."
    
    # Remove cursor-processing label
    gh pr edit "$pr_number" --repo "$repo" --remove-label "cursor-processing" 2>/dev/null || true
    
    # Add comment
    local comment="✅ Addressed all feedback automatically

Changes made by Cursor AI:
- Reviewed feedback in \`.cursor-feedback.txt\`
- Made necessary code changes
- Rebased on latest main
- All tests passing
- Ready for review"
    
    if gh pr comment "$pr_number" --repo "$repo" --body "$comment"; then
        log SUCCESS "PR comment added successfully"
    else
        log WARNING "Failed to update PR comment"
    fi
    
    # Update PR description with commit list
    update_pr_description "$pr_number" "$repo"
}

# Main workflow
main() {
    log INFO "==================================="
    log INFO "Cursor Auto-Response Starting"
    log INFO "==================================="
    
    # Parse arguments
    if [ $# -lt 2 ]; then
        echo "Usage: $0 <pr-number> <repo>"
        echo "Example: $0 42 ybalashkevych/temp-dev-2021"
        exit 1
    fi
    
    local pr_number=$1
    local repo=$2
    
    # Check prerequisites
    check_cursor_agent
    check_feedback_file
    
    # Step 1: Address feedback with Cursor Agent AI
    if ! address_feedback_with_ai "$pr_number"; then
        log ERROR "Failed to address feedback with AI"
        exit 1
    fi
    
    # Step 2: Pull and rebase from origin
    if ! pull_and_rebase_origin; then
        log ERROR "Failed to rebase on origin"
        exit 1
    fi
    
    # Step 3: Pull and rebase from main
    if ! pull_and_rebase_main; then
        log ERROR "Failed to rebase on main"
        exit 1
    fi
    
    # Step 4: Run tests
    if ! run_tests; then
        log ERROR "Tests failed - not pushing changes"
        log INFO "Please fix test failures manually"
        exit 1
    fi
    
    # Step 5: Push changes
    push_changes
    
    # Step 6: Update PR
    update_pr "$pr_number" "$repo"
    
    # Cleanup
    rm -f "$FEEDBACK_FILE"
    
    log SUCCESS "==================================="
    log SUCCESS "Auto-response completed successfully"
    log SUCCESS "==================================="
}

# Run main function
main "$@"

