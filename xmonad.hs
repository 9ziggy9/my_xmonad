{-# OPTIONS_GHC -Wno-deprecations #-}

  -- Base
import XMonad
import System.Directory
import System.IO (hPutStrLn)
import System.Exit (exitSuccess)
import qualified XMonad.StackSet as W

    -- Actions
import XMonad.Actions.CopyWindow (kill1)
import XMonad.Actions.CycleWS (Direction1D(..), moveTo, shiftTo, WSType(..), nextScreen, prevScreen)
import XMonad.Actions.MouseResize
import XMonad.Actions.Promote
import XMonad.Actions.RotSlaves (rotSlavesDown, rotAllDown)
import XMonad.Actions.WindowGo (runOrRaise)
import XMonad.Actions.WithAll (sinkAll, killAll)
import XMonad.Actions.Navigation2D
import qualified XMonad.Actions.Search as S

    -- Data
import Data.Char (isSpace, toUpper)
import Data.Maybe (fromJust)
import Data.Monoid
import Data.Maybe (isJust)
import Data.Tree
import qualified Data.Map as M

    -- Hooks
import XMonad.Hooks.DynamicLog (dynamicLogWithPP, wrap, xmobarPP, xmobarColor, shorten, PP(..))
import XMonad.Hooks.EwmhDesktops  -- for some fullscreen events, also for xcomposite in obs.
import XMonad.Hooks.ManageDocks (avoidStruts, docksEventHook, manageDocks, ToggleStruts(..))
import XMonad.Hooks.ManageHelpers (isFullscreen, doFullFloat, doCenterFloat)
import XMonad.Hooks.ServerMode
import XMonad.Hooks.SetWMName
import XMonad.Hooks.WorkspaceHistory

    -- Layouts
import XMonad.Layout.GridVariants (Grid(Grid))
import XMonad.Layout.SimplestFloat
import XMonad.Layout.Spiral
import XMonad.Layout.ResizableTile
import XMonad.Layout.Tabbed
import XMonad.Layout.ThreeColumns

    -- Layouts modifiers
import XMonad.Layout.LayoutModifier
import XMonad.Layout.LimitWindows (limitWindows, increaseLimit, decreaseLimit)
import XMonad.Layout.MultiToggle (mkToggle, single, EOT(EOT), (??))
import XMonad.Layout.MultiToggle.Instances (StdTransformers(NBFULL, MIRROR, NOBORDERS))
import XMonad.Layout.NoBorders
import XMonad.Layout.Renamed
import XMonad.Layout.Simplest
import XMonad.Layout.Spacing
import XMonad.Layout.SubLayouts
import XMonad.Layout.WindowArranger (windowArrange, WindowArrangerMsg(..))
import XMonad.Layout.WindowNavigation
import qualified XMonad.Layout.ToggleLayouts as T (toggleLayouts, ToggleLayout(Toggle))
import qualified XMonad.Layout.MultiToggle as MT (Toggle(..))

   -- Utilities
import XMonad.Util.Dmenu
import XMonad.Util.EZConfig (additionalKeysP)
import XMonad.Util.NamedScratchpad
import XMonad.Util.Run (runProcessWithInput, safeSpawn, spawnPipe)
import XMonad.Util.SpawnOnce

   -- ColorScheme module (SET ONLY ONE!)
      -- Possible choice are:
      -- DoomOne
      -- Dracula
      -- GruvboxDark
      -- MonokaiPro
      -- Nord
      -- OceanicNext
      -- Palenight
      -- SolarizedDark
      -- SolarizedLight
      -- TomorrowNight
import Colors.SolarizedDark

myFont :: String
myFont = "xft:FiradCode Nerd Font:regular:size=9:antialias=true:hinting=true"

myModMask :: KeyMask
myModMask = mod4Mask        -- Sets modkey to super/windows key

myTerminal :: String
myTerminal = "alacritty"    -- Sets default terminal

myBrowser :: String
myBrowser = "chromium "  -- Sets qutebrowser as browser

myEmacs :: String
myEmacs = "emacsclient -c -a 'emacs' "  -- Makes emacs keybindings easier to type

myEditor :: String
myEditor = "emacsclient -c -a 'emacs' "  -- Sets emacs as editor

myBorderWidth :: Dimension
myBorderWidth = 1           -- Sets border width for windows

myNormColor :: String       -- Border color of normal windows
myNormColor   = color11   -- This variable is imported from Colors.THEME

myFocusColor :: String      -- Border color of focused windows
myFocusColor  = color16     -- This variable is imported from Colors.THEME

windowCount :: X (Maybe String)
windowCount = gets $ Just . show . length . W.integrate' . W.stack . W.workspace . W.current . windowset

myStartupHook :: X ()
myStartupHook = do
    spawnOnce "picom"
    spawnOnce "/usr/bin/emacs --daemon" -- emacs daemon for the emacsclient
    spawnOnce "feh --bg-fill ~/wallpapers/solarized.png"
    setWMName "LG3D"

myNavigation2DConfig = def { layoutNavigation = [("spirals", sideNavigation)
					       , ("threeCol", sideNavigation)
					       , ("grid", sideNavigation)]}

myScratchPads :: [NamedScratchpad]
myScratchPads = [ NS "terminal" spawnTerm findTerm manageTerm
                , NS "browser" spawnBrowser findBrowser manageBrowser
                ]
  where
    spawnTerm  = myTerminal ++ " -t scratchpad"
    findTerm   = title =? "scratchpad"
    manageTerm = customFloating $ W.RationalRect l t w h
               where
                 h = 0.6
                 w = 0.6
                 t = 0.2
                 l = 0.2
    spawnBrowser  = "chromium --class=\"scratch-chrome\""
    findBrowser   = className =? "scratch-chrome"
    manageBrowser = customFloating $ W.RationalRect l t w h
               where
                 h = 0.90
                 w = 0.90
                 t = 0.95 -h
                 l = 0.95 -w

--Makes setting the spacingRaw simpler to write. The spacingRaw module adds a configurable amount of space around windows.
mySpacing :: Integer -> l a -> XMonad.Layout.LayoutModifier.ModifiedLayout Spacing l a
mySpacing i = spacingRaw False (Border i i i i) True (Border i i i i) True

-- Below is a variation of the above except no borders are applied
-- if fewer than two windows. So a single window has no gaps.
mySpacing' :: Integer -> l a -> XMonad.Layout.LayoutModifier.ModifiedLayout Spacing l a
mySpacing' i = spacingRaw True (Border i i i i) True (Border i i i i) True

-- Defining a bunch of layouts, many that I don't use.
-- limitWindows n sets maximum number of windows displayed for layout.
-- mySpacing n sets the gap size around the windows.
floats   = renamed [Replace "floats"]
           $ limitWindows 20 simplestFloat
grid     = renamed [Replace "grid"]
	   $ smartBorders
           $ windowNavigation
           $ addTabs shrinkText myTabTheme
           $ subLayout [] (smartBorders Simplest)
           $ limitWindows 12
           $ mySpacing 4
           $ mkToggle (single MIRROR)
           $ Grid (16/10)
spirals  = renamed [Replace "spirals"]
	   $ smartBorders
           $ windowNavigation
           $ addTabs shrinkText myTabTheme
           $ subLayout [] (smartBorders Simplest)
           $ mySpacing' 4
           $ spiral (6/7)
threeCol = renamed [Replace "threeCol"]
	   $ smartBorders
           $ windowNavigation
           $ addTabs shrinkText myTabTheme
           $ subLayout [] (smartBorders Simplest)
           $ limitWindows 7
	   $ mySpacing' 4
           $ ThreeColMid 1 (3/100) (1/2)
tabs     = renamed [Replace "tabs"]
           -- I cannot add spacing to this layout because it will
           -- add spacing between window and tabs which looks bad.
           $ tabbed shrinkText myTabTheme

-- setting colors for tabs layout and tabs sublayout.
myTabTheme = def { fontName            = myFont
                 , activeColor         = colorBack
                 , inactiveColor       = colorBack
                 , activeBorderColor   = colorFore
                 , inactiveBorderColor = colorFore
                 , activeTextColor     = color03
                 , inactiveTextColor   = colorFore
                 }

-- The layout hook
myLayoutHook = avoidStruts $ mouseResize $ windowArrange $ T.toggleLayouts floats
               $ mkToggle (NBFULL ?? NOBORDERS ?? EOT) myDefaultLayout
             where
               myDefaultLayout =     withBorder myBorderWidth threeCol
                                 ||| withBorder myBorderWidth spirals
                                 ||| withBorder myBorderWidth grid
                                 ||| withBorder myBorderWidth floats
                                 ||| noBorders tabs

-- myWorkspaces = [" 1 ", " 2 ", " 3 ", " 4 ", " 5 ", " 6 ", " 7 ", " 8 ", " 9 "]
myWorkspaces = [" dev ", " www ", " sys ", " doc ", " vbox ", " chat ", " mus ", " vid ", " gfx "]
myWorkspaceIndices = M.fromList $ zipWith (,) myWorkspaces [1..] -- (,) == \x y -> (x,y)

clickable ws = "<action=xdotool key super+"++show i++">"++ws++"</action>"
    where i = fromJust $ M.lookup ws myWorkspaceIndices

myManageHook :: XMonad.Query (Data.Monoid.Endo WindowSet)
myManageHook = composeAll
     -- 'doFloat' forces a window to float.  Useful for dialog boxes and such.
     -- using 'doShift ( myWorkspaces !! 7)' sends program to workspace 8!
     -- I'm doing it this way because otherwise I would have to write out the full
     -- name of my workspaces and the names would be very long if using clickable workspaces.
     [ className =? "confirm"         --> doFloat
     , className =? "file_progress"   --> doFloat
     , className =? "dialog"          --> doFloat
     , className =? "download"        --> doFloat
     , className =? "error"           --> doFloat
     , className =? "Gimp"            --> doFloat
     , className =? "notification"    --> doFloat
     , className =? "pinentry-gtk-2"  --> doFloat
     , className =? "splash"          --> doFloat
     , className =? "toolbar"         --> doFloat
     , className =? "Yad"             --> doCenterFloat
     , title =? "Oracle VM VirtualBox Manager"  --> doFloat
     , (className =? "firefox" <&&> resource =? "Dialog") --> doFloat  -- Float Firefox Dialog
     , isFullscreen -->  doFullFloat
     ] <+> namedScratchpadManageHook myScratchPads

-- START_KEYS
myKeys :: [(String, X ())]
myKeys =
    -- KB_GROUP Xmonad
        [ ("M-C-r", spawn "xmonad --recompile")       -- Recompiles xmonad
        , ("M-S-r", spawn "xmonad --restart")         -- Restarts xmonad
        , ("M-S-q", io exitSuccess)                   -- Quits xmonad

    -- KB_GROUP Run Prompts
        , ("M-p", spawn "dm-run") -- Dmenu

    -- KB_GROUP Useful programs to have a keybinding for launch
        , ("M-<Return>", spawn (myTerminal))
        , ("M-b", spawn (myBrowser))
        , ("M-M1-h", spawn (myTerminal ++ " -e htop"))

    -- KB_GROUP Kill windows
        , ("M-x", kill1)     -- Kill the currently focused client
        , ("M-S-x", killAll)   -- Kill all windows on current workspace

    -- KB_GROUP Workspaces
        , ("M-.", nextScreen)  -- Switch focus to next monitor
        , ("M-,", prevScreen)  -- Switch focus to prev monitor
    
    -- KB_GROUP Floating windows
        , ("M-f", sendMessage (T.Toggle "floats")) -- Toggles my 'floats' layout
        , ("M-t", withFocused $ windows . W.sink)  -- Push floating window back to tile
        , ("M-S-t", sinkAll)                       -- Push ALL floating windows to tile

    -- KB_GROUP Windows navigation
        , ("M-m", windows W.focusMaster)  -- Move focus to the master window

	-- FOCUS MOVEMENT
        , ("M-j", windowGo D False)
        , ("M-k", windowGo U False)
        , ("M-h", windowGo L False)    
        , ("M-l", windowGo R False)   
	-- TILE MOVEMENT
        , ("M-S-j", windowSwap D False)
        , ("M-S-k", windowSwap U False)
        , ("M-S-h", windowSwap L False)    
        , ("M-S-l", windowSwap R False)   

        , ("M-S-m", windows W.swapMaster) -- Swap the focused window and the master window
        --, ("M-<Backspace>", promote)      -- Moves focused window to master, others maintain order
        --, ("M-S-<Tab>", rotSlavesDown)    -- Rotate all windows except master and keep focus in place
        --, ("M-C-<Tab>", rotAllDown)       -- Rotate all the windows in the current stack

    -- KB_GROUP Layouts
        , ("M-<Space>", sendMessage NextLayout)           -- Switch to next layout
        , ("M-S-f", sendMessage (MT.Toggle NBFULL) >> sendMessage ToggleStruts) -- Toggles noborder/full

    -- KB_GROUP Window resizing
        , ("M-[", sendMessage Shrink)                   -- Shrink horiz window width
        , ("M-]", sendMessage Expand)                   -- Expand horiz window width
        , ("M-S-[", sendMessage MirrorShrink)          -- Shrink vert window width
        , ("M-S-]", sendMessage MirrorExpand)          -- Expand vert window width

    -- KB_GROUP Sublayouts
    -- This is used to push windows to tabbed sublayouts, or pull them out of it.
        , ("M-C-h", sendMessage $ pullGroup L)
        , ("M-C-l", sendMessage $ pullGroup R)
        , ("M-C-k", sendMessage $ pullGroup U)
        , ("M-C-j", sendMessage $ pullGroup D)
        -- , ("M-C-m", withFocused (sendMessage . MergeAll))
        , ("M-C-<Tab>", withFocused (sendMessage . UnMerge))
        -- , ("M-C-/", withFocused (sendMessage . UnMergeAll))
        , ("M-<Tab>", onGroup W.focusUp')    -- Switch focus to next tab
        -- , ("M-C-,", onGroup W.focusDown')  -- Switch focus to prev tab

    -- KB_GROUP Scratchpads
    -- Toggle show/hide these programs.  They run on a hidden workspace.
    -- When you toggle them to show, it brings them to your current workspace.
    -- Toggle them to hide and it sends them back to hidden workspace (NSP).
        , ("M-d", namedScratchpadAction myScratchPads "terminal")
        , ("M-c", namedScratchpadAction myScratchPads "browser")

    -- KB_GROUP Emacs (SUPER-e followed by a key)
        , ("M-e", spawn myEmacs )   -- emacs dashboard
        --, ("M-e b", spawn (myEmacs ++ ("--eval '(ibuffer)'")))   -- list buffers
        --, ("M-e d", spawn (myEmacs ++ ("--eval '(dired nil)'"))) -- dired
        --, ("M-e i", spawn (myEmacs ++ ("--eval '(erc)'")))       -- erc irc client
        --, ("M-e n", spawn (myEmacs ++ ("--eval '(elfeed)'")))    -- elfeed rss
        --, ("M-e s", spawn (myEmacs ++ ("--eval '(eshell)'")))    -- eshell
        --, ("M-e t", spawn (myEmacs ++ ("--eval '(mastodon)'")))  -- mastodon.el
        --, ("M-e v", spawn (myEmacs ++ ("--eval '(+vterm/here nil)'"))) -- vterm if on Doom Emacs
        --, ("M-e w", spawn (myEmacs ++ ("--eval '(doom/window-maximize-buffer(eww \"distro.tube\"))'"))) -- eww browser if on Doom Emacs
        --, ("M-e a", spawn (myEmacs ++ ("--eval '(emms)' --eval '(emms-play-directory-tree \"~/Music/\")'")))
        ]
    -- The following lines are needed for named scratchpads.
          where nonNSP          = WSIs (return (\ws -> W.tag ws /= "NSP"))
                nonEmptyNonNSP  = WSIs (return (\ws -> isJust (W.stack ws) && W.tag ws /= "NSP"))
-- END_KEYS

main :: IO ()
main = do
    -- Launching three instances of xmobar on their monitors.
    xmproc0 <- spawnPipe ("xmobar -x 0 $HOME/.config/xmobar/" ++ colorScheme ++ "-xmobarrc")
    xmproc1 <- spawnPipe ("xmobar -x 1 $HOME/.config/xmobar/" ++ colorScheme ++ "-xmobarrc")
    xmproc2 <- spawnPipe ("xmobar -x 2 $HOME/.config/xmobar/" ++ colorScheme ++ "-xmobarrc")
    -- the xmonad, ya know...what the WM is named after!
    xmonad $ withNavigation2DConfig myNavigation2DConfig $ ewmh def
        { manageHook         = myManageHook <+> manageDocks
        , handleEventHook    = docksEventHook
                               -- Uncomment this line to enable fullscreen support on things like YouTube/Netflix.
                               -- This works perfect on SINGLE monitor systems. On multi-monitor systems,
                               -- it adds a border around the window if screen does not have focus. So, my solution
                               -- is to use a keybinding to toggle fullscreen noborders instead.  (M-<Space>)
                               -- <+> fullscreenEventHook
        , modMask            = myModMask
        , terminal           = myTerminal
        , startupHook        = myStartupHook
        , layoutHook         = myLayoutHook
        , workspaces         = myWorkspaces
        , borderWidth        = myBorderWidth
        , normalBorderColor  = myNormColor
        , focusedBorderColor = myFocusColor
        , logHook = dynamicLogWithPP $ namedScratchpadFilterOutWorkspacePP $ xmobarPP
              -- XMOBAR SETTINGS
              { ppOutput = \x -> hPutStrLn xmproc0 x   -- xmobar on monitor 1
                              >> hPutStrLn xmproc1 x   -- xmobar on monitor 2
                              >> hPutStrLn xmproc2 x   -- xmobar on monitor 3
                -- Current workspace
              , ppCurrent = xmobarColor color06 "" . wrap
                            ("<box type=Bottom width=2 mb=2 color=" ++ color06 ++ ">") "</box>"
                -- Visible but not current workspace
              , ppVisible = xmobarColor color06 "" . clickable
                -- Hidden workspace
              , ppHidden = xmobarColor color05 "" . wrap
                           ("<box type=Top width=2 mt=2 color=" ++ color05 ++ ">") "</box>" . clickable
                -- Hidden workspaces (no windows)
              , ppHiddenNoWindows = xmobarColor color05 ""  . clickable
                -- Title of active window
              , ppTitle = xmobarColor color16 "" . shorten 60
                -- Separator character
              , ppSep =  "<fc=" ++ color09 ++ "> <fn=1>|</fn> </fc>"
                -- Urgent workspace
              , ppUrgent = xmobarColor color02 "" . wrap "!" "!"
                -- Adding # of windows on current workspace to the bar
              , ppExtras  = [windowCount]
                -- order of things in xmobar
              , ppOrder  = \(ws:l:t:ex) -> [ws,l]++ex++[t]
              }
        } `additionalKeysP` myKeys
