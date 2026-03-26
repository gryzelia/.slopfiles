if $nu.os-info.name == "windows" {
    $env.Path = ($env.Path | prepend "C:/Users/Name/AppData/Roaming/carapace/bin")
}

$env.config.completions.external = {
    enable: true
    max_results: 40
}

let carapace_completer = {|spans: list<string>| 
    if (which carapace | is-empty) { 
        return
    }

    carapace $spans.0 nushell ...$spans 
    | from json 
    | if ($in | default [] | where value =~ '^-.*ERR$' | is-empty) { $in } else { null }
}

let zoxide_completer = {|spans: list<string>|
    if (which zoxide | is-empty) { 
        return
    }

    let zoxide_dirs = ($spans | skip 1 | zoxide query -l ...$in | lines | where {|x| $x != env.PWD } | first 15)
    let pwd_dirs = match ($spans | length) {
        1 | 2 => (glob ($spans.1 + '*') | path relative-to (pwd) | where {|x| ($x | path type) == dir})
        _ => []
    }
    $pwd_dirs ++ $zoxide_dirs
}

$env.config.completions.external.completer = {|spans|
    let expanded_alias = (scope aliases | where name == $spans.0 | get --ignore-errors expansion.0)

    # overwrite
    let spans = (if $expanded_alias != null  {
        # put the first word of the expanded alias first in the span
        $spans | skip 1 | prepend ($expanded_alias | split row " " | take 1)
    } else { $spans })

    match $spans.0 {
        __zoxide_z => $zoxide_completer
        _ => $carapace_completer
    } | do $in $spans
}
