set -g fish_cursor_insert line
set -g fish_cursor_default block
set -g fish_cursor_replace_one underscore
set -g fish_cursor_replace underscore
set -g fish_cursor_external line
set -g fish_cursor_visual line

set -g fish_key_bindings fish_hybrid_key_bindings
bind -M insert ctrl-c __fish_cancel_commandline

# Override fish_title to set tmux pane title (works over SSH too)
# $argv[1] contains the full commandline when a command is running
function fish_title
    if set -q argv[1]
        echo $USER@(hostname -s):$PWD $argv[1]
    else
        set -l cmd (status current-command)
        test "$cmd" = fish; and set cmd
        echo $USER@(hostname -s):$PWD $cmd
    end
end
