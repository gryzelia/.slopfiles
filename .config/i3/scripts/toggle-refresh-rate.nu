#!/bin/nu

# Define the two refresh rates
const refresh_rate1 = 60
const refresh_rate2 = 165

# Get the current refresh rate
let is_refresh_rate1 = ((xrandr --query | grep -o $"($refresh_rate1).[0-9]*\\*") != '')

# Toggle between the two refresh rates
let new_rate = if $is_refresh_rate1 { $refresh_rate2 } else { $refresh_rate1 }

# Apply the new refresh rate
xrandr --rate $new_rate
