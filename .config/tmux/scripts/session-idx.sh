#!/usr/bin/env bash
# Outputs the 1-indexed creation-order position of the named session.
# Used by both status-left sections 2 and 3 (tmux caches by command string).

tmux list-sessions -F "#{session_created} #{session_name}" \
    | sort -n \
    | grep -n " ${1}$" \
    | cut -d: -f1
