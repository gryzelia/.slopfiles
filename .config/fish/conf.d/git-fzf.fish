function git-diff-fzf --description 'Browse git diff files with fzf'
    set -l git_root (git rev-parse --show-toplevel 2>/dev/null)
    or return 1

    set -l args $argv
    # Detect single commit (e.g. "abc123^!") vs range/working tree diff
    set -l single_commit (string match -r '^([a-f0-9]+)\^!\$' "$args")[2]

    set -l expect_keys ctrl-a
    if test -n "$single_commit"
        set expect_keys ctrl-a,ctrl-o
    end

    set -l fzf_args --ansi --multi --prompt "Git Diff($args)> " \
        --preview "git -C $git_root diff --color $args -- {1}" \
        --bind "ctrl-h:preview-half-page-up,ctrl-l:preview-half-page-down" \
        --expect $expect_keys

    set -l result (git -C $git_root diff --name-only $args | fzf $fzf_args)
    or return

    set -l key $result[1]
    set -l files $result[2..]

    if test "$key" = ctrl-a
        for file in $files
            git -C $git_root diff $args -- $file | git -C $git_root apply
        end
        git-diff-fzf $args
    else if test "$key" = ctrl-o; and test -n "$single_commit"
        for file in $files
            git -C $git_root checkout $single_commit -- $file
        end
        git-diff-fzf $args
    else
        test -n "$files[1]"; and $EDITOR "$git_root/$files[1]"
    end
end

complete -c git-diff-fzf --no-files --wraps 'git diff'

function __git_log_fzf_impl --description 'Browse git log with fzf (internal)'
    set -l warning $argv[1]
    set -e argv[1]
    set -l args $argv
    set -l prompt 'Git Log> '
    if test -n "$warning"
        set prompt (printf '\e[31m%s\e[0m > ' "$warning")
    end
    set -l fzf_args --ansi --multi --prompt $prompt \
        --preview 'git show --color {1}' \
        --bind "ctrl-h:preview-half-page-up,ctrl-l:preview-half-page-down" \
        --expect ctrl-o

    set -l result (git log --oneline --color --decorate $args | fzf $fzf_args)
    or return

    set -l key $result[1]
    set -l count (math (count $result) - 1)

    if test "$key" = ctrl-o
        set -l a (string match -r '[a-f0-9]+' $result[2])[1]
        if test $count -eq 1
            git-diff-fzf "$a^!"
        else
            set -l b (string match -r '[a-f0-9]+' $result[-1])[1]
            # Determine which is the ancestor
            set -l oldest
            set -l newest
            if git merge-base --is-ancestor $a $b 2>/dev/null
                set oldest $a
                set newest $b
            else if git merge-base --is-ancestor $b $a 2>/dev/null
                set oldest $b
                set newest $a
            else
                __git_log_fzf_impl 'Selection is not a continuous range' $args
                return
            end
            set -l expected (git rev-list --count "$oldest~1..$newest")
            if test "$expected" != "$count"
                __git_log_fzf_impl 'Selection is not a continuous range' $args
                return
            end
            git-diff-fzf "$oldest~1..$newest"
        end
    else
        set -l commit (string match -r '[a-f0-9]+' $result[2])[1]
        test -n "$commit"; and git show $commit
    end
end

function git-log-fzf --description 'Browse git log with fzf'
    __git_log_fzf_impl '' $argv
end

complete -c git-log-fzf --no-files --wraps 'git log'

function git-reflog-fzf --description 'Browse git reflog with fzf'
    set -l args $argv
    set -l fzf_args --ansi --prompt 'Git Reflog> ' \
        --preview 'git show --color {1}' \
        --bind "ctrl-h:preview-half-page-up,ctrl-l:preview-half-page-down" \
        --expect ctrl-o

    set -l result (git reflog --color --decorate $args | fzf $fzf_args)
    or return

    set -l key $result[1]
    set -l line $result[2]
    set -l commit (string match -r '[a-f0-9]+' $line)[1]
    test -n "$commit"; or return

    if test "$key" = ctrl-o
        git-diff-fzf "$commit^!"
    else
        git show $commit
    end
end

complete -c git-reflog-fzf --no-files --wraps 'git reflog'
