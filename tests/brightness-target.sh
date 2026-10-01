#!/usr/bin/env bash
# Test for scripts/brightness-target.sh
#
# Real wrapper, real ddcutil, real noctalia. Noctalia's Lua bridge breaks every
# `hyprctl dispatch` on this machine (it rejects unquoted args), so focus cannot
# be moved from a script. The only shim is therefore `hyprctl monitors -j`,
# made to report a chosen output as focused -- the wrapper's one input we cannot
# otherwise control. Everything downstream of that is the real code path.
#
# ddcutil display indexes renumber whenever a panel drops off the I2C bus, so
# connector -> index is resolved fresh each run. Only Hyprland connector NAMES
# are stable, which is what the wrapper keys on.
#
# Asserts the wrapper's actual contract -- right target, exit 0, no error leak.
# It deliberately does NOT assert the size of the step: how a given step value
# maps to VCP 10 is Noctalia's business, not the wrapper's.
#
# MACHINE-SPECIFIC. FALLBACK_NAME and DDC_DEAD below name this machine's
# monitor layout. On other hardware the brightness assertions report SKIP
# rather than a misleading PASS or FAIL; the usage/argument tests still run.
#
# usage: tests/brightness-target.sh [path-to-wrapper]

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${1:-$REPO_ROOT/scripts/brightness-target.sh}"
FALLBACK_NAME="DP-3"
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

IDX_DP2="$(ddc_index DP-2 || true)"
IDX_DP3="$(ddc_index DP-3 || true)"
V_DP3="$( [ -n "$IDX_DP3" ] && read_vcp "$IDX_DP3" )"

restore() {
  [ -n "$V_DP3" ] && [ -n "$IDX_DP3" ] && ddcutil --display "$IDX_DP3" setvcp 10 "$V_DP3" >/dev/null 2>&1
  rm -rf "$SHIM"
  printf '  (restored DP-3 to %s)\n' "${V_DP3:-n/a}"
}
trap restore EXIT

# Park the panel at a known value above the floor. Noctalia's step size varies,
# so a test that runs after another can otherwise start at 0 and "dim" to a
# no-op -- which would make a strict decrease assertion untestable.
prime() {
  [ -n "$IDX_DP3" ] || return 0
  ddcutil --display "$IDX_DP3" setvcp 10 60 >/dev/null 2>&1
  sleep 0.4
  read_vcp "$IDX_DP3"
}

# ddcutil is an unreliable oracle on this panel: a write sometimes fails to land
# inside the read window (observed flapping between 0 and 2 failures across runs
# with the wrapper unchanged). Retry a few times before declaring a routing bug,
# so a transient I2C dropout is not mistaken for a real failure. A pass still
# requires an OBSERVED decrease plus a clean exit.
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
    sleep 0.6; a="$(read_vcp "$IDX_DP3")"
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

echo "  [topology] $FALLBACK_NAME ddc-idx=${IDX_DP3:-UNREACHABLE} vcp=${V_DP3:-n/a} | DP-2 ddc-idx=${IDX_DP2:-unreachable}"
echo

echo "== 1. wrapper exists and is executable"
if [ -x "$SCRIPT" ]; then ok "executable: $SCRIPT"; else bad "missing or not executable: $SCRIPT"; fi

echo
echo "== 2. routes to the focused output when it HAS brightness"
if [ ! -x "$SCRIPT" ]; then bad "skipped - no executable wrapper"
elif [ -z "$IDX_DP3" ]; then bad "skipped - $FALLBACK_NAME unreachable over DDC, cannot assert"
else
  dimmed "focused $FALLBACK_NAME" "$FALLBACK_NAME"
fi

echo
echo "== 3. FALLS BACK to $FALLBACK_NAME when focus is on a DDC-less output ($DDC_DEAD)"
if [ ! -x "$SCRIPT" ]; then bad "skipped - no executable wrapper"
elif [ -z "$IDX_DP3" ]; then bad "skipped - $FALLBACK_NAME unreachable over DDC, cannot assert"
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
