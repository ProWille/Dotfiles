-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
hl.on("hyprland.start", function () 
   hl.exec_cmd("hypridle")
   hl.exec_cmd("noctalia")
   hl.exec_cmd("xrandr --output DP-3 --primary")
   hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
   hl.exec_cmd("sleep 3 && openrgb --startminimized --profile Zones.orp")
   hl.exec_cmd("sleep 3 && easyeffects --hide-window --service-mode")
end)
