#!/bin/bash

#
# invoke-cursor-agent.sh
# LiveAssistant
#
# Helper script to invoke cursor agent with prepared instructions
# This script reads the agent request and invokes cursor appropriately
#

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

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

# Parse request file
PR_NUMBER=$(jq -r '.pr_number' "$REQUEST_FILE")
THREAD_ID=$(jq -r '.thread_id' "$REQUEST_FILE")
COMMAND=$(jq -r '.command' "$REQUEST_FILE")
BRANCH=$(jq -r '.branch' "$REQUEST_FILE")
INSTRUCTIONS_FILE=$(jq -r '.instructions_file' "$REQUEST_FILE")
CONTEXT_FILE=$(jq -r '.context_file' "$REQUEST_FILE")
LOG_FILE=$(jq -r '.log_file' "$REQUEST_FILE")
REPO=$(jq -r '.repo' "$REQUEST_FILE")

log_msg INFO "Processing cursor agent request:"
log_msg INFO "  PR: #${PR_NUMBER}"
log_msg INFO "  Thread: ${THREAD_ID}"
log_msg INFO "  Command: ${COMMAND}"
log_msg INFO "  Branch: ${BRANCH}"

# Verify files exist
if [ ! -f "$INSTRUCTIONS_FILE" ]; then
    log_msg ERROR "Instructions file not found: $INSTRUCTIONS_FILE"
    exit 1
fi

if [ ! -f "$CONTEXT_FILE" ]; then
    log_msg ERROR "Context file not found: $CONTEXT_FILE"
    exit 1
fi

# Create response directory
WORK_DIR=$(dirname "$INSTRUCTIONS_FILE")

# Convert to absolute paths to handle directory changes
INSTRUCTIONS_FILE=$(cd "$(dirname "$INSTRUCTIONS_FILE")" && pwd)/$(basename "$INSTRUCTIONS_FILE")
CONTEXT_FILE=$(cd "$(dirname "$CONTEXT_FILE")" && pwd)/$(basename "$CONTEXT_FILE")
WORK_DIR=$(cd "$WORK_DIR" && pwd)
RESPONSE_FILE="$WORK_DIR/agent-response.txt"

log_msg INFO "Instructions: $INSTRUCTIONS_FILE"
log_msg INFO "Response will be written to: $RESPONSE_FILE"

# Validation function for response files
validate_response() {
    local response_file=$1
    if [ ! -f "$response_file" ]; then
        return 1
    fi
    if [ ! -s "$response_file" ]; then
        return 1
    fi
    # Response is valid if it exists and is non-empty
    # Agent will write SUCCESS: or FAILURE: prefix if following instructions
    return 0
}

# Method 1: Try cursor agent with print mode (non-interactive)
if command -v cursor &> /dev/null; then
    log_msg INFO "Attempting to invoke cursor agent with print mode..."
    
    # Change to work directory to ensure proper file access
    original_dir=$(pwd)
    cd "$WORK_DIR"
    
    # Get model from environment or use default
    model="${CURSOR_MODEL:-claude-4.5-sonnet}"
    log_msg INFO "Using model: $model"
    
    # Try cursor agent with print mode and instructions file
    # Redirect output to temp file first
    if cursor agent --print --model "$model" --output-format text < "$INSTRUCTIONS_FILE" > "${RESPONSE_FILE}.tmp" 2>&1; then
        cd "$original_dir"
        # Validate and wrap response
        if validate_response "${RESPONSE_FILE}.tmp"; then
            echo "SUCCESS: Cursor agent completed" > "$RESPONSE_FILE"
            echo "" >> "$RESPONSE_FILE"
            cat "${RESPONSE_FILE}.tmp" >> "$RESPONSE_FILE"
            rm -f "${RESPONSE_FILE}.tmp"
            log_msg SUCCESS "Cursor agent completed successfully"
            cat "$RESPONSE_FILE"
            exit 0
        else
            log_msg WARNING "Cursor agent produced empty or invalid response"
            rm -f "${RESPONSE_FILE}.tmp"
        fi
    else
        log_msg WARNING "Cursor agent invocation failed"
        cd "$original_dir"
    fi
fi

# Method 2: Try cursor agent with combined prompt
if command -v cursor &> /dev/null; then
    log_msg INFO "Attempting cursor agent with combined prompt..."
    
    # Change to work directory to ensure proper file access
    original_dir=$(pwd)
    cd "$WORK_DIR"
    
    # Create a combined prompt file
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
    
    # Get model from environment or use default
    model="${CURSOR_MODEL:-claude-4.5-sonnet}"
    log_msg INFO "Using model: $model with combined prompt"
    
    # Try cursor agent with the combined prompt
    # Redirect output to temp file first
    if cursor agent --print --model "$model" --output-format text < "$combined_prompt" > "${RESPONSE_FILE}.tmp" 2>&1; then
        cd "$original_dir"
        # Validate and wrap response
        if validate_response "${RESPONSE_FILE}.tmp"; then
            echo "SUCCESS: Cursor agent completed" > "$RESPONSE_FILE"
            echo "" >> "$RESPONSE_FILE"
            cat "${RESPONSE_FILE}.tmp" >> "$RESPONSE_FILE"
            rm -f "${RESPONSE_FILE}.tmp"
            log_msg SUCCESS "Cursor agent completed successfully"
            cat "$RESPONSE_FILE"
            exit 0
        else
            log_msg WARNING "Cursor agent produced empty or invalid response"
            rm -f "${RESPONSE_FILE}.tmp"
        fi
    else
        log_msg WARNING "Cursor agent with combined prompt failed"
        cd "$original_dir"
    fi
fi

# Method 3: Interactive mode - manual invocation required
log_msg INFO "Manual cursor agent invocation required..."
log_msg INFO ""
log_msg INFO "=========================================="
log_msg INFO "MANUAL CURSOR AGENT INVOCATION REQUIRED"
log_msg INFO "=========================================="
log_msg INFO ""
log_msg INFO "Instructions file: $INSTRUCTIONS_FILE"
log_msg INFO "Context file: $CONTEXT_FILE"
log_msg INFO "Work directory: $WORK_DIR"
log_msg INFO ""
log_msg INFO "Please:"
log_msg INFO "1. Open the work directory in Cursor manually: cursor $WORK_DIR"
log_msg INFO "2. Read the instructions file: $INSTRUCTIONS_FILE"
log_msg INFO "3. Read the context file: $CONTEXT_FILE"
log_msg INFO "4. Follow the workflow described in the instructions"
log_msg INFO "5. When complete, write your response to: $RESPONSE_FILE"
log_msg INFO ""
log_msg INFO "Response format:"
log_msg INFO "  For success: 'SUCCESS: <summary>'"
log_msg INFO "  For failure: 'FAILURE: <reason>'"
log_msg INFO ""
log_msg INFO "=========================================="

# DO NOT automatically open cursor - let user open manually when ready
# This prevents unwanted interruptions and gives user control over when to engage
# Removed: cursor "$WORK_DIR" &

# Create pending response
echo "PENDING_MANUAL_INVOCATION" > "$RESPONSE_FILE"

log_msg INFO "Waiting for manual completion..."
log_msg INFO "The daemon will check for completion automatically"

exit 2  # 2 = pending manual invocation

