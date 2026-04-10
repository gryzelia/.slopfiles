set -g fish_cursor_insert line
set -g fish_cursor_default block
set -g fish_cursor_replace_one underscore
set -g fish_cursor_replace underscore
set -g fish_cursor_external line
set -g fish_cursor_visual line

set -g fish_key_bindings fish_hybrid_key_bindings
bind -M insert ctrl-c __fish_cancel_commandline

# Ctrl+hjkl to navigate the completion pager (falls back to default behavior outside pager)
bind -M insert \ch 'if commandline -P; commandline -f backward-char; else; commandline -f backward-delete-char; end'
bind -M insert \ck 'if commandline -P; up-or-search; else; commandline -f kill-line; end'
bind -M insert \cl 'if commandline -P; commandline -f forward-char; else; commandline -f clear-screen; end'

# Pager down-or-search hook for Ctrl+j — called from starship's enter binding
function __pager_down_or_search
    if commandline -P
        down-or-search
        return 0
    end
    return 1
end

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
