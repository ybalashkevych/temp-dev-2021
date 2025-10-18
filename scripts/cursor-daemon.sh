#!/bin/bash

#
# cursor-daemon.sh
# LiveAssistant
#
# Background daemon that monitors GitHub PRs for changes needing attention
# Runs continuously and processes PRs labeled with "needs-changes"
#

# Debug: Write startup marker immediately (before any other operations)
echo "[DEBUG] $(date) - Daemon script starting (PID: $$)" >> /tmp/cursor-daemon-debug.log 2>&1

# Note: Not using 'set -e' to allow graceful error handling
# The daemon should continue running even if individual operations fail

# Configuration
POLL_INTERVAL=60  # Check GitHub every 60 seconds
LOG_DIR="logs"
REPO_OWNER="ybalashkevych"
REPO_NAME="temp-dev-2021"
AUTO_RESPOND=false  # Interactive mode: respond to commands only
INTERACTIVE_MODE=true  # Post analysis, wait for @ybalashkevych commands
# Uses: cursor CLI to open feedback file for AI-assisted manual changes
# Set to false if you want manual code changes only

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure log directory exists
mkdir -p "$LOG_DIR" 2>> /tmp/cursor-daemon-debug.log
echo "[DEBUG] $(date) - Log directory created/verified" >> /tmp/cursor-daemon-debug.log 2>&1

# Logging function
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        INFO)
            echo -e "${BLUE}[${timestamp}] [INFO]${NC} ${message}"
            ;;
        SUCCESS)
            echo -e "${GREEN}[${timestamp}] [SUCCESS]${NC} ${message}"
            ;;
        WARNING)
            echo -e "${YELLOW}[${timestamp}] [WARNING]${NC} ${message}"
            ;;
        ERROR)
            echo -e "${RED}[${timestamp}] [ERROR]${NC} ${message}"
            ;;
        *)
            echo "[${timestamp}] ${message}"
            ;;
    esac
}

# Check prerequisites
check_prerequisites() {
    log INFO "Checking prerequisites..."
    
    # Check if gh is installed
    if ! command -v gh &> /dev/null; then
        log ERROR "GitHub CLI (gh) is not installed"
        log ERROR "Install with: brew install gh"
        exit 1
    fi
    
    # Check if gh is authenticated
    if ! gh auth status &> /dev/null; then
        log ERROR "GitHub CLI is not authenticated"
        log ERROR "Run: gh auth login"
        exit 1
    fi
    
    # Check if jq is installed (optional, used for JSON parsing)
    if ! command -v jq &> /dev/null; then
        log WARNING "jq is not installed (optional but recommended)"
        log WARNING "Install with: brew install jq"
        # Don't exit - daemon can still work without jq
    fi
    
    log SUCCESS "All prerequisites met"
}

# Check if PR has unresolved comments
has_unresolved_comments() {
    local pr_number=$1
    
    # Get inline code review comments (not replies)
    local review_comments=$(gh api "repos/${REPO_OWNER}/${REPO_NAME}/pulls/${pr_number}/comments" \
        --jq '[.[] | select(.in_reply_to_id == null)] | length' 2>/dev/null || echo "0")
    
    if [ "$review_comments" -gt 0 ]; then
        return 0  # Has unresolved code review comments
    fi
    
    # Get PR-level comments
    local pr_comments=$(gh pr view "$pr_number" --repo "${REPO_OWNER}/${REPO_NAME}" \
        --json comments --jq '.comments | length' 2>/dev/null || echo "0")
    
    if [ "$pr_comments" -gt 0 ]; then
        return 0  # Has PR comments
    fi
    
    return 1  # No comments
}

# Check for @ybalashkevych commands in PR comments
check_for_commands() {
    local pr_number=$1
    
    # Get recent PR-level comments (last 5)
    local pr_comments=$(gh pr view "$pr_number" --repo "${REPO_OWNER}/${REPO_NAME}" \
        --json comments --jq '.comments[-5:] | .[] | .body' 2>/dev/null)
    
    # Get recent inline review comments (last 50)
    local inline_comments=$(gh api "repos/${REPO_OWNER}/${REPO_NAME}/pulls/${pr_number}/comments?per_page=50" \
        --jq '.[-50:] | .[] | .body' 2>/dev/null)
    
    # Combine both types of comments
    local all_comments=$(echo -e "${pr_comments}\n${inline_comments}")
    
    if echo "$all_comments" | grep -q "@ybalashkevych implement"; then
        log INFO "Found '@ybalashkevych implement' command"
        return 0
    elif echo "$all_comments" | grep -q "@ybalashkevych fix"; then
        log INFO "Found '@ybalashkevych fix' command"
        return 0
    elif echo "$all_comments" | grep -q "@ybalashkevych plan"; then
        log INFO "Found '@ybalashkevych plan' command"
        return 2
    fi
    
    return 1
}

# Process a single PR
process_pr() {
    local pr_number=$1
    
    log INFO "Processing PR #${pr_number}"
    
    # Call the PR processing script
    if ./scripts/cursor-pr.sh process "$pr_number" >> "$LOG_DIR/pr-${pr_number}.log" 2>&1; then
        log SUCCESS "Processed PR #${pr_number}"
        
        # Check mode
        if [ "$INTERACTIVE_MODE" = "true" ]; then
            log INFO "INTERACTIVE_MODE enabled - posting analysis..."
            
            # Post analysis as @ybalashkevych
            if ./scripts/cursor-respond-interactive.sh analyze "$pr_number" "${REPO_OWNER}/${REPO_NAME}" >> "$LOG_DIR/pr-${pr_number}-analysis.log" 2>&1; then
                log SUCCESS "Posted analysis to PR #${pr_number}"
                
                # Add awaiting-response label (prevents re-analyzing)
                gh pr edit "$pr_number" --repo "${REPO_OWNER}/${REPO_NAME}" \
                    --add-label "awaiting-response" 2>/dev/null || true
                    
                log INFO "Waiting for '@ybalashkevych implement' or '@ybalashkevych plan' command"
            else
                log WARNING "Failed to post analysis"
            fi
            
        elif [ "$AUTO_RESPOND" = "true" ]; then
            log INFO "AUTO_RESPOND enabled - triggering automatic response..."
            
            if ./scripts/cursor-pr.sh respond --auto "$pr_number" "${REPO_OWNER}/${REPO_NAME}" >> "$LOG_DIR/pr-${pr_number}-auto-respond.log" 2>&1; then
                log SUCCESS "Automatic response completed for PR #${pr_number}"
            else
                log WARNING "Automatic response failed for PR #${pr_number}"
            fi
        else
            log INFO "Manual mode - feedback ready"
            gh pr edit "$pr_number" --repo "${REPO_OWNER}/${REPO_NAME}" \
                --remove-label "needs-changes" 2>/dev/null || true
        fi
        
        return 0
    else
        log ERROR "Failed to process PR #${pr_number}"
        return 1
    fi
}

# Handle command execution
handle_command() {
    local pr_number=$1
    local command_type=$2
    
    log INFO "Executing command for PR #${pr_number}: $command_type"
    
    case "$command_type" in
        implement|fix)
            if ./scripts/cursor-respond-interactive.sh implement "$pr_number" "${REPO_OWNER}/${REPO_NAME}" >> "$LOG_DIR/pr-${pr_number}-implement.log" 2>&1; then
                log SUCCESS "Implementation completed for PR #${pr_number}"
                gh pr edit "$pr_number" --repo "${REPO_OWNER}/${REPO_NAME}" \
                    --remove-label "awaiting-response" 2>/dev/null || true
            else
                log ERROR "Implementation failed"
            fi
            ;;
        plan)
            if ./scripts/cursor-respond-interactive.sh plan "$pr_number" "${REPO_OWNER}/${REPO_NAME}" >> "$LOG_DIR/pr-${pr_number}-plan.log" 2>&1; then
                log SUCCESS "Posted implementation plan"
            else
                log ERROR "Failed to post plan"
            fi
            ;;
    esac
}

# Main monitoring loop
monitor_prs() {
    log INFO "Starting PR monitoring"
    log INFO "Polling interval: ${POLL_INTERVAL} seconds"
    log INFO "Monitoring repository: ${REPO_OWNER}/${REPO_NAME}"
    
    local iteration=0
    
    while true; do
        iteration=$((iteration + 1))
        
        log INFO "Check #${iteration}: Looking for PRs needing attention..."
        
        # Get all open PRs
        local all_prs=$(gh pr list \
            --repo "${REPO_OWNER}/${REPO_NAME}" \
            --state open \
            --json number,labels \
            --jq '.[] | "\(.number)|\([.labels[].name] | join(","))"' \
            2>&1)
        
        if [ $? -ne 0 ]; then
            log ERROR "Failed to fetch PRs from GitHub"
            log ERROR "Error: $all_prs"
            sleep $POLL_INTERVAL
            continue
        fi
        
        # Process PRs with unresolved comments (not already awaiting response)
        if [ -n "$all_prs" ]; then
            echo "$all_prs" | while IFS='|' read -r pr_number labels; do
                if [ -n "$pr_number" ]; then
                    # Skip if already awaiting response
                    if echo "$labels" | grep -q "awaiting-response"; then
                        continue
                    fi
                    
                    # Check if PR has unresolved comments
                    if has_unresolved_comments "$pr_number"; then
                        log INFO "Found unresolved comments in PR #${pr_number}"
                        process_pr "$pr_number"
                    fi
                fi
            done
        fi
        
        # Check for commands on PRs awaiting response
        local awaiting_prs=$(gh pr list \
            --repo "${REPO_OWNER}/${REPO_NAME}" \
            --label "awaiting-response" \
            --json number \
            --jq '.[].number' \
            2>/dev/null)
        
        if [ -n "$awaiting_prs" ]; then
            echo "$awaiting_prs" | while read -r pr_number; do
                if [ -n "$pr_number" ]; then
                    check_for_commands "$pr_number"
                    local cmd_type=$?
                    if [ "$cmd_type" -ne 1 ]; then
                        # Found a command (0 = implement, 2 = plan)
                        case $cmd_type in
                            0)
                                handle_command "$pr_number" "implement"
                                ;;
                            2)
                                handle_command "$pr_number" "plan"
                                ;;
                        esac
                    fi
                fi
            done
        fi
        
        if [ -z "$prs" ] && [ -z "$awaiting_prs" ]; then
            log INFO "No PRs need attention"
        fi
        
        # Sleep before next check
        sleep $POLL_INTERVAL
    done
}

# Signal handlers
cleanup() {
    log INFO "Received shutdown signal, cleaning up..."
    log INFO "Daemon stopped"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Main execution
main() {
    log INFO "=================================="
    log INFO "Cursor Background Daemon Starting"
    log INFO "=================================="
    
    # Check prerequisites first
    check_prerequisites
    
    log SUCCESS "Cursor daemon started successfully"
    log INFO "Process ID: $$"
    log INFO "Logs: $LOG_DIR/cursor-daemon.log"
    
    # Start monitoring
    monitor_prs
}

# Run main function
main

