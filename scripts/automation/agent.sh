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
        rm -rf "$work_dir"
        return 1
    fi
    
    # Checkout PR branch
    log_msg INFO "Checking out branch: $pr_branch"
    git fetch origin "$pr_branch" 2>&1 | tee -a "$agent_log"
    git checkout "$pr_branch" 2>&1 | tee -a "$agent_log"
    
    if [ $? -ne 0 ]; then
        log_msg ERROR "Failed to checkout branch $pr_branch"
        rm -rf "$work_dir"
        return 1
    fi
    
    # Pull latest changes
    git pull origin "$pr_branch" 2>&1 | tee -a "$agent_log"
    
    # Build agent prompt based on command
    local agent_instructions="$work_dir/instructions.md"
    build_agent_instructions "$pr_number" "$thread_id" "$command" "$pr_branch" "$context" > "$agent_instructions"
    
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
    
    # Clean up work directory if successful
    if [ $status -eq 0 ]; then
        rm -rf "$work_dir"
    fi
    
    echo "$response"
    return $status
}

# Build comprehensive instructions for cursor agent
build_agent_instructions() {
    local pr_number=$1
    local thread_id=$2
    local command=$3
    local pr_branch=$4
    local context=$5
    
    cat <<EOF
# Cursor Agent Instructions

**PR**: #${pr_number}  
**Thread**: ${thread_id}  
**Branch**: ${pr_branch}  
**Mode**: ${command}  
**Timestamp**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

---

## Your Task

EOF

    case "$command" in
        ask)
            cat <<EOF
You are reviewing feedback on this PR. Your job is to:

1. Read and understand all the feedback provided
2. Identify any unclear or ambiguous points
3. Formulate specific, actionable questions
4. **DO NOT make any code changes**
5. Respond with questions or clarifications

### Guidelines
- Ask about requirements if unclear
- Seek clarification on edge cases
- Confirm understanding before proceeding
- Be specific in your questions

---

## Feedback Context

${context}

---

## Your Response

Please provide your questions or clarifications below:

EOF
            ;;
        plan)
            cat <<EOF
You are creating an implementation plan for this PR. Your job is to:

1. Analyze all the feedback provided
2. Create a detailed implementation plan
3. Identify files that need changes
4. Outline specific changes required
5. **DO NOT make any code changes yet**
6. Estimate complexity and potential issues

### Guidelines
- Be specific about what changes are needed
- Reference exact files and functions
- Consider architecture rules (.cursor/rules/)
- Identify potential challenges
- Provide step-by-step approach

---

## Feedback Context

${context}

---

## Your Implementation Plan

Please provide a detailed plan below:

EOF
            ;;
        implement)
            cat <<EOF
You are implementing changes for this PR. Follow this workflow:

## Step 1: Understand Requirements
Read all feedback carefully and understand what needs to be changed.

## Step 2: Make Code Changes
- Follow project architecture rules (.cursor/rules/)
- Follow coding standards (CONTRIBUTING.md)
- Make focused, minimal changes
- Ensure code quality

## Step 3: Build & Test Loop (Max 10 Attempts)

You have up to 10 attempts to get the build and tests passing. Track your attempts and learn from each failure.

### Retry Loop Algorithm:

For **attempt 1 through 10**:

1. **Build Phase:**
   \`\`\`bash
   xcodebuild clean build -scheme LiveAssistant 2>&1 | tee build-attempt-\${ATTEMPT_NUM}.log
   \`\`\`
   
   - **If build succeeds**: Proceed to Test Phase below
   - **If build fails**: 
     - Read \`build-attempt-\${ATTEMPT_NUM}.log\` carefully
     - Identify the specific error (syntax, missing import, type mismatch, etc.)
     - Understand WHY it failed
     - Fix the error in the code
     - Log what you fixed: \`echo "Attempt \${ATTEMPT_NUM}: Fixed <description>" >> retry.log\`
     - Increment attempt counter
     - Go to next attempt (back to step 1)

2. **Test Phase** (only runs if build succeeded):
   \`\`\`bash
   xcodebuild test -scheme LiveAssistant -testPlan LiveAssistant 2>&1 | tee test-attempt-\${ATTEMPT_NUM}.log
   \`\`\`
   
   - **If all tests pass**: SUCCESS! Proceed to Step 4 (Commit)
   - **If tests fail**:
     - Read \`test-attempt-\${ATTEMPT_NUM}.log\` carefully
     - Identify which specific tests failed
     - Read the test failure messages and assertions
     - Understand WHY the tests failed (logic error, wrong output, exception, etc.)
     - Fix the code to address the root cause
     - Log what you fixed: \`echo "Attempt \${ATTEMPT_NUM}: Fixed test failure - <description>" >> retry.log\`
     - Increment attempt counter
     - Go to next attempt (back to step 1)

3. **Learning Between Attempts:**
   - Keep track of errors you've seen to avoid repeating fixes
   - If you see the same error twice, try a DIFFERENT approach
   - Read previous logs: \`cat retry.log\` to see what you already tried
   - Consider if your approach is fundamentally wrong

4. **Stop Conditions:**
   - **Success**: Build passes AND all tests pass → Proceed to Step 4
   - **Exhausted attempts**: After 10 failed attempts → Proceed to Failure Handling

### Example Progression:

\`\`\`
Attempt 1: Build fails - "Expected '}' on line 42" → Fix syntax error
Attempt 2: Build succeeds, test fails - "testAddUser: Expected true but got false" → Fix logic in addUser()
Attempt 3: Build succeeds, all tests pass → SUCCESS! Continue to commit.
\`\`\`

### Important Notes:

- Each attempt should BUILD on knowledge from previous failures
- Don't make random changes - understand the error first
- If stuck after 3-4 attempts with same error, reconsider your approach
- Save all logs (build-attempt-N.log, test-attempt-N.log, retry.log)

## Step 4: Commit Changes

Use proper commit format:
\`\`\`
type(scope): brief description

Addresses feedback in PR #${pr_number} thread ${thread_id}

- Detailed change 1
- Detailed change 2
\`\`\`

**Commit types**: feat, fix, refactor, test, docs, chore, perf, style

## Step 5: Push Changes

\`\`\`bash
git push origin ${pr_branch}
\`\`\`

## Step 6: Update PR Description

Call the update function to add changes summary to PR description.

## Step 7: Report Success

Create a response file with:
\`\`\`
SUCCESS: <brief summary of changes>

Changes made:
- Change 1
- Change 2

Build: ✅ Success
Tests: ✅ X/Y passed
Commits: <commit hash>
\`\`\`

---

## Feedback Context

${context}

---

## Failure Handling

If you cannot complete after 10 attempts:

1. Review \`retry.log\` - what did you try?
2. Read the last error logs carefully
3. Document your attempts comprehensively
4. Create response file with:

\`\`\`
FAILURE: Unable to resolve issues after 10 attempts

Attempts summary (from retry.log):
<paste retry.log contents>

Last build status: [SUCCESS/FAILURE]
Last test status: [SUCCESS/FAILURE/NOT_RUN]

Last error details:
<paste relevant error from build-attempt-10.log or test-attempt-10.log>

What was tried:
1. Attempt 1: Fixed syntax error
2. Attempt 2: Added missing import
3. Attempt 3-5: Tried different logic approaches for failing test
...

Why it failed:
<your analysis of the root cause>

Suggestions for manual fix:
<what a human should look at>

Manual intervention required.
\`\`\`

This detailed failure report helps the developer understand what went wrong and pick up where you left off.

---

## Important Notes

- You have access to all project files
- Follow .cursor/rules/ strictly
- Use SwiftGen for strings/assets (Strings.*, Asset.*)
- Write tests for new functionality
- Maintain 20%+ code coverage
- All ViewModels use @Observable + @MainActor
- Access data through Repositories, not Services directly

---

## Getting Started

Read the feedback context above and begin implementation.

EOF
            ;;
    esac
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

