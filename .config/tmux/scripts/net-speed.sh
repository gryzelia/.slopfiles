#!/usr/bin/env bash
# Prints current network download/upload speed by reading OS byte counters.
# No traffic is generated — this is passive monitoring only.
# References:
#   https://github.com/xamut/tmux-network-bandwidth
#   https://github.com/tmux-plugins/tmux-net-speed

CACHE_DIR="/tmp/tmux-net-speed"
mkdir -p "$CACHE_DIR"

get_bytes_linux() {
    # Sum RX and TX bytes across all non-loopback interfaces
    awk '
        NR>2 && $1 !~ /lo:/ {
            gsub(/:/, "", $1)
            rx += $2; tx += $10
        }
        END { print rx, tx }
    ' /proc/net/dev
}

get_bytes_bsd() {
    # netstat -ibn: sum ibytes/obytes for non-loopback interfaces
    netstat -ibn 2>/dev/null | awk '
        NR>1 && $1 !~ /lo/ && $4 ~ /[0-9]+\.[0-9]+/ {
            rx += $7; tx += $10
        }
        END { print rx, tx }
    '
}

format_speed() {
    # numfmt: auto-scale to human-readable IEC units (K, M, G)
    numfmt --to=iec --suffix=B --format="%.1f" "$1" 2>/dev/null || printf "%dB" "$1"
}

case "$(uname)" in
    Linux)       read -r rx tx <<< "$(get_bytes_linux)" ;;
    Darwin|*BSD) read -r rx tx <<< "$(get_bytes_bsd)" ;;
esac

now=$(date +%s)

# Read previous snapshot
if [ -f "$CACHE_DIR/prev" ]; then
    read -r prev_time prev_rx prev_tx < "$CACHE_DIR/prev"
    elapsed=$((now - prev_time))
    if [ "$elapsed" -gt 0 ]; then
        dl_speed=$(( (rx - prev_rx) / elapsed ))
        ul_speed=$(( (tx - prev_tx) / elapsed ))
        # Avoid negative values on counter reset
        [ "$dl_speed" -lt 0 ] 2>/dev/null && dl_speed=0
        [ "$ul_speed" -lt 0 ] 2>/dev/null && ul_speed=0
    else
        dl_speed=0
        ul_speed=0
    fi
else
    dl_speed=0
    ul_speed=0
fi

# Save current snapshot
echo "$now $rx $tx" > "$CACHE_DIR/prev"

printf "↓%s ↑%s" "$(format_speed "$dl_speed")" "$(format_speed "$ul_speed")"
