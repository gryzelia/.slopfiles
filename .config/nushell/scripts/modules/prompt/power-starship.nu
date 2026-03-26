let LEFT_DELIMITER = [ '|' (char rs) '>' ] | str join
let RIGHT_DELIMITER = [ '<' (char rs) '|' ] | str join

let FILL = (char -u a78f)

let background_colors = [
    { symbol:  , bg_color: "#3465A4", show_symbol: true }
    { symbol: , bg_color: "#4E9A06", show_symbol: true }
    { symbol: 🏷, bg_color: "#4E9A06", show_symbol: true }
    { symbol: 󱇯, bg_color: "#4E9A06", show_symbol: true }
    { symbol: 󱖫, bg_color: "#C4A000", show_symbol: false }
    { symbol: , bg_color: "#65D6CD", show_symbol: true }
    { symbol: , bg_color: "#D3D7CF", show_symbol: false }
]

def parse_segments [segments: list<string>] {
    $segments | each { |segment| 
        let split_index = $segment | str index-of ":"
        let symbol_ansi = $segment | str substring ..($split_index - 1)
        let rest = $segment | str substring ($split_index + 1)..
        let symbol = ($symbol_ansi | ansi strip | str trim)
        let record = $background_colors | where symbol == $symbol | get 0
        let content = if $record.show_symbol {
            $symbol_ansi + $rest
        } else {
            ($symbol_ansi | str replace --all $symbol "") + $rest
        }
        { content: $content, bg_color: $record.bg_color }
    }
}

def decorate_prompt [prompt: string] {
    let split = $prompt | split row $FILL
    let left = $split.0
    let right = $split | last 1 | get 0
    let left_split = $left | split row $LEFT_DELIMITER | drop 1
    let right_split = $right | split row $RIGHT_DELIMITER | skip 1
    let left_tokens = parse_segments $left_split
    let right_tokens = parse_segments $right_split
    let left_with_decorators = insert_left_decorators $left_tokens
    let right_with_decorators = insert_right_decorators $right_tokens

    let left_segment_length = ($left_with_decorators | ansi strip | str length -g)
    let right_segment_length = ($right_with_decorators | ansi strip | str length -g)
    let term_width = ((term size) | get columns)
    let padding_length = ($term_width - $left_segment_length - $right_segment_length) # guarantee sum === term_width

    [(ansi reset),
        $left_with_decorators,
        (ansi dark_gray),
        ('' | fill --character $FILL --width $padding_length)
        (ansi reset),
        ($right_with_decorators),
        (ansi reset),
        "\n"
    ] | str join ''
}

def insert_left_decorators [
    tokens: list<record<content: string, bg_color:string>>
] {
    let $R = (ansi reset)
    let body = $tokens | append {} | window 2 | each { |$pair|
        let $curr = $pair.0
        let $next = $pair.1
        [
            (ansi {bg: $curr.bg_color})
            ($curr.content)
            (ansi (if $next != {} {{fg: $curr.bg_color, bg: $next.bg_color}} else {fg: $curr.bg_color} ))
            (char nf_left_segment)
            ($R)
        ]
    } | flatten | str join
    $body
}

def insert_right_decorators [
    tokens: list<record<content: string, bg_color:string>>
] {
    let $R = (ansi reset)
    let body = $tokens | prepend {} | window 2 | each { |$pair|
        let $prev = $pair.0
        let $curr = $pair.1
        [
            (ansi (if $prev != {} {{fg: $prev.bg_color, bg: $curr.bg_color}} else {fg: $curr.bg_color} ))
            (char nf_right_segment)
            ($R)
            (ansi {bg: $curr.bg_color})
            ($curr.content)
        ]
    } | flatten | str join
    $body
}

def get_starship_prompt [] {
    ^starship prompt --cmd-duration $env.CMD_DURATION_MS $'--status=($env.LAST_EXIT_CODE)'
}


def create_prompt [] {
    decorate_prompt (get_starship_prompt)
}

$env.PROMPT_COMMAND = { create_prompt }

# avoid same PROMPT_INDICATOR
$env.PROMPT_INDICATOR = { "〉" }
$env.PROMPT_INDICATOR_VI_INSERT = { ": " }
$env.PROMPT_INDICATOR_VI_NORMAL = { "〉" }
$env.PROMPT_MULTILINE_INDICATOR = { "::: " }
