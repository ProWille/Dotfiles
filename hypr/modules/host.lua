--------------------------------
---- HOST-SPECIFIC PRESETS ----
--------------------------------
-- Resolves which monitor/workspace layout applies to this machine.
--
-- Detection order:
--   1. ~/.config/machine   -- if present, its first line names the preset
--   2. DRM scan            -- any eDP-*/LVDS-* connector present => laptop
--   3. anything else       -- pc (fallback / default)
--
-- Override for new machines:
--   echo pc > ~/.config/machine     # e.g. a desktop
--   echo laptop > ~/.config/machine # e.g. a laptop
--
-- The DRM scan treats a built-in display panel (eDP/LVDS) as the laptop
-- signal, so no hostname matching is needed. If io.popen is unavailable
-- it degrades to the marker / pc fallback.
--
-- To add your own preset, define the corresponding entry in PRESETS.

local function read_first_line(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local line = f:read("*l")
    f:close()
    return line
end

local function has_internal_panel()
    local ok, p = pcall(io.popen, "ls /sys/class/drm/ 2>/dev/null | grep -E 'eDP-|LVDS-'")
    if not ok or not p then
        return false
    end
    local line = p:read("*l")
    p:close()
    return line ~= nil
end

local function detect_host()
    local marker = read_first_line(os.getenv("HOME") .. "/.config/machine")
    if marker and marker ~= "" then
        return marker
    end

    if has_internal_panel() then
        return "laptop"
    end

    return "pc"
end

local PRESETS = {
    pc = {
        monitors = {
            { output   = "DP-3",
              mode     = "2560x1440@180",
              position = "0x0",
              scale    = "1",
              cm       = "auto" },

            { output     = "DP-2",
              mode       = "1920x1080@144",
              position   = "-1080x0",
              scale      = "1",
              transform  = 1,
              disabled    = false },

            { output   = "HDMI-A-1",
              mode     = "1920x1080@60",
              position = "2560x0",
              scale    = "1",
              disabled  = false },
        },

        -- persistent workspaces: 1-8 main, 9 second, 10 third
        workspaces = {
            ["1"]  = "DP-3",
            ["2"]  = "DP-3",
            ["3"]  = "DP-3",
            ["4"]  = "DP-3",
            ["5"]  = "DP-3",
            ["6"]  = "DP-3",
            ["7"]  = "DP-3",
            ["8"]  = "DP-3",
            ["9"]  = "DP-2",
            ["10"] = "HDMI-A-1",
        },

        default_monitor = "DP-3",
        xrandr_primary  = "DP-3",
    },

    laptop = {
        monitors = {
            { output   = "eDP-1",
              mode     = "1920x1080@60",
              position = "0x0",
              scale    = "1",
              cm       = "auto" },

            { output   = "HDMI-A-1",
              mode     = "1920x1080@60",
              position = "1920x0",
              scale    = "1",
              disabled  = false },
        },

        -- persistent workspaces: 1-9 built-in panel, 10 external HDMI
        workspaces = {
            ["1"]  = "eDP-1",
            ["2"]  = "eDP-1",
            ["3"]  = "eDP-1",
            ["4"]  = "eDP-1",
            ["5"]  = "eDP-1",
            ["6"]  = "eDP-1",
            ["7"]  = "eDP-1",
            ["8"]  = "eDP-1",
            ["9"]  = "eDP-1",
            ["10"] = "HDMI-A-1",
        },

        default_monitor = "eDP-1",
        xrandr_primary  = "eDP-1",
    },
}

local host = PRESETS[detect_host()]

if not host then
    host = PRESETS.pc
end

host.preset = detect_host()

return host