---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
local terminal    = "kitty"
local fileManager = "dolphin"
local menu        = "hyprlauncher"
local browser	  = "firefox"
local launcher	  = "fuzzel"
local vscode      = "code"


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier
local ipc = "noctalia msg"

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd(terminal))
local closeWindowBind = hl.bind(mainMod .. " + X", hl.dsp.window.close())
-- closeWindowBind:set_enabled(false)
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))    -- dwindle only
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("noctalia msg session lock"))
hl.bind(mainMod .. " + adiaeresis", hl.dsp.exec_cmd(ipc .. " brightness-up"))
hl.bind(mainMod .. " + odiaeresis", hl.dsp.exec_cmd(ipc .. " brightness-down"))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with CTRL + mainMod + left/right
hl.bind("CTRL + " .. mainMod .. " + left",  hl.dsp.focus({ workspace = "e-1" }))
hl.bind("CTRL + " .. mainMod .. " + right", hl.dsp.focus({ workspace = "e+1" }))

-- Move active window with CTRL + SHIFT + mainMod + left/right
hl.bind("CTRL + SHIFT + " .. mainMod .. " + left",  hl.dsp.window.move({ workspace = "e-1" }))
hl.bind("CTRL + SHIFT + " .. mainMod .. " + right", hl.dsp.window.move({ workspace = "e+1" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Core binds
hl.bind(mainMod .. "+ Space", hl.dsp.exec_cmd(ipc .. " panel-toggle launcher"))
hl.bind(mainMod .. "+ C", hl.dsp.exec_cmd(vscode))
hl.bind(mainMod .. "+ H", hl.dsp.exec_cmd(ipc .. " panel-toggle control-center"))
hl.bind(mainMod .. "+ K", hl.dsp.exec_cmd(ipc .. " caffeine-toggle"))
hl.bind(mainMod .. "+ comma", hl.dsp.exec_cmd(ipc .. " settings-toggle"))

-- Media keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(ipc .. " volume-up"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(ipc .. " volume-down"))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(ipc .. " volume-mute"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(ipc .. " brightness-up"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(ipc .. " brightness-down"))
