#!/usr/bin/env bash
# Test for scripts/brightness-target.sh
#
# Real wrapper, real ddcutil/brightnessctl, real noctalia. Noctalia's Lua bridge
# breaks every `hyprctl dispatch` on this machine (it rejects unquoted args), so
# focus cannot be moved from a script. The only shim is therefore
# `hyprctl monitors -j`, made to report a chosen output as focused -- the
# wrapper's one input we cannot otherwise control. Everything downstream of that
# is the real code path.
#
# Asserts the wrapper's actual contract -- right target, exit 0, no error leak.
# It deliberately does NOT assert the size of the step: how a given step value
# maps to VCP 10 or a backlight percentage is Noctalia's business, not the
# wrapper's.
#
# The fallback target is per host, read from ~/.config/machine (written by
# install.sh; laptop -> eDP-1, pc -> DP-3) -- the same marker the deployed
# wrapper resolves at runtime. The brightness oracle is hardware-dependent:
#
#   pc     DP-3   ddcutil on VCP 10. Display indexes renumber whenever a panel
#                 drops off the I2C bus, so connector -> index is resolved fresh
#                 each run. Only Hyprland connector NAMES are stable.
#   laptop eDP-1  built-in panels expose no DDC/CI (ddcutil: "Laptop displays do
#                 not support DDC/CI"), so the oracle is the sysfs backlight via
#                 brightnessctl (udev/polkit; a bare sysfs write needs root).
#
# DDC_DEAD names this machine's permanently DDC-less output (the TV). On
# hardware where neither oracle can reach the fallback panel the brightness
# assertions report SKIP rather than a misleading PASS or FAIL; the
# usage/argument tests still run.
#
# usage: tests/brightness-target.sh [path-to-wrapper]

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${1:-$REPO_ROOT/scripts/brightness-target.sh}"
case "$(cat "$HOME/.config/machine" 2>/dev/null)" in
  laptop) FALLBACK_NAME="eDP-1" ;;
  *)      FALLBACK_NAME="DP-3" ;;
esac
DDC_DEAD="HDMI-A-1"        # TV, permanently without DDC/CI

pass=0; fail=0; skip=0
ok()    { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
bad()   { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }
skipit(){ printf '  SKIP  %s\n' "$1"; skip=$((skip + 1)); }

read_vcp() {
  ddcutil --display "$1" getvcp 10 2>/dev/null \
    | grep -oE 'current value =[[:space:]]+[0-9]+' | grep -oE '[0-9]+'
}
ddc_index() {
  ddcutil detect 2>/dev/null | awk -v want="card1-$1" '
    /^[[:space:]]*Display [0-9]+/ { idx = $NF }
    /DRM_connector:/             { if ($2 == want) { print idx; found = 1; exit } }
    END                          { if (!found) exit 1 }
  '
}

# --- shim: force a chosen output to report as focused -------------------------
SHIM="$(mktemp -d)"
# The shim shadows the real hyprctl for this run only; always clean it up so a
# test run cannot leave a fake hyprctl behind in /tmp.
trap 'rm -rf "$SHIM"' EXIT
cat > "$SHIM/hyprctl" <<'SHIMEOF'
#!/usr/bin/env bash
if [ "${1:-}" = "monitors" ] && [ "${2:-}" = "-j" ] && [ -n "${FORCE_FOCUSED:-}" ]; then
  /usr/bin/hyprctl monitors -j | python3 -c "
import json, os, sys
want = os.environ['FORCE_FOCUSED']
ms = json.load(sys.stdin)
for m in ms:
    m['focused'] = (m['name'] == want)
print(json.dumps(ms))
"
  exit 0
fi
exec /usr/bin/hyprctl "$@"
SHIMEOF
chmod +x "$SHIM/hyprctl"

# --- oracle: how the fallback panel's brightness is read/written --------------
#   ddc   desktop monitor over DDC/CI (ddcutil, VCP 10)
#   sysfs laptop eDP panel over its sysfs backlight (brightnessctl)
IDX_DP2="$(ddc_index DP-2 || true)"   # pc-only output; unreachable on the laptop
IDX_FB="$(ddc_index "$FALLBACK_NAME" || true)"
ORACLE="none"
BACKLIGHT_DEV=""
case "$FALLBACK_NAME" in
  eDP-1)  # laptop panel: no DDC/CI, backlight under /sys/class/backlight
    BACKLIGHT_DEV="$(ls /sys/class/backlight 2>/dev/null | head -1)"
    [ -n "$BACKLIGHT_DEV" ] && ORACLE="sysfs"
    ;;
  *)      # desktop monitor: DDC/CI over the display's I2C bus
    [ -n "$IDX_FB" ] && ORACLE="ddc"
    ;;
esac

brightness_read() {
  case "$ORACLE" in
    ddc)   read_vcp "$IDX_FB" ;;
    sysfs) cat "/sys/class/backlight/$BACKLIGHT_DEV/brightness" 2>/dev/null ;;
    *)     return 1 ;;
  esac
}
brightness_set() { # <vcp-value | absolute backlight value>
  case "$ORACLE" in
    ddc)   ddcutil --display "$IDX_FB" setvcp 10 "$1" >/dev/null 2>&1 ;;
    sysfs) brightnessctl --quiet --device="$BACKLIGHT_DEV" set "$1" >/dev/null 2>&1 ;;
    *)     return 1 ;;
  esac
}

ORIG_FB="$(brightness_read)"
restore() {
  case "$ORACLE" in
    ddc)   [ -n "$ORIG_FB" ] && ddcutil --display "$IDX_FB" setvcp 10 "$ORIG_FB" >/dev/null 2>&1 ;;
    sysfs) [ -n "$ORIG_FB" ] && brightnessctl --quiet --device="$BACKLIGHT_DEV" set "$ORIG_FB" >/dev/null 2>&1 ;;
  esac
  rm -rf "$SHIM"
  printf '  (restored %s to %s)\n' "$FALLBACK_NAME" "${ORIG_FB:-n/a}"
}
trap restore EXIT

# Park the panel at a known value above the floor. Noctalia's step size varies,
# so a test that runs after another can otherwise start at 0 and "dim" to a
# no-op -- which would make a strict decrease assertion untestable.
prime() {
  case "$ORACLE" in
    ddc)   brightness_set 60 ;;
    sysfs) brightness_set 60% ;;
    *)     return 0 ;;
  esac
  sleep 0.4
  brightness_read
}

# The brightness oracle is not perfectly reliable on either backend: ddcutil
# writes sometimes fail to land inside the read window (observed flapping
# between 0 and 2 failures across runs with the wrapper unchanged), and a sysfs
# backlight can be clamped by hardware. Retry a few times before declaring a
# routing bug, so a transient drop is not mistaken for a real failure. A pass
# still requires an OBSERVED decrease plus a clean exit.
dimmed() { # dimmed <label> <FORCE_FOCUSED or empty>
  local label="$1" force="${2:-}" tries=0 b="" a="" out="" rc=""
  while [ "$tries" -lt 4 ]; do
    tries=$((tries + 1))
    b="$(prime)"
    if [ -n "$force" ]; then
      out="$(FORCE_FOCUSED="$force" PATH="$SHIM:$PATH" "$SCRIPT" down 2>&1)"; rc=$?
    else
      out="$("$SCRIPT" down 2>&1)"; rc=$?
    fi
    sleep 0.6; a="$(brightness_read)"
    if [ "$rc" -eq 0 ] && [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]; then
      ok "$label dimmed: $b -> $a (attempt $tries)"
      case "$out" in
        *error*) bad "error text leaked: $out" ;;
        *)       ok "no error text leaked (got: ${out:-<empty>})" ;;
      esac
      return 0
    fi
    sleep 0.3
  done
  bad "$label never dimmed after $tries attempts (last read: ${a:-n/a}, exit $rc, out: ${out:-<empty>})"
  return 1
}

echo "  [topology] $FALLBACK_NAME oracle=$ORACLE ddc-idx=${IDX_FB:-unreachable} backlight=${BACKLIGHT_DEV:-none} | DP-2 ddc-idx=${IDX_DP2:-unreachable}"
echo

echo "== 1. wrapper exists and is executable"
if [ -x "$SCRIPT" ]; then ok "executable: $SCRIPT"; else bad "missing or not executable: $SCRIPT"; fi

echo
echo "== 2. routes to the focused output when it HAS brightness"
if [ ! -x "$SCRIPT" ]; then bad "skipped - no executable wrapper"
elif [ "$ORACLE" = "none" ]; then bad "skipped - no reachable brightness oracle for $FALLBACK_NAME"
else
  dimmed "focused $FALLBACK_NAME" "$FALLBACK_NAME"
fi

echo
echo "== 3. FALLS BACK to $FALLBACK_NAME when focus is on a DDC-less output ($DDC_DEAD)"
if [ ! -x "$SCRIPT" ]; then bad "skipped - no executable wrapper"
elif [ "$ORACLE" = "none" ]; then bad "skipped - no reachable brightness oracle for $FALLBACK_NAME"
else
  dimmed "fallback $FALLBACK_NAME (focus forced to $DDC_DEAD)" "$DDC_DEAD"
fi

echo
echo "== 4. rejects a missing action argument"
if [ ! -x "$SCRIPT" ]; then bad "skipped - no executable wrapper"
else
  out="$("$SCRIPT" 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] && ok "non-zero exit ($rc)" || bad "exit 0 (expected non-zero)"
  case "$out" in *usage*) ok "prints usage" ;; *) bad "no usage message: $out" ;; esac
fi

echo
echo "== 5. rejects an unknown action"
if [ ! -x "$SCRIPT" ]; then bad "skipped - no executable wrapper"
else
  out="$("$SCRIPT" sideways 2>&1)"; rc=$?
  case "$out" in
    *"unknown action"*) ok "rejected locally with a clear message" ;;
    *) bad "no local rejection: $out" ;;
  esac
  case "$out" in
    *usage*) ok "prints usage" ;;
    *) bad "no usage message: $out" ;;
  esac
  case "$out" in
    *"unknown command"*) bad "bogus action was forwarded to noctalia: $out" ;;
    *) ok "bogus action never reached noctalia" ;;
  esac
  [ "$rc" -eq 2 ] && ok "exit 2 for invalid usage" || bad "exit $rc (expected 2)"
fi

printf '\n== %d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ]
