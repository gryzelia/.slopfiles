#!/usr/bin/env sh
# Counts child processes of a given PID (approximates background jobs).
# Usage: pane-jobs.sh <pane_pid>

pid="$1"

case "$(uname)" in
    Linux)
        ps --ppid "$pid" --no-headers 2>/dev/null | wc -l | tr -d " "
        ;;
    Darwin|*BSD)
        ps -o pid= -p "$(pgrep -P "$pid" 2>/dev/null)" 2>/dev/null | wc -l | tr -d " "
        ;;
esac
