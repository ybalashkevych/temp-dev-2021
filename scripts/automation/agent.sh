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

# Mock mode flag (set to 0 to enable real agent invocation)
MOCK_AGENT=${MOCK_AGENT:-1}

# Invoke agent in mock mode (for testing)
invoke_agent_mock() {
    local pr_number=$1
    local thread_id=$2
    local command=$3
    local context=$4
    
    local mock_log="$LOG_DIR/pr-${pr_number}-agent-mock-${thread_id}.log"
    
        log_msg INFO "[MOCK] Agent invocation - mode: $command"
    
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
CONTEXT SENT TO AGENT:
====================================
${context}

====================================
MOCK AGENT RESPONSE:
====================================
EOF
    
    # Generate mock response based on command
    local response=""
    case "$command" in
        ask)
            response="Mock: I have a few questions about this feedback:
1. Could you clarify the expected behavior?
2. Should this change apply to all similar cases?
3. Are there any edge cases I should consider?

Please provide additional details and I'll proceed with the implementation."
            ;;
        plan)
            response="Mock: Implementation Plan:

## Changes Required
1. Update the affected component
2. Add necessary validation
3. Write unit tests
4. Update documentation

## Files to Modify
- Component file
- Test file
- Documentation

## Estimated Complexity
Medium - Should take 1-2 iterations

Ready to implement when you confirm this approach."
            ;;
        implement)
            response="Mock: Implementation completed:

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
    return 0
}

# Invoke real cursor agent
invoke_agent_real() {
    local pr_number=$1
    local thread_id=$2
    local command=$3
    local context=$4
    
    local agent_log="$LOG_DIR/pr-${pr_number}-agent-${thread_id}.log"
    
        log_msg INFO "[REAL] Invoking cursor agent - mode: $command"
    
    # Save context to temporary file for agent
    local context_file="$LOG_DIR/.agent-context-${thread_id}.md"
    echo "$context" > "$context_file"
    
    # Get PR branch
    local pr_branch=$(gh pr view "$pr_number" --repo "${REPO_OWNER}/${REPO_NAME}" \
        --json headRefName --jq '.headRefName' 2>/dev/null)
    
    if [ -z "$pr_branch" ]; then
        log_msg ERROR "Could not determine PR branch"
        return 1
    fi
    
    # Checkout PR branch
        log_msg INFO "Checking out branch: $pr_branch"
    git fetch origin "$pr_branch" 2>&1 | tee -a "$agent_log"
    git checkout "$pr_branch" 2>&1 | tee -a "$agent_log"
    
    if [ $? -ne 0 ]; then
        log_msg ERROR "Failed to checkout branch $pr_branch"
        return 1
    fi
    
    # Build agent prompt based on command
    local agent_prompt=""
    case "$command" in
        ask)
            agent_prompt="You are reviewing feedback on PR #${pr_number}. 

Review the context below and ask clarifying questions if anything is unclear or ambiguous. Do not make any code changes yet, just analyze and ask questions.

Thread: ${thread_id}

${context}

Please provide your questions or clarifications."
            ;;
        plan)
            agent_prompt="You are planning changes for PR #${pr_number}.

Review the feedback context below and create a detailed implementation plan. Do not make code changes yet, just outline what needs to be done.

Thread: ${thread_id}

${context}

Please provide a detailed implementation plan."
            ;;
        implement)
            agent_prompt="You are implementing changes for PR #${pr_number}.

Review the feedback context below and implement the required changes. Follow these steps:

1. Make the necessary code changes following project architecture rules
2. Run build: xcodebuild clean build -scheme LiveAssistant
3. Run tests: xcodebuild test -scheme LiveAssistant -testPlan LiveAssistant
4. If build/test fails, analyze errors and fix (up to 10 attempts)
5. When successful, commit with format: type(scope): subject
   Body: Addresses feedback in PR #${pr_number} thread ${thread_id}
6. Push changes: git push origin ${pr_branch}
7. Update PR description with changes summary

Thread: ${thread_id}

${context}

Follow project conventions from .cursor/rules/ and CONTRIBUTING.md.
Implement the changes, test, commit with proper format, and push."
            ;;
    esac
    
    # Save prompt for logging
    echo "$agent_prompt" > "$agent_log"
    
    # Invoke cursor agent
    # Note: This is a placeholder - actual cursor invocation method depends on cursor CLI/API
    # For now, we'll use a placeholder that developers can replace with actual cursor command
    
    local response=""
    local status=0
    
    if [ "$command" = "implement" ]; then
        # For implement mode, agent should handle the full workflow
        # This is where cursor would be invoked with the prompt
        
        log_msg WARNING "[REAL] Cursor agent invocation not yet implemented"
        log_msg WARNING "[REAL] This requires cursor CLI/API integration"
        log_msg INFO "[REAL] Agent prompt saved to: $agent_log"
        log_msg INFO "[REAL] Context saved to: $context_file"
        
        response="Cursor agent invocation placeholder - see logs for prompt and context"
        status=1
        
        # TODO: Replace with actual cursor invocation:
        # cursor --agent --prompt "$agent_prompt" --context "$context_file" > "$agent_log" 2>&1
        # status=$?
        # response=$(cat "$agent_log")
    else
        # For ask/plan modes, simpler invocation
        log_msg WARNING "[REAL] Cursor agent invocation not yet implemented"
        
        response="Cursor agent invocation placeholder - see logs for prompt and context"
        status=1
        
        # TODO: Replace with actual cursor invocation
    fi
    
    # Clean up context file
    rm -f "$context_file"
    
    echo "$response"
    return $status
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

