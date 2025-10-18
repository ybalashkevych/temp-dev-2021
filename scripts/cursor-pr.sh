#!/bin/bash

#
# cursor-pr.sh
# LiveAssistant
#
# Multi-purpose PR management tool
# Usage: ./scripts/cursor-pr.sh [create|merge|process|respond] [args...]
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        INFO)
            echo -e "${BLUE}[${timestamp}] [INFO]${NC} ${message}"
            ;;
        SUCCESS)
            echo -e "${GREEN}[${timestamp}] [SUCCESS]${NC} ${message}"
            ;;
        WARNING)
            echo -e "${YELLOW}[${timestamp}] [WARNING]${NC} ${message}"
            ;;
        ERROR)
            echo -e "${RED}[${timestamp}] [ERROR]${NC} ${message}"
            ;;
    esac
}

# Check if gh is installed and authenticated
check_gh() {
    if ! command -v gh &> /dev/null; then
        log ERROR "GitHub CLI (gh) is not installed"
        echo "Install with: brew install gh"
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        log ERROR "GitHub CLI is not authenticated"
        echo "Run: gh auth login"
        exit 1
    fi
}

# Show usage
usage() {
    echo "Usage: $0 <command> [args...]"
    echo ""
    echo "Commands:"
    echo "  create <issue-number> <branch-name> \"<title>\" \"<body>\""
    echo "    Create a new pull request"
    echo ""
    echo "  merge <pr-number>"
    echo "    Merge an approved pull request"
    echo ""
    echo "  process <pr-number>"
    echo "    Process PR feedback and create feedback file"
    echo ""
    echo "  respond <pr-number> \"<changes-summary>\""
    echo "    Respond to PR feedback after making changes"
    echo ""
    echo "Examples:"
    echo "  $0 create 42 feat/issue-42-dark-mode \"#42: (feat): Add dark mode\" \"Description...\""
    echo "  $0 merge 42"
    echo "  $0 process 42"
    echo "  $0 respond 42 \"Fixed all issues\""
}

#
# CREATE command - Create a new pull request
#
cmd_create() {
    if [ $# -lt 4 ]; then
        echo -e "${RED}❌ Usage: $0 create <issue-number> <branch-name> \"<title>\" \"<body>\"${NC}"
        exit 1
    fi
    
    check_gh
    
    ISSUE_NUMBER=$1
    BRANCH_NAME=$2
    PR_TITLE=$3
    PR_BODY=$4
    
    log INFO "Creating Pull Request"
    
    # Validate title format
    if ! [[ $PR_TITLE =~ ^#[0-9]+:\ \([a-z]+\):\ .+ ]]; then
        log WARNING "Title doesn't match conventional commit format"
        echo "Expected: #<issue>: (type): description"
        echo ""
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check if branch exists locally
    if ! git rev-parse --verify "$BRANCH_NAME" &> /dev/null; then
        log ERROR "Branch '$BRANCH_NAME' does not exist locally"
        exit 1
    fi
    
    # Push branch
    log INFO "Pushing branch to origin..."
    if git push origin "$BRANCH_NAME" 2>&1; then
        log SUCCESS "Branch pushed"
    else
        log WARNING "Branch may already be pushed"
    fi
    
    # Check if PR already exists
    EXISTING_PR=$(gh pr list --head "$BRANCH_NAME" --json number --jq '.[0].number' 2>/dev/null || echo "")
    
    if [ -n "$EXISTING_PR" ]; then
        log WARNING "PR already exists for branch '$BRANCH_NAME' (#$EXISTING_PR)"
        echo -e "${BLUE}🔗 View PR: $(gh pr view "$EXISTING_PR" --json url --jq .url)${NC}"
        exit 0
    fi
    
    # Create the PR
    log INFO "Creating pull request..."
    PR_URL=$(gh pr create \
        --title "$PR_TITLE" \
        --body "$PR_BODY" \
        --base main \
        --head "$BRANCH_NAME" 2>&1)
    
    if [ $? -eq 0 ]; then
        log SUCCESS "Pull request created successfully!"
        echo -e "${BLUE}🔗 $PR_URL${NC}"
        
        PR_NUMBER=$(gh pr view "$BRANCH_NAME" --json number --jq .number)
        
        # Link to issue if not already in body
        if ! echo "$PR_BODY" | grep -q "Closes #$ISSUE_NUMBER"; then
            log INFO "Linking to issue #$ISSUE_NUMBER..."
            gh pr comment "$PR_NUMBER" --body "Closes #$ISSUE_NUMBER"
        fi
        
        log SUCCESS "Done! PR #$PR_NUMBER is ready for review"
    else
        log ERROR "Failed to create pull request"
        echo "$PR_URL"
        exit 1
    fi
}

#
# MERGE command - Merge an approved pull request
#
cmd_merge() {
    if [ $# -lt 1 ]; then
        echo -e "${RED}❌ Usage: $0 merge <pr-number>${NC}"
        exit 1
    fi
    
    check_gh
    
    PR_NUMBER=$1
    
    log INFO "Checking PR #$PR_NUMBER status..."
    
    # Check if PR exists
    if ! gh pr view "$PR_NUMBER" &> /dev/null; then
        log ERROR "PR #$PR_NUMBER not found"
        exit 1
    fi
    
    # Get PR details
    PR_STATE=$(gh pr view "$PR_NUMBER" --json state --jq .state)
    PR_TITLE=$(gh pr view "$PR_NUMBER" --json title --jq .title)
    PR_REVIEW_DECISION=$(gh pr view "$PR_NUMBER" --json reviewDecision --jq .reviewDecision)
    PR_MERGEABLE=$(gh pr view "$PR_NUMBER" --json mergeable --jq .mergeable)
    
    echo -e "${BLUE}📋 PR Details:${NC}"
    echo "  Title: $PR_TITLE"
    echo "  State: $PR_STATE"
    echo "  Review Decision: $PR_REVIEW_DECISION"
    echo "  Mergeable: $PR_MERGEABLE"
    echo ""
    
    # Check state
    if [ "$PR_STATE" = "MERGED" ]; then
        log SUCCESS "PR #$PR_NUMBER is already merged"
        exit 0
    fi
    
    if [ "$PR_STATE" = "CLOSED" ]; then
        log WARNING "PR #$PR_NUMBER is closed (not merged)"
        exit 1
    fi
    
    # Check approval
    if [ "$PR_REVIEW_DECISION" != "APPROVED" ]; then
        log ERROR "PR #$PR_NUMBER is not approved yet"
        exit 1
    fi
    
    # Check mergeable
    if [ "$PR_MERGEABLE" != "MERGEABLE" ]; then
        log ERROR "PR #$PR_NUMBER is not mergeable"
        exit 1
    fi
    
    # Check CI
    log INFO "Checking CI status..."
    CI_STATUS=$(gh pr checks "$PR_NUMBER" --json state --jq '.[].state' | sort -u)
    
    if echo "$CI_STATUS" | grep -q "FAILURE\|ERROR"; then
        log ERROR "Some CI checks failed"
        gh pr checks "$PR_NUMBER"
        exit 1
    fi
    
    if echo "$CI_STATUS" | grep -q "PENDING"; then
        log WARNING "Some CI checks are still pending"
        read -p "Wait for checks? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            while echo "$CI_STATUS" | grep -q "PENDING"; do
                sleep 10
                CI_STATUS=$(gh pr checks "$PR_NUMBER" --json state --jq '.[].state' | sort -u)
            done
            if echo "$CI_STATUS" | grep -q "FAILURE\|ERROR"; then
                log ERROR "Some CI checks failed"
                exit 1
            fi
        else
            exit 1
        fi
    else
        log SUCCESS "All CI checks passed"
    fi
    
    # Confirm merge
    echo ""
    log WARNING "Ready to merge PR #$PR_NUMBER"
    read -p "Proceed with merge? (y/N) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Merge cancelled"
        exit 0
    fi
    
    # Merge
    log INFO "Merging PR #$PR_NUMBER..."
    if gh pr merge "$PR_NUMBER" --rebase --delete-branch; then
        log SUCCESS "PR #$PR_NUMBER merged successfully!"
    else
        log ERROR "Failed to merge PR #$PR_NUMBER"
        exit 1
    fi
}

#
# PROCESS command - Process PR feedback
#
cmd_process() {
    if [ $# -lt 1 ]; then
        echo -e "${RED}❌ Usage: $0 process <pr-number>${NC}"
        exit 1
    fi
    
    check_gh
    
    PR_NUMBER=$1
    
    log INFO "Processing PR #$PR_NUMBER"
    
    # Verify PR exists
    if ! gh pr view "$PR_NUMBER" &> /dev/null; then
        log ERROR "PR #${PR_NUMBER} not found"
        exit 1
    fi
    
    # Get PR details
    log INFO "Fetching PR details..."
    PR_DATA=$(gh pr view "$PR_NUMBER" --json number,title,headRefName,comments,reviews)
    
    BRANCH=$(echo "$PR_DATA" | jq -r '.headRefName')
    PR_TITLE=$(echo "$PR_DATA" | jq -r '.title')
    
    log INFO "PR Title: $PR_TITLE"
    log INFO "Branch: $BRANCH"
    
    # Fetch and checkout
    log INFO "Fetching latest changes..."
    git fetch origin
    git fetch origin main
    
    log INFO "Checking out PR branch..."
    if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
        git checkout "$BRANCH"
        if ! git diff-index --quiet HEAD --; then
            log INFO "Stashing pending changes..."
            git stash push -m "Auto-stash before PR processing"
        fi
    else
        git checkout -b "$BRANCH" "origin/$BRANCH"
    fi
    
    # Create feedback file
    log INFO "Creating feedback file..."
    FEEDBACK_FILE=".cursor-feedback.txt"
    
    echo "# PR #${PR_NUMBER} Feedback" > "$FEEDBACK_FILE"
    echo "" >> "$FEEDBACK_FILE"
    echo "**Title:** $PR_TITLE" >> "$FEEDBACK_FILE"
    echo "**Branch:** $BRANCH" >> "$FEEDBACK_FILE"
    echo "" >> "$FEEDBACK_FILE"
    
    # Add comments (exclude resolved)
    COMMENTS=$(echo "$PR_DATA" | jq -r '.comments[]? | select(.isResolved != true) | "**\(.author.login)** commented:\n\(.body)\n"')
    if [ -n "$COMMENTS" ]; then
        echo "## Comments" >> "$FEEDBACK_FILE"
        echo "$COMMENTS" >> "$FEEDBACK_FILE"
    fi
    
    # Add reviews
    REVIEWS=$(echo "$PR_DATA" | jq -r '.reviews[]? | "**\(.author.login)** \(.state):\n\(.body)\n"')
    if [ -n "$REVIEWS" ]; then
        echo "## Reviews" >> "$FEEDBACK_FILE"
        echo "$REVIEWS" >> "$FEEDBACK_FILE"
    fi
    
    # Add inline review comments (comments on specific code lines, exclude resolved)
    log INFO "Fetching inline code review comments..."
    REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
    REVIEW_COMMENTS=$(gh api "repos/${REPO}/pulls/${PR_NUMBER}/comments" --jq '.[] | select(.in_reply_to_id == null) | "**\(.user.login)** commented on `\(.path):\(.original_line // .line)`:\n> \(.body)\n"' 2>/dev/null)
    
    if [ -n "$REVIEW_COMMENTS" ]; then
        echo "## Inline Code Review Comments" >> "$FEEDBACK_FILE"
        echo "" >> "$FEEDBACK_FILE"
        echo "$REVIEW_COMMENTS" >> "$FEEDBACK_FILE"
        log INFO "Added $(echo "$REVIEW_COMMENTS" | grep -c "commented on") inline review comments"
    fi
    
    log SUCCESS "Feedback file created: $FEEDBACK_FILE"
    log INFO "Process the feedback and make necessary changes"
    log INFO "When done, run: ./scripts/cursor-pr.sh respond $PR_NUMBER \"Your summary\""
}

#
# RESPOND command - Respond to PR feedback
#
cmd_respond() {
    if [ $# -lt 2 ]; then
        echo -e "${RED}❌ Usage: $0 respond <pr-number> \"<changes-summary>\"${NC}"
        exit 1
    fi
    
    check_gh
    
    PR_NUMBER=$1
    CHANGES_SUMMARY=$2
    
    log INFO "Responding to feedback on PR #${PR_NUMBER}"
    
    CURRENT_BRANCH=$(git branch --show-current)
    log INFO "Current branch: $CURRENT_BRANCH"
    
    # Run self-review
    log INFO "Running self-review checks..."
    if ./scripts/cursor-quality.sh review; then
        log SUCCESS "Self-review passed"
        
        # Push changes
        log INFO "Pushing changes..."
        if git push --force-with-lease origin "$CURRENT_BRANCH"; then
            log SUCCESS "Changes pushed"
            
            # Post comment
            log INFO "Posting comment on PR..."
            COMMENT="✅ **Feedback Addressed**

$CHANGES_SUMMARY

All self-review checks passed:
- ✅ SwiftLint (strict mode)
- ✅ swift-format
- ✅ Build successful
- ✅ Tests passing
- ✅ Code coverage >= 20%

Ready for re-review."
            
            if gh pr comment "$PR_NUMBER" --body "$COMMENT"; then
                log SUCCESS "Comment posted"
                
                # Update PR description with recent commits
                log INFO "Updating PR description..."
                REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
                COMMITS=$(git log origin/main..HEAD --oneline --no-decorate 2>/dev/null)
                
                if [ -n "$COMMITS" ]; then
                    CURRENT_BODY=$(gh pr view "$PR_NUMBER" --json body -q .body 2>/dev/null)
                    
                    # Remove old auto-updated section if exists
                    if echo "$CURRENT_BODY" | grep -q "## Recent Changes (Auto-updated)"; then
                        CURRENT_BODY=$(echo "$CURRENT_BODY" | sed '/## Recent Changes (Auto-updated)/,$d')
                    fi
                    
                    # Create changes section
                    CHANGES_SECTION="

---

## Recent Changes (Auto-updated)

$(echo "$COMMITS" | sed 's/^/- /')

**Last Update:** $(date '+%Y-%m-%d %H:%M:%S')  
**Status:** ✅ All tests passing  
**Review:** Ready for re-review"
                    
                    if gh pr edit "$PR_NUMBER" --body "${CURRENT_BODY}${CHANGES_SECTION}"; then
                        log SUCCESS "PR description updated with commit history"
                    else
                        log WARNING "Failed to update PR description"
                    fi
                fi
                
                log SUCCESS "Response complete! PR is ready for re-review"
            else
                log ERROR "Failed to post comment"
                exit 1
            fi
        else
            log ERROR "Failed to push changes"
            exit 1
        fi
    else
        log ERROR "Self-review failed. Fix issues before responding"
        exit 1
    fi
}

# Main command dispatcher
case "${1:-}" in
    create)
        shift
        cmd_create "$@"
        ;;
    merge)
        shift
        cmd_merge "$@"
        ;;
    process)
        shift
        cmd_process "$@"
        ;;
    respond)
        shift
        cmd_respond "$@"
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

