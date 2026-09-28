#!/usr/bin/env bash
# brightness-target.sh <up|down>
#
# Set monitor brightness on whichever output is currently focused, falling back
# to the main monitor when that output has no brightness control -- e.g. the TV
# on HDMI-A-1 has DDC/CI disabled, which makes a bare "noctalia msg brightness-up"
# fail with "current output has no brightness control".
#
# No step argument: noctalia's brightness-[up|down] ignores it (step=1 drops a
# panel at 70 down to 5) and always applies its own coarse step. Passing one
# through would be a knob that silently does nothing. Tune granularity in
# Noctalia's own settings instead.
set -uo pipefail

# Main monitor. Rename this if the connector is ever renumbered.
FALLBACK="DP-3"

ACTION="${1:?usage: brightness-target.sh <up|down>}"

case "$ACTION" in
  up | down) ;;
  *)
    echo "brightness-target.sh: unknown action '$ACTION' (want: up or down)" >&2
    echo "usage: brightness-target.sh <up|down>" >&2
    exit 2
    ;;
esac

focused="$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')"

# Output is fully suppressed: when the focused output is the TV this attempt is
# EXPECTED to fail, and noctalia reports that on stdout, not stderr -- so stderr
# redirection alone would still flash an error on every keypress. The fallback
# call below keeps its output, so a genuine failure there is still visible.
if [ -n "$focused" ] && noctalia msg "brightness-$ACTION" "$focused" >/dev/null 2>&1; then
  exit 0
fi

exec noctalia msg "brightness-$ACTION" "$FALLBACK"
