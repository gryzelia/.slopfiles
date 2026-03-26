zoxide init fish | source
direnv hook fish | source

set -gx FZF_DEFAULT_OPTS "--bind ctrl-u:preview-half-page-up,ctrl-d:preview-half-page-down,ctrl-b:preview-page-up,ctrl-f:preview-page-down,ctrl-q:half-page-up,ctrl-w:half-page-down,shift-up:preview-top,shift-down:preview-bottom"
fzf --fish | source

set -gx EDITOR nvim

set -q GHCUP_INSTALL_BASE_PREFIX[1]; or set GHCUP_INSTALL_BASE_PREFIX $HOME ; set -gx PATH $HOME/.cabal/bin $PATH $HOME/.ghcup/bin # ghcup-env

if test -d /home/linuxbrew
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
end
