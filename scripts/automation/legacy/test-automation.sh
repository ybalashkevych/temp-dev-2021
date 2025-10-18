#!/bin/bash

#
# test-automation.sh
# LiveAssistant
#
# Test script for automation system
# Verifies all components work correctly
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="../../logs"
TEST_LOG="$LOG_DIR/automation-test.log"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "======================================"
echo "Automation System Test"
echo "======================================"
echo ""

# Create logs directory
mkdir -p "$LOG_DIR"

# Test 1: Check script files exist
echo -n "Test 1: Checking script files... "
if [ -f "$SCRIPT_DIR/daemon.sh" ] && \
   [ -f "$SCRIPT_DIR/state.sh" ] && \
   [ -f "$SCRIPT_DIR/thread.sh" ] && \
   [ -f "$SCRIPT_DIR/agent.sh" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
    echo "Missing required script files"
    exit 1
fi

# Test 2: Check scripts are executable
echo -n "Test 2: Checking execute permissions... "
if [ -x "$SCRIPT_DIR/daemon.sh" ] && \
   [ -x "$SCRIPT_DIR/state.sh" ] && \
   [ -x "$SCRIPT_DIR/thread.sh" ] && \
   [ -x "$SCRIPT_DIR/agent.sh" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
    echo "Scripts not executable. Run: chmod +x scripts/automation/*.sh"
    exit 1
fi

# Test 3: Check GitHub CLI
echo -n "Test 3: Checking GitHub CLI... "
if command -v gh &> /dev/null; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
    echo "GitHub CLI not installed. Install with: brew install gh"
    exit 1
fi

# Test 4: Check GitHub CLI authentication
echo -n "Test 4: Checking GitHub CLI auth... "
if gh auth status &> /dev/null; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${YELLOW}⚠ WARN${NC} Not authenticated. Run: gh auth login"
fi

# Test 5: Source and test state.sh functions
echo -n "Test 5: Testing state.sh functions... "
source "$SCRIPT_DIR/state.sh" 2>/dev/null
init_state 2>&1 > /dev/null
if [ -f "$LOG_DIR/automation-state.json" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
    exit 1
fi

# Test 6: Test thread creation
echo -n "Test 6: Testing thread.sh functions... "
source "$SCRIPT_DIR/thread.sh" 2>/dev/null
TEST_THREAD=$(get_or_create_thread "999" "test-comment-id" 2>/dev/null)
if [ -n "$TEST_THREAD" ] && [ -f "$LOG_DIR/${TEST_THREAD}.json" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
    # Clean up test thread
    rm -f "$LOG_DIR/${TEST_THREAD}.json" 2>/dev/null
else
    echo -e "${RED}✗ FAIL${NC}"
    echo "TEST_THREAD='$TEST_THREAD'"
    exit 1
fi

# Test 7: Test mock agent invocation
echo -n "Test 7: Testing agent.sh mock mode... "
export MOCK_AGENT=1
source "$SCRIPT_DIR/agent.sh" 2>/dev/null
TEST_RESPONSE=$(invoke_agent_mock "999" "test-thread-123" "ask" "Test context" 2>&1)
if [ -n "$TEST_RESPONSE" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
    exit 1
fi

# Test 8: Test daemon syntax
echo -n "Test 8: Checking daemon.sh syntax... "
if bash -n "$SCRIPT_DIR/daemon.sh" 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
    echo "Syntax error in daemon.sh"
    exit 1
fi

# Test 9: Verify .gitignore entries
echo -n "Test 9: Checking .gitignore entries... "
if grep -q "automation-state.json" .gitignore && \
   grep -q "pr-.*-thread-.*.json" .gitignore; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${YELLOW}⚠ WARN${NC} State files may not be gitignored"
fi

# Test 10: Test daemon control script
echo -n "Test 10: Checking daemon-control.sh... "
if [ -f "scripts/daemon-control.sh" ] && \
   grep -q "automation/daemon.sh" "scripts/daemon-control.sh"; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
    echo "daemon-control.sh not updated for new automation scripts"
    exit 1
fi

echo ""
echo "======================================"
echo -e "${GREEN}All tests passed!${NC}"
echo "======================================"
echo ""
echo "Next steps:"
echo "1. Start daemon: ./scripts/daemon-control.sh start"
echo "2. Monitor logs: tail -f logs/cursor-daemon.log"
echo "3. Create test PR with feedback"
echo "4. Add 'awaiting-cursor-response' label"
echo "5. Observe daemon processing"
echo ""
echo "For real agent: MOCK_AGENT=0 (default)"
echo "For mock testing: MOCK_AGENT=1"
echo ""

