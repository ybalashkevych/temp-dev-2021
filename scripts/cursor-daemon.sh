#!/bin/bash

#
# cursor-daemon.sh
# LiveAssistant
#
# Background daemon that monitors GitHub PRs for changes needing attention
# Runs continuously and processes PRs labeled with "needs-changes"
#

set -e

# Configuration
POLL_INTERVAL=60  # Check GitHub every 60 seconds
LOG_DIR="logs"
REPO_OWNER="ybalashkevych"
REPO_NAME="LiveAssistant"

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure log directory exists
mkdir -p "$LOG_DIR"

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
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        log WARNING "jq is not installed, installing..."
        brew install jq || {
            log ERROR "Failed to install jq"
            exit 1
        }
    fi
    
    log SUCCESS "All prerequisites met"
}

# Process a single PR
process_pr() {
    local pr_number=$1
    
    log INFO "Processing PR #${pr_number}"
    
    # Call the PR processing script
    if ./scripts/cursor-process-pr.sh "$pr_number" >> "$LOG_DIR/pr-${pr_number}.log" 2>&1; then
        log SUCCESS "Processed PR #${pr_number}"
        
        # Remove "needs-changes" label
        if gh pr edit "$pr_number" --remove-label "needs-changes" 2>&1; then
            log INFO "Removed 'needs-changes' label from PR #${pr_number}"
        fi
        
        # Add "cursor-processing" label
        if gh pr edit "$pr_number" --add-label "cursor-processing" 2>&1; then
            log INFO "Added 'cursor-processing' label to PR #${pr_number}"
        fi
        
        return 0
    else
        log ERROR "Failed to process PR #${pr_number}"
        log ERROR "Check ${LOG_DIR}/pr-${pr_number}.log for details"
        return 1
    fi
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
        
        # Get PRs with "needs-changes" label
        local prs=$(gh pr list \
            --label "needs-changes" \
            --json number \
            --jq '.[].number' \
            2>&1)
        
        if [ $? -ne 0 ]; then
            log ERROR "Failed to fetch PRs from GitHub"
            log ERROR "Error: $prs"
            sleep $POLL_INTERVAL
            continue
        fi
        
        if [ -z "$prs" ]; then
            log INFO "No PRs need attention"
        else
            local pr_count=$(echo "$prs" | wc -l | tr -d ' ')
            log INFO "Found ${pr_count} PR(s) needing attention"
            
            # Process each PR
            echo "$prs" | while read -r pr_number; do
                if [ -n "$pr_number" ]; then
                    process_pr "$pr_number"
                fi
            done
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

