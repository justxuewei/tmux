# tmux

My personal tmux configuration.

## Install

```bash
./install.sh
```

The script symlinks `tmux.conf` to `~/.tmux.conf`, backing up any existing
config to `~/.tmux.conf.backup.<timestamp>` first. Because it's a symlink,
future `git pull`s apply automatically. If a tmux server is already running,
the script reloads it for you.

It also wires up the **coding-agent status indicator** (see below) when the
agents are present: it symlinks `agent-status.sh` to
`~/.claude/tmux-agent-status.sh`, merges hooks into `~/.claude/settings.json`
(needs `jq`), and adds `notify` to `~/.codex/config.toml`. Steps are skipped
when an agent isn't installed, and the whole script is idempotent — safe to
re-run on every device. Restart any running Claude Code sessions afterwards so
the new hooks load.

## Coding-agent status

Three signals, fed by Claude Code / Codex hooks that call `agent-status.sh`:

1. **Per-window tab markers** — each window tab gets a symbol for its agent's
   most urgent state, so you can see *which* window needs you and press its
   number to jump there. No colors are used (green bar, black text); the symbol
   carries the state, and the current window is wrapped in `[brackets]`:

   | State     | Tab   |
   |-----------|-------|
   | `waiting` | `●`   |
   | `working` | `◐`   |
   | `idle`    | `✓`   |

2. **Desktop notification on waiting** — when an agent transitions into
   `waiting`, the script sends an OSC 9 notification (named with the window)
   through tmux passthrough to the terminal, e.g. *"Claude waiting — 3:codex"*.
   Requires `set -g allow-passthrough on` (in `tmux.conf`) and a terminal that
   shows OSC 9 notifications (e.g. iTerm2).

3. **Global summary** on the right of the status line — totals at a glance:
   ```
   cc [1]working | cx [1]idle
   ```
   (`cc` = Claude Code, `cx` = Codex.)

### Multiple agents in one window (one per pane)

The tab symbol shows only the window's *most urgent* state, so when a window is
split the agent state is also shown per pane, in the pane border:

```
┌ 1:claude [cc:working] ─┐┌ 2:codex [cx:waiting] ─┐
```

The border line appears only while a window is split (a `window-layout-changed`
hook toggles `pane-border-status`), so single-pane windows keep their full
height. The global summary counts every agent (e.g. `cc [2]working`), and the
waiting notification names the pane too when the window is split.

How it works: each agent pane is tagged `@pane_agent = "cc:working"`; a single
pass records each window's dominant state (`@win_state`, drives the tab symbol)
and the global `@agents_summary`. tmux `pane-exited` / `pane-died` hooks
recompute when an agent's pane closes, so finished agents drop out. Agents
launched outside tmux are ignored.

## Key bindings

The prefix is the default `C-b`. All bindings below are pressed *after* the
prefix.

| Keys      | Action                            |
|-----------|-----------------------------------|
| `r`       | Reload config                     |
| `\|`      | Split horizontally (same path)    |
| `-`       | Split vertically (same path)      |
| `c`       | New window (same path)            |
| `h/j/k/l` | Move between panes (vim-style)    |
| `H/J/K/L` | Resize the current pane           |

In copy mode (vi keys): `v` starts a selection, `y` copies and exits.
