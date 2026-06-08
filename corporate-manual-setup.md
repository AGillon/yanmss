# Manual Setup Guide — Corporate / Managed-Device Variant

Steps that cannot be automated by `corporate-setup.sh`. Work through these after the script completes successfully.

This is the corporate counterpart to `manual-setup.md`. It deliberately omits everything that does not apply on an MDM-managed device — FileVault recovery key capture, Find My Mac, Lulu / BlockBlock / Malwarebytes / NextDNS bootstrap — because those tools are either replaced by org-managed equivalents or blocked outright on a managed device.

---

## Order of Operations

There is no security bootstrap section here — the org owns endpoint security, full-disk encryption, firewall, and DNS via MDM. Work through the items below as they become relevant.

---

## 1. CONFIG Block — Edit Before First Run

**When:** Once per employer, before running the script.

`corporate-setup.sh` has a `CONFIG` block near the top with `INSTALL_*=false` flags for every app or tool that is commonly MDM-pushed or otherwise risky on a managed device.

**Steps:**
1. Open `corporate-setup.sh` in any editor.
2. For each gated item, decide:
   - **Already MDM-pushed by the org?** Leave it `false`. Use the org-provided copy.
   - **Org allows personal install AND you actually want it?** Set to `true`.
   - **Unsure?** Leave it `false` and ask IT before flipping.
3. Save and run `./corporate-setup.sh`.

The full CONFIG block is reproduced inline at the top of the script with one-line comments on each flag explaining why it's gated.

---

## 2. Password Manager

**When:** Whatever the org-provided password manager is — sign in to that, *not* a personal Bitwarden.

If the org uses Bitwarden, the desktop app and CLI are usually deployed via MDM. Sign in with your org account. Don't install a second copy via `INSTALL_BITWARDEN_GUI=true` unless IT confirms it's allowed.

If the org uses 1Password, Okta, or another manager: use that. The setup script does not install any of these — it only knows about Bitwarden.

---

## 3. Terminal and Shell

### Starship — Prompt Customization

**When:** After the script completes (optional — Starship works out of the box).

The script installs Starship and adds `eval "$(starship init zsh)"` to `.zshrc`. The prompt works immediately with sensible defaults.

**To customize:**
1. Create or edit `~/.config/starship.toml`
2. See the full configuration reference at [starship.rs/config](https://starship.rs/config/)
3. Changes take effect on the next prompt (no shell restart needed)

---

### iTerm2 — Nerd Font

**When:** Only if you ran with `INSTALL_ITERM2=true`.

**Steps:**
1. `⌘,` → Profiles → Text tab
2. Click **Font** → search for **MesloLGS Nerd Font** (installed by the script)
3. Set size to 13 or 14

---

### `.zshrc` — Org Overwrite Risk

**When:** Watch for this on the next sync after running.

Some organizations centrally push a `.zshrc` via MDM or a config-management tool. If that's true at your org, the `.zshrc` written by `corporate-setup.sh` will be overwritten on the next sync.

**If it happens:**
- The `backup_file` helper preserves your prior `.zshrc` as `~/.zshrc.bak_<timestamp>`. Diff against the org-pushed version to recover any customizations.
- A common pattern is to source a personal `~/.zshrc.local` from the org `.zshrc` (if the org allows it). Move your customizations there and source it from whatever shell init the org leaves alone.

---

## 4. Browsers

### Firefox — Separate Work and Personal Profiles

**When:** Only if you ran with `INSTALL_FIREFOX=true`, and the org permits a non-default browser.

Using separate profiles keeps work and personal cookies, history, and extensions completely isolated.

**Steps:**
1. In Firefox address bar: `about:profiles`
2. Click **Create a New Profile**
3. Name one **Work** and keep the default as **Personal** (or create both fresh)
4. Each profile can have its own set of extensions — consider uBlock Origin in both
5. To switch profiles: `about:profiles` or use Firefox's profile switcher in the dock

---

## 5. Development Tools

### pyenv — Set a Default Python Version

**When:** After the script completes, before any Python development work.

The script installs pyenv but does not set a Python version (this depends on your project needs).

**Steps:**
```bash
# See available versions
pyenv install --list | grep "  3\."

# Install a specific version (e.g. latest 3.12)
pyenv install 3.12.x

# Set it as the global default
pyenv global 3.12.x

# Verify
python --version
```

---

### Terraform — Verify tfenv

**When:** After the script completes.

```bash
tfenv list          # should show the installed version with an asterisk
terraform --version # confirm it's active
```

---

### VS Code — Settings Sync

**When:** Only if you ran with `INSTALL_VSCODE=true` and the org didn't already deploy it.

If the org provides VS Code via MDM, do **not** flip the flag — use the org copy. Otherwise sign in to Settings Sync with whatever account the org permits (often a GitHub or Microsoft account; some orgs forbid personal accounts on work-context tools — check policy).

---

### Granting Accessibility / Full Disk Access

**When:** First launch of any app that needs it (Alfred, iTerm2 for some features).

On a managed device, MDM may auto-deny these prompts or strip the permission later. If a feature stops working after a sync, check **System Settings → Privacy & Security** to see whether the permission was revoked.

---

## 6. Display

### Display Scaling — Adjust Text Size

**When:** After the script completes, before extended use.

**Steps:**
1. System Settings → Displays
2. Select your preferred text size
3. If using an external monitor, configure each display separately

---

## 7. iCloud — Likely Org-Controlled

**When:** Most managed devices restrict or disable personal iCloud sign-in. If yours doesn't, decide consciously what to sync.

If iCloud is allowed:
- System Settings → Apple ID → iCloud → **Show All**
- Avoid syncing Desktop & Documents Folders if any work files might land there.
- Consider not signing in to personal iCloud at all on a corporate device — keeps the boundary clean.

---

## What's Deliberately Missing vs. `manual-setup.md`

If you previously used `manual-setup.md` for a personal device, these sections are intentionally absent here:

- **FileVault recovery key** — org-managed, key escrowed by IT
- **Find My Mac** — usually MDM-controlled
- **Lulu / BlockBlock / Malwarebytes / NextDNS** — none are installed by `corporate-setup.sh`; org EDR / managed firewall / managed DNS replace them
- **Tailscale sign-in** — Tailscale is not installed by `corporate-setup.sh`; the org VPN client is the one to use
- **Bitwarden 2FA bootstrap** — only relevant if the org uses Bitwarden; otherwise see section 2

---

## Summary Checklist

| Step | Done |
|---|---|
| Edit `CONFIG` block before first run | ☐ |
| Sign in to org-provided password manager | ☐ |
| Customize Starship prompt (optional) | ☐ |
| Set Nerd Font in iTerm2 (only if `INSTALL_ITERM2=true`) | ☐ |
| Confirm `.zshrc` survives next MDM sync (or move customizations to `.zshrc.local`) | ☐ |
| Set up Firefox work/personal profiles (only if `INSTALL_FIREFOX=true`) | ☐ |
| Set default Python version with pyenv | ☐ |
| Verify Terraform via `tfenv list` | ☐ |
| Sign in to VS Code Settings Sync (only if `INSTALL_VSCODE=true`) | ☐ |
| Grant Accessibility / Full Disk Access where needed | ☐ |
| Adjust display scaling (System Settings → Displays) | ☐ |
| Review iCloud sign-in / sync (if permitted) | ☐ |
