#!/bin/bash
# Cleanup old PR comments from deleted workflows
# Usage: ./scripts/cleanup-old-pr-comments.sh <PR_NUMBER>

set -e

PR_NUMBER="${1:-}"

if [ -z "$PR_NUMBER" ]; then
    echo "Usage: $0 <PR_NUMBER>"
    echo ""
    echo "Example: $0 2"
    echo ""
    echo "This will remove old bot comments from deleted workflows"
    exit 1
fi

echo "🔍 Finding old bot comments on PR #${PR_NUMBER}..."

# Get all bot comment IDs and their first line
BOT_COMMENT_LIST=$(gh api "/repos/:owner/:repo/issues/${PR_NUMBER}/comments" \
    --jq '.[] | select(.user.type == "Bot") | "Comment ID: \(.id) - \(.body | split("\n") | .[0])"' 2>/dev/null)

if [ -z "$BOT_COMMENT_LIST" ]; then
    echo "✅ No bot comments found on PR #${PR_NUMBER}"
    exit 0
fi

echo ""
echo "Found bot comments:"
echo "$BOT_COMMENT_LIST"
echo ""

# Look for old "Code Coverage Report" comments (from deleted code-coverage.yml)
OLD_COVERAGE_COMMENTS=$(gh api "/repos/:owner/:repo/issues/${PR_NUMBER}/comments" \
    --jq '[.[] | select(.user.type == "Bot" and (.body | contains("Code Coverage Report")))] | .[].id' 2>/dev/null)

if [ -n "$OLD_COVERAGE_COMMENTS" ]; then
    echo "🗑️  Found old 'Code Coverage Report' comments to delete:"
    echo "$OLD_COVERAGE_COMMENTS"
    echo ""
    
    for COMMENT_ID in $OLD_COVERAGE_COMMENTS; do
        echo "Deleting comment ID: $COMMENT_ID..."
        gh api -X DELETE "/repos/:owner/:repo/issues/comments/${COMMENT_ID}"
        echo "✅ Deleted"
    done
    
    echo ""
    echo "✅ Cleanup complete! Old comments removed from PR #${PR_NUMBER}"
else
    echo "✅ No old 'Code Coverage Report' comments found"
fi

echo ""
echo "📝 Current bot comments on PR #${PR_NUMBER}:"
gh api "/repos/:owner/:repo/issues/${PR_NUMBER}/comments" \
    --jq '[.[] | select(.user.type == "Bot")] | .[].body | split("\n") | .[0]' 2>/dev/null

