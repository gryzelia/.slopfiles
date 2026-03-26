alias te = table --expand 
alias g = git
alias gt = goto
alias rm = rm -I -t
alias cat = open --raw
# has some bugs with completion but there probably isn't a clean fix
alias dotfiles = git --git-dir ~/.dotfiles --work-tree ~

if $nu.os-info.name == 'windows' {
    alias psc = pwsh -C
    alias trash = explorer shell:RecycleBinFolder
    alias wexp = explorer
    alias wslkill = sudo TASKKILL /IM "wslservice.exe" /F  
}
