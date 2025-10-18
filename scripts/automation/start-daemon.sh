#!/bin/bash
#
# Convenience script to start the Cursor automation daemon
# Handles Python path and configuration
#

set -euo pipefail

# Add Python 3.11 bin to PATH
export PATH="/Users/yurii/Library/Python/3.11/bin:$PATH"

# Set GitHub token if not already set
if [ -z "${CURSOR_GITHUB_TOKEN:-}" ]; then
    if command -v gh &> /dev/null; then
        export CURSOR_GITHUB_TOKEN=$(gh auth token 2>/dev/null || echo "")
    fi
fi

# Change to automation directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if cursor-daemon is available
if ! command -v cursor-daemon &> /dev/null; then
    echo "❌ cursor-daemon not found. Installing..."
    python3.11 -m pip install -e . --user
fi

# Run daemon with any provided arguments
echo "🚀 Starting Cursor Automation Daemon..."
echo "   Repository: ${CURSOR_REPO_OWNER:-ybalashkevych}/${CURSOR_REPO_NAME:-temp-dev-2021}"
echo "   Log directory: logs/"
echo ""
echo "Press Ctrl+C to stop"
echo ""

cursor-daemon daemon "$@"


