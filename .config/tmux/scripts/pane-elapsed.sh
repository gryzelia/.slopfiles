#!/usr/bin/env sh
# Prints elapsed time of the foreground child process of a given PID.
# Usage: pane-elapsed.sh <pane_pid>
# Returns "-" if no child is running or elapsed time is 0.

pid="$1"

case "$(uname)" in
    Linux)
        s=$(ps --ppid "$pid" -o etimes= --no-headers 2>/dev/null | head -1 | tr -d " ")
        ;;
    Darwin|*BSD)
        # macOS/BSD ps doesn't have etimes; etime outputs as [[DD-]HH:]MM:SS
        raw=$(ps -o etime= -p "$(pgrep -P "$pid" 2>/dev/null | head -1)" 2>/dev/null | tr -d " ")
        if [ -n "$raw" ]; then
            # Parse [[DD-]HH:]MM:SS into total seconds
            days=0 hours=0 mins=0 secs=0
            case "$raw" in
                *-*) days="${raw%%-*}"; raw="${raw#*-}" ;;
            esac
            IFS=: read -r a b c <<EOF
$raw
EOF
            if [ -n "$c" ]; then
                hours="$a"; mins="$b"; secs="$c"
            else
                mins="$a"; secs="$b"
            fi
            s=$((days * 86400 + hours * 3600 + mins * 60 + secs))
        fi
        ;;
esac

if [ -n "$s" ] && [ "$s" -gt 0 ] 2>/dev/null; then
    printf '%dm%02ds' $((s / 60)) $((s % 60))
else
    echo "-"
fi
