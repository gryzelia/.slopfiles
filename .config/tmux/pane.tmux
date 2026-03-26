# Other color candidates:
# #0a7f44
# #16B364
# #3CA564
# #11944A
# #139F4F
ACTIVE_BORDER_COLOR="#0E8843"
INACTIVE_BORDER_COLOR="#C0C0C0"
PANE_LABEL_FG_COLOR="#fcf75e"

set -g pane-border-lines heavy
set -g pane-active-border-style "fg=${ACTIVE_BORDER_COLOR}"
set -g pane-border-style "fg=${INACTIVE_BORDER_COLOR}"
set -g pane-border-status bottom
set -g pane-border-indicators off
# Pane border format components:
#   #P                       - pane index
#   #{pane_current_command}   - foreground command (e.g. vim, zsh)
#   #{pane_title}             - user@hostname:dir, set by shell via escape sequence
#                               fish: see config.fish (fish_title)
#                               bash: PROMPT_COMMAND='printf "\033]2;%s@%s:%s\007" "$USER" "${HOSTNAME%%.*}" "$PWD"'
#                               zsh:  precmd() { printf '\033]2;%s@%s:%s\007' "$USER" "${HOST%%.*}" "$PWD" }
#   scripts/pane-jobs.sh      - count child processes (approximates background jobs)
#   scripts/pane-elapsed.sh   - elapsed time of foreground child process
# Active pane: colored text; inactive pane: dim default

set -g pane-border-format '\
 #{?pane_active,#[fg=#{PANE_LABEL_FG_COLOR}],#[fg=#{INACTIVE_BORDER_COLOR}]} #P: #{pane_current_command}\
 #{?pane_active,#[fg=#{ACTIVE_BORDER_COLOR}],#[fg=#{INACTIVE_BORDER_COLOR}]}|#{?pane_active,#[fg=#{PANE_LABEL_FG_COLOR}],#[fg=#{INACTIVE_BORDER_COLOR}]} ps:#($HOME/.config/tmux/scripts/pane-jobs.sh #{pane_pid})\
 #{?pane_active,#[fg=#{ACTIVE_BORDER_COLOR}],#[fg=#{INACTIVE_BORDER_COLOR}]}|#{?pane_active,#[fg=#{PANE_LABEL_FG_COLOR}],#[fg=#{INACTIVE_BORDER_COLOR}]} #($HOME/.config/tmux/scripts/pane-elapsed.sh #{pane_pid})\
 #{?pane_active,#[fg=#{ACTIVE_BORDER_COLOR}],#[fg=#{INACTIVE_BORDER_COLOR}]}|#{?pane_active,#[fg=#{PANE_LABEL_FG_COLOR}],#[fg=#{INACTIVE_BORDER_COLOR}]} #{pane_title} '
WINDOW_INACTIVE_BG_COLOR="colour233"
WINDOW_ACTIVE_BG_COLOR="black"
set -g window-style "bg=${WINDOW_INACTIVE_BG_COLOR}"
set -g window-active-style "bg=${WINDOW_ACTIVE_BG_COLOR}"
