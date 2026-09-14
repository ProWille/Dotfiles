--------------------------------
---- HOST-SPECIFIC PRESETS ----
--------------------------------
-- Resolves which monitor/workspace layout applies to this machine.
--
-- Detection order:
--   1. ~/.config/machine   -- if present, its first line names the preset
--   2. /etc/hostname       -- "William-Laptop" -> laptop
--   3. anything else       -- pc (fallback / default)
--
-- Override for new machines:
--   echo pc > ~/.config/machine     # e.g. a desktop
--   echo laptop > ~/.config/machine # e.g. a laptop

local function read_first_line(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local line = f:read("*l")
    f:close()
    return line
end

local function detect_host()
    local marker = read_first_line(os.getenv("HOME") .. "/.config/machine")
    if marker and marker ~= "" then
        return marker
    end

    local hostname = read_first_line("/etc/hostname") or ""
    if hostname:match("^William%-Laptop") then
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

        -- persistent workspaces: 1-5 main, 6 second, 7 third
        workspaces = {
            ["1"] = "DP-3",
            ["2"] = "DP-3",
            ["3"] = "DP-3",
            ["4"] = "DP-3",
            ["5"] = "DP-3",
            ["6"] = "DP-2",
            ["7"] = "HDMI-A-1",
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

        -- persistent workspaces: 1-5 built-in panel, 6 external HDMI
        workspaces = {
            ["1"] = "eDP-1",
            ["2"] = "eDP-1",
            ["3"] = "eDP-1",
            ["4"] = "eDP-1",
            ["5"] = "eDP-1",
            ["6"] = "HDMI-A-1",
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