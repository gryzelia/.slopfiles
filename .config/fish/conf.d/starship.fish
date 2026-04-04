# Official starship init (pipestatus, keymap, transient prompt, session key, etc.)
starship init fish | source

# Generate no-timeout config from the original (for full async git render)
set -g __starship_notimeout_config (mktemp /tmp/starship_notimeout_XXXXXX)
begin
    echo 'command_timeout = 600000'
    set -l cfg (set -q STARSHIP_CONFIG; and echo $STARSHIP_CONFIG; or echo "$HOME/.config/starship.toml")
    sed '/^command_timeout/d' "$cfg"
end > $__starship_notimeout_config

# Portable setsid — puts background jobs in a separate process group
# so Ctrl+C (SIGINT) doesn't kill them
if command -q setsid
    set -g __starship_setsid setsid
else
    set -g __starship_setsid perl -e 'use POSIX; POSIX::setsid(); exec @ARGV' --
end

# Clean up tmpfiles on exit
function __starship_cleanup --on-event fish_exit
    rm -f $__starship_notimeout_config $__starship_fast_tmpfile $__starship_full_tmpfile 2>/dev/null
end

# Async git rendering — overrides fish_prompt from the official init
# Line 1: starship (cached, with incremental async git updates)
# Line 2: fish vim mode indicator (instant)

# Mark when a real command was executed (for status capture)
function __starship_async_preexec --on-event fish_preexec
    set -g __starship_new_command 1
end

# Enter key hook — distinguishes Enter from widget repaints (ctrl+r, ctrl+t)
function __starship_mark_enter
    set -g __starship_enter_pressed 1
    commandline -f execute
end

# SIGUSR1 from async jobs — mark as repaint so we don't re-render
function __starship_async_handler --on-signal SIGUSR1
    set -g __starship_is_repaint 1
    commandline -f repaint
end

function fish_prompt
    # Capture status, keymap, duration, jobs
    set -g __starship_saved_pipestatus "$pipestatus"
    set -g __starship_saved_status $status
    set -g __starship_saved_duration "$CMD_DURATION$cmd_duration"
    __starship_set_job_count
    set -g __starship_saved_jobs $STARSHIP_JOBS
    switch "$fish_key_bindings"
        case fish_hybrid_key_bindings fish_vi_key_bindings fish_helix_key_bindings
            set STARSHIP_KEYMAP "$fish_bind_mode"
        case '*'
            set STARSHIP_KEYMAP insert
    end

    # One-time: hook Enter to distinguish from widget repaints (ctrl+r, ctrl+t)
    # Done here (not conf.d top-level) because fish initializes key bindings after conf.d
    if not set -q __starship_bindings_ready
        set -g __starship_bindings_ready 1
        switch "$fish_key_bindings"
            case fish_hybrid_key_bindings fish_vi_key_bindings fish_helix_key_bindings
                for mode in insert default visual replace replace_one
                    bind -M $mode \r __starship_mark_enter 2>/dev/null
                    bind -M $mode \n __starship_mark_enter 2>/dev/null
                end
            case '*'
                bind \r __starship_mark_enter 2>/dev/null
                bind \n __starship_mark_enter 2>/dev/null
        end
    end

    # Mark that a new command was run (triggers fresh render)
    if set -q __starship_new_command
        set -e __starship_new_command
        set -g __starship_new_cmd_render 1
    end

    # Export status for custom modules
    set -gx STARSHIP_LAST_STATUS $__starship_saved_status
    set -gx STARSHIP_LAST_PIPESTATUS "$__starship_saved_pipestatus"

    # Build shared starship args
    set -l starship_args \
        "--terminal-width=$COLUMNS" \
        "--status=$__starship_saved_status" \
        "--pipestatus=$__starship_saved_pipestatus" \
        "--keymap=$STARSHIP_KEYMAP" \
        "--cmd-duration=$__starship_saved_duration" \
        "--jobs=$__starship_saved_jobs"

    # Transient prompt support (from official init)
    if contains -- --final-rendering $argv; or test "$TRANSIENT" = "1"
        if test "$TRANSIENT" = "1"
            set -g TRANSIENT 0
            printf \e\[0J
        end
        if type -q starship_transient_prompt_func
            starship_transient_prompt_func $starship_args
        else
            printf "\e[1;32m❯\e[0m "
        end
        return
    end

    # Consume flags early so they don't leak across branches
    set -l is_repaint 0
    if set -q __starship_is_repaint
        set -e __starship_is_repaint
        set is_repaint 1
    end
    set -l is_enter 0
    if set -q __starship_enter_pressed
        set -e __starship_enter_pressed
        set is_enter 1
    end

    if test $is_repaint = 1; and not set -q __starship_new_cmd_render
        # SIGUSR1 repaint (no new command) — check for async results, update cache
        if set -q __starship_full_tmpfile; and test -s "$__starship_full_tmpfile"
            set -g __starship_prompt_cache (string collect < "$__starship_full_tmpfile")
            rm -f "$__starship_full_tmpfile"
            set -e __starship_full_tmpfile
            if set -q __starship_fast_tmpfile
                rm -f "$__starship_fast_tmpfile"
                set -e __starship_fast_tmpfile
            end
        else if set -q __starship_fast_tmpfile; and test -s "$__starship_fast_tmpfile"
            set -g __starship_prompt_cache (string collect < "$__starship_fast_tmpfile")
            rm -f "$__starship_fast_tmpfile"
            set -e __starship_fast_tmpfile
        end
    else if not set -q __starship_new_cmd_render; and test $is_enter = 0; and set -q __starship_last_bind_mode; and test "$fish_bind_mode" != "$__starship_last_bind_mode"
        # Mode change (no new command, no Enter) — use cache as-is, only line 2 updates
    else if not set -q __starship_new_cmd_render; and test $is_enter = 0; and set -q __starship_prompt_cache
        # Widget repaint (ctrl+r, ctrl+t, resize, etc.) — use cache
    else
        # New command, Enter, or first prompt — sync render + async jobs
        set -e __starship_new_cmd_render
        # Clean up previous async jobs (processes are self-terminating via setsid,
        # so we only need to remove their tmpfiles)
        rm -f $__starship_fast_tmpfile $__starship_full_tmpfile 2>/dev/null
        set -e __starship_fast_tmpfile
        set -e __starship_full_tmpfile

        # Sync render without git (single process in command substitution — no pipeline
        # to break on SIGUSR1, unlike the old starship | string collect approach)
        set -g __starship_prompt_cache (env GIT_DIR=/dev/null starship prompt $starship_args 2>/dev/null)

        # Shared args string for async fish -c subshells
        set -l args_str (string join -- ' ' $starship_args)
        set -l ppid $fish_pid

        # Async job 1: fast git (default timeout ~500ms)
        set -g __starship_fast_tmpfile (mktemp /tmp/starship_fast.XXXXXX)
        $__starship_setsid fish -c "
            starship prompt $args_str > '$__starship_fast_tmpfile' 2>/dev/null
            kill -SIGUSR1 $ppid 2>/dev/null
        " &
        disown $last_pid 2>/dev/null

        # Async job 2: full git (no timeout)
        set -g __starship_full_tmpfile (mktemp /tmp/starship_full.XXXXXX)
        $__starship_setsid fish -c "
            STARSHIP_CONFIG='$__starship_notimeout_config' starship prompt $args_str > '$__starship_full_tmpfile' 2>/dev/null
            kill -SIGUSR1 $ppid 2>/dev/null
        " &
        disown $last_pid 2>/dev/null
    end
    set -g __starship_last_bind_mode $fish_bind_mode

    # Line 1: cached starship output
    printf '%s' "$__starship_prompt_cache"

    # Line 2: vim mode indicator (fish-native, instant)
    echo
    printf '%s' (fish_default_mode_prompt | string trim -r)
    printf '❯ '
end
