#!/bin/bash

#
# automation/state.sh
# LiveAssistant
#
# State tracking utilities for processed comments and threads
# Prevents duplicate processing and maintains thread mappings
#

# Source common utilities if not already loaded
if ! command -v log_msg &> /dev/null; then
    _STATE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$_STATE_SCRIPT_DIR/common.sh" ]; then
        source "$_STATE_SCRIPT_DIR/common.sh"
    elif [ -f "scripts/automation/common.sh" ]; then
        source "scripts/automation/common.sh"
    else
        # Fallback: define a minimal log_msg function (output to stderr)
        log_msg() { echo "[$1] $2" >&2; }
    fi
fi

# State file location
STATE_FILE="${LOG_DIR:-logs}/automation-state.json"

# Initialize state file if it doesn't exist
init_state() {
    if [ ! -f "$STATE_FILE" ]; then
        echo '{"processed_comments": {}, "threads": {}, "comment_to_thread": {}}' > "$STATE_FILE"
        log_msg DEBUG "Initialized state file: $STATE_FILE"
    fi
}

# Check if comment has been processed
is_comment_processed() {
    local comment_id=$1
    init_state
    
    local processed=$(jq -r ".processed_comments[\"${comment_id}\"] // false" "$STATE_FILE" 2>/dev/null)
    [ "$processed" = "true" ]
}

# Mark comment as processed
mark_comment_processed() {
    local comment_id=$1
    local thread_id=$2
    init_state
    
    jq ".processed_comments[\"${comment_id}\"] = true | 
        .comment_to_thread[\"${comment_id}\"] = \"${thread_id}\"" \
        "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
    
        log_msg DEBUG "Marked comment $comment_id as processed (thread: $thread_id)"
}

# Get thread ID for a comment (if exists)
get_thread_for_comment() {
    local comment_id=$1
    init_state
    
    jq -r ".comment_to_thread[\"${comment_id}\"] // \"\"" "$STATE_FILE" 2>/dev/null
}

# Create new thread entry in state
register_thread() {
    local thread_id=$1
    local pr_number=$2
    init_state
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    jq ".threads[\"${thread_id}\"] = {
        \"pr_number\": ${pr_number},
        \"created_at\": \"${timestamp}\",
        \"status\": \"active\"
    }" "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
    
        log_msg DEBUG "Registered thread: $thread_id for PR #${pr_number}"
}

# Update thread status
update_thread_status() {
    local thread_id=$1
    local status=$2  # "active", "completed", "failed"
    init_state
    
    jq ".threads[\"${thread_id}\"].status = \"${status}\"" \
        "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
    
        log_msg DEBUG "Updated thread $thread_id status to: $status"
}

# Get all active threads for a PR
get_active_threads() {
    local pr_number=$1
    init_state
    
    jq -r ".threads | to_entries[] | 
           select(.value.pr_number == ${pr_number} and .value.status == \"active\") | 
           .key" "$STATE_FILE" 2>/dev/null || echo ""
}

# Clean up old state (optional, for maintenance)
cleanup_old_state() {
    local days_old=${1:-30}
    init_state
    
    local cutoff_date=$(date -u -v-${days_old}d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
                        date -u -d "${days_old} days ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
    
    if [ -z "$cutoff_date" ]; then
        log_msg WARNING "Could not calculate cutoff date for cleanup"
        return 1
    fi
    
    # This is a simplified cleanup - in production might want more sophisticated logic
        log_msg INFO "State cleanup: removing entries older than $days_old days"
    
    # For now, just log - actual implementation would filter by date
        log_msg DEBUG "Cleanup not yet implemented, state file preserved"
}

