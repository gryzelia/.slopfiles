# gssh — Multi-profile SSH key management for git
#
# Manages SSH keys and git identity profiles for use across
# any git forge (GitHub, GitLab, Codeberg, etc.).
#
# Profiles are stored in ~/.config/gssh/profiles as CSV:
#   username,email,key_name
#
# Used as a module by Fish wrappers:
#   nu -c "use ~/.config/fish/nu/gssh.nu *; fetch-profile 'user' | to json -r"

const PROFILES_DIR = ("~/.config/gssh" | path expand)
const PROFILES_PATH = ("~/.config/gssh/profiles" | path expand)
const SSH_KEYS_PATH = ("~/.ssh" | path expand)

def get-key-paths [key_name: string] {
    {
        ssh_key_path: ($SSH_KEYS_PATH | path join $key_name)
        ssh_pub_key_path: ($SSH_KEYS_PATH | path join $"($key_name).pub")
    }
}

# Build an SSH command string that uses a specific key.
export def make-ssh-cmd [key_name: string] {
    # Forward slashes for cross-platform compat (Windows SSH)
    let key_path = ($SSH_KEYS_PATH | str replace --all '\' '/' | path join $key_name)
    $"ssh -i ($key_path) -o IdentitiesOnly=yes"
}

# Register a git SSH profile and generate a key if needed.
#
# Creates an ed25519 SSH key (if one doesn't exist) and stores the
# profile in ~/.config/gssh/profiles. Does not modify any git config —
# use gssh-use or gssh-setup for that.
export def gssh-add [
    --email (-e): string      # Email for the SSH key and git commits
    --username (-u): string   # Git username for commits
    --key_name (-k): string   # SSH key filename (default: <username>-key)
] {
    if ($email | default "" | is-empty) or ($username | default "" | is-empty) {
        print "Usage: gssh-add -e <email> -u <username> [-k <key_name>]"
        print ""
        print "Register a git SSH profile and generate an SSH key if needed."
        print "Profiles are stored in ~/.config/gssh/profiles."
        print ""
        print "Options:"
        print "  -e, --email       Email for the SSH key and git commits"
        print "  -u, --username    Git username for commits"
        print "  -k, --key_name    SSH key filename (default: <username>-key)"
        error make {msg: "Missing required flags: --email and --username"}
    }

    let key_name = if ($key_name | default "" | is-empty) {
        $"($username)-key"
    } else {
        $key_name
    }

    let key_paths = get-key-paths $key_name

    if not ($key_paths.ssh_key_path | path exists) and not ($key_paths.ssh_pub_key_path | path exists) {
        print $"No existing key '($key_name)' found. Generating new ed25519 key..."
        ssh-keygen-at-path $email $key_paths.ssh_key_path $key_paths.ssh_pub_key_path
    } else {
        print $"Using existing key: ($key_paths.ssh_key_path)"
    }

    check-add-profile $username $email $key_name
}

# List all registered profiles.
export def gssh-list [] {
    if not ($PROFILES_PATH | path exists) {
        print "No profiles found."
        return
    }
    let raw = (open --raw $PROFILES_PATH | str trim)
    if ($raw | is-empty) {
        print "No profiles found."
        return
    }
    $raw | profiles-from-csv
}

# Look up a profile by username.
export def fetch-profile [username: string] {
    if not ($PROFILES_PATH | path exists) {
        error make {msg: "No profiles found."}
    }
    let raw = (open --raw $PROFILES_PATH | str trim)
    if ($raw | is-empty) {
        error make {msg: "No profiles found."}
    }
    let profiles = ($raw | profiles-from-csv)
    let matched = $profiles | where username == $username
    if ($matched | is-empty) {
        let available = ($profiles | get username | str join ", ")
        error make {msg: $"Profile '($username)' not found. Available: ($available)"}
    } else if ($matched | length) > 1 {
        error make {msg: $"Multiple profiles for '($username)'. Manually fix ($PROFILES_PATH)"}
    }
    $matched | first
}

# Register a profile and configure the current repo's git identity.
# Equivalent to gssh-add followed by gssh-use.
export def gssh-setup [
    --email (-e): string      # Email for the SSH key and git commits
    --username (-u): string   # Git username for commits
    --key_name (-k): string   # SSH key filename (default: <username>-key)
] {
    gssh-add -e $email -u $username -k $key_name
    let p = fetch-profile $username
    let ssh_cmd = make-ssh-cmd $p.key_name
    ^git config --local user.name $p.username
    ^git config --local user.email $p.email
    ^git config --local core.sshcommand $ssh_cmd
    print $"Configured git \(--local\) for ($p.username) <($p.email)>"
}

# Remove global git SSH identity.
export def gssh-unset-global [] {
    ^git config --global --unset-all user.name
    ^git config --global --unset-all user.email
    ^git config --global --unset-all core.sshcommand
    print "Global git identity cleared."
}

# List usernames only, one per line — used by Fish completions.
export def list-usernames [] {
    if not ($PROFILES_PATH | path exists) { return }
    let raw = (open --raw $PROFILES_PATH | str trim)
    if ($raw | is-empty) { return }
    $raw | from csv --noheaders | get column1 | to text
}

# --- Private helpers ---

def copy-to-clipboard [text: string] {
    # OSC 52: works over SSH, interpreted by the local terminal emulator
    # (Ghostty, kitty, iTerm2, tmux with set-clipboard on, etc.)
    let encoded = ($text | encode base64)
    print -n $"\e]52;c;($encoded)\a"

    # Also try native clipboard tools as fallback for local sessions
    if (which xclip | is-not-empty) {
        $text | xclip -selection clipboard
    } else if (which xsel | is-not-empty) {
        $text | xsel --clipboard --input
    } else if (which pbcopy | is-not-empty) {
        $text | pbcopy
    } else if (which clip.exe | is-not-empty) {
        $text | clip.exe
    }
}

def ssh-keygen-at-path [
    email: string
    ssh_key_path: string
    ssh_pub_key_path: string
] {
    ssh-keygen -t ed25519 -C $email -f ($ssh_key_path | path expand)
    let pub_key = (open --raw ($ssh_pub_key_path | path expand) | str trim)
    copy-to-clipboard $pub_key
    print "Public key copied to clipboard."
    print $"Key path: ($ssh_pub_key_path)"
}

def profiles-from-csv [] {
    $in | from csv --noheaders | rename username email key_name
}

def check-add-profile [
    username: string
    email: string
    key_name: string
] {
    mkdir $PROFILES_DIR

    if not ($PROFILES_PATH | path exists) {
        touch $PROFILES_PATH
    }

    let profiles_raw = (open --raw $PROFILES_PATH | str trim)
    let profiles = if ($profiles_raw | is-empty) {
        []
    } else {
        $profiles_raw | profiles-from-csv
    }

    let existing = $profiles | where username == $username
    let new_line = $"($username),($email),($key_name)\n"

    if ($existing | length) > 1 {
        error make {msg: $"Multiple profiles for '($username)'. Manually fix ($PROFILES_PATH)"}
    } else if ($existing | length) == 1 {
        let old = $existing | first
        print $"Existing profile for '($username)':"
        print $"  email:    ($old.email)"
        print $"  key_name: ($old.key_name)"
        print ""
        print "Replace with:"
        print $"  email:    ($email)"
        print $"  key_name: ($key_name)"
        print ""
        let answer = (input "Overwrite? (y/N): " | str trim | str downcase)
        if $answer == "y" {
            let kept = $profiles | where username != $username
            let csv_out = if ($kept | is-empty) { "" } else { $kept | to csv --noheaders }
            ($csv_out + $new_line) | save --force $PROFILES_PATH
            print $"Profile '($username)' updated."
        } else {
            print "Cancelled."
        }
    } else {
        $new_line | save --append $PROFILES_PATH
        print $"Profile '($username)' added."
    }
}
