complete -c gssh-use -f
complete -c gssh-use -s g -l global -d "Set globally instead of for the current repo"
complete -c gssh-use -n "test (count (commandline -opc)) -eq 1" \
    -a "(nu -c 'use ~/.config/fish/nu/gssh.nu *; list-usernames' 2>/dev/null)"
