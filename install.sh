#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"

DRY_RUN=false
DO_BACKUP=true
DO_OPENRGB=true
DO_DEPS=true
DO_GITCONFIG=false

for arg in "$@"; do
  case "$arg" in
    --dry-run)        DRY_RUN=true ;;
    --no-backup)      DO_BACKUP=false ;;
    --no-openrgb)     DO_OPENRGB=false ;;
    --skip-deps)      DO_DEPS=false ;;
    --with-gitconfig) DO_GITCONFIG=true ;;
    -h|--help)
      echo "Usage: bash install.sh [flags]"
      echo ""
      echo "  --dry-run         print actions without changing anything"
      echo "  --no-backup       overwrite existing files without backing them up"
      echo "  --no-openrgb      skip the PC-only OpenRGB systemd units"
      echo "  --skip-deps       don't check or install packages"
      echo "  --with-gitconfig  also deploy ~/.gitconfig"
      exit 0
      ;;
    *)
      echo "Unknown flag: $arg" >&2
      exit 1
      ;;
  esac
done

echo "==> Detected displays"
count=0
for p in /sys/class/drm/card*-*/status; do
  [ -f "$p" ] || continue
  conn="$(basename "$(dirname "$p")")"
  state="$(cat "$p" 2>/dev/null)"
  echo "    $conn: $state"
  count=$((count + 1))
done
if [ "$count" -eq 0 ]; then
  echo "    (none found - assuming desktop/pc)"
fi

echo "==> Host detection"
HOST="pc"
if ls /sys/class/drm/ 2>/dev/null | grep -qE 'eDP-|LVDS-'; then
  HOST="laptop"
fi
echo "    this machine is a $HOST"

MARKER="$HOME/.config/machine"
if [ "$DRY_RUN" = true ]; then
  echo "    [dry-run] would write '$HOST' to $MARKER"
else
  mkdir -p "$(dirname "$MARKER")"
  echo "$HOST" > "$MARKER"
  echo "    wrote '$HOST' to $MARKER"
fi

if [ "$DO_DEPS" = true ]; then
  echo "==> Dependencies"
  REQUIRED=(hyprland noctalia kitty hyprlauncher dolphin firefox easyeffects
            xorg-xrandr playerctl bibata-cursor-theme hyprpolkitagent)
  if [ "$DO_OPENRGB" = true ]; then
    REQUIRED+=(openrgb)
  fi
  MISSING=()
  for pkg in "${REQUIRED[@]}"; do
    if ! pacman -Q "$pkg" >/dev/null 2>&1; then
      MISSING+=("$pkg")
    fi
  done
  if [ "${#MISSING[@]}" -eq 0 ]; then
    echo "    all required packages are already installed"
  else
    echo "    missing: ${MISSING[*]}"
    if [ "$DRY_RUN" = true ]; then
      echo "    [dry-run] would install them"
    else
      read -rp "    install them now? [y/N] " ans
      if [[ "$ans" =~ ^[Yy]$ ]]; then
        helper=""
        for h in paru yay; do
          if command -v "$h" >/dev/null 2>&1; then
            helper="$h"
            break
          fi
        done
        if [ -n "$helper" ]; then
          "$helper" -S --needed "${MISSING[@]}"
        else
          sudo pacman -S --needed "${MISSING[@]}"
        fi
      else
        echo "    skipping - install them manually before using these dotfiles"
      fi
    fi
  fi
fi

deploy_dir() {
  local src="$1" dest="$2"
  if [ ! -d "$src" ]; then
    echo "    skip  $dest (no $src in repo)"
    return
  fi
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ]; then
    if [ "$DO_BACKUP" = true ]; then
      if [ "$DRY_RUN" = true ]; then
        echo "    [dry-run] backup $dest -> $dest.bak-$TS"
      else
        mv "$dest" "$dest.bak-$TS"
        echo "    backed up $dest -> $dest.bak-$TS"
      fi
    else
      rm -rf "$dest"
    fi
  fi
  if [ "$DRY_RUN" = true ]; then
    echo "    [dry-run] deploy $src -> $dest"
  else
    mkdir -p "$dest"
    cp -a "$src/." "$dest/"
    echo "    deployed $src -> $dest"
  fi
}

deploy_file() {
  local src="$1" dest="$2"
  if [ ! -e "$src" ]; then
    echo "    skip  $dest (no $src in repo)"
    return
  fi
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ]; then
    if [ "$DO_BACKUP" = true ]; then
      if [ "$DRY_RUN" = true ]; then
        echo "    [dry-run] backup $dest -> $dest.bak-$TS"
      else
        mv "$dest" "$dest.bak-$TS"
        echo "    backed up $dest -> $dest.bak-$TS"
      fi
    else
      rm -rf "$dest"
    fi
  fi
  if [ "$DRY_RUN" = true ]; then
    echo "    [dry-run] deploy $src -> $dest"
  else
    cp -a "$src" "$dest"
    echo "    deployed $src -> $dest"
  fi
}

echo "==> Deploying configs"
deploy_dir  "$REPO_DIR/hypr"                  "$HOME/.config/hypr"
deploy_dir  "$REPO_DIR/kitty"                 "$HOME/.config/kitty"
deploy_dir  "$REPO_DIR/fastfetch"             "$HOME/.config/fastfetch"
deploy_file "$REPO_DIR/noctalia/config.toml" "$HOME/.config/noctalia/config.toml"
deploy_file "$REPO_DIR/noctalia/lockscreen-bg.png" "$HOME/.config/noctalia/lockscreen-bg.png"
deploy_file "$REPO_DIR/.zshrc"                "$HOME/.zshrc"
deploy_file "$REPO_DIR/.p10k.zsh"             "$HOME/.p10k.zsh"

for f in "$REPO_DIR"/fonts/*.ttf; do
  [ -f "$f" ] || continue
  deploy_file "$f" "$HOME/.local/share/fonts/$(basename "$f")"
done

if [ "$DO_GITCONFIG" = true ]; then
  deploy_file "$REPO_DIR/.gitconfig" "$HOME/.gitconfig"
fi

DEPLOYED_SYSTEMD=false
if [ "$DO_OPENRGB" = true ]; then
  for unit in openrgb.service openrgb-quit.service; do
    if [ -f "$REPO_DIR/systemd/user/$unit" ]; then
      deploy_file "$REPO_DIR/systemd/user/$unit" "$HOME/.config/systemd/user/$unit"
      DEPLOYED_SYSTEMD=true
    fi
  done
fi

echo "==> Post-install"
if [ "$DEPLOYED_SYSTEMD" = true ]; then
  if [ "$DRY_RUN" = true ]; then
    echo "    [dry-run] systemctl --user daemon-reload"
  else
    systemctl --user daemon-reload
    echo "    systemctl --user daemon-reload"
  fi
fi
if [ "$DRY_RUN" = true ]; then
  echo "    [dry-run] fc-cache -f"
else
  fc-cache -f >/dev/null 2>&1 || true
  echo "    font cache refreshed"
fi

echo "==> Done"
echo "    Log out and pick the Hyprland session to start."
if [ "$HOST" = "pc" ]; then
  echo "    PC-only: systemctl --user enable openrgb.service openrgb-quit.service"
fi
if [ "$DO_BACKUP" = true ]; then
  echo "    Previous files are available as .bak-$TS if anything looks wrong."
fi
