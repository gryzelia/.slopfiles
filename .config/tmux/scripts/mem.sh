#!/usr/bin/env bash
# Prints memory usage percentage.
# References:
#   https://github.com/samoshkin/tmux-plugin-sysstat/blob/master/scripts/mem.sh

case "$(uname)" in
    Linux)
        # /proc/meminfo: prefer MemAvailable (modern kernels), else sum free+buffers+cached
        awk '
            /MemTotal:/     { total=$2 }
            /MemAvailable:/ { avail=$2 }
            END {
                if (avail && total) printf "%d%%", ((total - avail) / total) * 100
            }
        ' /proc/meminfo
        ;;
    Darwin|*BSD)
        # vm_stat reports in pages; multiply by page size
        # Used = active + wired; Available = free + inactive + speculative + compressor
        page_size=$(sysctl -nq vm.pagesize 2>/dev/null || echo 4096)
        vm_stat 2>/dev/null | awk -v ps="$page_size" -F ':' '
            BEGIN { used=0; free=0 }
            /Pages active/      { gsub(/[^0-9]/, "", $2); used+=$2 }
            /Pages wired/       { gsub(/[^0-9]/, "", $2); used+=$2 }
            /Pages free/        { gsub(/[^0-9]/, "", $2); free+=$2 }
            /Pages inactive/    { gsub(/[^0-9]/, "", $2); free+=$2 }
            /Pages speculative/ { gsub(/[^0-9]/, "", $2); free+=$2 }
            /Pages occupied by compressor/ { gsub(/[^0-9]/, "", $2); free+=$2 }
            END {
                total = used + free
                if (total > 0) printf "%d%%", (used / total) * 100
            }
        '
        ;;
esac
