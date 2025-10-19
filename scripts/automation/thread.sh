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
    
    local code_snippet=""
    local function_name=""
    
    # Fetch surrounding code if location provided
    if [ -n "$location" ] && [ "$location" != '""' ] && [ "$location" != "null" ]; then
        local file_path=$(echo "$location" | cut -d':' -f1)
        local line_num=$(echo "$location" | cut -d':' -f2)
        
        if [ -f "$file_path" ] && [ -n "$line_num" ]; then
            log_msg DEBUG "Fetching code context for $file_path:$line_num"
            
            # Get ±10 lines around the comment location
            local start=$((line_num - 10))
            [ $start -lt 1 ] && start=1
            local end=$((line_num + 10))
            
            # Extract code with line numbers and marker
            code_snippet=$(awk -v start=$start -v end=$end -v target=$line_num '
                NR >= start && NR <= end {
                    marker = (NR == target) ? " ← " : "   "
                    printf "%3d|%s%s\n", NR, marker, $0
                }' "$file_path" 2>/dev/null || echo "")
            
            # Try to detect function/class name (basic heuristic for Swift)
            function_name=$(awk -v target=$line_num '
                /^[[:space:]]*(func|class|struct|enum|protocol|extension)/ {
                    name = $0
                }
                NR == target {
                    print name
                    exit
                }' "$file_path" 2>/dev/null | sed 's/^[[:space:]]*//' || echo "")
        fi
    fi
    
    # Escape content for JSON
    local escaped_content=$(echo "$content" | jq -Rs .)
    local escaped_location=$(echo "$location" | jq -Rs .)
    local escaped_code=$(echo "$code_snippet" | jq -Rs .)
    local escaped_function=$(echo "$function_name" | jq -Rs .)
    
    # Add message to thread with code_snippet and function_name fields
    jq ".messages += [{
        \"role\": \"${role}\",
        \"author\": \"${author}\",
        \"content\": ${escaped_content},
        \"location\": ${escaped_location},
        \"code_snippet\": ${escaped_code},
        \"function_name\": ${escaped_function},
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
    
    # Get linked issue if any (provides original requirements/context)
    local issue_number=$(gh pr view "$pr_number" --repo "${REPO_OWNER}/${REPO_NAME}" \
        --json body --jq '.body' 2>/dev/null | grep -oE '#[0-9]+' | head -1 | tr -d '#' || echo "")
    local issue_body=""
    local issue_title=""
    local has_issue_context=false
    
    if [ -n "$issue_number" ]; then
        issue_title=$(gh issue view "$issue_number" --repo "${REPO_OWNER}/${REPO_NAME}" \
            --json title --jq '.title' 2>/dev/null || echo "")
        issue_body=$(gh issue view "$issue_number" --repo "${REPO_OWNER}/${REPO_NAME}" \
            --json body --jq '.body' 2>/dev/null || echo "")
        
        # Validate issue has meaningful content
        if [ -n "$issue_body" ] && [ "$issue_body" != "null" ] && [ "${#issue_body}" -gt 10 ]; then
            has_issue_context=true
        fi
    fi
    
    # Get changed files
    local changed_files=$(gh pr view "$pr_number" --repo "${REPO_OWNER}/${REPO_NAME}" \
        --json files --jq '.files[].path' 2>/dev/null | head -20 | tr '\n' ', ' | sed 's/,$//')
    
    # Build context document
    local context="# Agent Context for PR #${pr_number}

## 1. PR Metadata
- **Title**: ${pr_title}
- **Branch**: ${pr_branch}
- **Files Changed**: ${changed_files}

## 2. Requirements & Background

"
    
    # Prioritize linked issue description over PR body
    if [ "$has_issue_context" = true ]; then
        # Use issue as primary context
        context="${context}### Linked Issue #${issue_number}: ${issue_title}

${issue_body}

"
        log_msg DEBUG "Using linked issue #${issue_number} as primary context"
    else
        # Fallback to PR body
        if [ -n "$pr_body" ] && [ "$pr_body" != "null" ]; then
            context="${context}### PR Description

${pr_body}

"
            log_msg DEBUG "Using PR body as primary context (no linked issue)"
        else
            context="${context}### Description

_No description provided in PR or linked issue_

"
            log_msg WARNING "No context found in PR body or linked issue"
        fi
    fi
    
    context="${context}
---

## 3. Review Conversation & Code Context

"
    
    # Add all messages from thread
    local messages=$(jq -r '.messages[] | 
        "### \(.role | ascii_upcase) (\(.author)) - \(.timestamp)\n" +
        (if .location != "" then 
            "**Location**: `\(.location)`" + 
            (if .function_name != "" then " in `\(.function_name)`" else "" end) + 
            "\n\n" 
        else "" end) +
        (if .code_snippet != "" then 
            "**Code at location:**\n```\n\(.code_snippet)\n```\n\n" 
        else "" end) +
        (if .location != "" then "**Comment:** " else "" end) +
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

