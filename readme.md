# YANMSS (Yet Another New Mac Setup Script)

## About

YANMSS is a single-shot Bash script that takes a fresh macOS install to a working development environment: a Homebrew-based toolchain, a themed terminal, security hardening, and the apps you actually use. It is opinionated — meant to be read top-to-bottom and re-run safely.

This repo is a fork of [`mikeprivette/yanmss`](https://github.com/mikeprivette/yanmss) and has diverged substantially: 1Password was swapped for Bitwarden, security hardening and security tools were added, Starship prompt and a Nerd Font were added, and pyenv/tfenv/Go/Rust/Claude Code were added to the dev toolchain.

## What it does

Beyond the installs in the table below, the script:

- Runs under `set -euo pipefail` and re-execs into `bash` if invoked via `sh`.
- Tees every action to `~/mac_setup_<timestamp>.log` for post-mortem debugging.
- Re-runnable: every install step is guarded so a second run is a no-op for already-installed components. Dotfiles are backed up before they are rewritten.
- Wraps network commands in a 5-attempt retry helper.
- Hardens macOS via `defaults`, `fdesetup`, and `socketfilterfw`: schedules FileVault for next login, enables the application firewall, requires a password immediately on screen lock, enables automatic security updates, scopes AirDrop to Contacts Only, and removes a curated list of unused stock Apple apps (GarageBand, iMovie, Keynote, Numbers, Pages, Chess, Stocks).
- Configures iTerm2's Natural Text Editing key map (Option+Arrow word jump, Cmd+Arrow line jump, Option+Backspace word delete, etc.) by writing directly to its plist.
- Writes a curated `.zshrc` (Oh My Zsh + plugins, aliases, pyenv init, Starship init).

## What gets installed

Every third-party component the script puts on the machine. In install order.

| Name | Category | Install method | Purpose |
|---|---|---|---|
| Xcode Command Line Tools | Bootstrap | `xcode-select` | Compiler, git, headers — required by Homebrew. |
| Homebrew | Bootstrap | `curl \| bash` | Package manager underpinning everything below. |
| coreutils | Prerequisite | `brew` | Provides `gdate` for the zsh exec-time hook. |
| bc | Prerequisite | `brew` | Floating-point math for the zsh exec-time hook. |
| z | CLI | `brew` | Smart `cd` — jumps to frequently-used directories. |
| bat | CLI | `brew` | `cat` with syntax highlighting; aliased over `cat`. |
| tree | CLI | `brew` | Directory tree visualization. |
| tldr | CLI | `brew` | Concise command examples in lieu of man pages. |
| jq | CLI | `brew` | JSON processor. |
| ripgrep | CLI | `brew` | Fast recursive grep (`rg`). |
| fd | CLI | `brew` | Fast `find` alternative. |
| htop | CLI | `brew` | Interactive process viewer. |
| grep | CLI | `brew` | GNU grep (replaces BSD grep). |
| uv | CLI | `brew` | Fast Python package/dependency manager. |
| snowflake-cli | CLI | `brew` | Snowflake command-line client. |
| shellcheck | CLI | `brew` | Static analysis for shell scripts; used to lint `setup.sh` itself. |
| iterm2 | Terminal | `brew --cask` | Terminal emulator. |
| Oh My Zsh | Shell framework | `curl \| sh` | zsh plugin/theme framework. |
| zsh-autosuggestions | Shell plugin | `git clone` | Inline command suggestions from history. |
| zsh-syntax-highlighting | Shell plugin | `git clone` | Live syntax highlighting in the prompt. |
| starship | Shell prompt | `brew` | Cross-shell prompt; configured via `~/.config/starship.toml`. |
| font-meslo-lg-nerd-font | Font | `brew --cask` | Meslo Nerd Font — glyphs/icons for Starship and the terminal. |
| pyenv | Version manager | `brew` | Python version manager. The script does **not** install a Python — pick one with `pyenv install`. |
| tfenv | Version manager | `brew` | Terraform version manager. |
| Terraform (latest) | Language tool | `tfenv` | Latest Terraform installed and selected via `tfenv install latest`. |
| go | Language | `brew` | Go toolchain. |
| Rust toolchain | Language | `curl \| sh` | Installed via `rustup` (rustc, cargo, etc.). |
| gh | Dev CLI | `brew` | GitHub CLI. |
| glab | Dev CLI | `brew` | GitLab CLI. |
| awscli | Dev CLI | `brew` | AWS CLI. |
| bitwarden-cli | Dev CLI | `brew` | Bitwarden CLI (`bw`). |
| Claude Code | Dev CLI | `curl \| sh` | Anthropic's CLI agent (`claude`), native install from claude.ai. |
| visual-studio-code | Editor | `brew --cask` | VSCode. |
| docker-desktop | Dev tool | `brew --cask` | Docker Desktop (VM-based Docker for macOS). |
| firefox | Browser | `brew --cask` | Firefox. |
| tailscale-app | Network | `brew --cask` | Tailscale mesh VPN client (GUI app). |
| basictex | Dev tool | `brew --cask` | Minimal TeX distribution. |
| lulu | Security | `brew --cask` | Outbound application firewall (fills macOS's egress gap). |
| blockblock | Security | `brew --cask` | Persistence monitor — alerts on new launch agents/login items. |
| suspicious-package | Security | `brew --cask` | Quick Look extension to inspect `.pkg` installers before opening. |
| malwarebytes | Security | `brew --cask` | On-demand macOS malware scanner. |
| nextdns | Security | `brew` (third-party tap) | DNS-level ads/trackers/malware blocking; configuration is manual. |
| alfred | Productivity | `brew --cask` | Spotlight replacement / launcher. |
| slack | Communication | `brew --cask` | Slack desktop client. |
| bitwarden | Password manager | `brew --cask` | Bitwarden desktop app. |
| obsidian | Notes | `brew --cask` | Markdown notes / knowledge base. |
| whatsapp | Communication | `brew --cask` | WhatsApp desktop client. |

## Installation

```shell
sh -c "$(curl -fsSL https://raw.githubusercontent.com/AGillon/yanmss/master/setup.sh)"
```

If [Xcode Command Line Tools](https://developer.apple.com/library/archive/technotes/tn2339/_index.html#//apple_ref/doc/uid/DTS40014588-CH1-WHAT_IS_THE_COMMAND_LINE_TOOLS_PACKAGE_) are not present, the script installs them and waits for completion before continuing.

## Usage

The script requests `sudo` once at the start and keeps it alive for the duration. It then runs end-to-end without further interaction. Progress streams to the terminal and to `~/mac_setup_<timestamp>.log`.

## Post-installation

The script does everything it safely can without human input. The remaining steps — capturing the FileVault recovery key, enabling Find My Mac, approving Lulu/BlockBlock permissions, configuring NextDNS with your profile ID, setting the Nerd Font in iTerm2, picking a Python version with `pyenv install`, signing in to Tailscale and Bitwarden — are documented step-by-step in **[`manual-setup.md`](./manual-setup.md)**, with a checklist at the end.

## New commands available

- **`z [directory]`** — jump to frequently-used directories (learns from your `cd` usage).
- **`cat [file]`** — now `bat` with syntax highlighting; use `ocat` for the original.
- **`tldr [command]`** — quick command examples.
- **`tree`** — directory structure as a tree.
- **`rg`** — ripgrep, fast recursive search.
- **`fd`** — fast `find` alternative.

## Contributions

Issues and PRs welcome.

## Disclaimer

Use this script at your own risk. It's been used on multiple machines but configurations vary; review `setup.sh` before running, especially the security and stock-app removal sections.
