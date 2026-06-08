#!/bin/sh
# Mac Setup Script — corporate / managed-device variant.
#
# This is a strict subset of setup.sh, designed for a macOS device under
# corporate MDM. It does NOT touch FileVault, the application firewall, the
# login window, /Applications stock apps, or install kernel-extension-backed
# security tools (Lulu, BlockBlock) or a DNS proxy (NextDNS) — all of which
# either require sudo, are MDM-managed, or will conflict with org-deployed
# equivalents.
#
# Apps that are commonly MDM-pushed in corporate environments (Slack,
# Bitwarden, VS Code, Docker Desktop, Firefox, Alfred, etc.) are gated behind
# the CONFIG block below, defaulting to off. Edit the flags once per employer
# before the first run.
#
# Re-running this script should never prompt for sudo. The only auth prompt
# possible is the GUI dialog from xcode-select --install (gated by
# INSTALL_XCODE_TOOLS).

# Ensure we run with bash - compatible with sh
if [ -z "${BASH_VERSION:-}" ]; then
    if command -v bash >/dev/null 2>&1; then
        exec bash "$0" "$@"
    else
        echo "Error: This script requires bash"
        exit 1
    fi
fi

# From here on, we're guaranteed to be in bash
# Enable strict mode for safety
set -euo pipefail

# ============================================================
# CONFIG — edit before first run.
# Set to true only after confirming your org allows the item.
# Anything left false is silently skipped with a [skipped] log line.
# ============================================================
INSTALL_XCODE_TOOLS=true        # usually fine even on managed; flip if blocked
INSTALL_ITERM2=false            # org may standardize on Terminal.app
INSTALL_SNOWFLAKE_CLI=false     # only if you actually use Snowflake at work
INSTALL_RUST=false              # uses curl|sh; some orgs block that pattern
INSTALL_BITWARDEN_CLI=false     # often MDM-pushed; check org password manager
INSTALL_CLAUDE_CODE=false       # uses curl|sh
INSTALL_VSCODE=false            # very commonly MDM-pushed
INSTALL_DOCKER_DESKTOP=false    # licensing + hypervisor conflicts
INSTALL_FIREFOX=false           # org may standardize on Chrome/Safari
INSTALL_BASICTEX=false
INSTALL_ALFRED=false            # needs Accessibility perm; may be denied
INSTALL_SLACK=false             # almost always MDM-pushed
INSTALL_BITWARDEN_GUI=false     # see CLI note above
INSTALL_OBSIDIAN=false          # check data-classification policy
INSTALL_WHATSAPP=false
# ============================================================

# Log the start of the script execution
LOGFILE="$HOME/mac_corporate_setup_$(date +'%Y%m%d_%H%M%S').log"

# Simple logging that works everywhere
{

echo "[$(date)] Starting Mac corporate setup..."

# Root vs. user-level install policy:
#   - This script intentionally does NOT use sudo. Every step here is
#     user-scope: Homebrew installs into the user-owned prefix, all
#     `defaults write` targets user domains, all dotfile edits are under
#     $HOME, and all git clones are into user-owned directories.
#   - If you need any of the system-level operations from setup.sh
#     (FileVault, firewall, /Applications stock-app removal, system-wide
#     defaults), run those manually after confirming your org allows them.

# Function to check the system processor
detect_architecture() {
  ARCH=$(uname -m)
  if [[ "$ARCH" == "arm64" ]]; then
      echo "[$(date)] M1/M2/M3 Processor detected. Proceeding with compatible installations."
  else
      echo "[$(date)] Intel Processor detected. Proceeding with installations."
  fi
}

detect_architecture

# Retry logic for network-related commands
retry() {
  local n=0
  local try=5
  until [ $n -ge $try ]; do
    "$@" && return 0
    n=$((n+1))
    echo "Retry $n/$try failed for: $*"
    sleep 5
  done
  echo "Command failed after $try attempts: $*"
  return 1
}

# Idempotent cask installer — skips if already installed so re-runs don't abort.
brew_cask_install() {
  if brew list --cask "$1" &>/dev/null; then
    echo "[$(date)] $1 already installed, skipping."
  else
    brew install --cask --appdir="/Applications" "$1"
  fi
}

# Backup a file with a timestamped suffix before overwriting it.
backup_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
      local backup_suffix
      backup_suffix="$(date +'%Y%m%d_%H%M%S')"
      cp "$file" "${file}.bak_${backup_suffix}"
      echo "[$(date)] Backed up $file to ${file}.bak_${backup_suffix}"
  fi
}

# Helper: log a uniform "skipped because flag is off" message for gated installs.
log_skipped() {
  echo "[$(date)] [skipped: $1 is false] $2"
}

# Xcode Command Line Tools — provides git, make, headers. Required by Homebrew
# and any source-build path. xcode-select --install pops a GUI dialog (no sudo
# on the command line); on a managed device this is usually allowed but org
# policy may have it pre-installed or blocked entirely.
install_xcode_tools() {
  if [ "$INSTALL_XCODE_TOOLS" != "true" ]; then
    log_skipped "INSTALL_XCODE_TOOLS" "Xcode Command Line Tools"
    return
  fi
  echo "[$(date)] Checking for Xcode Command Line Tools..."
  if ! xcode-select -p >/dev/null 2>&1; then
    echo "[$(date)] Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "[$(date)] Waiting for Xcode Command Line Tools installation..."
    until xcode-select -p >/dev/null 2>&1; do
      sleep 5
    done
    echo "[$(date)] Xcode Command Line Tools installed."
  else
    echo "[$(date)] Xcode Command Line Tools already installed."
  fi
}

install_xcode_tools

# Homebrew. On a managed device brew may already be present (org-pushed or
# user-installed previously); we only install if missing. We also log the
# detected prefix so an unexpected location (e.g. /usr/local on Apple Silicon
# or an MDM-managed prefix) is visible in the run log.
install_homebrew() {
  echo "[$(date)] Checking for Homebrew..."
  if ! command -v brew >/dev/null 2>&1; then
      echo "[$(date)] Installing Homebrew..."
      NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

      # Add Homebrew to PATH (guard against duplicate entries on re-run)
      echo "[$(date)] Adding Homebrew to PATH..."
      if ! grep -q '/opt/homebrew/bin/brew shellenv' ~/.zprofile 2>/dev/null; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
      fi
      eval "$(/opt/homebrew/bin/brew shellenv)"
  else
      echo "[$(date)] Homebrew already installed at: $(command -v brew)"
      local detected_prefix
      detected_prefix="$(brew --prefix)"
      if [ "$detected_prefix" != "/opt/homebrew" ] && [ "$detected_prefix" != "/usr/local" ]; then
        echo "[$(date)] NOTE: Homebrew prefix is $detected_prefix — may be org-managed. Skipping prefix changes."
      fi
  fi
}

install_homebrew

# Update and Upgrade Homebrew: Ensure Homebrew is up-to-date.
update_homebrew() {
  echo "[$(date)] Updating and Upgrading Homebrew..."
  brew update
  brew upgrade
}

update_homebrew

# Install coreutils for gdate and bc for calculations.
install_prerequisites() {
  echo "[$(date)] Installing prerequisites..."
  brew install coreutils bc
}

install_prerequisites

# Install useful command-line tools. snowflake-cli is gated since it's
# situational (you only want it if your employer uses Snowflake).
install_cli_tools() {
  echo "[$(date)] Installing command-line tools..."

  echo "[$(date)] Installing z (smart directory jumping)..."
  brew install z

  echo "[$(date)] Installing bat (better cat with syntax highlighting)..."
  brew install bat

  echo "[$(date)] Installing additional CLI tools..."
  brew install tree     # Display directory structure
  brew install tldr     # Simplified man pages
  brew install jq       # JSON processor
  brew install ripgrep  # Fast grep alternative
  brew install fd       # Fast find alternative
  brew install htop     # Better top
  brew install grep     # GNU grep (replaces BSD grep)
  brew install uv       # Fast Python package manager
  brew install shellcheck     # Shell script static analysis

  if [ "$INSTALL_SNOWFLAKE_CLI" = "true" ]; then
    echo "[$(date)] Installing snowflake-cli..."
    brew install snowflake-cli
  else
    log_skipped "INSTALL_SNOWFLAKE_CLI" "snowflake-cli"
  fi
}

install_cli_tools

# Finder Configuration: Set up Finder preferences like showing hidden files.
# All user-scope defaults — safe on managed devices (org may overwrite via MDM
# but our writes won't fail).
configure_finder() {
  echo "[$(date)] Configuring Finder settings..."
  chflags nohidden ~/Library
  defaults write com.apple.finder AppleShowAllFiles YES
  defaults write com.apple.finder ShowPathbar -bool true
  defaults write com.apple.finder ShowStatusBar -bool true
  defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
  osascript -e 'tell application "Finder" to quit'
  osascript -e 'tell application "Finder" to launch'
}

configure_finder

# User-scope security preferences only. The setup.sh equivalent
# (configure_security) also enables FileVault, the application firewall,
# disables auto-login, and writes a system-wide automatic-updates default —
# all of which require sudo and are MDM-managed on a corporate device. Those
# are deliberately omitted here.
configure_user_security() {
  echo "[$(date)] Configuring user-scope security preferences..."

  # Screensaver — require password immediately on wake/lock.
  defaults write com.apple.screensaver askForPassword -int 1
  defaults write com.apple.screensaver askForPasswordDelay -int 0

  # Automatic updates (user-scope only — the system-wide version requires sudo).
  defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
  defaults write com.apple.SoftwareUpdate AutomaticDownload -bool true
  defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -bool true

  # AirDrop — restrict discoverability to contacts only (default is "Everyone").
  defaults write com.apple.sharingd DiscoverableMode -string "Contacts Only"
  killall sharingd 2>/dev/null || true

  echo "[$(date)] User-scope security preferences configured."
}

configure_user_security

# Terminal and Shell Setup: iTerm2 (gated) and Oh My Zsh + plugins + .zshrc.
# The Oh My Zsh + zsh plugins + .zshrc rewrite all run unconditionally — they
# are user-scope and idempotent. NOTE: if your org centrally pushes .zshrc via
# MDM/config-management, our rewrite will be overwritten on the next sync.
# backup_file preserves the prior version so you can recover the org content.
install_terminal_tools() {
  if [ "$INSTALL_ITERM2" = "true" ]; then
    echo "[$(date)] Installing iTerm2..."
    # A corporate/MDM-pushed iTerm.app is not Homebrew-managed, so brew_cask_install
    # would fall through to `brew install --cask` and abort on the existing app.
    # Skip the install when the app is already present; preferences below still apply.
    if [ -d "/Applications/iTerm.app" ]; then
      echo "[$(date)] iTerm2 already present (corporate/MDM or manual), skipping install."
    else
      brew_cask_install iterm2
    fi

    # iTerm2 preferences: Natural Text Editing keymap + profile/app-level
    # behavior tuning. Font is intentionally left untouched (user's manual
    # choice survives). On a corporate device, org MDM configuration profiles
    # for com.googlecode.iterm2 will override anything we set here.
    echo "[$(date)] Configuring iTerm2 preferences..."
    local iterm_plist="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
    # iTerm2 rewrites its plist on quit; preemptively quit so writes survive.
    osascript -e 'tell application "iTerm" to quit' 2>/dev/null || true
    sleep 1
    if [ ! -f "$iterm_plist" ]; then
      open -a iTerm && sleep 3 && osascript -e 'tell application "iTerm" to quit'
      sleep 1
    fi
    local pb="/usr/libexec/PlistBuddy"
    local km=":New Bookmarks:0:Keyboard Map"
    _iterm_key() {
      local key="$1" action="$2" text="$3"
      $pb -c "Add '$km:$key' dict" "$iterm_plist" 2>/dev/null || true
      $pb -c "Delete '$km:$key:Action'" "$iterm_plist" 2>/dev/null || true
      $pb -c "Add    '$km:$key:Action' integer $action" "$iterm_plist"
      $pb -c "Delete '$km:$key:Text'" "$iterm_plist" 2>/dev/null || true
      $pb -c "Add    '$km:$key:Text' string '$text'" "$iterm_plist"
    }
    _iterm_profile_set() {
      local key="$1" type="$2" value="$3"
      $pb -c "Set ':New Bookmarks:0:$key' $value" "$iterm_plist" 2>/dev/null \
        || $pb -c "Add ':New Bookmarks:0:$key' $type $value" "$iterm_plist"
    }
    # Natural Text Editing keymap.
    _iterm_key "0xf702-0x280000" 10 "b"         # Option+Left  → word backward
    _iterm_key "0xf703-0x280000" 10 "f"         # Option+Right → word forward
    _iterm_key "0xf702-0x300000" 11 "0x1"       # Cmd+Left    → beginning of line
    _iterm_key "0xf703-0x300000" 11 "0x5"       # Cmd+Right   → end of line
    _iterm_key "0x7f-0x80000"    11 "0x1b 0x7f" # Option+Bksp  → delete word backward
    _iterm_key "0x7f-0x100000"   11 "0x15"      # Cmd+Bksp     → delete line backward
    _iterm_key "0xf728-0x80000"  10 "d"         # Option+Del   → delete word forward
    _iterm_key "0xf728-0x0"      11 "0x4"       # Del          → delete char forward
    # Default profile preferences.
    _iterm_profile_set "Custom Directory" string  Recycle    # new tab/split reuses prior cwd
    _iterm_profile_set "Scrollback Lines" integer 10000      # bump from stock 1000
    _iterm_profile_set "Visual Bell"      bool    true
    _iterm_profile_set "Flashing Bell"    bool    true
    # App-level preferences.
    defaults write com.googlecode.iterm2 ShowFullScreenTabBar -bool true
    defaults write com.googlecode.iterm2 AppleWindowTabbingMode -string manual
    defaults write com.googlecode.iterm2 NoSyncIgnoreSystemWindowRestoration -bool true
    defaults write com.googlecode.iterm2 NoSyncWindowRestoresWorkspaceAtLaunch -bool false
    defaults write com.googlecode.iterm2 SoundForEsc -bool false
    defaults write com.googlecode.iterm2 VisualIndicatorForEsc -bool false
    defaults write com.googlecode.iterm2 HapticFeedbackForEsc -bool false
    defaults write com.googlecode.iterm2 SUSendProfileInfo -bool false
    killall cfprefsd 2>/dev/null || true
    echo "[$(date)] iTerm2 preferences configured."
  else
    log_skipped "INSTALL_ITERM2" "iTerm2 + keymap + preferences"
  fi

  echo "[$(date)] Installing oh-my-zsh..."
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
    echo "[$(date)] Oh My Zsh already installed."
  fi

  echo "[$(date)] Installing zsh plugins..."
  ZSH_CUSTOM=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}

  if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
  else
    echo "[$(date)] zsh-autosuggestions already installed."
  fi

  if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
  else
    echo "[$(date)] zsh-syntax-highlighting already installed."
  fi

  echo "[$(date)] Configuring .zshrc..."
  if [ -f "$HOME/.zshrc" ]; then
    backup_file ~/.zshrc
  fi

  cat > ~/.zshrc << 'ZSHRC_CONFIG'
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Starship prompt — cross-shell, fast, and actively maintained.
# Customize via ~/.config/starship.toml — see https://starship.rs/config/
ZSH_THEME="robbyrussell"

# Disable compfix warning for insecure directories
ZSH_DISABLE_COMPFIX="true"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
plugins=(
  git
  brew
  macos
  z
  zsh-autosuggestions
  zsh-syntax-highlighting
  colored-man-pages
  command-not-found
)

# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh

# User configuration

# Custom functions for execution time tracking
preexec() {
  timer=$(gdate +%s.%N 2>/dev/null || date +%s)
}

precmd() {
  if [ -n "$timer" ]; then
    now=$(gdate +%s.%N 2>/dev/null || date +%s)
    if command -v bc >/dev/null 2>&1 && command -v gdate >/dev/null 2>&1; then
      elapsed=$(echo "$now - $timer" | bc)
      timer_show=$(printf "%.2f" $elapsed)
      echo "Execution time: ${timer_show}s"
    fi
    unset timer
  fi
}

# Aliases
alias ll="ls -la"
alias la="ls -A"
alias l="ls -CF"
alias cat="bat"           # Use bat instead of cat
alias ocat="/bin/cat"     # Original cat if needed

# Set PATH for Homebrew
export PATH="/opt/homebrew/bin:$PATH"

# Go
export PATH="/usr/local/go/bin:$PATH"

# Rust/Cargo
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

# Initialize z for smart directory jumping
if command -v brew >/dev/null 2>&1; then
  # Load z installed via Homebrew
  if [ -f "$(brew --prefix)/etc/profile.d/z.sh" ]; then
    source "$(brew --prefix)/etc/profile.d/z.sh"
  fi
fi

# pyenv — Python version manager
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi

# Starship prompt (must be the last line in .zshrc)
eval "$(starship init zsh)"
ZSHRC_CONFIG

  echo "[$(date)] .zshrc configuration complete."
}

install_terminal_tools

# Starship prompt + Meslo Nerd Font.
# The .zshrc above ends with `eval "$(starship init zsh)"`, so starship must
# be on PATH before that file is sourced. Activating the Nerd Font in
# iTerm2/Terminal.app is manual (see corporate-manual-setup.md).
install_prompt_and_font() {
  echo "[$(date)] Installing Starship prompt..."
  brew install starship

  echo "[$(date)] Installing Meslo Nerd Font..."
  brew_cask_install font-meslo-lg-nerd-font
}

install_prompt_and_font

# Python version management via pyenv. pyenv itself is installed in
# install_dev_tools(); this function is a placeholder for a logged status
# check, mirroring setup.sh.
install_python() {
  echo "[$(date)] Configuring pyenv..."
  if ! command -v pyenv >/dev/null 2>&1; then
    echo "[$(date)] pyenv not found — it will be installed in install_dev_tools()."
  else
    echo "[$(date)] pyenv already installed: $(pyenv --version)"
  fi
}

install_python

# Developer tools.
#
# Unconditional installs (user-scope, low corporate-conflict risk):
#   pyenv  — manages Python versions
#   tfenv  — manages Terraform versions
#   go     — official Homebrew formula
#   gh     — GitHub CLI
#   glab   — GitLab CLI
#   awscli — AWS CLI
#
# Gated installs (set the relevant INSTALL_* flag to true to enable):
#   rust          — uses curl|sh; some orgs block that pattern
#   bitwarden-cli — often MDM-pushed via the org password manager
#   claude-code   — uses curl|sh
#   visual-studio-code — very commonly MDM-pushed
#   docker-desktop     — licensing + hypervisor conflicts
#   firefox            — org may standardize on Chrome/Safari
#   basictex
#
# Tailscale is intentionally omitted — VPN clients are almost always
# MDM-controlled and a second VPN can conflict with the org client.
install_dev_tools() {
  echo "[$(date)] Installing developer tools and additional apps..."

  echo "[$(date)] Installing pyenv..."
  brew install pyenv

  echo "[$(date)] Installing tfenv and latest Terraform..."
  brew install tfenv
  tfenv install latest
  tfenv use latest

  echo "[$(date)] Installing Go..."
  brew install go

  if [ "$INSTALL_RUST" = "true" ]; then
    echo "[$(date)] Installing Rust via rustup..."
    if ! command -v rustup >/dev/null 2>&1; then
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
      # Source cargo env so rust tools are available for the rest of this script
      # shellcheck disable=SC1091
      source "$HOME/.cargo/env"
    else
      echo "[$(date)] Rust already installed: $(rustc --version)"
    fi
  else
    log_skipped "INSTALL_RUST" "rustup / Rust toolchain"
  fi

  echo "[$(date)] Installing CLI tools..."
  brew install gh
  brew install awscli
  brew install glab

  if [ "$INSTALL_BITWARDEN_CLI" = "true" ]; then
    echo "[$(date)] Installing bitwarden-cli..."
    brew install bitwarden-cli
  else
    log_skipped "INSTALL_BITWARDEN_CLI" "bitwarden-cli"
  fi

  if [ "$INSTALL_CLAUDE_CODE" = "true" ]; then
    echo "[$(date)] Installing Claude Code..."
    if ! command -v claude >/dev/null 2>&1; then
      curl -fsSL https://claude.ai/install.sh | sh
    else
      echo "[$(date)] Claude Code already installed: $(claude --version 2>/dev/null)"
    fi
  else
    log_skipped "INSTALL_CLAUDE_CODE" "Claude Code"
  fi

  echo "[$(date)] Installing cask applications..."
  if [ "$INSTALL_VSCODE" = "true" ]; then
    brew_cask_install visual-studio-code
  else
    log_skipped "INSTALL_VSCODE" "Visual Studio Code"
  fi

  if [ "$INSTALL_DOCKER_DESKTOP" = "true" ]; then
    brew_cask_install docker-desktop
  else
    log_skipped "INSTALL_DOCKER_DESKTOP" "Docker Desktop"
  fi

  if [ "$INSTALL_FIREFOX" = "true" ]; then
    brew_cask_install firefox
  else
    log_skipped "INSTALL_FIREFOX" "Firefox"
  fi

  if [ "$INSTALL_BASICTEX" = "true" ]; then
    brew_cask_install basictex
  else
    log_skipped "INSTALL_BASICTEX" "BasicTeX"
  fi

  echo "[$(date)] Developer tools installation complete."
}

install_dev_tools

# Light security tooling. setup.sh's install_security_tools also installs
# Lulu, BlockBlock, Malwarebytes, and NextDNS — all of which conflict with
# corporate EDR / managed firewall / managed DNS or require permissions an
# MDM agent will deny. Suspicious Package is the only piece that's safe on a
# managed device: it's a Quick Look extension with no special permissions.
install_security_tools() {
  echo "[$(date)] Installing Suspicious Package (Quick Look extension)..."
  brew_cask_install suspicious-package
}

install_security_tools

# Core / productivity applications. All gated — these are the apps most
# likely to already be MDM-pushed in a corporate environment.
install_core_apps() {
  echo "[$(date)] Installing core applications..."

  if [ "$INSTALL_ALFRED" = "true" ]; then
    brew_cask_install alfred
  else
    log_skipped "INSTALL_ALFRED" "Alfred"
  fi

  if [ "$INSTALL_SLACK" = "true" ]; then
    brew_cask_install slack
  else
    log_skipped "INSTALL_SLACK" "Slack"
  fi

  if [ "$INSTALL_BITWARDEN_GUI" = "true" ]; then
    brew_cask_install bitwarden
  else
    log_skipped "INSTALL_BITWARDEN_GUI" "Bitwarden desktop app"
  fi

  if [ "$INSTALL_OBSIDIAN" = "true" ]; then
    brew_cask_install obsidian
  else
    log_skipped "INSTALL_OBSIDIAN" "Obsidian"
  fi

  if [ "$INSTALL_WHATSAPP" = "true" ]; then
    brew_cask_install whatsapp
  else
    log_skipped "INSTALL_WHATSAPP" "WhatsApp"
  fi
}

install_core_apps

# Clean up: Remove outdated versions from the cellar.
cleanup_homebrew() {
  echo "[$(date)] Running brew cleanup..."
  brew cleanup
}

cleanup_homebrew

echo "[$(date)] Mac corporate setup script completed successfully."

} 2>&1 | tee -a "$LOGFILE"

exit 0
