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
    mkdir -p "$LOG_DIR/comments"
}

# Get PR-level comments (excludes resolved conversations)
get_pr_comments() {
    local pr_number=$1
    
    ensure_comments_cache
    
    # Fetch comments with base64-encoded bodies to prevent line splitting
    gh api "repos/${REPO_OWNER}/${REPO_NAME}/issues/${pr_number}/comments" \
        --jq '.[] | select(.performed_via_github_app == null or .performed_via_github_app == false) | 
              "\(.id)|\(.user.login)|\(.body | @base64)"' 2>/dev/null | \
    while IFS='|' read -r id user body_b64; do
        if [ -n "$id" ]; then
            # Decode body and write to file
            local body=$(echo "$body_b64" | base64 --decode 2>/dev/null || echo "")
            local body_file="$LOG_DIR/comments/pr-${pr_number}-${id}.txt"
            echo "$body" > "$body_file"
            # Output metadata with file path
            echo "${id}|issue|${user}|${body_file}"
        fi
    done || echo ""
}

# Get inline review comments (excludes resolved, includes only top-level not replies)
get_review_comments() {
    local pr_number=$1
    
    ensure_comments_cache
    
    # Get review comments with base64-encoded bodies to prevent line splitting
    gh api "repos/${REPO_OWNER}/${REPO_NAME}/pulls/${pr_number}/comments" \
        --jq '.[] | select(.in_reply_to_id == null) | 
              "\(.id)|\(.user.login)|\(.path):\(.line // .original_line)|\(.body | @base64)"' 2>/dev/null | \
    while IFS='|' read -r id user location body_b64; do
        if [ -n "$id" ]; then
            # Decode body and write to file
            local body=$(echo "$body_b64" | base64 --decode 2>/dev/null || echo "")
            local body_file="$LOG_DIR/comments/pr-${pr_number}-${id}.txt"
            echo "$body" > "$body_file"
            # Output metadata with file path
            echo "${id}|review|${user}|${location}|${body_file}"
        fi
    done || echo ""
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
    
    log_msg DEBUG "Parsing command from: $body"
    
    # Check for explicit commands
    if echo "$body" | grep -q "@ybalashkevych plan"; then
        log_msg DEBUG "Detected command: plan"
        echo "plan"
    elif echo "$body" | grep -q "@ybalashkevych fix"; then
        log_msg DEBUG "Detected command: implement (fix)"
        echo "implement"
    elif echo "$body" | grep -q "@ybalashkevych implement"; then
        log_msg DEBUG "Detected command: implement"
        echo "implement"
    else
        log_msg DEBUG "No explicit command found, defaulting to: ask"
        # Default: ask mode for any feedback
        echo "ask"
    fi
}

# Clean comment for agent consumption
clean_comment_for_agent() {
    local body=$1
    
    # Remove GitHub-specific artifacts
    echo "$body" | \
        sed 's/<details>/\n/g' | \
        sed 's/<\/details>/\n/g' | \
        sed 's/<summary>//g' | \
        sed 's/<\/summary>//g' | \
        sed 's/```suggestion/```/g' | \
        sed 's/@ybalashkevych [a-z]*//' | \
        sed 's/^[ \t]*//;s/[ \t]*$//'  # Trim whitespace
}

# Get all feedback for a PR
get_pr_feedback() {
    local pr_number=$1
    local log_file="$LOG_DIR/pr-${pr_number}-monitor.log"
    
    log_msg INFO "Fetching feedback for PR #${pr_number}..." | tee -a "$log_file"
    
    local feedback_found=0
    
    # Get PR comments
    local pr_comments=$(get_pr_comments "$pr_number")
    if [ -n "$pr_comments" ]; then
        while IFS='|' read -r comment_id type author body_file; do
            if [ -z "$comment_id" ]; then
                continue
            fi
            
            # Read body from file
            local body=$(cat "$body_file" 2>/dev/null || echo "")
            
            # Skip if already fully processed (has both reactions)
            if has_processed_reactions "$comment_id" "$type"; then
                log_msg DEBUG "Skipping already processed comment $comment_id" | tee -a "$log_file"
                continue
            fi
            
            # Parse command
            local command=$(parse_command "$body")
            local cleaned_body=$(clean_comment_for_agent "$body")
            
            log_msg INFO "Found PR comment: ID=$comment_id, Author=$author, Command=$command" | tee -a "$log_file"
            echo "${pr_number}|${comment_id}|${type}|${author}|${command}||${cleaned_body}"
            feedback_found=1
        done <<< "$pr_comments"
    fi
    
    # Get review comments
    local review_comments=$(get_review_comments "$pr_number")
    if [ -n "$review_comments" ]; then
        while IFS='|' read -r comment_id type author file_line body_file; do
            if [ -z "$comment_id" ]; then
                continue
            fi
            
            # Read body from file
            local body=$(cat "$body_file" 2>/dev/null || echo "")
            
            # Skip if already fully processed
            if has_processed_reactions "$comment_id" "$type"; then
                log_msg DEBUG "Skipping already processed comment $comment_id" | tee -a "$log_file"
                continue
            fi
            
            # Check if conversation is resolved (skip if true)
            # For now, we'll process all unresolved - GitHub API limitation
            
            # Parse command
            local command=$(parse_command "$body")
            local cleaned_body=$(clean_comment_for_agent "$body")
            
            log_msg INFO "Found review comment: ID=$comment_id, Author=$author, Location=$file_line, Command=$command" | tee -a "$log_file"
            echo "${pr_number}|${comment_id}|${type}|${author}|${command}|${file_line}|${cleaned_body}"
            feedback_found=1
        done <<< "$review_comments"
    fi
    
    if [ $feedback_found -eq 0 ]; then
        log_msg INFO "No unprocessed feedback found for PR #${pr_number}" | tee -a "$log_file"
    fi
    
    return 0
}

# Process a single comment/feedback
process_feedback() {
    local pr_number=$1
    local comment_id=$2
    local comment_type=$3
    local author=$4
    local command=$5
    local file_line=$6
    local body=$7
    
    local log_file="$LOG_DIR/pr-${pr_number}-monitor.log"
    
    log_msg INFO "Processing feedback from $author (comment: $comment_id, command: $command)" | tee -a "$log_file"
    
    # Step 1: Add 👀 reaction immediately (guard against re-processing)
    add_reaction "$comment_id" "$comment_type" "eyes"
    
    # Step 2: Get or create thread for this comment
    local thread_id=$(get_or_create_thread "$pr_number" "$comment_id")
    log_msg INFO "Using thread: $thread_id" | tee -a "$log_file"
    
    # Step 3: Add feedback to thread context
    add_to_thread "$thread_id" "user" "$author" "$body" "$file_line"
    
    # Step 4: Build full context for agent
    local context=$(build_agent_context "$pr_number" "$thread_id")
    
    # Step 5: Invoke agent with context and command
    log_msg INFO "Invoking agent in '$command' mode..." | tee -a "$log_file"
    local response=$(invoke_agent "$pr_number" "$thread_id" "$command" "$context")
    local status=$?
    
    if [ $status -eq 0 ]; then
        log_msg SUCCESS "Agent completed successfully" | tee -a "$log_file"
        
        # Step 6: Add agent response to thread
        add_to_thread "$thread_id" "assistant" "cursor-agent" "$response" ""
        
        # Step 7: Post response to PR and get new comment ID
        local agent_comment_id=$(post_agent_response "$pr_number" "$comment_id" "$comment_type" "$command" "$response")
        
        if [ -n "$agent_comment_id" ]; then
            log_msg INFO "Agent posted comment: $agent_comment_id" | tee -a "$log_file"
            
            # Step 8: Add 🚀 reaction to AGENT's comment (not original)
            add_reaction "$agent_comment_id" "issue" "rocket"
            
            # Step 9: Add ✅ reaction to AGENT's comment
            add_reaction "$agent_comment_id" "issue" "+1"
            
            # Also add eyes reaction to original comment to mark as processed
            add_reaction "$comment_id" "$comment_type" "eyes"
        else
            log_msg WARNING "Could not get agent comment ID, skipping reactions" | tee -a "$log_file"
        fi
    else
        log_msg ERROR "Agent failed to process feedback" | tee -a "$log_file"
        
        # Add ❌ reaction (failure)
        add_reaction "$comment_id" "$comment_type" "-1"
        
        # Post failure comment
        local failure_message="❌ **Processing Failed**\n\nI encountered an error while processing this feedback.\n\nThread: \`${thread_id}\`\nPlease check the logs for details."
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
                while IFS='|' read -r pr_num comment_id comment_type author command file_line body; do
                    if [ -z "$comment_id" ]; then
                        continue
                    fi
                    
                    process_feedback "$pr_num" "$comment_id" "$comment_type" "$author" "$command" "$file_line" "$body"
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

