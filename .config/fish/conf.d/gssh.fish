set -g __gssh_nu_path ~/.config/fish/nu/gssh.nu

# --- Helper ---

function __gssh_fetch_profile --description "Fetch a gssh profile as Fish variables"
    # Returns: username email key_name ssh_cmd (as separate list elements)
    set -l username $argv[1]
    nu -c "
        use $__gssh_nu_path *
        let p = (fetch-profile '$username')
        let ssh = (make-ssh-cmd \$p.key_name)
        print \$'(\$p.username)\t(\$p.email)\t(\$p.key_name)\t(\$ssh)'
    " | string split \t
end

# --- Thin Nushell passthroughs ---

function gssh-add --description "Register a git SSH profile"
    nu -c "use $__gssh_nu_path *; gssh-add $argv"
end

function gssh-list --description "List registered git SSH profiles"
    nu -c "use $__gssh_nu_path *; gssh-list"
end

function gssh-setup --description "Register an SSH profile and configure git identity"
    nu -c "use $__gssh_nu_path *; gssh-setup $argv"
end

function gssh-unset-global --description "Remove global git SSH identity"
    nu -c "use $__gssh_nu_path *; gssh-unset-global"
end

# --- Fish wrappers (need git completions) ---

function gssh-clone --wraps "git clone" --description "git clone with an SSH profile"
    argparse 'u/username=' -- $argv
    or return 1

    if not set -q _flag_username
        echo "gssh-clone: clone a repo using an SSH profile" >&2
        echo "" >&2
        echo "Usage: gssh-clone -u <username> <repo> [git clone args...]" >&2
        echo "" >&2
        echo "All standard git clone flags are supported." >&2
        echo "Run 'gssh-list' to see available profiles." >&2
        return 1
    end

    set -l p (__gssh_fetch_profile $_flag_username)
    or begin
        echo "Run 'gssh-add' or 'gssh-setup' to register a profile." >&2
        return 1
    end

    command git clone \
        --config "user.name=$p[1]" \
        --config "user.email=$p[2]" \
        --config "core.sshcommand=$p[4]" \
        $argv
end

function gssh-use --description "Configure git identity for the current repo (or globally)"
    argparse 'g/global' -- $argv
    or return 1

    set -l username $argv[1]
    if test -z "$username"
        echo "gssh-use: set git identity from an SSH profile" >&2
        echo "" >&2
        echo "Usage: gssh-use [-g] <username>" >&2
        echo "" >&2
        echo "  -g, --global    Set globally instead of for the current repo" >&2
        echo "" >&2
        echo "Run 'gssh-list' to see available profiles." >&2
        return 1
    end

    set -l p (__gssh_fetch_profile $username)
    or begin
        echo "Run 'gssh-add' or 'gssh-setup' to register a profile." >&2
        return 1
    end

    set -l scope --local
    if set -q _flag_global
        set scope --global
    end

    git config $scope user.name $p[1]
    git config $scope user.email $p[2]
    git config $scope core.sshcommand "$p[4]"
    echo "Configured git ($scope) for $p[1] <$p[2]>"
end
