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

# Get all comments on the PR
COMMENTS=$(gh api "/repos/:owner/:repo/issues/${PR_NUMBER}/comments" --jq '.[] | select(.user.type == "Bot") | {id: .id, body: .body | split("\n") | .[0]}')

if [ -z "$COMMENTS" ]; then
    echo "✅ No bot comments found on PR #${PR_NUMBER}"
    exit 0
fi

echo ""
echo "Found bot comments:"
echo "$COMMENTS" | jq -r '"Comment ID: \(.id) - \(.body)"'
echo ""

# Look for old "Code Coverage Report" comments (from deleted code-coverage.yml)
OLD_COVERAGE_COMMENTS=$(echo "$COMMENTS" | jq -r 'select(.body | contains("Code Coverage Report")) | .id')

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
gh api "/repos/:owner/:repo/issues/${PR_NUMBER}/comments" --jq '.[] | select(.user.type == "Bot") | .body | split("\n") | .[0]'

