#!/bin/bash

#
# cursor-respond-interactive.sh
# LiveAssistant
#
# Interactive response handler for PR feedback
# Responds as @ybalashkevych to commands: analyze, implement, plan
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
FEEDBACK_FILE=".cursor-feedback.txt"
MAIN_BRANCH="main"

# Logging
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

# Find the thread where a command was issued
find_command_thread() {
    local pr_number=$1
    local repo=$2
    local command=$3  # "plan" or "implement"
    
    # Check inline review comments first
    local thread_data=$(gh api "repos/${repo}/pulls/${pr_number}/comments?per_page=50" \
        --jq ".[-50:] | .[] | select(.body | contains(\"@ybalashkevych ${command}\")) | {id: .id, path: .path, body: .body, line: (.line // .original_line), in_reply_to: .in_reply_to_id}" \
        2>/dev/null | tail -1)
    
    if [ -z "$thread_data" ]; then
        # Try PR-level comments
        thread_data=$(gh api "repos/${repo}/issues/${pr_number}/comments?per_page=50" \
            --jq ".[-50:] | .[] | select(.body | contains(\"@ybalashkevych ${command}\")) | {id: .id, body: .body, type: \"pr_comment\"}" \
            2>/dev/null | tail -1)
    fi
    
    echo "$thread_data"
}

# Get full thread conversation
get_thread_conversation() {
    local pr_number=$1
    local repo=$2
    local comment_id=$3
    local comment_type=${4:-"review"}
    
    if [ "$comment_type" = "pr_comment" ]; then
        # PR-level comment - just return it
        gh api "repos/${repo}/issues/comments/${comment_id}" \
            --jq '"\(.user.login): \(.body)"' 2>/dev/null
    else
        # Review comment - get parent and all replies
        local parent_id=$(gh api "repos/${repo}/pulls/comments/${comment_id}" \
            --jq '.in_reply_to_id // .id' 2>/dev/null)
        
        gh api "repos/${repo}/pulls/${pr_number}/comments?per_page=100" \
            --jq "[.[] | select(.id == ${parent_id} or .in_reply_to_id == ${parent_id})] | sort_by(.created_at) | .[] | \"\\(.user.login): \\(.body)\"" \
            2>/dev/null
    fi
}

# Check prerequisites
check_prerequisites() {
    if ! command -v gh &> /dev/null; then
        log ERROR "GitHub CLI (gh) not found"
        exit 1
    fi
    
    if ! command -v cursor &> /dev/null; then
        log WARNING "Cursor CLI not found, some features may not work"
    fi
}

# Check if a message needs a response (question, command, or request)
needs_response() {
    local msg_body="$1"
    
    # Skip if empty or null
    if [ -z "$msg_body" ] || [ "$msg_body" = "null" ]; then
        return 1
    fi
    
    # Skip comments that are primarily numbers (>=70% of chars are digits)
    local total_chars=$(echo "$msg_body" | wc -c | tr -d ' ')
    local num_chars=$(echo "$msg_body" | tr -cd '0-9' | wc -c | tr -d ' ')
    if [ "$total_chars" -gt 10 ] && [ "$num_chars" -gt 0 ]; then
        local percent=$((num_chars * 100 / total_chars))
        if [ "$percent" -ge 70 ]; then
            return 1  # Skip number-heavy comments
        fi
    fi
    
    # Skip lists of 3+ numbers (timestamps, IDs, etc)
    if echo "$msg_body" | grep -qE '([0-9]+[[:space:],]*){3,}'; then
        return 1
    fi
    
    # Check for clear indicators of needing a response
    if echo "$msg_body" | grep -qiE '(\?|@ybalashkevych (implement|fix|plan)|can you|could you|please|do it|implement this|fix this|address this)'; then
        return 0  # Needs response
    fi
    
    # Check if it's a short message (likely a follow-up)
    local word_count=$(echo "$msg_body" | wc -w | tr -d ' ')
    if [ "$word_count" -lt 15 ]; then
        # Short message - likely needs response unless it looks like acknowledgment
        if ! echo "$msg_body" | grep -qiE '(thanks|thank you|ok|okay|great|perfect|sounds good|got it|understood)'; then
            return 0  # Needs response
        fi
    fi
    
    return 1  # Doesn't need response
}

# Analyze feedback and reply in threads
analyze_feedback() {
    local pr_number=$1
    local repo=$2
    
    log INFO "Analyzing feedback for PR #${pr_number}..."
    
    if [ ! -f "$FEEDBACK_FILE" ]; then
        log ERROR "No feedback file found: $FEEDBACK_FILE"
        exit 1
    fi
    
    local replied_count=0
    
    # Get parent comment IDs (threads start here) - comments with no in_reply_to_id
    local parent_ids=$(gh api "repos/${repo}/pulls/${pr_number}/comments?per_page=100" \
        --jq '[.[] | select(.in_reply_to_id == null)] | .[].id' 2>/dev/null)
    
    if [ -n "$parent_ids" ]; then
        local total_parents=$(echo "$parent_ids" | wc -l | tr -d ' ')
        log INFO "Found ${total_parents} parent comments to check"
        
        local processed=0
        while IFS= read -r parent_id; do
            [ -z "$parent_id" ] && continue
            ((processed++))
            log INFO "Processing thread ${processed}/${total_parents}: #${parent_id}"
            
            # Count replies from ybalashkevych in this thread (excluding parent)
            local my_reply_count=$(gh api "repos/${repo}/pulls/${pr_number}/comments?per_page=100" \
                --jq "[.[] | select(.in_reply_to_id == $parent_id and .user.login == \"ybalashkevych\")] | length" 2>/dev/null)
            
            # Skip if I've already replied 2+ times (likely infinite loop)
            if [ "$my_reply_count" -ge 2 ]; then
                log INFO "Skipping thread #${parent_id} - already replied ${my_reply_count} times"
                continue
            fi
            
            # Get the last message in the thread (from parent + all replies, sorted by time)
            local last_msg_body=$(gh api "repos/${repo}/pulls/${pr_number}/comments?per_page=100" \
                --jq "[.[] | select(.id == $parent_id or .in_reply_to_id == $parent_id)] | sort_by(.created_at) | .[-1].body" 2>/dev/null)
            local last_msg_user=$(gh api "repos/${repo}/pulls/${pr_number}/comments?per_page=100" \
                --jq "[.[] | select(.id == $parent_id or .in_reply_to_id == $parent_id)] | sort_by(.created_at) | .[-1].user.login" 2>/dev/null)
            
            # Skip if last message body is null/empty
            if [ -z "$last_msg_body" ] || [ "$last_msg_body" = "null" ]; then
                log WARNING "Skipping thread #${parent_id} - empty last message"
                continue
            fi
            
            # Skip bot comments entirely (cursor[bot], github-actions[bot], etc.)
            if [[ "$last_msg_user" =~ \[bot\]$ ]]; then
                log INFO "Skipping thread #${parent_id} - last message from bot: ${last_msg_user}"
                continue
            fi
            
            # Skip automated responses (old spam from before we fixed it)
            if echo "$last_msg_body" | grep -qiE "(I see you'?'?ve provided (a list of|three) numbers?|These (appear to be|look like).*(timestamp|ID)|Could you (help me understand|please clarify))"; then
                log INFO "Skipping thread #${parent_id} - looks like old automated response"
                continue
            fi
            
            # Skip if the last message is MY reply (avoid replying to myself)
            if [ "$last_msg_user" = "ybalashkevych" ] && [ "$my_reply_count" -gt 0 ]; then
                log INFO "Skipping thread #${parent_id} - last message is my own reply"
                continue
            fi
            
            # Check if the last message needs a response
            if ! needs_response "$last_msg_body"; then
                log INFO "Skipping thread #${parent_id} - last message doesn't need response"
                continue
            fi
            
            # Get parent comment details for context
            local parent_user=$(gh api "repos/${repo}/pulls/${pr_number}/comments?per_page=100" \
                --jq ".[] | select(.id == $parent_id) | .user.login" 2>/dev/null)
            local parent_body=$(gh api "repos/${repo}/pulls/${pr_number}/comments?per_page=100" \
                --jq ".[] | select(.id == $parent_id) | .body" 2>/dev/null)
            local parent_path=$(gh api "repos/${repo}/pulls/${pr_number}/comments?per_page=100" \
                --jq ".[] | select(.id == $parent_id) | .path" 2>/dev/null)
            local parent_line=$(gh api "repos/${repo}/pulls/${pr_number}/comments?per_page=100" \
                --jq ".[] | select(.id == $parent_id) | (.line // .original_line // \"unknown\")" 2>/dev/null)
            
            log INFO "Responding to thread on ${parent_path} (last msg from ${last_msg_user})..."
            
            # Build context from the thread (first 5 messages)
            local thread_context=$(gh api "repos/${repo}/pulls/${pr_number}/comments?per_page=100" \
                --jq "[.[] | select(.id == $parent_id or .in_reply_to_id == $parent_id)] | sort_by(.created_at) | .[0:5] | .[] | \"\(.user.login): \(.body)\"" 2>/dev/null)
            
            # Generate contextual response with full Cursor context
            local prompt="@Rules @Codebase @${parent_path}

You are responding to a code review comment as the PR author.

## Context
- **File**: ${parent_path} (line ${parent_line})
- **Reviewer**: ${last_msg_user}
- **Thread history**:
${thread_context}

## Their Latest Message
${last_msg_body}

## Your Task
1. Read the file being discussed: ${parent_path}
2. Review our project rules (.cursor/rules/)
3. Consider our MVVM architecture and coding standards
4. Provide a thoughtful, specific response that:
   - References actual code when relevant
   - Follows our architecture patterns
   - Gives concrete answers or action plans
   - Uses first-person voice (I, I'll, I've)
   - Is conversational and professional
   - Avoids mentioning AI/automation

Keep your response concise (2-4 sentences) but specific and helpful."

            local response
            if command -v cursor &> /dev/null; then
                response=$(cursor agent -p "$prompt" 2>&1 | grep -v "^Cursor" | grep -v "^Press" | grep -v "^Loading" | sed '/^$/d' | head -10 || echo "Got it! I'll address this.")
            else
                response="Thanks! I'll look into this."
            fi
            
            # Reply to the thread (in_reply_to = parent_id)
            if gh api "repos/${repo}/pulls/${pr_number}/comments" \
                -X POST \
                -F body="$response" \
                -F in_reply_to="$parent_id" 2>/dev/null; then
                log SUCCESS "✓ Replied to thread #${parent_id}"
                ((replied_count++))
            else
                log WARNING "Failed to reply to thread #${parent_id}"
            fi
            
            sleep 2  # Rate limiting
        done <<< "$parent_ids"
    fi
    
    # Get PR-level comment IDs
    local pr_comment_ids=$(gh api "repos/${repo}/issues/${pr_number}/comments" \
        --jq '.[].id' 2>/dev/null)
    
    if [ -n "$pr_comment_ids" ]; then
        while IFS= read -r comment_id; do
            [ -z "$comment_id" ] && continue
            
            # Get comment details
            local comment_user=$(gh api "repos/${repo}/issues/${pr_number}/comments" \
                --jq ".[] | select(.id == $comment_id) | .user.login" 2>/dev/null)
            local comment_body=$(gh api "repos/${repo}/issues/${pr_number}/comments" \
                --jq ".[] | select(.id == $comment_id) | .body" 2>/dev/null)
            
            # Skip if body is null/empty
            if [ -z "$comment_body" ] || [ "$comment_body" = "null" ]; then
                continue
            fi
            
            # Skip bot comments entirely
            if [[ "$comment_user" =~ \[bot\]$ ]]; then
                log INFO "Skipping PR comment #${comment_id} - from bot: ${comment_user}"
                continue
            fi
            
            # Skip automated responses (old spam from before we fixed it)
            if echo "$comment_body" | grep -qiE "(I see you'?'?ve provided (a list of|three) numbers?|These (appear to be|look like).*(timestamp|ID)|Could you (help me understand|please clarify))"; then
                log INFO "Skipping PR comment #${comment_id} - looks like old automated response"
                continue
            fi
            
            # Check if it looks like an automated summary (starts with markdown or checkmark)
            if echo "$comment_body" | grep -qE '^(## |### |\* |\- |[0-9]+\.|✅)'; then
                # Automated summary - only respond if it has questions/commands
                if ! echo "$comment_body" | grep -qiE '(\?|@ybalashkevych)'; then
                    log INFO "Skipping automated summary comment #${comment_id}"
                    continue
                fi
            fi
            
            # Check if this message needs a response
            if ! needs_response "$comment_body"; then
                log INFO "Skipping PR comment #${comment_id} - doesn't need response"
                continue
            fi
            
            log INFO "Responding to PR comment from ${comment_user}..."
            
            # Generate contextual response with full Cursor context
            local prompt="@Rules @Codebase

You are responding to a PR-level comment as the PR author.

## Context
- **PR**: Automated development workflow (#2)
- **Commenter**: ${comment_user}
- **Their comment**:
${comment_body}

## Your Task
1. Review our project rules (.cursor/rules/)
2. Consider the broader PR context and our architecture
3. Provide a thoughtful, specific response that:
   - Addresses their specific question or concern
   - References relevant code or patterns if applicable
   - Gives concrete answers or action plans
   - Uses first-person voice (I, I'll, I've)
   - Is conversational and professional
   - Avoids mentioning AI/automation

Keep your response concise (2-4 sentences) but specific and helpful."

            local response
            if command -v cursor &> /dev/null; then
                response=$(cursor agent -p "$prompt" 2>&1 | grep -v "^Cursor" | grep -v "^Press" | grep -v "^Loading" | sed '/^$/d' | head -10 || echo "Thanks for the feedback!")
            else
                response="Thanks! I'll address this."
            fi
            
            # Post the reply
            if gh api "repos/${repo}/issues/${pr_number}/comments" \
                -X POST \
                -F body="$response" 2>/dev/null; then
                log SUCCESS "✓ Replied to PR comment from ${comment_user}"
                ((replied_count++))
            else
                log WARNING "Failed to reply to PR comment #${comment_id}"
            fi
            
            sleep 2  # Rate limiting
        done <<< "$pr_comment_ids"
    fi
    
    if [ $replied_count -gt 0 ]; then
        log SUCCESS "Replied to ${replied_count} comment(s) in threads"
        log INFO "💬 To make changes, reply: '@ybalashkevych implement'"
        log INFO "📋 For detailed plan: '@ybalashkevych plan'"
    else
        log INFO "No new comments needing responses"
    fi
}

# Create implementation plan
create_plan() {
    local pr_number=$1
    local repo=$2
    
    log INFO "Creating implementation plan..."
    
    # Find the thread where plan was requested
    local thread_info=$(find_command_thread "$pr_number" "$repo" "plan")
    
    if [ -z "$thread_info" ]; then
        log ERROR "Could not find '@ybalashkevych plan' command"
        return 1
    fi
    
    # Parse thread info (JSON from find_command_thread) using grep/sed
    local comment_id=$(echo "$thread_info" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
    local file_path=$(echo "$thread_info" | grep -o '"path":"[^"]*"' | cut -d'"' -f4)
    [ -z "$file_path" ] && file_path="general"
    local line_num=$(echo "$thread_info" | grep -o '"line":[0-9]*' | cut -d':' -f2)
    [ -z "$line_num" ] && line_num="N/A"
    local comment_type=$(echo "$thread_info" | grep -o '"type":"[^"]*"' | cut -d'"' -f4)
    [ -z "$comment_type" ] && comment_type="review"
    local in_reply_to=$(echo "$thread_info" | grep -o '"in_reply_to":[0-9]*' | cut -d':' -f2)
    [ -z "$in_reply_to" ] && in_reply_to="$comment_id"
    
    # Get conversation context from this specific thread
    local conversation=$(get_thread_conversation "$pr_number" "$repo" "$comment_id" "$comment_type")
    
    log INFO "Planning for thread in ${file_path}:${line_num}"
    
    # Create context-aware prompt
    local file_context=""
    if [ "$file_path" != "general" ] && [ "$file_path" != "null" ]; then
        file_context="@${file_path}"
    fi
    
    local prompt="@Rules @Codebase ${file_context}

You are the PR author creating an implementation plan for a SPECIFIC thread discussion.

## Thread Context
**File:** ${file_path} (line ${line_num})
**Discussion:**
${conversation}

## Your Task
Create a detailed implementation plan that addresses THE SPECIFIC REQUEST in this thread only:

1. **Understand This Request:**
   - What specific change is being asked for in this thread?
   - What file/component is being discussed?
   
2. **Create Focused Plan:**
   - Address ONLY what was discussed in this specific thread
   - Reference the actual file/code mentioned
   - Be specific about what will change
   
3. **Format:**
   ## Implementation Plan
   
   ### What Was Requested
   [Summarize the specific request from THIS thread]
   
   ### Proposed Solution
   **File(s):** ${file_path}
   
   **Changes:**
   - [Specific change 1]
   - [Specific change 2]
   
   **Approach:**
   [How you'll implement these specific changes]
   
   **Expected Outcome:**
   [What the result will be]

Write in first-person. Focus ONLY on this thread's discussion."

    local plan
    if command -v cursor &> /dev/null; then
        plan=$(cursor agent -p "$prompt" 2>&1 | grep -v "^Cursor" | grep -v "^Press" | grep -v "^Loading" | sed '/^$/d')
    else
        plan="## Implementation Plan\n\nI'll address this specific request."
    fi
    
    # Reply in the SAME THREAD
    if [ "$comment_type" = "pr_comment" ]; then
        # PR-level comment
        if gh pr comment "$pr_number" --repo "$repo" --body "$plan"; then
            log SUCCESS "Posted implementation plan"
        else
            log ERROR "Failed to post plan"
            return 1
        fi
    else
        # Review comment - reply to thread
        if gh api "repos/${repo}/pulls/${pr_number}/comments" \
            -X POST \
            -F body="$plan" \
            -F in_reply_to="$in_reply_to" 2>/dev/null; then
            log SUCCESS "Posted plan in thread"
        else
            log ERROR "Failed to post plan in thread"
            return 1
        fi
    fi
    
    log INFO "Reply with '@ybalashkevych implement' when ready"
}

# Implement changes based on feedback
implement_changes() {
    local pr_number=$1
    local repo=$2
    
    log INFO "Implementing changes for PR #${pr_number}..."
    
    # Find the thread where implement was requested
    local thread_info=$(find_command_thread "$pr_number" "$repo" "implement")
    
    if [ -z "$thread_info" ]; then
        log ERROR "Could not find '@ybalashkevych implement' command"
        return 1
    fi
    
    # Parse thread info (JSON from find_command_thread) using grep/sed
    local comment_id=$(echo "$thread_info" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
    local file_path=$(echo "$thread_info" | grep -o '"path":"[^"]*"' | cut -d'"' -f4)
    [ -z "$file_path" ] && file_path="general"
    local comment_type=$(echo "$thread_info" | grep -o '"type":"[^"]*"' | cut -d'"' -f4)
    [ -z "$comment_type" ] && comment_type="review"
    local in_reply_to=$(echo "$thread_info" | grep -o '"in_reply_to":[0-9]*' | cut -d':' -f2)
    [ -z "$in_reply_to" ] && in_reply_to="$comment_id"
    
    # Get conversation context from this specific thread
    local conversation=$(get_thread_conversation "$pr_number" "$repo" "$comment_id" "$comment_type")
    
    log INFO "Implementing changes for thread in ${file_path}"
    
    # Post "working on it" in the SAME THREAD
    local working_msg="Working on this now..."
    if [ "$comment_type" = "pr_comment" ]; then
        gh pr comment "$pr_number" --repo "$repo" --body "$working_msg" || true
    else
        gh api "repos/${repo}/pulls/${pr_number}/comments" \
            -X POST -F body="$working_msg" -F in_reply_to="$in_reply_to" 2>/dev/null || true
    fi
    
    # Create thread-specific implementation prompt
    local file_context=""
    if [ "$file_path" != "general" ] && [ "$file_path" != "null" ]; then
        file_context="@${file_path}"
    fi
    
    local prompt="@Rules @Codebase ${file_context}

You MUST implement the changes discussed in this thread. This is not optional.

## Thread Discussion:
${conversation}

## CRITICAL INSTRUCTIONS:
1. READ the entire conversation above - it contains a DETAILED implementation plan
2. The plan has specific steps (numbered 1-7 or similar) - follow ALL of them
3. Make SUBSTANTIAL changes to ${file_path} - not just whitespace
4. If the plan says to reduce from 187 to 50-60 lines, DO IT
5. If the plan says to consolidate sections, CONSOLIDATE THEM
6. If the plan says to remove sections, REMOVE THEM

## Your Task:
- Open and EDIT ${file_path}
- Make ALL the changes described in the implementation plan above
- Be AGGRESSIVE in consolidating and simplifying as requested
- Follow the specific approach steps listed in the plan
- The goal is SUBSTANTIAL refactoring, not minor tweaks

DO NOT:
- Make only whitespace changes
- Be conservative or cautious
- Skip steps from the plan
- Commit anything (I handle git)

START EDITING NOW - make the substantial changes requested in the plan."

    log INFO "Making changes with cursor agent (without -f flag for substantial edits)..."
    
    if command -v cursor &> /dev/null; then
        # Run cursor agent to make changes (removed -f flag to allow substantial changes)
        if cursor agent -p "$prompt" 2>&1 | tee /tmp/cursor-impl-output.log; then
            log SUCCESS "Changes completed"
        else
            log WARNING "Cursor agent completed with warnings"
        fi
    else
        log ERROR "Cursor agent not available"
        local error_msg="⚠️ Can't make automated changes (cursor not available). Will address manually."
        if [ "$comment_type" = "pr_comment" ]; then
            gh pr comment "$pr_number" --repo "$repo" --body "$error_msg"
        else
            gh api "repos/${repo}/pulls/${pr_number}/comments" \
                -X POST -F body="$error_msg" -F in_reply_to="$in_reply_to" 2>/dev/null
        fi
        return 1
    fi
    
    # Check for changes
    if git diff --quiet && git diff --cached --quiet; then
        log WARNING "No file changes detected - cursor agent made no changes"
        # Don't post a comment - it would create an infinite loop
        # Just silently exit (changes may have already been made in a previous attempt)
        log INFO "Skipping comment to avoid loop - implementation likely already done"
        return 0
    fi
    
    log SUCCESS "Changes made, proceeding with git operations..."
    
    # Show what changed
    git status --short
    
    # Commit changes
    local commit_msg="fix: address PR #${pr_number} feedback

Addressed comments and review feedback.
Changes made in response to discussion."

    git add -A
    git commit -m "$commit_msg"
    
    # Pull and rebase
    log INFO "Pulling latest changes..."
    local current_branch=$(git branch --show-current)
    
    if ! git pull --rebase origin "$current_branch"; then
        log WARNING "Rebase conflicts detected"
        if git diff --name-only --diff-filter=U | grep -q .; then
            log INFO "Attempting automatic conflict resolution..."
            if git rerere && git add -A && git rebase --continue; then
                log SUCCESS "Conflicts resolved automatically"
            else
                log ERROR "Manual conflict resolution needed"
                git rebase --abort
                local conflict_msg="⚠️ Made changes but hit merge conflicts. Will resolve and push shortly."
                if [ "$comment_type" = "pr_comment" ]; then
                    gh pr comment "$pr_number" --repo "$repo" --body "$conflict_msg"
                else
                    gh api "repos/${repo}/pulls/${pr_number}/comments" \
                        -X POST -F body="$conflict_msg" -F in_reply_to="$in_reply_to" 2>/dev/null
                fi
                return 1
            fi
        fi
    fi
    
    # Run tests
    log INFO "Running tests..."
    if xcodebuild test -scheme LiveAssistant -destination 'platform=macOS' &>/dev/null; then
        log SUCCESS "All tests passing"
    else
        log ERROR "Tests failed"
        local tests_failed_msg="⚠️ Made changes but tests are failing. Fixing now..."
        if [ "$comment_type" = "pr_comment" ]; then
            gh pr comment "$pr_number" --repo "$repo" --body "$tests_failed_msg"
        else
            gh api "repos/${repo}/pulls/${pr_number}/comments" \
                -X POST -F body="$tests_failed_msg" -F in_reply_to="$in_reply_to" 2>/dev/null
        fi
        return 1
    fi
    
    # Push changes
    log INFO "Pushing changes..."
    if git push origin "$current_branch"; then
        log SUCCESS "Changes pushed"
        
        # Post completion comment in thread
        local commits=$(git log origin/$MAIN_BRANCH..HEAD --oneline --no-decorate | head -5)
        local success_msg="✅ Changes implemented and pushed.

Recent commits:
\`\`\`
$commits
\`\`\`

All tests passing. Ready for review!"
        
        if [ "$comment_type" = "pr_comment" ]; then
            gh pr comment "$pr_number" --repo "$repo" --body "$success_msg" || true
        else
            gh api "repos/${repo}/pulls/${pr_number}/comments" \
                -X POST -F body="$success_msg" -F in_reply_to="$in_reply_to" 2>/dev/null || true
        fi
        
        return 0
    else
        log ERROR "Push failed"
        return 1
    fi
}

# Main command dispatcher
main() {
    check_prerequisites
    
    local command=$1
    
    case "$command" in
        analyze)
            if [ $# -lt 3 ]; then
                echo "Usage: $0 analyze <pr-number> <repo>"
                exit 1
            fi
            analyze_feedback "$2" "$3"
            ;;
        plan)
            if [ $# -lt 3 ]; then
                echo "Usage: $0 plan <pr-number> <repo> [scope]"
                exit 1
            fi
            create_plan "$2" "$3" "${4:-all}"
            ;;
        implement)
            if [ $# -lt 3 ]; then
                echo "Usage: $0 implement <pr-number> <repo> [scope]"
                exit 1
            fi
            implement_changes "$2" "$3" "${4:-all}"
            ;;
        *)
            echo "Usage: $0 {analyze|plan|implement} <pr-number> <repo> [scope]"
            echo ""
            echo "Commands:"
            echo "  analyze    - Post analysis of PR feedback as @ybalashkevych"
            echo "  plan       - Create detailed implementation plan"
            echo "  implement  - Make changes and push (responds to @ybalashkevych implement)"
            exit 1
            ;;
    esac
}

main "$@"

