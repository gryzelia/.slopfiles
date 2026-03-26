local wezterm = require 'wezterm'
local act = wezterm.action;
local config = {}

local is_macos = string.find(wezterm.target_triple, 'apple')
local is_linux = string.find(wezterm.target_triple, 'linux')
local is_windows = string.find(wezterm.target_triple, 'windows')

config.enable_scroll_bar = true
if is_macos then
    config.font_size = 12
else
    config.font_size = 9
end

config.font = wezterm.font_with_fallback({
    { family = 'JetBrains Mono', weight = 'Bold' },
    { family = 'Symbols Nerd Font Mono', weight = 'Bold' },
    -- 'Symbols Nerd Font'
})

local session_manager = require("wezterm-session-manager/session-manager")

wezterm.on("save_session", function(window) session_manager.save_state(window) end)
wezterm.on("load_session", function(window) session_manager.load_state(window) end)
wezterm.on("restore_session", function(window) session_manager.restore_state(window) end)

config.leader = { key = ';', mods = 'CTRL', timeout_milliseconds = 1000 }

local pane_navigation_keys = {
    { key = 'q', mods = 'ALT',       action = act.PaneSelect { alphabet = '1234567890', } },
    { key = 'q', mods = 'ALT|SHIFT', action = act.PaneSelect { alphabet = '1234567890', mode = 'SwapWithActiveKeepFocus', } },
    { key = 'h', mods = 'ALT',       action = act.ActivatePaneDirection 'Left', },
    { key = 'j', mods = 'ALT',       action = act.ActivatePaneDirection 'Down', },
    { key = 'k', mods = 'ALT',       action = act.ActivatePaneDirection 'Up', },
    { key = 'l', mods = 'ALT',       action = act.ActivatePaneDirection 'Right', },
}
-- use CMD instead of Alt on macos
if is_macos then
    for _, mapping in ipairs(pane_navigation_keys) do
        print(mapping)
        mapping.mods = mapping.mods:gsub('ALT', 'CMD')
    end
end

local other_keys = {
    -- Disable ALT-Enter
    {
        key = 'Enter',
        mods = 'ALT',
        action = act.Nop,
    },
    {
        key = 'F11',
        mods = 'CTRL',
        action = act.ToggleFullScreen,
    },
    { key = "S", mods = "LEADER", action = act { EmitEvent = "save_session" } },
    { key = "L", mods = "LEADER", action = act { EmitEvent = "load_session" } },
    { key = "R", mods = "LEADER", action = act { EmitEvent = "restore_session" } },
}

local all_keys = {table.unpack(other_keys)}
table.move(pane_navigation_keys, 1, #pane_navigation_keys, #all_keys + 1, all_keys)
config.keys = all_keys

config.mouse_bindings = {
    -- Change the default click behavior so that it only selects
    -- text and doesn't open hyperlinks
    {
        event = { Up = { streak = 1, button = "Left" } },
        mods = "NONE",
        action = act.CompleteSelection("PrimarySelection"),
    },

    -- and make CTRL-Click open hyperlinks
    {
        event = { Up = { streak = 1, button = "Left" } },
        mods = "CTRL",
        action = act.OpenLinkAtMouseCursor,
    },

    -- Disable the 'Down' event of CTRL-Click to avoid weird program behaviors
    {
        event = { Down = { streak = 1, button = 'Left' } },
        mods = 'CTRL',
        action = act.Nop,
    },
}
if is_macos then
    config.default_prog = { '/opt/homebrew/bin/fish' }
else
    config.default_prog = { 'nu' }
end

config.window_padding = {
    left = 6,
    right = 6,
    top = 3,
    bottom = 3,
}
config.enable_scroll_bar = true
config.colors = {
    scrollbar_thumb = '#454545'
}

return config
