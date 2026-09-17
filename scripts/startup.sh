#!/usr/bin/env bash
# Session startup extras: OpenRGB profile + EasyEffects pipewire service.
# Launched once by Noctalia's `started` hook (see noctalia/config.toml).
set -euo pipefail

# EasyEffects gates its tray icon on QSystemTrayIcon::isSystemTrayAvailable(),
# which on Wayland needs Noctalia's SNI watcher (org.kde.StatusNotifierWatcher)
# to already be on the session bus. Wait for it so the icon isn't skipped.
while ! busctl --user status org.kde.StatusNotifierWatcher >/dev/null 2>&1; do
  sleep 0.5
done

command -v easyeffects >/dev/null 2>&1 && easyeffects --hide-window --service-mode &

# @@ORGB_STARTUP@@ is rendered by install.sh: "--profile NAME" when
# --openrgb-startup is given, empty otherwise (OpenRGB stays optional).
command -v openrgb >/dev/null 2>&1 && openrgb --startminimized --server @@ORGB_STARTUP@@ &
