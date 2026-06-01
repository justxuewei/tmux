#!/usr/bin/env bash
#
# Install tmux.conf into ~/.tmux.conf, backing up any existing config.
#
set -euo pipefail

# Resolve the directory this script lives in (so it works from anywhere).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SRC="$SCRIPT_DIR/tmux.conf"
DEST="$HOME/.tmux.conf"

if [[ ! -f "$SRC" ]]; then
    echo "error: source config not found at $SRC" >&2
    exit 1
fi

# Back up an existing real file (not our own symlink) before overwriting.
if [[ -e "$DEST" || -L "$DEST" ]]; then
    if [[ -L "$DEST" && "$(readlink -f "$DEST")" == "$(readlink -f "$SRC")" ]]; then
        echo "Already linked to $SRC — nothing to back up."
    else
        BACKUP="$DEST.backup.$(date +%Y%m%d%H%M%S)"
        mv "$DEST" "$BACKUP"
        echo "Backed up existing config -> $BACKUP"
    fi
fi

# Symlink so future `git pull`s apply automatically.
ln -sfn "$SRC" "$DEST"
echo "Linked $DEST -> $SRC"

# Reload if a tmux server is running.
if command -v tmux >/dev/null 2>&1 && tmux info >/dev/null 2>&1; then
    tmux source-file "$DEST"
    echo "Reloaded running tmux server."
else
    echo "Done. Start tmux (or run: tmux source-file ~/.tmux.conf)."
fi
