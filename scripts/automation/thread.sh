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

# Get session ID for thread
get_session_id() {
    local thread_id=$1
    local log_dir_path="${LOG_DIR:-logs}"
    local thread_file="$log_dir_path/${thread_id}.json"
    
    if [ ! -f "$thread_file" ]; then
        echo ""
        return 1
    fi
    
    jq -r '.cursor_session_id // ""' "$thread_file" 2>/dev/null || echo ""
}

# Store session ID for thread
store_session_id() {
    local thread_id=$1
    local session_id=$2
    local log_dir_path="${LOG_DIR:-logs}"
    local thread_file="$log_dir_path/${thread_id}.json"
    
    if [ ! -f "$thread_file" ]; then
        log_msg ERROR "Thread file not found: $thread_file"
        return 1
    fi
    
    jq ".cursor_session_id = \"${session_id}\"" "$thread_file" > "${thread_file}.tmp" && \
        mv "${thread_file}.tmp" "$thread_file"
    
    log_msg DEBUG "Stored session ID for thread $thread_id: $session_id"
}

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
  "cursor_session_id": "",
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

# Build full context for agent (simplified)
build_context() {
    local pr_number=$1
    local thread_id=$2
    
    local log_dir_path="${LOG_DIR:-logs}"
    local thread_file="$log_dir_path/${thread_id}.json"
    
    if [ ! -f "$thread_file" ]; then
        log_msg ERROR "Thread file not found: $thread_file"
        return 1
    fi
    
    # Get PR metadata in one call
    local pr_data=$(gh pr view "$pr_number" --repo "${REPO_OWNER}/${REPO_NAME}" \
        --json title,headRefName,body,files 2>/dev/null)
    
    local pr_title=$(echo "$pr_data" | jq -r '.title // "Unknown"')
    local pr_branch=$(echo "$pr_data" | jq -r '.headRefName // "unknown"')
    local pr_body=$(echo "$pr_data" | jq -r '.body // ""')
    local changed_files=$(echo "$pr_data" | jq -r '.files[].path' | head -20 | tr '\n' ', ' | sed 's/,$//')
    
    # Build context document
    cat <<EOF
# Agent Context for PR #${pr_number}

## 1. PR Metadata
- **Title**: ${pr_title}
- **Branch**: ${pr_branch}
- **Files Changed**: ${changed_files}

## 2. PR Description
${pr_body:-_No description provided_}

---

## 3. Review Conversation

EOF
    
    # Add all messages from thread with simplified formatting
    jq -r '.messages[] | 
        "### \(.role | ascii_upcase) (\(.author)) - \(.timestamp)\n" +
        (if .location != "" then "**Location**: `\(.location)`\n\n" else "" end) +
        (if .code_snippet != "" then "```\n\(.code_snippet)\n```\n\n" else "" end) +
        "\(.content)\n"' "$thread_file" 2>/dev/null
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

