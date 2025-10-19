#!/bin/bash

#
# daemon-control.sh
# LiveAssistant
#
# Simple daemon control without launchd
# Usage: ./scripts/daemon-control.sh {start|stop|status|restart}
#

DAEMON_SCRIPT="./scripts/automation/daemon.sh"
LOG_DIR="logs"
PID_FILE="${LOG_DIR}/cursor-daemon.pid"

case "$1" in
    start)
        if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
            echo "Daemon already running (PID: $(cat "$PID_FILE"))"
            exit 0
        fi
        
        echo "Starting cursor daemon..."
        nohup "$DAEMON_SCRIPT" >> "$LOG_DIR/cursor-daemon.log" 2>> "$LOG_DIR/cursor-daemon.error.log" &
        echo $! > "$PID_FILE"
        echo "Daemon started (PID: $!)"
        echo "View logs: tail -f $LOG_DIR/cursor-daemon.log"
        ;;
    
    stop)
        if [ -f "$PID_FILE" ]; then
            PID=$(cat "$PID_FILE")
            if kill -0 "$PID" 2>/dev/null; then
                kill "$PID"
                rm "$PID_FILE"
                echo "Daemon stopped"
            else
                echo "Daemon not running (stale PID file)"
                rm "$PID_FILE"
            fi
        else
            echo "Daemon not running"
        fi
        ;;
    
    status)
        if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
            echo "Daemon is running (PID: $(cat "$PID_FILE"))"
        else
            echo "Daemon is not running"
        fi
        ;;
    
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
    
    *)
        echo "Usage: $0 {start|stop|status|restart}"
        exit 1
        ;;
esac

