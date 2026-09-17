#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"

DRY_RUN=false
DO_BACKUP=true
NVIDIA_FLAG="auto"
DO_DEPS=true
DO_GITCONFIG=false
DO_ASK=true
# Optional OpenRGB profile automation. Empty (default) keeps OpenRGB
# fully optional: it is not in REQUIRED and no profile is ever forced.
# Set via --openrgb-startup/--openrgb-exit or edit these right here.
OPENRGB_STARTUP_PROFILE=""
OPENRGB_EXIT_PROFILE=""

for arg in "$@"; do
  case "$arg" in
    --dry-run)        DRY_RUN=true ;;
    --no-backup)      DO_BACKUP=false ;;
    --no-nvidia)      NVIDIA_FLAG="off" ;;
    --nvidia)         NVIDIA_FLAG="on" ;;
    --skip-deps)      DO_DEPS=false ;;
    --with-gitconfig) DO_GITCONFIG=true ;;
    --openrgb-startup=*) OPENRGB_STARTUP_PROFILE="${arg#*=}" ;;
    --openrgb-exit=*)    OPENRGB_EXIT_PROFILE="${arg#*=}" ;;
    --yes)            DO_ASK=false ;;
    -h|--help)
      echo "Usage: bash install.sh [flags]"
      echo ""
      echo "  --dry-run         print actions without changing anything"
      echo "  --no-backup       overwrite existing files without backing them up"
      echo "  --no-nvidia       skip NVIDIA env vars even if an NVIDIA GPU is detected"
      echo "  --nvidia          uncomment NVIDIA env vars even on a non-NVIDIA machine"
      echo "  --skip-deps       don't check or install packages"
      echo "  --with-gitconfig  also deploy ~/.gitconfig"
      echo "  --openrgb-startup=NAME  apply OpenRGB profile NAME at session start (optional)"
      echo "  --openrgb-exit=NAME     apply OpenRGB profile NAME on logout/reboot/shutdown (optional)"
      echo "  --yes             skip the first-run confirmation prompt"
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

HAS_NVIDIA=false
if lspci 2>/dev/null | grep -qi nvidia; then
  HAS_NVIDIA=true
fi

case "$NVIDIA_FLAG" in
  on)  DO_NVIDIA=true ;;
  off) DO_NVIDIA=false ;;
  auto)
    if [ "$HAS_NVIDIA" = true ]; then
      DO_NVIDIA=true
    else
      DO_NVIDIA=false
    fi
    ;;
esac
if [ "$DO_NVIDIA" = true ]; then
  echo "    NVIDIA env vars: enabled"
else
  echo "    NVIDIA env vars: skipped"
fi

case "$HOST" in
  laptop)
    N_MAIN="eDP-1"
    N_CB_CX="960.0";  N_CB_CY="470.0"
    N_CD_CX="960.0";  N_CD_CY="600.0"
    N_LB_CX="960.0";  N_LB_CY="898.0";  N_LB_W="720.0"
    ;;
  pc)
    N_MAIN="DP-3"
    N_CB_CX="1280.0"; N_CB_CY="630.0"
    N_CD_CX="1280.0"; N_CD_CY="800.0"
    N_LB_CX="1280.0"; N_LB_CY="1321.0"; N_LB_W="525.0"
    ;;
  *)
    echo "    unknown preset '$HOST' - noctalia config keeps template placeholder"
    ;;
esac

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
            xorg-xrandr playerctl hyprpolkitagent zsh eza fastfetch git)
  if [ "$DO_NVIDIA" = true ]; then
    REQUIRED+=(nvidia-utils)
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

deploy_noctalia() {
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
  if [ -z "${N_MAIN:-}" ]; then
    if [ "$DRY_RUN" = true ]; then
      echo "    [dry-run] deploy template $src -> $dest (unresolved placeholders)"
    else
      cp -a "$src" "$dest"
      echo "    deployed template $src -> $dest (unresolved placeholders)"
    fi
    return
  fi
  if [ "$DRY_RUN" = true ]; then
    echo "    [dry-run] render $src -> $dest (host=$HOST)"
  else
    ORGB_LOGOUT="true"
    if [ -n "$OPENRGB_EXIT_PROFILE" ]; then
      ORGB_LOGOUT="openrgb --nodetect --profile $OPENRGB_EXIT_PROFILE"
    fi
    sed -e "s|@@MAIN@@|$N_MAIN|g" \
        -e "s|@@CB_CX@@|$N_CB_CX|g" \
        -e "s|@@CB_CY@@|$N_CB_CY|g" \
        -e "s|@@CD_CX@@|$N_CD_CX|g" \
        -e "s|@@CD_CY@@|$N_CD_CY|g" \
        -e "s|@@LB_CX@@|$N_LB_CX|g" \
        -e "s|@@LB_CY@@|$N_LB_CY|g" \
        -e "s|@@LB_W@@|$N_LB_W|g" \
        -e "s|@@OPENRGB_LOGOUT@@|$ORGB_LOGOUT|g" \
        "$src" > "$dest"
    echo "    rendered $src -> $dest (host=$HOST)"
  fi
}

deploy_startup() {
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
  ORGB_ARGS=""
  if [ -n "$OPENRGB_STARTUP_PROFILE" ]; then
    ORGB_ARGS="--profile $OPENRGB_STARTUP_PROFILE"
  fi
  if [ "$DRY_RUN" = true ]; then
    echo "    [dry-run] render $src -> $dest"
  else
    sed -e "s|@@ORGB_STARTUP@@|$ORGB_ARGS|g" "$src" > "$dest"
    chmod +x "$dest"
    echo "    rendered $src -> $dest"
  fi
}

echo "==> Deploying configs"

CONFIRM_TARGETS=(
  "$HOME/.config/hypr"
  "$HOME/.config/kitty"
  "$HOME/.config/fastfetch"
  "$HOME/.config/noctalia/config.toml"
  "$HOME/.config/noctalia/lockscreen-bg.png"
  "$HOME/.zshrc"
  "$HOME/.p10k.zsh"
  "$HOME/.local/bin/startup.sh"
)
if [ "$DO_GITCONFIG" = true ]; then
  CONFIRM_TARGETS+=("$HOME/.gitconfig")
fi

EXISTING=()
for t in "${CONFIRM_TARGETS[@]}"; do
  [ -e "$t" ] && EXISTING+=("$t")
done

if [ "$DRY_RUN" = false ] && [ "$DO_ASK" = true ] && [ "${#EXISTING[@]}" -gt 0 ]; then
  echo "    The following will be replaced (and backed up):"
  for t in "${EXISTING[@]}"; do
    echo "      - $t"
  done
  read -rp "    Proceed? [y/N] " ans
  if [[ ! "$ans" =~ ^[Yy]$ ]]; then
    echo "    aborted - nothing was changed"
    exit 1
  fi
fi

deploy_dir  "$REPO_DIR/hypr"                  "$HOME/.config/hypr"

ENV_FILE="$HOME/.config/hypr/modules/env.lua"
if [ "$DO_NVIDIA" = true ] && [ -f "$ENV_FILE" ]; then
  if [ "$DRY_RUN" = true ]; then
    echo "    [dry-run] uncomment NVIDIA env vars in $ENV_FILE"
  else
    sed -i 's/^--hl\.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")/hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")/' "$ENV_FILE"
    sed -i 's/^--hl\.env("LIBVA_DRIVER_NAME", "nvidia")/hl.env("LIBVA_DRIVER_NAME", "nvidia")/' "$ENV_FILE"
    echo "    uncommented NVIDIA env vars in $ENV_FILE"
  fi
fi

deploy_dir  "$REPO_DIR/kitty"                 "$HOME/.config/kitty"
deploy_dir  "$REPO_DIR/fastfetch"             "$HOME/.config/fastfetch"
deploy_noctalia "$REPO_DIR/noctalia/config.toml" "$HOME/.config/noctalia/config.toml"
deploy_file "$REPO_DIR/noctalia/lockscreen-bg.png" "$HOME/.config/noctalia/lockscreen-bg.png"
deploy_file "$REPO_DIR/.zshrc"                "$HOME/.zshrc"
deploy_file "$REPO_DIR/.p10k.zsh"             "$HOME/.p10k.zsh"

for f in "$REPO_DIR"/fonts/*.ttf; do
  [ -f "$f" ] || continue
  deploy_file "$f" "$HOME/.local/share/fonts/$(basename "$f")"
done

deploy_startup "$REPO_DIR/scripts/startup.sh" "$HOME/.local/bin/startup.sh"

if [ "$DO_GITCONFIG" = true ]; then
  deploy_file "$REPO_DIR/.gitconfig" "$HOME/.gitconfig"
fi

echo "==> Shell setup (Oh My Zsh)"
git_clone_if_missing() {
  local url="$1" dir="$2"
  if [ -d "$dir/.git" ]; then
    echo "    present  $dir"
    return
  fi
  if [ -e "$dir" ]; then
    echo "    WARNING incomplete clone at $dir - re-cloning"
    [ "$DRY_RUN" = true ] || rm -rf "$dir"
  fi
  if [ "$DRY_RUN" = true ]; then
    echo "    [dry-run] git clone $url $dir"
  else
    git clone --depth=1 "$url" "$dir"
    echo "    cloned   $dir"
  fi
}
OMZ="$HOME/.oh-my-zsh"
git_clone_if_missing "https://github.com/ohmyzsh/ohmyzsh.git" "$OMZ"
git_clone_if_missing "https://github.com/romkatv/powerlevel10k.git" "$OMZ/custom/themes/powerlevel10k"
git_clone_if_missing "https://github.com/zsh-users/zsh-autosuggestions.git" "$OMZ/custom/plugins/zsh-autosuggestions"
git_clone_if_missing "https://github.com/zsh-users/zsh-syntax-highlighting.git" "$OMZ/custom/plugins/zsh-syntax-highlighting"
git_clone_if_missing "https://github.com/zsh-users/zsh-completions.git" "$OMZ/custom/plugins/zsh-completions"
unset OMZ

echo "==> Post-install"
if [ "$DRY_RUN" = true ]; then
  echo "    [dry-run] fc-cache -f"
else
  fc-cache -f >/dev/null 2>&1 || true
  echo "    font cache refreshed"
fi

echo "==> Done"
echo "    Log out and pick the Hyprland session to start."
if [ "$DO_NVIDIA" = true ]; then
  echo "    NVIDIA: log out and back in for the env vars to take effect."
fi
if [ "$DO_BACKUP" = true ]; then
  echo "    Previous files are available as .bak-$TS if anything looks wrong."
fi
