#!/usr/bin/env bash
#
# Install this tmux setup on a device:
#   1. symlink tmux.conf            -> ~/.tmux.conf
#   2. symlink agent-status.sh      -> ~/.claude/tmux-agent-status.sh
#   3. merge Claude Code hooks into ~/.claude/settings.json   (needs jq)
#   4. add Codex `notify` to       ~/.codex/config.toml
#
# Steps 3 and 4 are skipped automatically when the agent isn't installed
# (no ~/.claude or ~/.codex). Everything is idempotent — safe to re-run.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 1. tmux.conf ──────────────────────────────────────────────────────────
SRC="$SCRIPT_DIR/tmux.conf"
DEST="$HOME/.tmux.conf"

if [[ ! -f "$SRC" ]]; then
    echo "error: source config not found at $SRC" >&2
    exit 1
fi

if [[ -e "$DEST" || -L "$DEST" ]]; then
    if [[ -L "$DEST" && "$(readlink -f "$DEST")" == "$(readlink -f "$SRC")" ]]; then
        echo "tmux.conf: already linked."
    else
        BACKUP="$DEST.backup.$(date +%Y%m%d%H%M%S)"
        mv "$DEST" "$BACKUP"
        echo "tmux.conf: backed up existing -> $BACKUP"
    fi
fi
ln -sfn "$SRC" "$DEST"
echo "tmux.conf: linked $DEST -> $SRC"

# ── 2. agent-status dispatcher ────────────────────────────────────────────
# Deployed to a fixed path the agent configs reference.
AGENT_SRC="$SCRIPT_DIR/agent-status.sh"
AGENT_DEST="$HOME/.claude/tmux-agent-status.sh"

if [[ -d "$HOME/.claude" ]]; then
    ln -sfn "$AGENT_SRC" "$AGENT_DEST"
    chmod +x "$AGENT_SRC"
    echo "agent-status: linked $AGENT_DEST -> $AGENT_SRC"
else
    echo "agent-status: ~/.claude not found — skipping (install Claude Code first)."
fi

# ── 3. Claude Code hooks ──────────────────────────────────────────────────
SETTINGS="$HOME/.claude/settings.json"

if [[ -d "$HOME/.claude" ]]; then
    if ! command -v jq >/dev/null 2>&1; then
        echo "Claude hooks: jq not installed — skipping. Add the hooks manually (see README)."
    else
        [[ -f "$SETTINGS" ]] || echo '{}' > "$SETTINGS"
        CMD='$HOME/.claude/tmux-agent-status.sh'
        TMP="$(mktemp)"
        # For each event: drop any prior tmux-agent-status entry, then append a
        # fresh one. Re-running always converges to exactly one of each.
        jq --arg cmd "$CMD" '
          def ensure($evt; $state):
            .hooks[$evt] = (((.hooks[$evt] // [])
              | map(select(any(.hooks[]?; .command | test("tmux-agent-status.sh")) | not)))
              + [ { hooks: [ { type: "command", command: ($cmd + " cc " + $state) } ] } ]);
          .hooks = (.hooks // {})
          | ensure("UserPromptSubmit"; "working")
          | ensure("Notification"; "waiting")
          | ensure("Stop"; "done")
          | ensure("SessionEnd"; "clear")
        ' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
        echo "Claude hooks: merged into $SETTINGS"
    fi
fi

# ── 4. Codex notify ───────────────────────────────────────────────────────
CODEX="$HOME/.codex/config.toml"

if [[ -f "$CODEX" ]]; then
    if grep -qE '^[[:space:]]*notify[[:space:]]*=' "$CODEX"; then
        echo "Codex notify: already set in $CODEX — leaving as-is."
    else
        # Top-level keys must precede any [table]; line 1 is always valid.
        sed -i.bak "1i notify = [\"$AGENT_DEST\", \"cx\"]" "$CODEX"
        echo "Codex notify: added to $CODEX (backup at $CODEX.bak)"
    fi
else
    echo "Codex notify: ~/.codex/config.toml not found — skipping."
fi

# ── reload ────────────────────────────────────────────────────────────────
if command -v tmux >/dev/null 2>&1 && tmux info >/dev/null 2>&1; then
    tmux source-file "$DEST"
    echo "Reloaded running tmux server."
else
    echo "Done. Start tmux (or run: tmux source-file ~/.tmux.conf)."
fi

echo "Note: restart any running Claude Code sessions so the new hooks load."
