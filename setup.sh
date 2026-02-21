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
  local cmd="$@"
  until [ $n -ge $try ]
  do
      $cmd && break
      n=$((n+1))
      echo "Retry $n/$try failed for: $cmd"
      sleep 5
  done
}

# Function to install Homebrew if not already installed
install_homebrew() {
  echo "[$(date)] Checking for Homebrew..."
  if ! command -v brew >/dev/null 2>&1; then
      echo "[$(date)] Installing Homebrew..."
      retry /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

      # Add Homebrew to PATH
      echo "[$(date)] Adding Homebrew to PATH..."
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
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
# node is required here so npm is available for Claude Code installation later.
install_prerequisites() {
  echo "[$(date)] Installing prerequisites..."
  brew install coreutils bc node
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
}

install_cli_tools

# Function to install XCode Command Line Tools
install_xcode_tools() {
  echo "[$(date)] Checking for Xcode Command Line Tools..."
  if ! xcode-select -p >/dev/null 2>&1; then
      echo "[$(date)] Installing Xcode Command Line Tools..."
      xcode-select --install
  else
      echo "[$(date)] Xcode Command Line Tools already installed."
  fi
}

install_xcode_tools

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

# Terminal and Shell Setup: Install iTerm2 and Oh My Zsh.
install_terminal_tools() {
  echo "[$(date)] Installing iTerm2..."
  brew install --cask --appdir="/Applications" iterm2
  
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

# Powerlevel10k theme — pairs well with Catppuccin Macchiato terminal colors.
# Run `p10k configure` on first launch to complete setup.
ZSH_THEME="powerlevel10k/powerlevel10k"

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
eval "$(pyenv init -)"

# Powerlevel10k config (generated by `p10k configure` or pre-placed at ~/.p10k.zsh)
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
ZSHRC_CONFIG
  
  echo "[$(date)] .zshrc configuration complete."
}

backup_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
      local backup_suffix="$(date +'%Y%m%d_%H%M%S')"
      cp "$file" "${file}.bak_${backup_suffix}"
      echo "[$(date)] Backed up $file to ${file}.bak_${backup_suffix}"
  fi
}

install_terminal_tools

# Catppuccin Macchiato theme — applies wherever scriptable.
# Items requiring a manual step after the script runs:
#   iTerm2  : Preferences > Profiles > Colors > Color Presets > Import
#             select ~/.iterm2/catppuccin-macchiato.itermcolors
#   VSCode  : Cmd+Shift+P > Color Theme > Catppuccin Macchiato
#   Firefox : Install from https://addons.mozilla.org/en-US/firefox/addon/catppuccin-macchiato/
#   p10k    : Run `p10k configure` on first terminal launch
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

  # Powerlevel10k — required for the ZSH_THEME set in .zshrc
  echo "[$(date)] Installing Powerlevel10k..."
  brew install romkatv/romkatv/powerlevel10k

  echo "[$(date)] Catppuccin Macchiato theme installation complete."
  echo "[$(date)] Manual steps required — see post-script checklist in readme.md."
}

install_catppuccin

# Powerline Fonts Installation: Clone and install Powerline fonts.
install_powerline_fonts() {
  echo "[$(date)] Installing Powerline fonts..."
  if [ ! -d "$HOME/fonts" ]; then
      retry git clone https://github.com/powerline/fonts.git "$HOME/fonts"
      pushd "$HOME/fonts" && ./install.sh && popd
  else
      echo "[$(date)] Powerline fonts already installed."
  fi
}

install_powerline_fonts

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
#   docker — Homebrew cask installs Docker Desktop (VM-based, covers most use cases)
#   firefox, tailscale, visual-studio-code — standard Homebrew casks
#   claude-code — npm-only; not available on Homebrew
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

  # CLI tools
  echo "[$(date)] Installing CLI tools..."
  brew install gh
  brew install awscli
  brew install glab
  brew install bitwarden-cli

  # Claude Code (npm-only — not available on Homebrew)
  echo "[$(date)] Installing Claude Code via npm..."
  npm install -g @anthropic-ai/claude-code

  # Cask applications
  echo "[$(date)] Installing cask applications..."
  brew install --cask --appdir="/Applications" visual-studio-code
  brew install --cask --appdir="/Applications" docker
  brew install --cask --appdir="/Applications" firefox
  brew install --cask --appdir="/Applications" tailscale

  echo "[$(date)] Developer tools installation complete."
}

install_dev_tools

# Core Applications Installation: Install essential applications using Homebrew.
# Note: visual-studio-code is installed in install_dev_tools() to avoid duplication.
install_core_apps() {
  echo "[$(date)] Installing core applications..."
  brew install --cask --appdir="/Applications" alfred &
  brew install --cask --appdir="/Applications" slack &
  brew install --cask --appdir="/Applications" 1password &
  wait
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