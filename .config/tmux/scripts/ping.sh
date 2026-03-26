#!/usr/bin/env bash
# Prints ping latency to a target host (default: 8.8.8.8).
# Runs ping in the background to avoid blocking the status bar.
# On each invocation: if the previous background ping finished, read its
# result, update the cache, and start a new one. Otherwise return the cache.
# References:
#   https://github.com/ayzenquwe/tmux-ping

HOST="${1:-8.8.8.8}"

PING_LOG="/tmp/tmux-ping.log"
PING_CACHE="/tmp/tmux-ping.cache"
PING_PID="/tmp/tmux-ping.pid"

ping_not_running() {
    [ ! -f "$PING_PID" ] || ! kill -0 "$(cat "$PING_PID")" 2>/dev/null
}

read_cached_result() {
    if [ -f "$PING_CACHE" ]; then
        cat "$PING_CACHE"
    else
        echo "×"
    fi
}

read_ping_result() {
    # rtt line format: rtt min/avg/max/mdev = x/AVG/x/x ms
    local ms
    ms=$(cut -sd / -f 5 "$PING_LOG" 2>/dev/null | cut -d . -f 1)
    if [ -n "$ms" ] && [ "$ms" -ge 0 ] 2>/dev/null; then
        printf "%sms" "$ms"
    else
        echo "×"
    fi
}

execute_ping() {
    case "$(uname)" in
        Linux)
            # -c 1: single ping, -W 2: 2 second timeout
            ping -c 1 -W 2 "$HOST" > "$PING_LOG" 2>/dev/null &
            ;;
        Darwin|*BSD)
            # macOS ping uses -t for timeout
            ping -c 1 -t 2 "$HOST" > "$PING_LOG" 2>/dev/null &
            ;;
    esac
    echo "$!" > "$PING_PID"
}

main() {
    if ping_not_running; then
        # Previous ping finished — read its result and start a new one
        read_ping_result > "$PING_CACHE"
        execute_ping
    fi

    read_cached_result
}
main
