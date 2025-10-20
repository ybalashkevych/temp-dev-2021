#!/bin/bash

#
# invoke-cursor-agent.sh
# LiveAssistant
#
# Simplified cursor agent invocation with session resumption support
#

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/thread.sh"

# Check arguments
if [ $# -lt 1 ]; then
    log_msg ERROR "Usage: $0 <agent-request.json>"
    exit 1
fi

REQUEST_FILE=$1

if [ ! -f "$REQUEST_FILE" ]; then
    log_msg ERROR "Request file not found: $REQUEST_FILE"
    exit 1
fi

# Parse request
PR_NUMBER=$(jq -r '.pr_number' "$REQUEST_FILE")
THREAD_ID=$(jq -r '.thread_id' "$REQUEST_FILE")
COMMAND=$(jq -r '.command' "$REQUEST_FILE")
BRANCH=$(jq -r '.branch' "$REQUEST_FILE")
INSTRUCTIONS_FILE=$(jq -r '.instructions_file' "$REQUEST_FILE")
CONTEXT_FILE=$(jq -r '.context_file' "$REQUEST_FILE")
LOG_FILE=$(jq -r '.log_file' "$REQUEST_FILE")

log_msg INFO "Processing cursor agent request:"
log_msg INFO "  PR: #${PR_NUMBER}, Thread: ${THREAD_ID}, Command: ${COMMAND}"

# Verify files exist
if [ ! -f "$INSTRUCTIONS_FILE" ] || [ ! -f "$CONTEXT_FILE" ]; then
    log_msg ERROR "Instructions or context file not found"
    exit 1
fi

# Convert to absolute paths
INSTRUCTIONS_FILE=$(cd "$(dirname "$INSTRUCTIONS_FILE")" && pwd)/$(basename "$INSTRUCTIONS_FILE")
CONTEXT_FILE=$(cd "$(dirname "$CONTEXT_FILE")" && pwd)/$(basename "$CONTEXT_FILE")
WORK_DIR=$(dirname "$INSTRUCTIONS_FILE")
RESPONSE_FILE="$WORK_DIR/agent-response.txt"

log_msg INFO "Work directory: $WORK_DIR"

# Check if cursor is available
if ! command -v cursor &> /dev/null; then
    log_msg ERROR "Cursor CLI not found"
    echo "PENDING_MANUAL_INVOCATION" > "$RESPONSE_FILE"
    exit 2
fi

# Get model from environment
model="${CURSOR_MODEL:-claude-4.5-sonnet}"
log_msg INFO "Using model: $model"

# Try session resumption first
existing_session=$(get_session_id "$THREAD_ID")
if [ -n "$existing_session" ]; then
    log_msg INFO "Attempting to resume session: $existing_session"
    
    if cursor agent --session "$existing_session" --resume --print --model "$model" \
        < "$INSTRUCTIONS_FILE" > "${RESPONSE_FILE}.tmp" 2>&1; then
        
        if [ -s "${RESPONSE_FILE}.tmp" ]; then
            echo "SUCCESS: Cursor agent completed (resumed session)" > "$RESPONSE_FILE"
            echo "" >> "$RESPONSE_FILE"
            cat "${RESPONSE_FILE}.tmp" >> "$RESPONSE_FILE"
            rm -f "${RESPONSE_FILE}.tmp"
            log_msg SUCCESS "Session resumed successfully"
            exit 0
        fi
    fi
    
    log_msg WARNING "Session resume failed, creating new session"
    rm -f "${RESPONSE_FILE}.tmp"
fi

# Create combined prompt with context
combined_prompt="$WORK_DIR/combined-prompt.md"
{
    echo "# Instructions"
    cat "$INSTRUCTIONS_FILE"
    echo ""
    echo "---"
    echo ""
    echo "# Context"
    cat "$CONTEXT_FILE"
} > "$combined_prompt"

# Create new session
log_msg INFO "Creating new cursor agent session..."

# Invoke cursor and capture session ID
if cursor agent --print --model "$model" --output-format text \
    < "$combined_prompt" > "${RESPONSE_FILE}.tmp" 2>&1; then
    
    if [ -s "${RESPONSE_FILE}.tmp" ]; then
        # Try to extract session ID from output (if cursor provides it)
        # Format might be: "Session ID: abc123" or similar
        session_id=$(grep -oE "Session[: ]+[a-zA-Z0-9-]+" "${RESPONSE_FILE}.tmp" | head -1 | awk '{print $NF}' || echo "")
        
        if [ -n "$session_id" ]; then
            store_session_id "$THREAD_ID" "$session_id"
            log_msg INFO "Stored new session ID: $session_id"
        fi
        
        echo "SUCCESS: Cursor agent completed" > "$RESPONSE_FILE"
        echo "" >> "$RESPONSE_FILE"
        cat "${RESPONSE_FILE}.tmp" >> "$RESPONSE_FILE"
        rm -f "${RESPONSE_FILE}.tmp"
        log_msg SUCCESS "Cursor agent completed successfully"
        exit 0
    fi
fi

# Fallback to manual mode
log_msg WARNING "Automatic invocation failed"
log_msg INFO "=========================================="
log_msg INFO "MANUAL CURSOR AGENT INVOCATION REQUIRED"
log_msg INFO "=========================================="
log_msg INFO ""
log_msg INFO "Instructions: $INSTRUCTIONS_FILE"
log_msg INFO "Context: $CONTEXT_FILE"
log_msg INFO "Work directory: $WORK_DIR"
log_msg INFO ""
log_msg INFO "When complete, write response to: $RESPONSE_FILE"
log_msg INFO "Format: 'SUCCESS: <summary>' or 'FAILURE: <reason>'"

echo "PENDING_MANUAL_INVOCATION" > "$RESPONSE_FILE"
exit 2
