#!/bin/bash

#
# automation/agent.sh
# LiveAssistant
#
# Cursor agent invocation and integration
# Handles ask, plan, and implement modes with proper context
#

# Source common utilities if not already loaded
if ! command -v log_msg &> /dev/null; then
    _AGENT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$_AGENT_SCRIPT_DIR/common.sh" ]; then
        source "$_AGENT_SCRIPT_DIR/common.sh"
    elif [ -f "scripts/automation/common.sh" ]; then
        source "scripts/automation/common.sh"
    else
        # Fallback: define a minimal log_msg function (output to stderr)
        log_msg() { echo "[$1] $2" >&2; }
    fi
fi

# Mock mode flag (set to 1 to enable mock mode for testing)
MOCK_AGENT=${MOCK_AGENT:-0}

# Cursor model to use (default: claude-4.5-sonnet)
CURSOR_MODEL=${CURSOR_MODEL:-claude-4.5-sonnet}

# Invoke agent in mock mode (for testing)
invoke_agent_mock() {
    local pr_number=$1
    local thread_id=$2
    local command=$3
    local context=$4
    
    # Set LOG_DIR if not already set
    local log_dir="${LOG_DIR:-logs}"
    local mock_log="$log_dir/pr-${pr_number}-agent-mock-${thread_id}.log"
    local work_dir="$log_dir/.agent-work-${thread_id}"
    
    log_msg INFO "[MOCK] Agent invocation - mode: $command"
    
    # Create work directory for mock
    mkdir -p "$work_dir"
    
    # Save context to file (same as real agent)
    local context_file="$work_dir/context.md"
    echo "$context" > "$context_file"
    
    # Generate instructions using the same template system
    local agent_instructions="$work_dir/instructions.md"
    build_agent_instructions "$pr_number" "$thread_id" "$command" "mock-branch" > "$agent_instructions"
    
    # Log what would be sent to agent
    cat > "$mock_log" <<EOF
====================================
MOCK AGENT INVOCATION
====================================
Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
PR Number: ${pr_number}
Thread ID: ${thread_id}
Command: ${command}

====================================
FILES GENERATED:
====================================
Instructions: ${agent_instructions}
Context: ${context_file}
Work directory: ${work_dir}

====================================
MOCK AGENT RESPONSE:
====================================
EOF
    
    # Generate mock response based on command
    local response=""
    case "$command" in
        ask)
            response="SUCCESS: Questions about the feedback

I have a few questions about this feedback:

1. Could you clarify the expected behavior?
2. Should this change apply to all similar cases?
3. Are there any edge cases I should consider?

Please provide additional details and I'll proceed with the implementation."
            ;;
        plan)
            response="SUCCESS: Implementation plan created

## Implementation Plan

### Changes Required
1. Update the affected component
2. Add necessary validation
3. Write unit tests
4. Update documentation

### Files to Modify
- Component file
- Test file
- Documentation

### Estimated Complexity
Medium - Should take 1-2 iterations

Ready to implement when you confirm this approach."
            ;;
        implement)
            response="SUCCESS: Implementation completed

## Changes Made
- Fixed the reported issue
- Added validation logic  
- Updated tests
- All tests passing
- Code coverage maintained

## Build Status
✅ Build: Success
✅ Tests: 15/15 passed
✅ Coverage: 85%

Changes committed and pushed to branch."
            ;;
    esac
    
    echo "$response" >> "$mock_log"
    echo "$response"
    
    # Simulate processing delay
    sleep 2
    
    log_msg INFO "[MOCK] Agent completed successfully"
    log_msg INFO "Mock work directory preserved: $work_dir"
    return 0
}

# Invoke real cursor agent
invoke_agent_real() {
    local pr_number=$1
    local thread_id=$2
    local command=$3
    local context=$4
    
    local agent_log="$LOG_DIR/pr-${pr_number}-agent-${thread_id}.log"
    local work_dir="$LOG_DIR/.agent-work-${thread_id}"
    
    log_msg INFO "[REAL] Invoking cursor agent - mode: $command"
    
    # Create work directory
    mkdir -p "$work_dir"
    
    # Save context to file for agent
    local context_file="$work_dir/context.md"
    echo "$context" > "$context_file"
    
    # Get PR branch
    local pr_branch=$(gh pr view "$pr_number" --repo "${REPO_OWNER}/${REPO_NAME}" \
        --json headRefName --jq '.headRefName' 2>/dev/null)
    
    if [ -z "$pr_branch" ]; then
        log_msg ERROR "Could not determine PR branch"
        # Don't clean up work directories - keep for debugging
        # if [ "${KEEP_WORK_DIR:-0}" != "1" ]; then
        #     rm -rf "$work_dir"
        # else
        #     log_msg INFO "Keeping work directory for debugging: $work_dir"
        # fi
        log_msg INFO "Work directory preserved: $work_dir"
        return 1
    fi
    
    # Checkout PR branch
    log_msg INFO "Checking out branch: $pr_branch"
    git fetch origin "$pr_branch" 2>&1 | tee -a "$agent_log"
    git checkout "$pr_branch" 2>&1 | tee -a "$agent_log"
    
    if [ $? -ne 0 ]; then
        log_msg ERROR "Failed to checkout branch $pr_branch"
        # Don't clean up work directories - keep for debugging
        # if [ "${KEEP_WORK_DIR:-0}" != "1" ]; then
        #     rm -rf "$work_dir"
        # else
        #     log_msg INFO "Keeping work directory for debugging: $work_dir"
        # fi
        log_msg INFO "Work directory preserved: $work_dir"
        return 1
    fi
    
    # Pull latest changes
    git pull origin "$pr_branch" 2>&1 | tee -a "$agent_log"
    
    # Build agent prompt based on command
    local agent_instructions="$work_dir/instructions.md"
    build_agent_instructions "$pr_number" "$thread_id" "$command" "$pr_branch" > "$agent_instructions"
    
    log_msg INFO "Agent instructions saved to: $agent_instructions"
    log_msg INFO "Context saved to: $context_file"
    
    # Create a marker file for the agent to process
    local marker_file="$work_dir/agent-request.json"
    cat > "$marker_file" <<EOF
{
  "pr_number": ${pr_number},
  "thread_id": "${thread_id}",
  "command": "${command}",
  "branch": "${pr_branch}",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "instructions_file": "${agent_instructions}",
  "context_file": "${context_file}",
  "log_file": "${agent_log}",
  "repo": "${REPO_OWNER}/${REPO_NAME}"
}
EOF
    
    log_msg INFO "Agent request prepared: $marker_file"
    
    # Invoke the agent via helper script
    local response=""
    local status=0
    
    if [ -f "./scripts/automation/invoke-cursor-agent.sh" ]; then
        log_msg INFO "Invoking cursor agent via helper script..."
        response=$(./scripts/automation/invoke-cursor-agent.sh "$marker_file" 2>&1 | tee -a "$agent_log")
        status=$?
    else
        log_msg WARNING "Cursor agent helper script not found"
        log_msg INFO "Manual invocation required - see: $agent_instructions"
        
        # Create response file for manual pickup
        local response_file="$work_dir/agent-response.txt"
        echo "PENDING_MANUAL_INVOCATION" > "$response_file"
        
        response="Agent invocation prepared. Manual processing required.
Instructions: $agent_instructions
Context: $context_file
Work directory: $work_dir
When complete, update: $response_file"
        status=2  # 2 = pending manual invocation
    fi
    
    # Check for response file
    local response_file="$work_dir/agent-response.txt"
    if [ -f "$response_file" ]; then
        response=$(cat "$response_file")
        if [ "$response" = "PENDING_MANUAL_INVOCATION" ]; then
            status=2
        elif echo "$response" | grep -q "SUCCESS"; then
            status=0
        else
            status=1
        fi
    fi
    
    # Don't clean up work directories - keep for debugging
    # if [ $status -eq 0 ]; then
    #     if [ "${KEEP_WORK_DIR:-0}" != "1" ]; then
    #         rm -rf "$work_dir"
    #     else
    #         log_msg INFO "Keeping work directory for debugging: $work_dir"
    #     fi
    # fi
    log_msg INFO "Work directory preserved: $work_dir"
    
    echo "$response"
    return $status
}

# Build comprehensive instructions for cursor agent
build_agent_instructions() {
    local pr_number=$1
    local thread_id=$2
    local command=$3
    local pr_branch=$4
    # Remove $context parameter - no longer embedded
    
    local template_dir="scripts/automation/templates"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Header (common to all modes)
    cat "$template_dir/instructions-header.md" | \
        sed "s/{{PR_NUMBER}}/$pr_number/g" | \
        sed "s/{{THREAD_ID}}/$thread_id/g" | \
        sed "s/{{BRANCH}}/$pr_branch/g" | \
        sed "s/{{MODE}}/$command/g" | \
        sed "s/{{TIMESTAMP}}/$timestamp/g"
    
    # Mode-specific instructions
    cat "$template_dir/instructions-$command.md" | \
        sed "s/{{PR_NUMBER}}/$pr_number/g" | \
        sed "s/{{THREAD_ID}}/$thread_id/g" | \
        sed "s/{{BRANCH}}/$pr_branch/g"
    
    # Footer (common to all modes)
    cat "$template_dir/instructions-footer.md"
}

# Main agent invocation entry point
invoke_agent() {
    local pr_number=$1
    local thread_id=$2
    local command=$3
    local context=$4
    
    if [ "$MOCK_AGENT" = "1" ]; then
        invoke_agent_mock "$pr_number" "$thread_id" "$command" "$context"
    else
        invoke_agent_real "$pr_number" "$thread_id" "$command" "$context"
    fi
}

# Update PR description with changes (called by agent after successful implement)
update_pr_description() {
    local pr_number=$1
    local changes_summary=$2
    
        log_msg INFO "Updating PR #${pr_number} description with changes"
    
    # Get current PR description
    local current_body=$(gh pr view "$pr_number" --repo "${REPO_OWNER}/${REPO_NAME}" \
        --json body --jq '.body' 2>/dev/null || echo "")
    
    # Remove old automated changes section if exists
    if echo "$current_body" | grep -q "## Automated Changes"; then
        current_body=$(echo "$current_body" | sed '/## Automated Changes/,$d')
    fi
    
    # Get recent commits
    local commits=$(git log origin/main..HEAD --oneline --no-decorate 2>/dev/null | head -10)
    
    # Build changes section
    local changes_section="

---

## Automated Changes

### Recent Commits
${commits}

### Summary
${changes_summary}

**Last Updated**: $(date '+%Y-%m-%d %H:%M:%S')  
**Status**: ✅ Changes committed and pushed  
"
    
    # Update PR description
    local new_body="${current_body}${changes_section}"
    
    echo "$new_body" | gh pr edit "$pr_number" --repo "${REPO_OWNER}/${REPO_NAME}" \
        --body-file - 2>/dev/null || {
        log_msg WARNING "Failed to update PR description"
        return 1
    }
    
        log_msg SUCCESS "Updated PR #${pr_number} description"
    return 0
}

