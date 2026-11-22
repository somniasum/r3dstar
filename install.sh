#!/usr/bin/env bash

# author: somniasum
# description: DedSec Hyprland desktop for Fedora (coding, binary exploitation, gaming)
# version: 0.1
#
# usage: ./install.sh [--no-packages] [--no-copr] [--gaming] [--dev] [--all] [-h]

set -u

# Script configuration
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR
readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
readonly TIMESTAMP
LOG_FILE="/tmp/hyprland_setup_${TIMESTAMP}.log"
readonly LOG_FILE
# Third-party COPRs, tried in order (Fedora does not ship Hyprland itself)
readonly COPRS=("ashbuk/Hyprland-Fedora" "lionheartp/Hyprland")

OPT_PACKAGES=true
OPT_COPR=true
OPT_GAMING=false
OPT_DEV=false
SUDO_PID=""

# Color definitions
declare -A COLORS=(
  [RED]='\033[0;31m'
  [GREEN]='\033[0;32m'
  [BLUE]='\033[0;34m'
  [PURPLE]='\033[0;35m'
  [YELLOW]='\033[1;33m'
  [CYAN]='\033[0;36m'
  [BOLD]='\033[1m'
  [NC]='\033[0m'
)

# Log level configurations
declare -A LOG_LEVELS=(
  [INFO]="${COLORS[BLUE]}[ - ]${COLORS[NC]}"
  [SUCCESS]="${COLORS[GREEN]}[ + ]${COLORS[NC]}"
  [NOTICE]="${COLORS[CYAN]}[ # ]${COLORS[NC]}"
  [ERROR]="${COLORS[RED]}[ ! ]${COLORS[NC]}"
  [WARN]="${COLORS[YELLOW]}[ * ]${COLORS[NC]}"
  [PROMPT]="${COLORS[PURPLE]}[ ? ]${COLORS[NC]}"
)

# Logging functions
log() {
  local level="$1"
  shift
  local message="$*"
  echo -e "${LOG_LEVELS[$level]} $message"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >>"$LOG_FILE"
}

log_error() {
  local message="$*"
  echo -e "${LOG_LEVELS[ERROR]} $message" >&2
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $message" >>"$LOG_FILE"
}

# Progress indicator for operations (command output goes to the log file)
run_with_progress() {
  local message="$1"
  shift
  log INFO "$message"
  "$@" >>"$LOG_FILE" 2>&1
}

# Banner
show_banner() {
  echo -e "${COLORS[PURPLE]}"
  cat <<'EOF'
╔════════════════════════════════════════╗
║                r3dstar                 ║
║                 v.0.1                  ║
╚════════════════════════════════════════╝
EOF
  echo -e "${COLORS[NC]}"
  log NOTICE "Log file: $LOG_FILE"
  echo
}

# Prompt function to handle user input
prompt() {
  local prompt_text="${1:-}"
  local response
  echo -ne "${LOG_LEVELS[PROMPT]} ${prompt_text} [${COLORS[GREEN]}Y${COLORS[NC]}/${COLORS[RED]}n${COLORS[NC]}]: "
  read -r response || response=""
  # exit code for yes or no
  [[ "$response" =~ ^[Yy]$ || -z "$response" ]]
}

usage() {
  cat <<EOF
Usage: ./install.sh [options]

  --no-packages   skip dnf (only copy the config files)
  --no-copr       never enable a COPR (Hyprland must already be installed)
  --gaming        also install gamemode, mangohud and gamescope
  --dev           also install coding and reverse-engineering tools (gdb, radare2, nasm, ...)
  --all           --gaming and --dev together
  -h, --help      show this help
EOF
}

parse_args() {
  while (($#)); do
    case "$1" in
    --no-packages) OPT_PACKAGES=false ;;
    --no-copr) OPT_COPR=false ;;
    --gaming) OPT_GAMING=true ;;
    --dev) OPT_DEV=true ;;
    --all)
      OPT_GAMING=true
      OPT_DEV=true
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
    esac
    shift
  done
}

cleanup() {
  [[ -n "$SUDO_PID" ]] && kill "$SUDO_PID" 2>/dev/null
  return 0
}

# Check prerequisites
check_prerequisites() {
  if [[ $EUID -eq 0 ]]; then
    log_error "Do not run as root. Run as a normal user, the script uses sudo."
    exit 1
  fi

  if [[ ! -r /etc/fedora-release ]] || ! command -v dnf &>/dev/null; then
    log_error "DNF not found. Are you running Fedora?"
    exit 1
  fi

  if [[ ! -f "$REPO_DIR/hypr/hyprland.lua" ]]; then
    log_error "Run this from the repo root (hypr/hyprland.lua not found)."
    exit 1
  fi

  if [[ "$OPT_PACKAGES" == true ]]; then
    if ! sudo -v; then
      log_error "Use sudo."
      exit 1
    fi
    # keep sudo alive during long installs
    (while true; do
      sudo -n true 2>/dev/null
      sleep 50
      kill -0 "$$" 2>/dev/null || exit
    done) &
    SUDO_PID=$!
  fi

  log SUCCESS "Prerequisites checked."
}

# Is Hyprland installable from the repos we have enabled right now?
hyprland_available() {
  [[ -n "$(dnf repoquery --quiet hyprland 2>/dev/null)" ]]
}

# Hyprland: Fedora repos first, third-party COPR only if needed and only with your OK
install_hyprland() {
  if rpm -q hyprland &>/dev/null; then
    log SUCCESS "Hyprland already installed ($(rpm -q hyprland))."
    return 0
  fi

  if ! hyprland_available; then
    if [[ "$OPT_COPR" == false ]]; then
      log_error "Hyprland is not in your enabled repos and --no-copr was given."
      return 1
    fi

    log WARN "Hyprland is not in the Fedora repos. It is available from unofficial COPR repos."
    log WARN "A COPR is built by a third party, you are trusting that maintainer."
    if ! prompt "Enable a Hyprland COPR (${COPRS[*]})?"; then
      log NOTICE "Skipping Hyprland install."
      return 1
    fi

    run_with_progress "Installing dnf COPR support." sudo dnf install -y dnf5-plugins

    local copr found=false
    for copr in "${COPRS[@]}"; do
      if run_with_progress "Enabling COPR $copr." sudo dnf copr enable -y "$copr" && hyprland_available; then
        log SUCCESS "Using COPR $copr."
        found=true
        break
      fi
      log WARN "$copr has no Hyprland build for Fedora $(rpm -E %fedora), disabling it."
      # shellcheck disable=SC2024
      sudo dnf copr disable -y "$copr" >>"$LOG_FILE" 2>&1
    done

    if [[ "$found" == false ]]; then
      log_error "No Hyprland package found for Fedora $(rpm -E %fedora)."
      log_error "Check https://copr.fedorainfracloud.org for a build, then re-run."
      return 1
    fi
  fi

  if run_with_progress "Installing Hyprland." sudo dnf install -y --skip-unavailable hyprland xdg-desktop-portal-hyprland; then
    log SUCCESS "Hyprland installed."
  else
    log_error "Hyprland install failed. Check the log file."
    return 1
  fi
}

# Packages from packages/*.txt (one dnf call)
install_packages() {
  local file="$1" label="$2" line
  local -a pkgs=()

  while IFS= read -r line; do
    line="${line%%#*}"
    line="${line//[[:space:]]/}"
    [[ -n "$line" ]] && pkgs+=("$line")
  done <"$file"

  if run_with_progress "Installing $label packages (${#pkgs[@]})." sudo dnf install -y --skip-unavailable "${pkgs[@]}"; then
    log SUCCESS "$label packages installed."
  else
    log WARN "Some $label packages failed. Check the log file."
  fi
}

# Copy one file, keeping a backup if yours differs
deploy_file() {
  local src="$1" dst="$2" mode="$3"
  if [[ -f "$dst" ]] && ! cmp -s "$src" "$dst"; then
    cp -a "$dst" "${dst}.bak.${TIMESTAMP}"
    log NOTICE "Backed up $dst"
  fi
  install -Dm"$mode" "$src" "$dst"
}

# Like deploy_file, but fills in @HOME@ first (so re-runs do not look like changes)
deploy_template() {
  local src="$1" dst="$2" mode="$3" tmp
  tmp=$(mktemp)
  sed "s|@HOME@|$HOME|g" "$src" >"$tmp"
  deploy_file "$tmp" "$dst" "$mode"
  rm -f "$tmp"
}

deploy_configs() {
  local f
  deploy_file "$REPO_DIR/hypr/hyprland.lua" "$CONFIG_DIR/hypr/hyprland.lua" 644
  for f in "$REPO_DIR"/hypr/scripts/*; do
    deploy_file "$f" "$CONFIG_DIR/hypr/scripts/$(basename "$f")" 755
  done
  deploy_file "$REPO_DIR/waybar/config.jsonc" "$CONFIG_DIR/waybar/config.jsonc" 644
  deploy_file "$REPO_DIR/waybar/style.css" "$CONFIG_DIR/waybar/style.css" 644
  deploy_file "$REPO_DIR/ghostty/config" "$CONFIG_DIR/ghostty/config" 644
  deploy_file "$REPO_DIR/fuzzel/fuzzel.ini" "$CONFIG_DIR/fuzzel/fuzzel.ini" 644
  deploy_file "$REPO_DIR/mako/config" "$CONFIG_DIR/mako/config" 644
  deploy_file "$REPO_DIR/wallpaper.png" "$CONFIG_DIR/wallpaper.png" 644
  deploy_file "$REPO_DIR/fastfetch/dedsec.txt" "$CONFIG_DIR/fastfetch/dedsec.txt" 644
  deploy_template "$REPO_DIR/fastfetch/config.jsonc" "$CONFIG_DIR/fastfetch/config.jsonc" 644
  log SUCCESS "Config files installed to $CONFIG_DIR"
}

# Summary report
show_summary() {
  echo
  echo -e "${COLORS[CYAN]}╔════════════════════════════════════════╗${COLORS[NC]}"
  echo -e "${COLORS[CYAN]}║                SUMM4RY                 ║${COLORS[NC]}"
  echo -e "${COLORS[CYAN]}╚════════════════════════════════════════╝${COLORS[NC]}"
  echo

  log SUCCESS "Setup finished."
  echo
  log NOTICE "Next steps:"
  echo " • Log out and choose ${COLORS[BOLD]}Hyprland${COLORS[NC]} on the login screen"
  echo " • Or from a TTY run: start-hyprland"
  echo " • Wallpaper: cp your image to ~/.config/wallpaper.png (solid black until then)"
  echo " • Errors after login? run: hyprctl configerrors"
  echo " • Terminal is ghostty (not in the Fedora repos, install it separately)"
  echo " • Keys: see README.md (Super+Return terminal, Super+\` scratch terminal, Super+F10 game mode)"
  echo " • New CTF target: ~/.config/hypr/scripts/ctf <name> <ip>  (add the scripts folder to PATH)"
  echo " • Clipboard history stores text you copy. Wipe it with Super+Shift+v after copying secrets"
  echo
  log INFO "Log file saved: $LOG_FILE"
}

# Main execution
main() {
  parse_args "$@"
  show_banner
  check_prerequisites

  if [[ "$OPT_PACKAGES" == true ]]; then
    install_hyprland || log WARN "Continuing without Hyprland, install it later and re-run."
    install_packages "$REPO_DIR/packages/fedora.txt" "desktop"
    if [[ "$OPT_GAMING" == true ]]; then
      install_packages "$REPO_DIR/packages/gaming.txt" "gaming"
    fi
    if [[ "$OPT_DEV" == true ]]; then
      install_packages "$REPO_DIR/packages/dev.txt" "dev"
    fi
  else
    log NOTICE "Skipping packages."
  fi

  deploy_configs
  show_summary
}

trap cleanup EXIT

# Only run when executed, so the functions can be sourced for testing
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
