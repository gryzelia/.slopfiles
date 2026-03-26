#!/usr/bin/env bash
# Prints packet loss percentage using weighted averaging.
# Only outputs if loss > 0% to avoid clutter.
# Runs ping in the background to avoid blocking the status bar.
# Weighted average: max of (last value, avg of last 2, ..., avg of all)
#   — matches the algorithm from the reference plugin.
# References:
#   https://github.com/jaclu/tmux-packet-loss

HOST="${1:-8.8.8.8}"
COUNT=5
HISTORY_SIZE=5

CACHE_DIR="/tmp/tmux-packet-loss"
HISTORY_FILE="$CACHE_DIR/history"
RESULT_FILE="$CACHE_DIR/result"
PID_FILE="$CACHE_DIR/ping.pid"
LOG_FILE="$CACHE_DIR/ping.log"

mkdir -p "$CACHE_DIR"

ping_not_running() {
    [ ! -f "$PID_FILE" ] || ! kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

read_ping_loss() {
    # Parse "X% packet loss" from ping output
    local loss
    case "$(uname)" in
        Linux)
            loss=$(awk -F '[, %]+' '/packet loss/ { print $6 }' "$LOG_FILE" 2>/dev/null)
            ;;
        Darwin|*BSD)
            loss=$(awk -F '[, %]+' '/packet loss/ { print $7 }' "$LOG_FILE" 2>/dev/null)
            ;;
    esac
    echo "${loss:-0}"
}

append_to_history() {
    echo "$1" >> "$HISTORY_FILE"
    # Keep only the last HISTORY_SIZE entries
    tail -n "$HISTORY_SIZE" "$HISTORY_FILE" > "$HISTORY_FILE.tmp"
    mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
}

# Weighted average: max of (last value, avg of last 2, avg of last 3, ..., avg of all)
weighted_loss() {
    awk '
    {
        vals[NR] = $1
        n = NR
    }
    END {
        if (n == 0) { print 0; exit }
        mx = 0
        for (w = 1; w <= n; w++) {
            sum = 0
            for (i = n; i > n - w; i--) sum += vals[i]
            avg = sum / w
            if (avg > mx) mx = avg
        }
        printf "%d", mx
    }' "$HISTORY_FILE" 2>/dev/null || echo 0
}

execute_ping() {
    case "$(uname)" in
        Linux)
            ping -c "$COUNT" -W 2 "$HOST" > "$LOG_FILE" 2>/dev/null &
            ;;
        Darwin|*BSD)
            ping -c "$COUNT" -t 2 "$HOST" > "$LOG_FILE" 2>/dev/null &
            ;;
    esac
    echo "$!" > "$PID_FILE"
}

main() {
    if ping_not_running; then
        # Previous ping finished — record result and start a new one
        if [ -f "$LOG_FILE" ]; then
            append_to_history "$(read_ping_loss)"
        fi
        execute_ping
    fi

    local loss
    loss=$(weighted_loss)
    if [ "$loss" -gt 0 ] 2>/dev/null; then
        printf "%s%%" "$loss" > "$RESULT_FILE"
    else
        rm -f "$RESULT_FILE"
    fi

    # Output cached result (or nothing if 0%)
    [ -f "$RESULT_FILE" ] && cat "$RESULT_FILE"
}
main
