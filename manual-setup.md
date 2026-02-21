# Manual Setup Guide

Steps that cannot be automated by `setup.sh`. Work through these after the script completes successfully.

---

## Order of Operations

Complete these in roughly this order — security first, then tooling, then personalization.

---

## 1. Security (Complete First)

### FileVault Recovery Key

**When:** At your next login after running the script.

FileVault will activate and display a personal recovery key. You must save this before continuing — if you lose it and forget your login password, the disk is unrecoverable.

**Action:** Copy the recovery key into Bitwarden under a "FileVault Recovery Key" entry before dismissing the prompt.

---

### Find My Mac

**When:** Immediately after script completes.

macOS cannot enable Find My Mac from the command line — it requires Apple ID authentication.

**Steps:**
1. System Settings → Apple ID → iCloud
2. Enable **Find My Mac**
3. Also enable **Find My network** (works even when offline)

---

### Lulu — Outbound Firewall Initial Setup

**When:** On first launch of Lulu (it will open automatically after install).

Lulu blocks unknown outbound connections and asks what to do each time a new app phones home. The first few days will have more prompts as it learns your usage.

**Steps:**
1. Approve the system permissions Lulu requests (Notifications, Full Disk Access)
2. When prompted for an app you recognize and trust (e.g. Firefox, Slack), click **Allow**
3. When prompted for something unexpected or unfamiliar, click **Block** and investigate
4. Set Lulu to launch at login: Lulu menu bar icon → Preferences → Launch at Login

---

### BlockBlock — Persistence Monitor Setup

**When:** On first launch.

**Steps:**
1. Approve system permissions when prompted (Full Disk Access, Notifications)
2. During the initial scan it will show everything already installed — this is normal, click **Allow** for items you recognize
3. Going forward, any new persistent install will trigger an alert

---

### Malwarebytes — Initial Scan

**When:** Within the first day of setup.

**Steps:**
1. Open Malwarebytes
2. Approve privacy permissions if prompted
3. Run a full scan on a fresh machine to establish a clean baseline
4. Free tier is sufficient — skip the premium upsell

---

### NextDNS — Account and Configuration

**When:** After script completes. This is the most involved security step.

NextDNS blocks ads, trackers, and malware at the DNS layer across all apps on the machine, not just the browser.

**Steps:**
1. Create a free account at [nextdns.io](https://nextdns.io)
2. Copy your Profile ID from the NextDNS dashboard
3. In Terminal, run:
   ```
   sudo nextdns install \
     -config YOUR_PROFILE_ID \
     -report-client-info \
     -auto-activate
   ```
4. Verify it's working: visit [test.nextdns.io](https://test.nextdns.io)
5. In the NextDNS dashboard, tune your blocklists (recommended starting point: NextDNS Ads & Trackers Blocklist + OISD)

**Note:** If you travel and use untrusted networks, NextDNS combined with Tailscale provides good baseline protection.

---

### Review App Permissions

**When:** Within first week — as you use apps and they request access.

macOS prompts for permissions when apps first need them. Revisit periodically:

- System Settings → Privacy & Security → Camera
- System Settings → Privacy & Security → Microphone
- System Settings → Privacy & Security → Location Services
- System Settings → Privacy & Security → Full Disk Access
- System Settings → Privacy & Security → Screen Recording

Revoke access for anything you don't actively use or don't recognize.

---

## 2. Password Manager

### Bitwarden — Initial Setup

**When:** Before you start using any other accounts on this machine.

The script installs both the Bitwarden desktop app (`bitwarden`) and the CLI (`bitwarden-cli`).

**Steps:**
1. Open Bitwarden, log in or create an account
2. Set up two-factor authentication (Authenticator app, not SMS)
3. Create two vaults or use folder organization to separate **Work** and **Personal** credentials
4. Store the FileVault recovery key here (see section 1 above)
5. For CLI use: `bw login` and save the session token as `export BW_SESSION="..."` in a shell session

---

## 3. Terminal and Shell

### Powerlevel10k — Theme Configuration

**When:** First time you open a new terminal session after the script.

The script sets `ZSH_THEME="powerlevel10k/powerlevel10k"` in `.zshrc`. On first launch, p10k's configuration wizard starts automatically.

**Steps:**
1. Open iTerm2
2. Follow the `p10k configure` wizard — it guides you through font, style, and layout options
3. For Catppuccin Macchiato colors to render correctly, complete the iTerm2 color scheme import first (see below)

**To re-run the wizard at any time:** `p10k configure`

---

### iTerm2 — Catppuccin Macchiato Color Scheme

**When:** Before running `p10k configure`.

The script downloads the color scheme to `~/.iterm2/catppuccin-macchiato.itermcolors` but cannot import it — iTerm2 requires a GUI interaction.

**Steps:**
1. Open iTerm2
2. `⌘,` → Profiles → Colors tab
3. Click **Color Presets...** dropdown → **Import...**
4. Navigate to `~/.iterm2/catppuccin-macchiato.itermcolors` and select it
5. Click **Color Presets...** again → select **Catppuccin Macchiato**

---

### iTerm2 — Powerline Font

**When:** Same session as color scheme import.

**Steps:**
1. `⌘,` → Profiles → Text tab
2. Click **Font** → search for **Meslo LG M for Powerline** (installed by the script)
3. Set size to 13 or 14

---

## 4. Editors and Browsers

### VSCode — Activate Catppuccin Macchiato Theme

**When:** First time you open VSCode.

The script installs the extension but cannot set it as the active theme.

**Steps:**
1. Open VSCode
2. `⌘+Shift+P` → type **Color Theme** → select **Preferences: Color Theme**
3. Choose **Catppuccin Macchiato**
4. For icons: `⌘+Shift+P` → **File Icon Theme** → **Catppuccin Macchiato**

---

### Firefox — Catppuccin Macchiato Theme

**When:** First time you open Firefox. Not scriptable — Firefox add-ons require browser interaction.

**Steps:**
1. Open Firefox
2. Visit [addons.mozilla.org/en-US/firefox/addon/catppuccin-macchiato](https://addons.mozilla.org/en-US/firefox/addon/catppuccin-macchiato/)
3. Click **Add to Firefox**

---

### Firefox — Separate Work and Personal Profiles

**When:** Before you start logging into accounts in Firefox.

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

### Tailscale — Sign In

**When:** After the script completes.

**Steps:**
1. Open Tailscale from the menu bar
2. Sign in with your work account (or personal account if using for personal VPN/networking)
3. Approve the device in your Tailscale admin panel if required

---

### Terraform — Verify tfenv

**When:** After the script completes.

```bash
tfenv list          # should show the installed version with an asterisk
terraform --version # confirm it's active
```

---

## 6. iCloud — Review What's Synced

**When:** Within the first day.

By default iCloud syncs Desktop, Documents, and much more. For mixed personal/professional use, decide consciously what goes into your personal iCloud.

**Review:**
- System Settings → Apple ID → iCloud → **Show All** (next to iCloud Drive)
- Consider turning off Desktop & Documents Folders sync if work files shouldn't land in personal iCloud
- Safari sync: if using Firefox as your main browser, Safari sync is probably unnecessary — disable to reduce data exposure

---

## Summary Checklist

| Step | Done |
|---|---|
| Save FileVault recovery key to Bitwarden | ☐ |
| Enable Find My Mac | ☐ |
| Approve Lulu permissions, set launch at login | ☐ |
| Approve BlockBlock permissions | ☐ |
| Run Malwarebytes initial scan | ☐ |
| Configure NextDNS with profile ID | ☐ |
| Review app permissions in System Settings | ☐ |
| Log in to Bitwarden, enable 2FA | ☐ |
| Import Catppuccin Macchiato into iTerm2 | ☐ |
| Set Powerline font in iTerm2 | ☐ |
| Run `p10k configure` | ☐ |
| Activate Catppuccin Macchiato in VSCode | ☐ |
| Install Catppuccin Macchiato in Firefox | ☐ |
| Set up Firefox work and personal profiles | ☐ |
| Set default Python version with pyenv | ☐ |
| Sign in to Tailscale | ☐ |
| Verify Terraform via `tfenv list` | ☐ |
| Review iCloud sync settings | ☐ |
