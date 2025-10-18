#!/bin/bash

#
# automation/common.sh
# LiveAssistant
#
# Common utilities shared across all automation scripts
#

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function (outputs to stderr to not interfere with function returns)
log_msg() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        INFO)
            echo -e "${BLUE}[${timestamp}] [INFO]${NC} ${message}" >&2
            ;;
        SUCCESS)
            echo -e "${GREEN}[${timestamp}] [SUCCESS]${NC} ${message}" >&2
            ;;
        WARNING)
            echo -e "${YELLOW}[${timestamp}] [WARNING]${NC} ${message}" >&2
            ;;
        ERROR)
            echo -e "${RED}[${timestamp}] [ERROR]${NC} ${message}" >&2
            ;;
        DEBUG)
            if [ "${DEBUG:-0}" = "1" ]; then
                echo -e "${NC}[${timestamp}] [DEBUG]${NC} ${message}" >&2
            fi
            ;;
    esac
}

