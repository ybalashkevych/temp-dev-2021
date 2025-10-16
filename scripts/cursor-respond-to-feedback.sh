#!/bin/bash

#
# cursor-respond-to-feedback.sh
# LiveAssistant
#
# Responds to PR feedback after Cursor makes changes
# 1. Runs self-review checks
# 2. Pushes changes if checks pass
# 3. Comments on PR with summary
# 4. Updates labels
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check arguments
if [ $# -lt 2 ]; then
    echo -e "${RED}Usage: $0 <pr-number> <changes-summary>${NC}"
    echo ""
    echo "Example:"
    echo "  $0 42 \"Fixed SwiftLint warnings and updated tests\""
    exit 1
fi

PR_NUMBER=$1
CHANGES_SUMMARY=$2

# Logging function
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        INFO)
            echo -e "${BLUE}[${timestamp}] [PR#${PR_NUMBER}] [INFO]${NC} ${message}"
            ;;
        SUCCESS)
            echo -e "${GREEN}[${timestamp}] [PR#${PR_NUMBER}] [SUCCESS]${NC} ${message}"
            ;;
        WARNING)
            echo -e "${YELLOW}[${timestamp}] [PR#${PR_NUMBER}] [WARNING]${NC} ${message}"
            ;;
        ERROR)
            echo -e "${RED}[${timestamp}] [PR#${PR_NUMBER}] [ERROR]${NC} ${message}"
            ;;
    esac
}

log INFO "Responding to feedback on PR #${PR_NUMBER}"

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)
log INFO "Current branch: $CURRENT_BRANCH"

# Run self-review
log INFO "Running self-review checks..."
echo ""

if ./scripts/cursor-self-review.sh; then
    log SUCCESS "Self-review passed"
    
    # Push changes
    log INFO "Pushing changes to origin..."
    if git push origin "$CURRENT_BRANCH"; then
        log SUCCESS "Changes pushed successfully"
        
        # Post comment on PR
        log INFO "Posting comment on PR..."
        
        COMMENT_BODY="✅ **Feedback Addressed**

${CHANGES_SUMMARY}

## Changes Made
$(git log origin/${CURRENT_BRANCH}..HEAD --oneline --no-decorate | sed 's/^/- /')

## Verification
- ✅ Self-review checks passed
- ✅ SwiftLint validation passed
- ✅ swift-format validation passed
- ✅ All tests passed
- ✅ Build successful

Ready for re-review.

---
*Automated response by Cursor*"
        
        if gh pr comment "$PR_NUMBER" --body "$COMMENT_BODY"; then
            log SUCCESS "Comment posted on PR"
        else
            log WARNING "Failed to post comment on PR"
        fi
        
        # Update labels
        log INFO "Updating PR labels..."
        
        # Remove "cursor-processing" label
        gh pr edit "$PR_NUMBER" --remove-label "cursor-processing" 2>/dev/null || log WARNING "Could not remove 'cursor-processing' label"
        
        # Add "ready-for-review" label
        gh pr edit "$PR_NUMBER" --add-label "ready-for-review" 2>/dev/null || log WARNING "Could not add 'ready-for-review' label"
        
        log SUCCESS "Labels updated"
        
        echo ""
        echo "======================================"
        echo "✅ Response Complete"
        echo "======================================"
        echo ""
        echo "PR #${PR_NUMBER} is ready for re-review"
        echo "View PR: https://github.com/ybalashkevych/LiveAssistant/pull/${PR_NUMBER}"
        echo ""
        
        exit 0
        
    else
        log ERROR "Failed to push changes"
        exit 1
    fi
    
else
    log ERROR "Self-review checks failed"
    log WARNING "Not pushing changes until checks pass"
    
    # Post comment about failure
    FAILURE_COMMENT="⚠️ **Processing Feedback**

Made changes to address feedback:

${CHANGES_SUMMARY}

However, self-review checks failed. Working on fixing the issues...

## Failed Checks
Please check the following:
- SwiftLint violations
- swift-format violations  
- Build errors
- Test failures

Will update once all checks pass.

---
*Automated response by Cursor*"
    
    if gh pr comment "$PR_NUMBER" --body "$FAILURE_COMMENT"; then
        log INFO "Posted failure comment on PR"
    fi
    
    echo ""
    echo "======================================"
    echo "❌ Self-Review Failed"
    echo "======================================"
    echo ""
    echo "Please fix the issues shown above and try again:"
    echo "  ./scripts/cursor-respond-to-feedback.sh ${PR_NUMBER} \"<summary>\""
    echo ""
    
    exit 1
fi

