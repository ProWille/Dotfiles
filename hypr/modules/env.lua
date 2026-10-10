-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Toolkit Backend Variables
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")

-- XDG Specifications
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Qt Variables
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
-- qt6ct, not "kde" and not "hyprqt6engine": the KDE platform theme ships as
-- KDEPlasmaPlatformTheme6.so from plasma-integration, which this setup does
-- not install. hyprqt6engine is an AUR/chaotic-aur build pinned to a specific
-- Qt minor; since Qt 6.12 its loader silently ignores any QPA plugin whose
-- major.minor differs from the runtime ("QPA plugins must match Qt
-- Major.Minor" in QFactoryLoader), so it fell back to Qt's built-in light
-- palette after the 6.12 update. qt6ct-kde is rebuilt with every Qt release
-- and reads the same ~/.config/qt6ct/qt6ct.conf colour scheme.
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-- NVIDIA Specific
--hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
--hl.env("LIBVA_DRIVER_NAME", "nvidia")

-- Cursor Style
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
