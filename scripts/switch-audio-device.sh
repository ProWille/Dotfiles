#!/usr/bin/env bash
# switch-audio-device.sh [sink|source]
#
# Cycle WirePlumber's default audio device: "sink" (speakers/headphones/HDMI out,
# the default) or "source" (mics). Wraps around after the last device.
#
# `wpctl set-default` is the whole trick: EasyEffects owns the apps (they stream
# into easyeffects_sink) but its filter chain always ends at the *default*
# hardware sink, so the chain re-links itself when the default moves. Apps that
# bypass EasyEffects follow the default sink directly. Input works the same way
# through easyeffects_source.
#
# Device lists come from `wpctl status`, whose "Filters" section also holds
# easyeffects_sink/easyeffects_source -- those are virtual nodes, not devices you
# can pick, so the Sinks/Sources sections are read and nothing else.
set -uo pipefail

KIND="${1:-sink}"

case "$KIND" in
  sink)   SECTION="Sinks:"   ; AFTERS="Sources:" ;;
  source) SECTION="Sources:" ; AFTERS="Filters:"  ;;
  *)
    echo "switch-audio-device.sh: unknown kind '$KIND' (want: sink or source)" >&2
    echo "usage: switch-audio-device.sh [sink|source]" >&2
    exit 2
    ;;
esac

command -v wpctl >/dev/null 2>&1 || { echo "switch-audio-device.sh: wpctl not found" >&2; exit 1; }

status="$(wpctl status)" || exit 1

# Rows look like: ' │  *  125. CORSAIR HS80 ... Analog Stereo [vol: 0.60]'
# The leading '*' marks the current default; strip the trailing volume, which is
# noise in a notification and changes between runs.
ids=() ; names=() ; current=-1
while IFS= read -r row; do
  [[ "$row" =~ ([*]?)[[:space:]]*([0-9]+)\.[[:space:]]+(.*)$ ]] || continue
  ids+=("${BASH_REMATCH[2]}")
  names+=("${BASH_REMATCH[3]% \[vol:*}")
  [[ -n "${BASH_REMATCH[1]}" ]] && current=$(( ${#ids[@]} - 1 ))
done < <(printf '%s\n' "$status" | sed -n "/$SECTION/,/$AFTERS/p" | grep -E '^[^0-9]*[0-9]+\. ')

case "${#ids[@]}" in
  0) echo "switch-audio-device.sh: no ${KIND}s listed by wpctl" >&2 ; exit 1 ;;
  1)
    # Nothing to switch to; say so rather than silently doing nothing.
    noctalia msg notification-show "Audio ${KIND}" "Only one ${KIND} available" >/dev/null 2>&1
    exit 0
    ;;
esac

# current=-1 (default not in the list) starts at the first entry.
next=$(( (current + 1) % ${#ids[@]} ))

wpctl set-default "${ids[$next]}" || exit 1

noctalia msg notification-show "Audio ${KIND}" "${names[$next]}" >/dev/null 2>&1
exit 0
