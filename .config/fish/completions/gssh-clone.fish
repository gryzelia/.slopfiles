complete -c gssh-clone -s u -l username -x -d "SSH profile username" \
    -a "(nu -c 'use ~/.config/fish/nu/gssh.nu *; list-usernames' 2>/dev/null)"
complete -c gssh-clone --wraps "git clone"
