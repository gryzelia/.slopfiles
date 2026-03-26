import XMonad
import XMonad.Hooks.StatusBar
import XMonad.Hooks.DynamicLog
import XMonad.Hooks.ManageDocks
import XMonad.Util.EZConfig
import XMonad.Operations
import System.IO

import XMonad.Layout.Renamed
import XMonad.Layout.ToggleLayouts
import XMonad.Layout.Spiral
import XMonad.Layout.Grid
import XMonad.Layout.Tabbed

import XMonad.Actions.CycleSelectedLayouts


main :: IO ()
main = do
  let myStartupHook = do spawn "dunst"

  let recompileRestart = do spawn "if type xmonad; then \
           \ xmonad --recompile && xmonad --restart && notify-send 'XMonad' 'Recompiled and restarted successfully'; \
           \ else notify-send 'XMonad' 'xmonad binary not found: recompile failed'; \
           \ fi"

  let keybinds = [ ("M-S-z", spawn "xscreensaver-command -lock")
                 , ("M-C-s", unGrab *> spawn "scrot -s")
                 , ("M-f"  , spawn "firefox")
                 , ("M-d"  , spawn "rofi -show drun")
                 , ("M-C-r", recompileRestart)
                 , ("M-C-l", sendMessage ToggleLayout)
                 , ("M-S-q", kill)
                 , ("M-t", sendMessage $ JumpToLayout "Tabbed")
                 , ("M-g", sendMessage $ JumpToLayout "Grid")
                 ]

  let disabledKeybinds = [ ("M-S-c", spawn "") ]

  let defaultLayout = (renamed [Replace "Grid"] $ GridRatio 1) ||| (renamed [Replace "Tabbed"] $ simpleTabbed)

  mySB <- statusBarPipe "xmobar" (pure xmobarPP)
  xmonad . withEasySB mySB defToggleStrutsKey
    $ def
      { terminal    = "st"
      , modMask     = mod1Mask
      , borderWidth = 4
      , normalBorderColor  = "#cccccc"
      , focusedBorderColor = "#cd8b00"
      , focusFollowsMouse = False
      , layoutHook = defaultLayout
      , startupHook = myStartupHook
      }`additionalKeysP` (keybinds ++ disabledKeybinds)
