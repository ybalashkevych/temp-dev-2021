#!/bin/bash

#
# automation/daemon.sh
# LiveAssistant
#
# Background daemon that monitors GitHub PRs for feedback needing cursor agent response
# Runs continuously and processes feedback using reaction-based guards to prevent loops
#

set -euo pipefail

# Configuration
POLL_INTERVAL=60
LOG_DIR="logs"
REPO_OWNER="ybalashkevych"
REPO_NAME="temp-dev-2021"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Source common utilities
source "$SCRIPT_DIR/common.sh"

# Check prerequisites
check_prerequisites() {
    log_msg INFO "Checking prerequisites..."
    
    if ! command -v gh &> /dev/null; then
        log_msg ERROR "GitHub CLI (gh) is not installed"
        log_msg ERROR "Install with: brew install gh"
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        log_msg ERROR "GitHub CLI is not authenticated"
        log_msg ERROR "Run: gh auth login"
        exit 1
    fi
    
    if [ ! -f "$SCRIPT_DIR/state.sh" ]; then
        log_msg ERROR "Missing required script: state.sh"
        exit 1
    fi
    
    if [ ! -f "$SCRIPT_DIR/thread.sh" ]; then
        log_msg ERROR "Missing required script: thread.sh"
        exit 1
    fi
    
    if [ ! -f "$SCRIPT_DIR/agent.sh" ]; then
        log_msg ERROR "Missing required script: agent.sh"
        exit 1
    fi
    
    log_msg SUCCESS "All prerequisites met"
}

# Source utility scripts
source "$SCRIPT_DIR/state.sh"
source "$SCRIPT_DIR/thread.sh"
source "$SCRIPT_DIR/agent.sh"

# Get all open PRs with awaiting-cursor-response label
get_prs_awaiting_response() {
    gh pr list \
        --repo "${REPO_OWNER}/${REPO_NAME}" \
        --state open \
        --label "awaiting-cursor-response" \
        --json number \
        --jq '.[].number' 2>/dev/null || echo ""
}

# Check if comment has required reactions (both eyes and rocket)
has_processed_reactions() {
    local comment_id=$1
    local comment_type=$2  # "issue" or "review"
    
    local api_endpoint
    if [ "$comment_type" = "issue" ]; then
        api_endpoint="repos/${REPO_OWNER}/${REPO_NAME}/issues/comments/${comment_id}/reactions"
    else
        api_endpoint="repos/${REPO_OWNER}/${REPO_NAME}/pulls/comments/${comment_id}/reactions"
    fi
    
    local reactions=$(gh api "$api_endpoint" --jq '.[].content' 2>/dev/null || echo "")
    
    # Check if both 'eyes' (👀) and 'rocket' (🚀) reactions exist
    if echo "$reactions" | grep -q "eyes" && echo "$reactions" | grep -q "rocket"; then
        return 0  # Already fully processed
    fi
    
    return 1  # Not fully processed
}

# Add reaction to comment
add_reaction() {
    local comment_id=$1
    local comment_type=$2  # "issue" or "review"
    local reaction=$3      # "eyes", "rocket", "+1", "-1"
    
    local api_endpoint
    if [ "$comment_type" = "issue" ]; then
        api_endpoint="repos/${REPO_OWNER}/${REPO_NAME}/issues/comments/${comment_id}/reactions"
    else
        api_endpoint="repos/${REPO_OWNER}/${REPO_NAME}/pulls/comments/${comment_id}/reactions"
    fi
    
    # Use lowercase -f flag to avoid +1 being interpreted as number
    # Also capture error output for better debugging
    local error_output=$(gh api "$api_endpoint" -X POST -f content="$reaction" 2>&1)
    
    if [ $? -ne 0 ]; then
        log_msg WARNING "Failed to add $reaction reaction to comment $comment_id: $error_output"
        return 1
    fi
    
    log_msg DEBUG "Added $reaction reaction to comment $comment_id"
    return 0
}

# Ensure comments cache directory exists
ensure_comments_cache() {
    local thread_id=$1
    mkdir -p "$LOG_DIR/comments"
    if [ -n "$thread_id" ]; then
        mkdir -p "$LOG_DIR/comments/thread-${thread_id}"
    fi
}

# Fetch all comments (PR and inline) in one function
fetch_all_comments() {
    local pr_number=$1
    
    ensure_comments_cache ""
    
    # Get PR-level comments
    gh api "repos/${REPO_OWNER}/${REPO_NAME}/issues/${pr_number}/comments" \
        --jq '.[] | select(.performed_via_github_app == null or .performed_via_github_app == false) | 
              "\(.id)|pr|\(.user.login)||"' 2>/dev/null
    
    # Get inline review comments (top-level only, not replies)
    gh api "repos/${REPO_OWNER}/${REPO_NAME}/pulls/${pr_number}/comments" \
        --jq '.[] | select(.in_reply_to_id == null) | 
              "\(.id)|inline|\(.user.login)|\(.path):\(.line // .original_line)|"' 2>/dev/null
}

# Get comment body from GitHub
get_comment_body() {
    local comment_id=$1
    local is_inline=$2
    
    local api_endpoint
    if [ "$is_inline" = "inline" ]; then
        api_endpoint="repos/${REPO_OWNER}/${REPO_NAME}/pulls/comments/${comment_id}"
    else
        api_endpoint="repos/${REPO_OWNER}/${REPO_NAME}/issues/comments/${comment_id}"
    fi
    
    gh api "$api_endpoint" --jq '.body' 2>/dev/null || echo ""
}

# Save comment to appropriate location
save_comment() {
    local pr_number=$1
    local comment_id=$2
    local is_inline=$3
    local thread_id=$4
    local body=$5
    
    local comment_file
    if [ "$is_inline" = "inline" ] && [ -n "$thread_id" ]; then
        ensure_comments_cache "$thread_id"
        comment_file="$LOG_DIR/comments/thread-${thread_id}/pr-${pr_number}-${comment_id}.txt"
    else
        ensure_comments_cache ""
        comment_file="$LOG_DIR/comments/pr-${pr_number}-${comment_id}.txt"
    fi
    
    echo "$body" > "$comment_file"
    echo "$comment_file"
}

# Check if conversation thread is resolved
is_conversation_resolved() {
    local pr_number=$1
    local comment_id=$2
    
    # Get review threads and check if the comment's thread is resolved
    local resolved=$(gh api "repos/${REPO_OWNER}/${REPO_NAME}/pulls/${pr_number}/comments/${comment_id}" \
        --jq 'select(.pull_request_review_id != null) | .pull_request_review_id' 2>/dev/null || echo "")
    
    if [ -n "$resolved" ]; then
        # Check if the review thread is resolved
        local thread_resolved=$(gh api "repos/${REPO_OWNER}/${REPO_NAME}/pulls/${pr_number}/comments" \
            --jq ".[] | select(.id == ${comment_id}) | select(.pull_request_review_id == ${resolved}) | 
                  select(.in_reply_to_id == null) | length" 2>/dev/null || echo "0")
        
        # For now, we'll consider it not resolved unless explicitly marked
        # GitHub doesn't provide a direct API for conversation resolution status
        return 1
    fi
    
    return 1  # Not resolved
}

# Parse command from comment body
parse_command() {
    local body=$1
    
    # Check for explicit commands
    if echo "$body" | grep -q "@ybalashkevych plan"; then
        echo "plan"
    elif echo "$body" | grep -q "@ybalashkevych \(fix\|implement\)"; then
        echo "implement"
    else
        echo "ask"
    fi
}

# Clean comment for agent consumption
clean_comment() {
    local body=$1
    
    # Remove GitHub-specific artifacts and mentions
    echo "$body" | \
        sed -e 's/<details>/\n/g' -e 's/<\/details>/\n/g' \
            -e 's/<summary>//g' -e 's/<\/summary>//g' \
            -e 's/```suggestion/```/g' \
            -e 's/@ybalashkevych [a-z]*//' \
            -e 's/^[ \t]*//;s/[ \t]*$//'
}

# Get all feedback for a PR (simplified)
get_pr_feedback() {
    local pr_number=$1
    local log_file="$LOG_DIR/pr-${pr_number}-monitor.log"
    
    log_msg INFO "Fetching feedback for PR #${pr_number}..." | tee -a "$log_file"
    
    local all_comments=$(fetch_all_comments "$pr_number")
    
    if [ -z "$all_comments" ]; then
        log_msg INFO "No comments found for PR #${pr_number}" | tee -a "$log_file"
        return 0
    fi
    
    # Process each comment
    while IFS='|' read -r comment_id is_inline author code_location _; do
        [ -z "$comment_id" ] && continue
        
        # Determine comment type for reactions API
        local comment_type="issue"
        [ "$is_inline" = "inline" ] && comment_type="review"
        
        # Skip if already processed
        if has_processed_reactions "$comment_id" "$comment_type"; then
            log_msg DEBUG "Skipping processed comment $comment_id" | tee -a "$log_file"
            continue
        fi
        
        # Get comment body
        local body=$(get_comment_body "$comment_id" "$is_inline")
        [ -z "$body" ] && continue
        
        # Parse and clean
        local command=$(parse_command "$body")
        local cleaned_body=$(clean_comment "$body")
        
        log_msg INFO "Found comment: ID=$comment_id, Type=$is_inline, Author=$author, Command=$command" | tee -a "$log_file"
        echo "${pr_number}|${comment_id}|${is_inline}|${comment_type}|${author}|${command}|${code_location}|${cleaned_body}"
    done <<< "$all_comments"
}

# Process a single comment/feedback (simplified)
process_feedback() {
    local pr_number=$1
    local comment_id=$2
    local is_inline=$3
    local comment_type=$4
    local author=$5
    local command=$6
    local code_location=$7
    local body=$8
    
    local log_file="$LOG_DIR/pr-${pr_number}-monitor.log"
    
    log_msg INFO "Processing feedback from $author (comment: $comment_id, command: $command)" | tee -a "$log_file"
    
    # Add 👀 reaction (guard against re-processing)
    add_reaction "$comment_id" "$comment_type" "eyes"
    
    # Get or create thread for this comment
    local thread_id=$(get_or_create_thread "$pr_number" "$comment_id")
    log_msg INFO "Using thread: $thread_id" | tee -a "$log_file"
    
    # Save comment to appropriate location
    save_comment "$pr_number" "$comment_id" "$is_inline" "$thread_id" "$body"
    
    # Add feedback to thread context
    add_to_thread "$thread_id" "user" "$author" "$body" "$code_location"
    
    # Build context and invoke agent
    local context=$(build_context "$pr_number" "$thread_id")
    log_msg INFO "Invoking agent in '$command' mode..." | tee -a "$log_file"
    local response=$(invoke_agent "$pr_number" "$thread_id" "$command" "$context")
    local status=$?
    
    if [ $status -eq 0 ]; then
        log_msg SUCCESS "Agent completed successfully" | tee -a "$log_file"
        
        # Add agent response to thread
        add_to_thread "$thread_id" "assistant" "cursor-agent" "$response" ""
        
        # Post response to PR
        local agent_comment_id=$(post_agent_response "$pr_number" "$comment_id" "$comment_type" "$command" "$response")
        
        if [ -n "$agent_comment_id" ]; then
            log_msg INFO "Agent posted comment: $agent_comment_id" | tee -a "$log_file"
            add_reaction "$agent_comment_id" "issue" "rocket"
            add_reaction "$agent_comment_id" "issue" "+1"
        fi
    else
        log_msg ERROR "Agent failed to process feedback" | tee -a "$log_file"
        add_reaction "$comment_id" "$comment_type" "-1"
        
        local failure_message="❌ **Processing Failed**\n\nThread: \`${thread_id}\`\nPlease check the logs."
        post_comment "$pr_number" "$failure_message"
    fi
}

# Post comment to PR
post_comment() {
    local pr_number=$1
    local message=$2
    
    # Post comment and capture the response with comment URL
    local comment_url=$(gh pr comment "$pr_number" \
        --repo "${REPO_OWNER}/${REPO_NAME}" \
        --body "$message" 2>&1)
    
    if [ $? -ne 0 ]; then
        log_msg ERROR "Failed to post comment to PR #${pr_number}: $comment_url"
        return 1
    fi
    
    # Extract comment ID from URL (format: https://github.com/.../pull/5#issuecomment-123456)
    local comment_id=$(echo "$comment_url" | grep -oE '#issuecomment-[0-9]+' | grep -oE '[0-9]+')
    
    if [ -n "$comment_id" ]; then
        echo "$comment_id"
        return 0
    else
        log_msg WARNING "Could not extract comment ID from: $comment_url"
        return 1
    fi
}

# Post agent response based on mode
post_agent_response() {
    local pr_number=$1
    local comment_id=$2
    local comment_type=$3
    local command=$4
    local response=$5
    
    local message=""
    
    case "$command" in
        ask)
            message="🤔 **Questions & Clarifications**\n\n${response}\n\n---\n*Reply with answers or use \`@ybalashkevych plan\` to see implementation plan*"
            ;;
        plan)
            message="📋 **Implementation Plan**\n\n${response}\n\n---\n*Use \`@ybalashkevych implement\` to proceed with changes*"
            ;;
        implement)
            message="✅ **Changes Implemented**\n\n${response}\n\n---\n*Changes have been committed and pushed. Ready for review.*"
            ;;
    esac
    
    # Post comment and return the new comment ID
    post_comment "$pr_number" "$message"
}

# Main monitoring loop
monitor_prs() {
    log_msg INFO "Starting PR monitoring daemon"
    log_msg INFO "Repository: ${REPO_OWNER}/${REPO_NAME}"
    log_msg INFO "Poll interval: ${POLL_INTERVAL}s"
    log_msg INFO ""
    
    local iteration=0
    
    while true; do
        iteration=$((iteration + 1))
        log_msg INFO "=== Check #${iteration} ===" 
        
        # Get PRs awaiting cursor response
        local prs=$(get_prs_awaiting_response)
        
        if [ -z "$prs" ]; then
            log_msg INFO "No PRs awaiting response"
        else
            local pr_count=$(echo "$prs" | wc -l | tr -d ' ')
            log_msg INFO "Found ${pr_count} PR(s) awaiting response"
            
            # Process each PR
            while read -r pr_number; do
                if [ -z "$pr_number" ]; then
                    continue
                fi
                
                log_msg INFO "Processing PR #${pr_number}..."
                
                # Get all feedback for this PR
                local feedback=$(get_pr_feedback "$pr_number")
                
                if [ -z "$feedback" ]; then
                    log_msg INFO "No unprocessed feedback in PR #${pr_number}"
                    continue
                fi
                
                # Process each feedback item
                while IFS='|' read -r pr_num comment_id is_inline comment_type author command code_location body; do
                    [ -z "$comment_id" ] && continue
                    process_feedback "$pr_num" "$comment_id" "$is_inline" "$comment_type" "$author" "$command" "$code_location" "$body"
                done <<< "$feedback"
                
            done <<< "$prs"
        fi
        
        log_msg INFO "Sleeping for ${POLL_INTERVAL}s..."
        log_msg INFO ""
        sleep $POLL_INTERVAL
    done
}

# Cleanup handler
cleanup() {
    log_msg INFO "Received shutdown signal"
    log_msg INFO "Daemon stopped"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Main entry point
main() {
    log_msg INFO "========================================"
    log_msg INFO "Cursor Automation Daemon Starting"
    log_msg INFO "========================================"
    log_msg INFO ""
    
    check_prerequisites
    
    log_msg SUCCESS "Daemon initialized successfully"
    log_msg INFO "Process ID: $$"
    log_msg INFO ""
    
    monitor_prs
}

# Run
main

