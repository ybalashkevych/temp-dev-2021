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

# Cursor model to use (default: claude-4.5-sonnet)
CURSOR_MODEL=${CURSOR_MODEL:-claude-4.5-sonnet}

# Invoke cursor agent
invoke_agent() {
    local pr_number=$1
    local thread_id=$2
    local command=$3
    local context=$4
    
    local agent_log="$LOG_DIR/pr-${pr_number}-agent-${thread_id}.log"
    local work_dir="$LOG_DIR/.agent-work-${thread_id}"
    
    log_msg INFO "Invoking cursor agent - mode: $command"
    mkdir -p "$work_dir"
    
    # Save context to file
    echo "$context" > "$work_dir/context.md"
    
    # Get PR branch and checkout
    local pr_branch=$(gh pr view "$pr_number" --repo "${REPO_OWNER}/${REPO_NAME}" \
        --json headRefName --jq '.headRefName' 2>/dev/null)
    
    if [ -z "$pr_branch" ]; then
        log_msg ERROR "Could not determine PR branch"
        return 1
    fi
    
    log_msg INFO "Checking out branch: $pr_branch"
    git fetch origin "$pr_branch" 2>&1 | tee -a "$agent_log"
    git checkout "$pr_branch" 2>&1 | tee -a "$agent_log" || {
        log_msg ERROR "Failed to checkout branch $pr_branch"
        return 1
    }
    git pull origin "$pr_branch" 2>&1 | tee -a "$agent_log"
    
    # Build agent instructions
    build_instructions "$pr_number" "$thread_id" "$command" "$pr_branch" > "$work_dir/instructions.md"
    
    # Create request file
    cat > "$work_dir/agent-request.json" <<EOF
{
  "pr_number": ${pr_number},
  "thread_id": "${thread_id}",
  "command": "${command}",
  "branch": "${pr_branch}",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "instructions_file": "${work_dir}/instructions.md",
  "context_file": "${work_dir}/context.md",
  "log_file": "${agent_log}",
  "repo": "${REPO_OWNER}/${REPO_NAME}"
}
EOF
    
    # Invoke cursor agent
    local response=""
    local status=0
    
    if [ -f "./scripts/automation/invoke-cursor-agent.sh" ]; then
        response=$(./scripts/automation/invoke-cursor-agent.sh "$work_dir/agent-request.json" 2>&1 | tee -a "$agent_log")
        status=$?
    else
        log_msg WARNING "Cursor agent helper script not found"
        echo "PENDING_MANUAL_INVOCATION" > "$work_dir/agent-response.txt"
        response="Manual invocation required. See: $work_dir/instructions.md"
        status=2
    fi
    
    # Check response file
    if [ -f "$work_dir/agent-response.txt" ]; then
        response=$(cat "$work_dir/agent-response.txt")
        if [ "$response" = "PENDING_MANUAL_INVOCATION" ]; then
            status=2
        elif echo "$response" | grep -q "SUCCESS"; then
            status=0
        else
            status=1
        fi
    fi
    
    echo "$response"
    return $status
}

# Build instructions for cursor agent (simplified)
build_instructions() {
    local pr_number=$1
    local thread_id=$2
    local command=$3
    local pr_branch=$4
    
    local template_dir="scripts/automation/templates"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Use sed to replace all placeholders in one pass
    sed -e "s/{{PR_NUMBER}}/$pr_number/g" \
        -e "s/{{THREAD_ID}}/$thread_id/g" \
        -e "s/{{BRANCH}}/$pr_branch/g" \
        -e "s/{{MODE}}/$command/g" \
        -e "s/{{TIMESTAMP}}/$timestamp/g" \
        "$template_dir/instructions-header.md" \
        "$template_dir/instructions-$command.md" \
        "$template_dir/instructions-footer.md"
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

