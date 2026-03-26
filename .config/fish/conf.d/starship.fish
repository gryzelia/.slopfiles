# Official starship init (pipestatus, keymap, transient prompt, session key, etc.)
starship init fish | source

# Generate no-timeout config from the original (for full async git render)
set -g __starship_notimeout_config (mktemp /tmp/starship_notimeout_XXXXXX)
begin
    echo 'command_timeout = 600000'
    sed '/^command_timeout/d' ~/.config/starship.toml
end > $__starship_notimeout_config

# Portable setsid — puts background jobs in a separate process group
# so Ctrl+C (SIGINT) doesn't kill them
if command -q setsid
    set -g __starship_setsid setsid
else
    set -g __starship_setsid perl -e 'use POSIX; POSIX::setsid(); exec @ARGV' --
end

# Async git rendering — overrides fish_prompt from the official init
# Line 1: starship (cached, with incremental async git updates)
# Line 2: fish vim mode indicator (instant)

# Mark when a real command was executed (for status capture)
function __starship_async_preexec --on-event fish_preexec
    set -g __starship_new_command 1
end

# SIGUSR1 from async jobs — mark as repaint so we don't re-render
function __starship_async_handler --on-signal SIGUSR1
    set -g __starship_is_repaint 1
    commandline -f repaint
end

function fish_prompt
    # Keymap — always update (for mode changes)
    switch "$fish_key_bindings"
        case fish_hybrid_key_bindings fish_vi_key_bindings fish_helix_key_bindings
            set STARSHIP_KEYMAP "$fish_bind_mode"
        case '*'
            set STARSHIP_KEYMAP insert
    end

    # Capture status only after a real command (not on mode change/repaint)
    if set -q __starship_new_command
        set -e __starship_new_command
        set STARSHIP_CMD_PIPESTATUS $pipestatus
        set STARSHIP_CMD_STATUS $status
        set STARSHIP_DURATION "$CMD_DURATION$cmd_duration"
        __starship_set_job_count
        # Save for repaints and async jobs
        set -g __starship_saved_pipestatus "$STARSHIP_CMD_PIPESTATUS"
        set -g __starship_saved_status $STARSHIP_CMD_STATUS
        set -g __starship_saved_duration $STARSHIP_DURATION
        set -g __starship_saved_jobs $STARSHIP_JOBS
        set -g __starship_new_cmd_render 1
    end

    # Export status for custom modules
    set -gx STARSHIP_LAST_STATUS $__starship_saved_status
    set -gx STARSHIP_LAST_PIPESTATUS "$__starship_saved_pipestatus"

    # Transient prompt support (from official init)
    if contains -- --final-rendering $argv; or test "$TRANSIENT" = "1"
        if test "$TRANSIENT" = "1"
            set -g TRANSIENT 0
            printf \e\[0J
        end
        if type -q starship_transient_prompt_func
            starship_transient_prompt_func --terminal-width="$COLUMNS" --status=$__starship_saved_status --pipestatus="$__starship_saved_pipestatus" --keymap=$STARSHIP_KEYMAP --cmd-duration=$__starship_saved_duration --jobs=$__starship_saved_jobs
        else
            printf "\e[1;32m❯\e[0m "
        end
        return
    end

    if set -q __starship_is_repaint; and not set -q __starship_new_cmd_render
        # SIGUSR1 repaint (no new command) — check for async results, update cache
        set -e __starship_is_repaint
        if set -q __starship_full_tmpfile; and test -s "$__starship_full_tmpfile"
            set -g __starship_prompt_cache (cat "$__starship_full_tmpfile" | string collect)
            rm -f "$__starship_full_tmpfile"
            set -e __starship_full_tmpfile
            set -e __starship_full_pid
            if set -q __starship_fast_tmpfile
                kill "$__starship_fast_pid" 2>/dev/null
                rm -f "$__starship_fast_tmpfile"
                set -e __starship_fast_tmpfile
                set -e __starship_fast_pid
            end
        else if set -q __starship_fast_tmpfile; and test -s "$__starship_fast_tmpfile"
            set -g __starship_prompt_cache (cat "$__starship_fast_tmpfile" | string collect)
            rm -f "$__starship_fast_tmpfile"
            set -e __starship_fast_tmpfile
            set -e __starship_fast_pid
        end
    else if not set -q __starship_new_cmd_render; and set -q __starship_last_bind_mode; and test "$fish_bind_mode" != "$__starship_last_bind_mode"
        # Mode change (no new command) — use cache as-is, only line 2 updates
    else
        # After command, empty Enter, Ctrl+C, or first prompt — sync render + async jobs
        set -e __starship_new_cmd_render
        # Kill previous async jobs
        for pid in $__starship_fast_pid $__starship_full_pid
            kill "$pid" 2>/dev/null
        end
        for f in $__starship_fast_tmpfile $__starship_full_tmpfile
            rm -f "$f" 2>/dev/null
        end
        set -e __starship_fast_pid
        set -e __starship_full_pid
        set -e __starship_fast_tmpfile
        set -e __starship_full_tmpfile

        # Sync render without git (~10ms, foreground)
        set -g __starship_prompt_cache (env GIT_DIR=/dev/null starship prompt \
            --terminal-width="$COLUMNS" \
            --status=$__starship_saved_status \
            --pipestatus="$__starship_saved_pipestatus" \
            --keymap=$STARSHIP_KEYMAP \
            --cmd-duration=$__starship_saved_duration \
            --jobs=$__starship_saved_jobs 2>/dev/null | string collect)

        set -l ppid $fish_pid

        # Async job 1: fast git (default timeout ~500ms)
        set -g __starship_fast_tmpfile (mktemp /tmp/starship_fast.XXXXXX)
        $__starship_setsid fish -c "
            starship prompt \
                --terminal-width=$COLUMNS \
                --status=$__starship_saved_status \
                --pipestatus='$__starship_saved_pipestatus' \
                --keymap=$STARSHIP_KEYMAP \
                --cmd-duration=$__starship_saved_duration \
                --jobs=$__starship_saved_jobs \
                > '$__starship_fast_tmpfile' 2>/dev/null
            kill -SIGUSR1 $ppid 2>/dev/null
        " &
        set -g __starship_fast_pid $last_pid
        disown $__starship_fast_pid 2>/dev/null

        # Async job 2: full git (no timeout)
        set -g __starship_full_tmpfile (mktemp /tmp/starship_full.XXXXXX)
        $__starship_setsid fish -c "
            STARSHIP_CONFIG='$__starship_notimeout_config' starship prompt \
                --terminal-width=$COLUMNS \
                --status=$__starship_saved_status \
                --pipestatus='$__starship_saved_pipestatus' \
                --keymap=$STARSHIP_KEYMAP \
                --cmd-duration=$__starship_saved_duration \
                --jobs=$__starship_saved_jobs \
                > '$__starship_full_tmpfile' 2>/dev/null
            kill -SIGUSR1 $ppid 2>/dev/null
        " &
        set -g __starship_full_pid $last_pid
        disown $__starship_full_pid 2>/dev/null
    end
    set -g __starship_last_bind_mode $fish_bind_mode

    # Line 1: cached starship output
    printf '%s' "$__starship_prompt_cache"

    # Line 2: vim mode indicator (fish-native, instant)
    echo
    printf '%s' (fish_default_mode_prompt | string trim -r)
    printf '❯ '
end
