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
| `S`       | Swap with selected pane           |

In copy mode (vi keys): `v` starts a selection, `y` copies and exits.
