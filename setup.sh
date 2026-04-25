#!/bin/sh
# Automated Mac Setup Script - Updated Nov 2023
# This script installs essential command-line tools and applications using Homebrew.

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

# Log the start of the script execution
LOGFILE="$HOME/mac_setup_$(date +'%Y%m%d_%H%M%S').log"

# Simple logging that works everywhere
{

echo "[$(date)] Starting Mac setup..."

# Root vs. user-level install policy:
#   - Run this script as your normal user account (NOT as root).
#   - Homebrew and all `brew install` / `brew install --cask` commands must run
#     as the logged-in user; Homebrew will abort if invoked via sudo.
#   - `npm install -g`, pyenv, tfenv, VSCode extensions, and dotfiles all live
#     under $HOME and must also be run as the user.
#   - The only operations that need elevation are: xcode-select --install and
#     removing stock apps from /Applications (handled via sudo rm -rf below).
#   - keep_sudo_active() handles those cases without requiring you to run the
#     entire script as root.

# Function to keep sudo active
keep_sudo_active() {
  sudo -v
  while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
}

# Request and keep the administrator password active.
keep_sudo_active

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

# Xcode Command Line Tools — must be installed before Homebrew and git clones.
# xcode-select --install returns immediately (opens a GUI dialog), so we poll
# until the tools are actually present before continuing.
install_xcode_tools() {
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

# Function to install Homebrew if not already installed
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
      echo "[$(date)] Homebrew already installed."
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

# Install useful command-line tools
install_cli_tools() {
  echo "[$(date)] Installing command-line tools..."
  
  # Install z - a smarter cd command
  echo "[$(date)] Installing z (smart directory jumping)..."
  brew install z
  
  # Install bat - a better cat with syntax highlighting
  echo "[$(date)] Installing bat (better cat with syntax highlighting)..."
  brew install bat
  
  # Install other useful tools
  echo "[$(date)] Installing additional CLI tools..."
  brew install tree     # Display directory structure
  brew install tldr     # Simplified man pages
  brew install jq       # JSON processor
  brew install ripgrep  # Fast grep alternative
  brew install fd       # Fast find alternative
  brew install htop     # Better top
  brew install grep     # GNU grep (replaces BSD grep)
  brew install uv       # Fast Python package manager
  brew install snowflake-cli  # Snowflake CLI
}

install_cli_tools

# Finder Configuration: Set up Finder preferences like showing hidden files.
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

# Security hardening: enable critical protections that are off by default in macOS.
#
# Root vs. user policy:
#   - FileVault, firewall, login window: require sudo (system-level)
#   - Screensaver password, AirDrop, auto-update checks: user-level defaults
#
# NOTE: FileVault is deferred to next login so the script isn't interrupted
# by an interactive password prompt. The recovery key will be displayed at
# that point — save it somewhere safe (e.g. Bitwarden).
configure_security() {
  echo "[$(date)] Configuring security settings..."

  # FileVault — full-disk encryption. Deferred to next login.
  if fdesetup status | grep -q "FileVault is Off"; then
    echo "[$(date)] Scheduling FileVault to enable at next login..."
    sudo fdesetup enable -defer /var/db/fvdefer 2>/dev/null || \
      echo "[$(date)] WARNING: FileVault deferral not supported on this version — enable manually in System Settings → Privacy & Security."
  else
    echo "[$(date)] FileVault already enabled."
  fi

  # Application firewall — blocks unsolicited inbound connections.
  # The built-in firewall is off by default; this turns it on.
  echo "[$(date)] Enabling application firewall..."
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

  # Screensaver — require password immediately on wake/lock.
  echo "[$(date)] Configuring screensaver password lock..."
  defaults write com.apple.screensaver askForPassword -int 1
  defaults write com.apple.screensaver askForPasswordDelay -int 0

  # Auto-login — disable so a password is required at boot.
  echo "[$(date)] Disabling automatic login..."
  sudo defaults delete /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null || true

  # Automatic updates — enable all categories, including security patches.
  echo "[$(date)] Enabling automatic software updates..."
  defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
  defaults write com.apple.SoftwareUpdate AutomaticDownload -bool true
  defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -bool true
  defaults write com.apple.SoftwareUpdate ConfigDataInstall -bool true
  sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool true

  # AirDrop — restrict discoverability to contacts only (default is "Everyone").
  echo "[$(date)] Setting AirDrop to Contacts Only..."
  defaults write com.apple.sharingd DiscoverableMode -string "Contacts Only"
  killall sharingd 2>/dev/null || true

  echo "[$(date)] Security settings configured."
}

configure_security

# Remove unused stock Apple apps that will never be used.
# NOTE: macOS may re-download these after an OS update — this is a known
# limitation without MDM tooling. Do NOT add system-integrated apps (Safari,
# Messages, Mail, Photos, etc.) to this list.
remove_stock_apps() {
  echo "[$(date)] Removing unused stock Apple apps..."
  local apps=(
    "/Applications/GarageBand.app"
    "/Applications/iMovie.app"
    "/Applications/Keynote.app"
    "/Applications/Numbers.app"
    "/Applications/Pages.app"
    "/Applications/Chess.app"
    "/Applications/Stocks.app"
  )
  for app in "${apps[@]}"; do
    if [ -d "$app" ]; then
      echo "[$(date)] Removing $app..."
      sudo rm -rf "$app"
    else
      echo "[$(date)] $app not found, skipping."
    fi
  done
}

remove_stock_apps

backup_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
      local backup_suffix="$(date +'%Y%m%d_%H%M%S')"
      cp "$file" "${file}.bak_${backup_suffix}"
      echo "[$(date)] Backed up $file to ${file}.bak_${backup_suffix}"
  fi
}

# Terminal and Shell Setup: Install iTerm2 and Oh My Zsh.
install_terminal_tools() {
  echo "[$(date)] Installing iTerm2..."
  brew_cask_install iterm2

  # iTerm2: Enable Natural Text Editing key mappings.
  # Maps Option+Arrow to word jump, Cmd+Arrow to line jump,
  # Option+Backspace to delete word, etc.
  echo "[$(date)] Configuring iTerm2 Natural Text Editing..."
  local iterm_plist="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
  # Launch iTerm2 briefly to generate default preferences if needed
  if [ ! -f "$iterm_plist" ]; then
    open -a iTerm && sleep 3 && osascript -e 'tell application "iTerm" to quit'
    sleep 1
  fi
  local pb="/usr/libexec/PlistBuddy"
  local km=":New Bookmarks:0:Keyboard Map"
  # Helper: add or overwrite a key mapping entry
  _iterm_key() {
    local key="$1" action="$2" text="$3"
    $pb -c "Add '$km:$key' dict" "$iterm_plist" 2>/dev/null || true
    $pb -c "Delete '$km:$key:Action'" "$iterm_plist" 2>/dev/null || true
    $pb -c "Add    '$km:$key:Action' integer $action" "$iterm_plist"
    $pb -c "Delete '$km:$key:Text'" "$iterm_plist" 2>/dev/null || true
    $pb -c "Add    '$km:$key:Text' string '$text'" "$iterm_plist"
  }
  _iterm_key "0xf702-0x280000" 10 "b"         # Option+Left  → word backward
  _iterm_key "0xf703-0x280000" 10 "f"         # Option+Right → word forward
  _iterm_key "0xf702-0x300000" 11 "0x1"       # Cmd+Left    → beginning of line
  _iterm_key "0xf703-0x300000" 11 "0x5"       # Cmd+Right   → end of line
  _iterm_key "0x7f-0x80000"    11 "0x1b 0x7f" # Option+Bksp  → delete word backward
  _iterm_key "0x7f-0x100000"   11 "0x15"      # Cmd+Bksp     → delete line backward
  _iterm_key "0xf728-0x80000"  10 "d"         # Option+Del   → delete word forward
  _iterm_key "0xf728-0x0"      11 "0x4"       # Del          → delete char forward
  echo "[$(date)] iTerm2 Natural Text Editing configured."

  echo "[$(date)] Installing oh-my-zsh..."
  # Check if Oh My Zsh is already installed
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
    echo "[$(date)] Oh My Zsh already installed."
  fi
  
  # Install additional zsh plugins
  echo "[$(date)] Installing zsh plugins..."
  ZSH_CUSTOM=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}
  
  # Install zsh-autosuggestions
  if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
  else
    echo "[$(date)] zsh-autosuggestions already installed."
  fi
  
  # Install zsh-syntax-highlighting
  if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
  else
    echo "[$(date)] zsh-syntax-highlighting already installed."
  fi

  # Configure .zshrc properly
  echo "[$(date)] Configuring .zshrc..."
  
  # Backup existing .zshrc if it exists
  if [ -f "$HOME/.zshrc" ]; then
    backup_file ~/.zshrc
  fi
  
  # Create a new .zshrc with proper configuration
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

# Bat configuration — Catppuccin Macchiato theme (installed by install_catppuccin)
export BAT_THEME="Catppuccin Macchiato"

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

# Catppuccin Macchiato theme — applies wherever scriptable.
# Items requiring a manual step after the script runs:
#   iTerm2  : Preferences > Profiles > Colors > Color Presets > Import
#             select ~/.iterm2/catppuccin-macchiato.itermcolors
#   VSCode  : Cmd+Shift+P > Color Theme > Catppuccin Macchiato
#   Firefox : Install from https://addons.mozilla.org/en-US/firefox/addon/catppuccin-macchiato/
#   Starship: Customize via ~/.config/starship.toml
install_catppuccin() {
  echo "[$(date)] Installing Catppuccin Macchiato theme..."

  # bat — download theme file and rebuild cache
  if command -v bat >/dev/null 2>&1; then
    echo "[$(date)] Configuring Catppuccin Macchiato for bat..."
    mkdir -p "$(bat --config-dir)/themes"
    curl -fsSL \
      "https://raw.githubusercontent.com/catppuccin/bat/main/themes/Catppuccin%20Macchiato.tmTheme" \
      -o "$(bat --config-dir)/themes/Catppuccin Macchiato.tmTheme"
    bat cache --build
  fi

  # VSCode — install theme and icon pack extensions
  if command -v code >/dev/null 2>&1; then
    echo "[$(date)] Installing Catppuccin VSCode extensions..."
    code --install-extension Catppuccin.catppuccin-vsc
    code --install-extension Catppuccin.catppuccin-vsc-icons
  fi

  # iTerm2 — download color scheme so it's ready to import manually
  echo "[$(date)] Downloading Catppuccin Macchiato iTerm2 color scheme..."
  mkdir -p "$HOME/.iterm2"
  curl -fsSL \
    "https://raw.githubusercontent.com/catppuccin/iterm/main/colors/catppuccin-macchiato.itermcolors" \
    -o "$HOME/.iterm2/catppuccin-macchiato.itermcolors"

  # Starship prompt — cross-shell, fast, actively maintained
  echo "[$(date)] Installing Starship prompt..."
  brew install starship

  # Nerd Font — provides icons and glyphs used by Starship
  echo "[$(date)] Installing Meslo Nerd Font..."
  brew_cask_install font-meslo-lg-nerd-font

  echo "[$(date)] Catppuccin Macchiato theme installation complete."
  echo "[$(date)] Manual steps required — see post-script checklist in readme.md."
}

install_catppuccin


# Python version management via pyenv.
# pyenv itself is installed in install_dev_tools().
# After the script runs, set a Python version with:
#   pyenv install <version> && pyenv global <version>
install_python() {
  echo "[$(date)] Configuring pyenv..."
  if ! command -v pyenv >/dev/null 2>&1; then
    echo "[$(date)] pyenv not found — it will be installed in install_dev_tools()."
  else
    echo "[$(date)] pyenv already installed: $(pyenv --version)"
  fi
}

install_python

# Developer tools and additional applications.
# Install method rationale:
#   tfenv  — manages Terraform versions (replaces raw `terraform` install)
#   pyenv  — manages Python versions (replaces direct `brew install python`)
#   gh     — official GitHub CLI Homebrew formula
#   awscli — official AWS CLI Homebrew formula
#   glab   — official GitLab CLI Homebrew formula
#   bitwarden-cli — official Homebrew formula
#   go     — official Go Homebrew formula
#   docker-desktop — Homebrew cask installs Docker Desktop (VM-based)
#   firefox, tailscale-app, visual-studio-code — standard Homebrew casks
#   claude-code — native install via claude.ai/install.sh
#   rust   — installed via rustup (official installer)
install_dev_tools() {
  echo "[$(date)] Installing developer tools and additional apps..."

  # Python version manager
  echo "[$(date)] Installing pyenv..."
  brew install pyenv

  # Terraform version manager + latest Terraform
  echo "[$(date)] Installing tfenv and latest Terraform..."
  brew install tfenv
  tfenv install latest
  tfenv use latest

  # Go
  echo "[$(date)] Installing Go..."
  brew install go

  # Rust via rustup (official installer, non-interactive)
  echo "[$(date)] Installing Rust via rustup..."
  if ! command -v rustup >/dev/null 2>&1; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    # Source cargo env so rust tools are available for the rest of this script
    source "$HOME/.cargo/env"
  else
    echo "[$(date)] Rust already installed: $(rustc --version)"
  fi

  # CLI tools
  echo "[$(date)] Installing CLI tools..."
  brew install gh
  brew install awscli
  brew install glab
  brew install bitwarden-cli

  # Claude Code (native install)
  echo "[$(date)] Installing Claude Code..."
  if ! command -v claude >/dev/null 2>&1; then
    curl -fsSL https://claude.ai/install.sh | sh
  else
    echo "[$(date)] Claude Code already installed: $(claude --version 2>/dev/null)"
  fi

  # Cask applications
  echo "[$(date)] Installing cask applications..."
  brew_cask_install visual-studio-code
  brew_cask_install docker-desktop
  brew_cask_install firefox
  brew_cask_install tailscale-app
  brew_cask_install basictex

  echo "[$(date)] Developer tools installation complete."
}

install_dev_tools

# Security tools: fills gaps that macOS's built-in protections don't cover.
#
#   Lulu            — outbound application firewall. macOS blocks unsolicited
#                     inbound connections but applies no policy to egress traffic.
#                     Lulu alerts you when an app tries to phone home.
#   BlockBlock      — monitors for persistent background components (launch agents,
#                     cron jobs, login items). Alerts you when something tries to
#                     survive a reboot.
#   Suspicious Pkg  — Quick Look extension so you can inspect a .pkg installer
#                     before running it.
#   Malwarebytes    — on-demand macOS malware scanner. Free tier is sufficient.
#   NextDNS         — DNS-level ad, tracker, and malware blocking across all apps.
#                     Requires account setup and a profile ID — see manual-setup.md.
#
# NOTE: Lulu and BlockBlock will request system permissions (Full Disk Access,
# Notifications) on first launch. Approve them for these tools to be effective.
install_security_tools() {
  echo "[$(date)] Installing security tools..."

  brew_cask_install lulu
  brew_cask_install blockblock
  brew_cask_install suspicious-package
  brew_cask_install malwarebytes

  # NextDNS CLI — installs the local DNS proxy. Configuration (account + profile ID)
  # must be completed manually; see manual-setup.md.
  brew install nextdns/tap/nextdns

  echo "[$(date)] Security tools installation complete."
  echo "[$(date)] See manual-setup.md for post-install configuration steps."
}

install_security_tools

# Core Applications Installation: Install essential applications using Homebrew.
# Note: visual-studio-code is installed in install_dev_tools() to avoid duplication.
install_core_apps() {
  echo "[$(date)] Installing core applications..."
  brew_cask_install alfred
  brew_cask_install slack
  brew_cask_install bitwarden
  brew_cask_install obsidian
  brew_cask_install whatsapp
}

install_core_apps

# Clean up: Remove outdated versions from the cellar.
cleanup_homebrew() {
  echo "[$(date)] Running brew cleanup..."
  brew cleanup
}

cleanup_homebrew

# Ensure successful completion
echo "[$(date)] Mac setup script completed successfully."

} 2>&1 | tee -a "$LOGFILE"

exit 0