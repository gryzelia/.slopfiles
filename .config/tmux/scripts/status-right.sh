#!/usr/bin/env bash
# Outputs the formatted status-right string via a cache file.
#
# The #() returns instantly by reading the cached output. The actual metric
# computation runs in the background and updates the cache for next time.
# Since the #() output matches what tmux already rendered, tmux's grid_compare
# sees no change and skips the redraw. On the next status-interval tick, the
# new cached values appear — giving exactly 1 redraw per interval.
#
# This is needed because cpu.sh takes ~1s (top -bn2 -d1). Without the cache,
# the delayed #() completion triggers a staggered redraw that causes cursor
# flickering over SSH.
#
# Colors and icons are duplicated here from status.conf to avoid the
# overhead of reading tmux options. Keep them in sync if changed.

SCRIPTS_DIR="$HOME/.config/tmux/scripts"
CACHE="/tmp/tmux-status-right.cache"
PIDFILE="/tmp/tmux-status-right.pid"

# --- Return cached output immediately ---
cat "$CACHE" 2>/dev/null

# --- Skip if a background update is already running ---
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    exit 0
fi

# --- Background: compute new values and update cache ---
# Redirect stdout/stderr to /dev/null so the subshell doesn't block
# on tmux's #() pipe after the foreground cat has finished.
(
    echo $BASHPID > "$PIDFILE"

    # --- Colors (from status.conf, Kanagawa Wave - bright) ---
    SBG="#1A0061"     # status bar bg
    DFG="#1F1F28"     # dark fg
    LFG="#DCD7BA"     # light fg
    BAT_BG="#e82424"  # battery - bright red
    CPU_BG="#e6c384"  # cpu - bright yellow
    MEM_BG="#98bb6c"  # mem - bright green
    DSK_BG="#7fb4ca"  # disk - bright blue
    NET_BG="#938aa9"  # net - bright magenta
    TIM_BG="#727169"  # time - bright black

    # --- Icons (Unicode) ---
    SEP=$'\ue0b8'         # powerline separator
    ICON_CPU=$'\U000f035b' # 󰍛
    ICON_MEM=$'\uefc5'
    ICON_DSK=$'\U000f02ca' # 󰋊
    ICON_SWP=$'\U000f0fb5' # 󰾵
    ICON_PNG=$'\uebcb'
    ICON_LOS=$'\U000f015b' # 󰅛

    # --- Collect metrics ---
    bat=$("$SCRIPTS_DIR/battery.sh")
    cpu=$("$SCRIPTS_DIR/cpu.sh")
    mem=$("$SCRIPTS_DIR/mem.sh")
    swap=$("$SCRIPTS_DIR/swap.sh")
    disk=$("$SCRIPTS_DIR/disk.sh")
    net=$("$SCRIPTS_DIR/net-speed.sh")
    ping=$("$SCRIPTS_DIR/ping.sh")
    loss=$("$SCRIPTS_DIR/packet-loss.sh")
    time_str=$(date +'%Y-%m-%d %H:%M %Z')

    # --- Build output ---
    out=""

    # Battery (conditional)
    if [ -n "$bat" ]; then
        out+="#[fg=${SBG},bg=${BAT_BG}]${SEP}#[fg=${LFG},bg=${BAT_BG}] ${bat} "
        out+="#[fg=${BAT_BG},bg=${CPU_BG}]${SEP}"
    else
        out+="#[fg=${SBG},bg=${CPU_BG}]${SEP}"
    fi

    # CPU
    out+="#[fg=${DFG},bg=${CPU_BG}] ${ICON_CPU} ${cpu} "

    # Memory + conditional swap
    out+="#[fg=${CPU_BG},bg=${MEM_BG}]${SEP}#[fg=${DFG},bg=${MEM_BG}] ${ICON_MEM} ${mem}"
    [ -n "$swap" ] && out+=" ${ICON_SWP} ${swap}"
    out+=" "

    # Disk
    out+="#[fg=${MEM_BG},bg=${DSK_BG}]${SEP}#[fg=${DFG},bg=${DSK_BG}] ${ICON_DSK} ${disk} "

    # Network + ping + conditional loss
    out+="#[fg=${DSK_BG},bg=${NET_BG}]${SEP}#[fg=${DFG},bg=${NET_BG}] ${net} ${ICON_PNG} ${ping}"
    [ -n "$loss" ] && out+=" ${ICON_LOS} ${loss}"
    out+=" "

    # Time
    out+="#[fg=${NET_BG},bg=${TIM_BG}]${SEP}#[fg=${LFG},bg=${TIM_BG}] ${time_str} "

    printf '%s' "$out" > "$CACHE"

    rm -f "$PIDFILE"
) >/dev/null 2>&1 &

exit 0
