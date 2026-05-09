#!/bin/bash
#
# install.sh - Setup dotfiles symlinks
# Idempotent: 何度実行しても安全
#

set -euo pipefail

# === Configuration ===
DOTFILES="$HOME/dotfiles"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
SCRIPTS_DIR="$HOME/Scripts"
LAUNCHD_DIR="$HOME/Library/LaunchAgents"

# === Helpers ===
log() {
    echo "[install] $*"
}

backup_if_real() {
    local target="$1"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        mkdir -p "$BACKUP_DIR"
        log "Backing up: $target -> $BACKUP_DIR/"
        mv "$target" "$BACKUP_DIR/"
    fi
}

create_symlink() {
    local source="$1"
    local target="$2"
    backup_if_real "$target"
    ln -sf "$source" "$target"
    log "Linked: $target -> $source"
}

# === Pre-flight checks ===
if [ ! -d "$DOTFILES" ]; then
    echo "Error: $DOTFILES does not exist"
    exit 1
fi

log "Starting installation from $DOTFILES"

# === 1. launchd plists ===
log "=== Setting up launchd ==="
mkdir -p "$LAUNCHD_DIR"

if [ -d "$DOTFILES/launchd" ]; then
    for plist in "$DOTFILES"/launchd/*.plist; do
        [ -e "$plist" ] || continue
        name=$(basename "$plist")
        target="$LAUNCHD_DIR/$name"
        label="${name%.plist}"

        # 既に loaded されてたら unload
        if launchctl list | grep -q "$label"; then
            launchctl unload "$target" 2>/dev/null || true
        fi

        create_symlink "$plist" "$target"
        launchctl load "$target"
        log "Loaded: $label"
    done
fi

# === 2. Scripts (folder or file ごと symlink) ===
log "=== Setting up scripts ==="
mkdir -p "$SCRIPTS_DIR"

if [ -d "$DOTFILES/scripts" ]; then
    for entry in "$DOTFILES"/scripts/*; do
        [ -e "$entry" ] || continue
        name=$(basename "$entry")
        target="$SCRIPTS_DIR/$name"

        create_symlink "$entry" "$target"

        # File なら実行権限つける
        if [ -f "$entry" ]; then
            chmod +x "$entry"
        fi
    done
fi

# === 3. .env のチェック ===
log "=== Checking .env files ==="
ENV_FILE="$DOTFILES/scripts/mail-imap/.env"
ENV_EXAMPLE="$DOTFILES/scripts/mail-imap/.env.example"

if [ ! -f "$ENV_FILE" ] && [ -f "$ENV_EXAMPLE" ]; then
    log "⚠️  .env not found at: $ENV_FILE"
    log "    Copy .env.example to .env and fill in real values:"
    log "    cp $ENV_EXAMPLE $ENV_FILE"
    log "    vim $ENV_FILE"
fi

# === 4. Python dependencies ===
log "=== Python dependencies ==="
if [ -f "$DOTFILES/scripts/mail-imap/requirements.txt" ]; then
    log "ℹ️  Install Python dependencies with:"
    log "    pip3 install -r $DOTFILES/scripts/mail-imap/requirements.txt"
fi

# === 5. Raycast (manual step) ===
log "=== Raycast setup ==="
log "⚠️  Manual step:"
log "    Raycast preferences (Cmd+,) -> Extensions -> Script Commands"
log "    -> Add Script Directory: $DOTFILES/raycast"

# === Summary ===
log ""
log "✅ Installation complete!"
[ -d "$BACKUP_DIR" ] && log "📦 Backups: $BACKUP_DIR"
log ""
log "Verify with:"
log "  launchctl list | grep mailcleanup"
log "  ls -la $SCRIPTS_DIR"
