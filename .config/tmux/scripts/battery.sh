#!/usr/bin/env bash
# Prints a nerdfont battery icon (charging-state-aware) + percentage,
# or nothing if no battery is present.
# Icons:
#   󰂄  charging
#   󰁹  discharging >=80%
#   󰁾  discharging >=40%
#   󰁻  discharging >=20%
#   󰂃  discharging <20%

get_battery() {
    local pct="" status=""
    case "$(uname)" in
        Linux)
            for bat in /sys/class/power_supply/BAT*; do
                if [ -r "$bat/capacity" ]; then
                    pct=$(cat "$bat/capacity")
                    status=$(cat "$bat/status" 2>/dev/null)
                    break
                fi
            done
            if [ -z "$pct" ] && command -v acpi >/dev/null 2>&1; then
                local acpi_out
                acpi_out=$(acpi -b 2>/dev/null | head -1)
                pct=$(echo "$acpi_out" | grep -oP '\d+(?=%)')
                case "$acpi_out" in
                    *Charging*)    status="Charging" ;;
                    *Discharging*) status="Discharging" ;;
                    *Full*)        status="Full" ;;
                esac
            fi
            ;;
        Darwin|*BSD)
            if command -v pmset >/dev/null 2>&1; then
                local pmset_out
                pmset_out=$(pmset -g batt 2>/dev/null)
                pct=$(echo "$pmset_out" | grep -oE '[0-9]+%' | head -1 | tr -d '%')
                case "$pmset_out" in
                    *"AC Power"*) status="Charging" ;;
                    *)            status="Discharging" ;;
                esac
                # pmset reports "charged" or "finishing charge" when full
                if echo "$pmset_out" | grep -qiE 'charged|finishing charge'; then
                    status="Full"
                fi
            fi
            ;;
    esac

    [ -z "$pct" ] && return

    local icon
    if [ "$status" = "Charging" ]; then
        icon="󰂄"
    elif [ "$pct" -ge 80 ]; then
        icon="󰁹"
    elif [ "$pct" -ge 40 ]; then
        icon="󰁾"
    elif [ "$pct" -ge 20 ]; then
        icon="󰁻"
    else
        icon="󰂃"
    fi

    printf '%s %d%%' "$icon" "$pct"
}

get_battery
