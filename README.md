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
# 1. Clone (好きなディレクトリでOK、install.sh はどこに置いても動く)
git clone git@github.com:hardy1031/dotfiles.git ~/General/PersonalLab/dotfiles
# 別の場所でも可: git clone git@github.com:hardy1031/dotfiles.git ~/dotfiles

# 2. Install Python dependencies
pip3 install -r <repo>/scripts/mail-imap/requirements.txt

# 3. Configure credentials
cp <repo>/scripts/mail-imap/.env.example <repo>/scripts/mail-imap/.env
vim <repo>/scripts/mail-imap/.env

# 4. Run install
cd <repo>
./install.sh

# 5. Manual: set Raycast script directory to <repo>/raycast
```

## Daily workflow

Edit any file in the repo, changes are reflected immediately via symlinks.

```bash
cd <repo>
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
