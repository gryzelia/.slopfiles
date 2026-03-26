#!/usr/bin/env bash
# Prints current CPU usage percentage.
# Uses top (2 samples, 1s apart) with iostat fallback.
# The sampling tool handles the two-snapshot delta internally.
# References:
#   https://github.com/samoshkin/tmux-plugin-sysstat/blob/master/scripts/cpu_collect.sh
#   https://github.com/tmux-plugins/tmux-cpu

case "$(uname)" in
    Linux)
        # top -bn2: batch mode, 2 samples; extract idle% from last sample
        if command -v top >/dev/null 2>&1; then
            top -bn2 -d1 2>/dev/null | awk '/^%?Cpu/ { idle=$8 } END { printf "%d%%", 100-idle }'
        # iostat -c 1 2: 2 samples 1s apart; last field is idle%
        elif command -v iostat >/dev/null 2>&1; then
            iostat -c 1 2 2>/dev/null | awk 'END { printf "%d%%", 100-$NF }'
        fi
        ;;
    Darwin|*BSD)
        # top -l2: 2 samples; extract idle from "CPU usage" line
        if command -v top >/dev/null 2>&1; then
            top -l 2 -s 1 -n 0 2>/dev/null | awk '/CPU usage/ { gsub(/%/,""); printf "%d%%\n", 100-$7 }' | tail -1
        # iostat: subtract idle from 100
        elif command -v iostat >/dev/null 2>&1; then
            iostat -c 2 -w 1 2>/dev/null | awk 'END { printf "%d%%", 100-$(NF-3) }'
        fi
        ;;
esac
