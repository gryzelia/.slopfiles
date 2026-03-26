#!/usr/bin/env bash
# Prints disk usage for all real filesystems with abbreviated mount points.
# df is POSIX and works on both Linux and macOS/BSD.

# Abbreviate by taking first char of each path component:
#   /            -> /
#   /home        -> /h
#   /mnt/data    -> /m/d
#   /Volumes/USB -> /V/U
abbreviate() {
    if [ "$1" = "/" ]; then
        echo "/"
        return
    fi
    # Match each /component: capture first char after /, consume rest up to next /
    # Replace with just /firstchar. The g flag repeats for all components.
    # e.g. /mnt/local/hdd -> /m/l/h
    echo "$1" | sed 's|/\(.\)[^/]*|/\1|g'
}

case "$(uname)" in
    Linux)
        # df -h: human-readable sizes
        # -x: exclude pseudo-filesystems (tmpfs, devtmpfs, squashfs, overlay)
        # awk: skip header (NR>1), exclude /boot mounts,
        #      strip % from $5 (Use%), print mount ($6) and usage
        raw=$(df -h -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs 2>/dev/null \
            | awk 'NR>1 && $6 !~ /^\/(boot|efi)/ { gsub(/%/,"",$5); print $6, $5 }')
        ;;
    Darwin)
        # APFS volumes share a container, so individual "Used" values are
        # misleading. /System/Volumes/Data's Capacity% reflects the whole
        # container's usage. Show that for internal storage, plus any
        # external drives under /Volumes/.
        raw=$(df -h 2>/dev/null \
            | awk 'NR>1 && ($NF == "/System/Volumes/Data" || $NF ~ /^\/Volumes\//) { gsub(/%/,"",$5); print $NF, $5 }')
        ;;
    *BSD)
        # df -h: human-readable sizes
        # awk: skip header, only include real devices (/dev/...),
        #      exclude /boot, strip % from $5 (Capacity), print mount ($NF) and usage
        raw=$(df -h 2>/dev/null \
            | awk 'NR>1 && $1 ~ /^\/dev/ && $NF !~ /^\/boot/ { gsub(/%/,"",$5); print $NF, $5 }')
        ;;
esac

output=""
while read -r mount pct; do
    [ -z "$mount" ] && continue
    label=$(abbreviate "$mount")
    [ -n "$output" ] && output="$output "
    output="$output$label:$pct%"
done <<< "$raw"

echo "$output"
