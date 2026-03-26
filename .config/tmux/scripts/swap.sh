#!/usr/bin/env bash
# Prints swap used as an absolute size (e.g. 1.2G), or nothing if no swap or 0 used.

case "$(uname)" in
    Linux)
        # /proc/meminfo: SwapTotal and SwapFree in KiB
        awk '
            /SwapTotal:/ { total=$2 }
            /SwapFree:/  { free=$2 }
            END {
                used = total - free
                if (total > 0 && used > 0) {
                    if (used >= 1048576) printf "%.1fG", used / 1048576
                    else if (used >= 1024) printf "%.0fM", used / 1024
                    else printf "%dK", used
                }
            }
        ' /proc/meminfo
        ;;
    Darwin|*BSD)
        # sysctl vm.swapusage: "total = 9216.00M  used = 8669.12M  free = 546.88M"
        sysctl -nq vm.swapusage 2>/dev/null \
            | awk '{ gsub(/M/,""); if ($3+0 > 0 && $6+0 > 0) {
                used = $6
                if (used >= 1024) printf "%.1fG", used / 1024
                else printf "%.0fM", used
            }}'
        ;;
esac
