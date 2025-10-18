#!/bin/bash

# Wrapper script for cursor-daemon to help debug launchd issues
# This ensures proper environment setup for launchd execution

# Set up PATH explicitly
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin

# Set HOME explicitly (launchd may not set it)
export HOME="${HOME:-/Users/yurii}"

# Change to project directory
cd /Users/yurii/Desktop/Projects/LiveAssistant || {
    echo "$(date) - Failed to change to project directory" >> /tmp/cursor-daemon-wrapper.log
    exit 1
}

# Log startup
echo "$(date) - Wrapper starting daemon from $(pwd)" >> /tmp/cursor-daemon-wrapper.log
echo "$(date) - PATH: $PATH" >> /tmp/cursor-daemon-wrapper.log
echo "$(date) - HOME: $HOME" >> /tmp/cursor-daemon-wrapper.log

# Execute the actual daemon
# Note: stdout/stderr are already redirected by launchd plist
exec ./scripts/cursor-daemon.sh 2>&1

