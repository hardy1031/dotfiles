#!/bin/bash
#
# uninstall.sh - Remove dotfiles symlinks
# Repo の中の実 file は touch しない、symlink のみ削除
#

set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$HOME/Scripts"
LAUNCHD_DIR="$HOME/Library/LaunchAgents"

log() {
    echo "[uninstall] $*"
}

# launchd jobs を unload して symlink 削除
if [ -d "$DOTFILES/launchd" ]; then
    for plist in "$DOTFILES"/launchd/*.plist; do
        [ -e "$plist" ] || continue
        name=$(basename "$plist")
        target="$LAUNCHD_DIR/$name"

        if [ -L "$target" ]; then
            launchctl unload "$target" 2>/dev/null || true
            rm "$target"
            log "Removed: $target"
        fi
    done
fi

# Script symlinks を削除
if [ -d "$DOTFILES/scripts" ]; then
    for entry in "$DOTFILES"/scripts/*; do
        [ -e "$entry" ] || continue
        name=$(basename "$entry")
        target="$SCRIPTS_DIR/$name"

        if [ -L "$target" ]; then
            rm "$target"
            log "Removed: $target"
        fi
    done
fi

log "✅ Uninstall complete (repo files in $DOTFILES are untouched)"
