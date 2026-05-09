# Dotfiles

Personal macOS automation toolkit. Reproducible setup via symlink pattern.

## What's inside

### `launchd/` + `scripts/mail-imap/`
Scheduled email cleanup automation.

- **Trigger**: launchd, daily at 3:00 AM
- **What**: Python scripts that connect to IMAP and clean up old emails
- **Files**:
  - `cleanup.py` - main cleanup logic
  - `check_folder.py`, `check_mail.py` - helper utilities
  - `requirements.txt` - Python dependencies

### `raycast/`
Manual-trigger shortcuts via Raycast (one-keystroke workflows).

## Philosophy

- **Single source of truth**: actual files live in this repo. OS-required
  locations (`~/Library/LaunchAgents/`, `~/Scripts/`) are symlinks pointing here.
- **Reproducible**: `git clone` + `./install.sh` recreates the entire setup.
- **Idempotent install**: re-running `install.sh` is safe.

## Prerequisites

- macOS
- Python 3 (via pyenv recommended)
- Raycast (for `raycast/` scripts)

## Setup

```bash
# 1. Clone
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles

# 2. Install Python dependencies
pip3 install -r ~/dotfiles/scripts/mail-imap/requirements.txt

# 3. Configure credentials
cp ~/dotfiles/scripts/mail-imap/.env.example \
   ~/dotfiles/scripts/mail-imap/.env
vim ~/dotfiles/scripts/mail-imap/.env

# 4. Run install
cd ~/dotfiles
./install.sh

# 5. Manual: set Raycast script directory to ~/dotfiles/raycast
```

## Daily workflow

Edit any file in `~/dotfiles/`, changes are reflected immediately via symlinks.

```bash
cd ~/dotfiles
vim scripts/mail-imap/cleanup.py
# test, then commit
git add . && git commit -m "..." && git push
```

For plist changes, reload the launchd job:
```bash
launchctl unload ~/Library/LaunchAgents/com.local.mailcleanup.plist
launchctl load   ~/Library/LaunchAgents/com.local.mailcleanup.plist
```

## Architecture

```
~/dotfiles/scripts/mail-imap/cleanup.py        ← actual file
~/Scripts/mail-imap  →  symlink ↑              ← what OS sees
~/Library/LaunchAgents/...plist  →  symlink    ← what launchd loads
```

## Uninstall

```bash
cd ~/dotfiles
./uninstall.sh
```

Removes symlinks only. Repo files are preserved.
