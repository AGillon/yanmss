# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A single-shot Mac bootstrap: one Bash script (`setup.sh`) that takes a fresh macOS install to a working dev environment, plus `manual-setup.md` for the steps that genuinely cannot be scripted (FileVault key capture, GUI-only theme imports, account sign-ins).

Originally forked from `mikeprivette/yanmss`. This fork has diverged substantially — added security hardening, security tools, swapped 1Password → Bitwarden, added Starship, pyenv/tfenv, Catppuccin theming, and extensive idempotence work. Do not assume upstream parity.

## Running and testing

```bash
./setup.sh                # full run; prompts for sudo once and keeps it alive
bash setup.sh             # equivalent
shellcheck setup.sh       # lint (not currently wired into CI; run manually before commits)
```

There is no test suite. The script is meant to be re-runnable — every install step should be idempotent (see "Idempotence" below). The cheapest way to validate a change is to re-run the script on an already-set-up machine and confirm it completes without errors and without redoing already-done work.

Logs land in `~/mac_setup_<timestamp>.log` (every run, via `tee`). When debugging a failed step, that log is the source of truth, not stdout.

## Architecture

### One script, function-per-concern

`setup.sh` is intentionally monolithic — a single file is easier to `curl | sh` and easier for a user to audit before running than a multi-file project. Internal structure:

1. **Bootstrap header** (lines 1–17): re-execs under `bash` if invoked via `sh`, then `set -euo pipefail`.
2. **Logging wrapper**: the entire body is wrapped in `{ ... } 2>&1 | tee -a "$LOGFILE"` (lines 23 / 620). Anything outside that block won't appear in the log.
3. **Helpers**: `keep_sudo_active`, `retry`, `brew_cask_install`, `backup_file`. Defined inline before first use — order matters because of `set -e`.
4. **Install functions**: each major area (`install_homebrew`, `install_cli_tools`, `configure_security`, `install_terminal_tools`, `install_catppuccin`, `install_dev_tools`, `install_security_tools`, `install_core_apps`, etc.) is a function defined and immediately invoked. Adding a new area means: define a function, invoke it, document any manual follow-up in `manual-setup.md`.

### Idempotence is mandatory

Re-running the script must be safe. Patterns already in use:
- `brew_cask_install` (line 74) wraps `brew install --cask` with a `brew list --cask` check.
- Plain `brew install` is naturally idempotent (Homebrew skips already-installed formulae).
- Git clones are guarded with `[ ! -d ... ]` (zsh plugins, lines 318/325).
- Dotfile appends are guarded with `grep -q` before writing (e.g. `.zprofile` brew shellenv, line 111).
- `defaults write` is naturally idempotent.
- `sudo defaults delete ... 2>/dev/null || true` for entries that may not exist.

When adding a step that isn't naturally idempotent, add the guard. Don't rely on the user only running the script once.

### Root vs user policy

Documented inline at lines 27–36. The script runs as the user; `sudo` is requested up-front and kept alive by `keep_sudo_active`. Only system-level operations (`xcode-select --install`, `sudo rm` of stock apps, FileVault, firewall, system-wide `defaults`) use `sudo`. Homebrew, `npm -g`, pyenv/tfenv, and dotfile edits must run as the user — Homebrew refuses to run under sudo.

### `setup.sh` ↔ `manual-setup.md` contract

If a step requires GUI interaction, account credentials, a recovery key the user must capture, or otherwise can't be scripted safely, it goes in `manual-setup.md` with a `**When:**` marker and explicit steps. Inside `setup.sh`, leave a comment pointing at the manual step (see the Catppuccin and security tool blocks for examples). The summary checklist at the bottom of `manual-setup.md` mirrors the section list — keep them in sync.

### Theme: Catppuccin Macchiato

Applied wherever scriptable in `install_catppuccin` (bat theme + cache rebuild, VSCode extensions, iTerm2 color file download, Starship/Nerd Font install). Actual *activation* in iTerm2, VSCode, and Firefox is manual — see `manual-setup.md` §3–4.

## Conventions

- Every echo is timestamped: `echo "[$(date)] ..."`. Keep this consistent — the log is grepped by date.
- Use the existing helpers (`retry`, `brew_cask_install`, `backup_file`) rather than reinventing.
- Comments above each function explain *why* a particular install method or ordering was chosen (see `install_dev_tools` at line 494 for the canonical example). New functions should follow that pattern.
- Don't reorder install functions casually — `install_homebrew` must precede anything `brew`-based, `install_prerequisites` (coreutils/bc) must precede anything that uses `gdate`, `install_dev_tools` installs `pyenv` which `install_python` then references.
