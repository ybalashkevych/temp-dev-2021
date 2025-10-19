#!/bin/bash

#
# automation/thread.sh
# LiveAssistant
#
# Thread conversation management utilities
# Handles thread creation, context building, and conversation history
#

# Source common utilities if not already loaded
if ! command -v log_msg &> /dev/null; then
    _THREAD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$_THREAD_SCRIPT_DIR/common.sh" ]; then
        source "$_THREAD_SCRIPT_DIR/common.sh"
    elif [ -f "scripts/automation/common.sh" ]; then
        source "scripts/automation/common.sh"
    else
        # Fallback: define a minimal log_msg function (output to stderr)
        log_msg() { echo "[$1] $2" >&2; }
    fi
fi

# Get or create thread for a comment
get_or_create_thread() {
    local pr_number=$1
    local comment_id=$2
    
    # Check if comment already has a thread
    local existing_thread=$(get_thread_for_comment "$comment_id")
    
    if [ -n "$existing_thread" ]; then
        log_msg DEBUG "Using existing thread: $existing_thread"
        echo "$existing_thread"
        return 0
    fi
    
    # Create new thread
    local timestamp=$(date +%s)
    local thread_id="pr-${pr_number}-thread-${timestamp}"
    
    # Register in state
    register_thread "$thread_id" "$pr_number"
    
    # Create thread file
    local log_dir_path="${LOG_DIR:-logs}"
    mkdir -p "$log_dir_path"
    local thread_file="$log_dir_path/${thread_id}.json"
    cat > "$thread_file" <<EOF
{
  "thread_id": "${thread_id}",
  "pr_number": ${pr_number},
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "status": "active",
  "messages": []
}
EOF
    
        log_msg INFO "Created new thread: $thread_id"
    echo "$thread_id"
}

# Add message to thread
add_to_thread() {
    local thread_id=$1
    local role=$2        # "user" or "assistant"
    local author=$3      # username
    local content=$4     # message content
    local location=$5    # file:line or empty
    
    local log_dir_path="${LOG_DIR:-logs}"
    local thread_file="$log_dir_path/${thread_id}.json"
    
    if [ ! -f "$thread_file" ]; then
        log_msg ERROR "Thread file not found: $thread_file"
        return 1
    fi
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Escape content for JSON
    local escaped_content=$(echo "$content" | jq -Rs .)
    local escaped_location=$(echo "$location" | jq -Rs .)
    
    # Add message to thread
    jq ".messages += [{
        \"role\": \"${role}\",
        \"author\": \"${author}\",
        \"content\": ${escaped_content},
        \"location\": ${escaped_location},
        \"timestamp\": \"${timestamp}\"
    }]" "$thread_file" > "${thread_file}.tmp" && mv "${thread_file}.tmp" "$thread_file"
    
        log_msg DEBUG "Added message to thread $thread_id from $author"
}

# Build full context for agent
build_agent_context() {
    local pr_number=$1
    local thread_id=$2
    
    local log_dir_path="${LOG_DIR:-logs}"
    local thread_file="$log_dir_path/${thread_id}.json"
    
    if [ ! -f "$thread_file" ]; then
        log_msg ERROR "Thread file not found: $thread_file"
        return 1
    fi
    
    # Get PR metadata
    local pr_title=$(gh pr view "$pr_number" --repo "${REPO_OWNER}/${REPO_NAME}" \
        --json title --jq '.title' 2>/dev/null || echo "Unknown")
    local pr_branch=$(gh pr view "$pr_number" --repo "${REPO_OWNER}/${REPO_NAME}" \
        --json headRefName --jq '.headRefName' 2>/dev/null || echo "unknown")
    local pr_body=$(gh pr view "$pr_number" --repo "${REPO_OWNER}/${REPO_NAME}" \
        --json body --jq '.body' 2>/dev/null || echo "")
    
    # Get changed files
    local changed_files=$(gh pr view "$pr_number" --repo "${REPO_OWNER}/${REPO_NAME}" \
        --json files --jq '.files[].path' 2>/dev/null | head -20 | tr '\n' ', ' | sed 's/,$//')
    
    # Build context document
    local context="# PR #${pr_number} Context

## PR Information
- **Title**: ${pr_title}
- **Branch**: ${pr_branch}
- **Files Changed**: ${changed_files}

## PR Description
${pr_body}

## Conversation Thread (${thread_id})

"
    
    # Add all messages from thread
    local messages=$(jq -r '.messages[] | 
        "### \(.role | ascii_upcase) (\(.author)) - \(.timestamp)\n" +
        (if .location != "" then "**Location**: `\(.location)`\n\n" else "" end) +
        "\(.content)\n"' "$thread_file" 2>/dev/null)
    
    context="${context}${messages}"
    
    echo "$context"
}

# Get thread status
get_thread_status() {
    local thread_id=$1
    local log_dir_path="${LOG_DIR:-logs}"
    local thread_file="$log_dir_path/${thread_id}.json"
    
    if [ ! -f "$thread_file" ]; then
        echo "not_found"
        return 1
    fi
    
    jq -r '.status' "$thread_file" 2>/dev/null || echo "unknown"
}

# Update thread status
set_thread_status() {
    local thread_id=$1
    local status=$2  # "active", "completed", "failed"
    
    local log_dir_path="${LOG_DIR:-logs}"
    local thread_file="$log_dir_path/${thread_id}.json"
    
    if [ ! -f "$thread_file" ]; then
        log_msg ERROR "Thread file not found: $thread_file"
        return 1
    fi
    
    jq ".status = \"${status}\"" "$thread_file" > "${thread_file}.tmp" && \
        mv "${thread_file}.tmp" "$thread_file"
    
    # Also update in state
    update_thread_status "$thread_id" "$status"
    
        log_msg DEBUG "Set thread $thread_id status to: $status"
}

# Get message count in thread
get_message_count() {
    local thread_id=$1
    local log_dir_path="${LOG_DIR:-logs}"
    local thread_file="$log_dir_path/${thread_id}.json"
    
    if [ ! -f "$thread_file" ]; then
        echo "0"
        return 1
    fi
    
    jq '.messages | length' "$thread_file" 2>/dev/null || echo "0"
}

# List all threads for a PR
list_pr_threads() {
    local pr_number=$1
    local log_dir_path="${LOG_DIR:-logs}"
    
    find "$log_dir_path" -name "pr-${pr_number}-thread-*.json" -type f 2>/dev/null | \
        xargs -I {} basename {} .json
}

