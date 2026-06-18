#!/usr/bin/env bash
# Reflect coding-agent state in tmux: per-window tab markers + desktop
# notification when an agent starts waiting for you.
#
# Per pane:    @pane_agent = "<type>:<state>"   (cc:working, cx:idle, ...)
#              type = cc (Claude Code) | cx (Codex)
# Per window:  @win_state  = the window's most urgent agent state
#              (waiting > working > idle), used to color the tab.
# Global:      @agents_summary = "cc [1]working | cx [1]idle" (status-right).
#
# Modes:
#   tmux-agent-status.sh cc working|waiting|done|clear   (Claude Code hook)
#   tmux-agent-status.sh cx '<json-event>'               (Codex notify)
#   tmux-agent-status.sh refresh                         (recompute everything)
#   tmux-agent-status.sh summary                         (print global summary)

rank_of() {  # urgency: waiting beats working beats idle
  case "$1" in waiting) echo 3 ;; working) echo 2 ;; idle) echo 1 ;; *) echo 0 ;; esac
}

# Single pass over all panes -> global summary + per-window dominant state.
recompute() {
  local wid val st r type seg c w state out=""
  declare -A cnt winrank
  while IFS=' ' read -r wid val; do
    [ -z "$val" ] && continue
    cnt["$val"]=$(( ${cnt["$val"]:-0} + 1 ))
    st="${val#*:}"
    r=$(rank_of "$st")
    [ "$r" -gt "${winrank[$wid]:-0}" ] && winrank["$wid"]=$r
  done < <(tmux list-panes -a -F '#{window_id} #{@pane_agent}' 2>/dev/null)

  # Global summary, grouped by type. Plain text only (no colors): the status
  # bar stays green with black text.
  for type in cc cx; do
    seg=""
    for st in working waiting idle; do
      c=${cnt["$type:$st"]:-0}
      [ "$c" -gt 0 ] && seg="$seg [$c]$st"
    done
    if [ -n "$seg" ]; then
      [ -n "$out" ] && out="$out | "
      out="$out$type$seg"
    fi
  done
  tmux set-option -g @agents_summary "$out" 2>/dev/null

  # Per-window dominant state (drives tab color in tmux.conf).
  for w in $(tmux list-windows -a -F '#{window_id}' 2>/dev/null); do
    case "${winrank[$w]:-0}" in
      3) state=waiting ;; 2) state=working ;; 1) state=idle ;; *) state="" ;;
    esac
    if [ -z "$state" ]; then
      tmux set-option -wu -t "$w" @win_state 2>/dev/null
    else
      tmux set-option -w -t "$w" @win_state "$state" 2>/dev/null
    fi
  done
  tmux refresh-client -S 2>/dev/null
}

case "$1" in
  summary) tmux show -gv @agents_summary 2>/dev/null; exit 0 ;;
  refresh) recompute; exit 0 ;;
esac

# Otherwise: a per-pane state update from an agent hook. Needs a pane.
[ -z "$TMUX_PANE" ] && exit 0

agent="$1"          # cc | cx
arg="$2"
case "$arg" in
  working|waiting|done|clear)
    state="$arg"
    ;;
  *)
    etype=$(printf '%s' "$arg" | sed -n 's/.*"type"[: ]*"\([^"]*\)".*/\1/p')
    case "$etype" in
      agent-turn-complete) state="done" ;;
      *)                   state="waiting" ;;
    esac
    ;;
esac

case "$state" in
  working) label="working" ;;
  waiting) label="waiting" ;;
  done)    label="idle"    ;;
  *)       label=""        ;;
esac

# Remember the previous state so we only notify on the transition INTO waiting.
old=$(tmux show -pv -t "$TMUX_PANE" @pane_agent 2>/dev/null)

if [ -z "$label" ]; then
  tmux set-option -pu -t "$TMUX_PANE" @pane_agent 2>/dev/null
else
  tmux set-option -p -t "$TMUX_PANE" @pane_agent "${agent}:${label}" 2>/dev/null
fi

# Desktop notification, naming the window (and pane, if the window is split),
# only when it just became waiting.
if [ "$label" = waiting ] && [ "${old#*:}" != waiting ]; then
  case "$agent" in cc) who="Claude" ;; cx) who="Codex" ;; *) who="$agent" ;; esac
  # One query; '|' delimited so a window name with spaces stays intact.
  info=$(tmux display-message -p -t "$TMUX_PANE" \
    '#{window_index}:#{window_name}|#{window_panes}|#{pane_index}|#{pane_tty}' 2>/dev/null)
  wname=${info%%|*}; rest=${info#*|}
  panes=${rest%%|*}; rest=${rest#*|}
  pidx=${rest%%|*};  tty=${rest##*|}
  loc="$wname"; [ "${panes:-1}" -gt 1 ] && loc="$wname pane $pidx"
  # OSC 9 notification wrapped for tmux passthrough (needs allow-passthrough on).
  [ -n "$tty" ] && printf '\ePtmux;\e\e]9;%s\a\e\\' "$who waiting — $loc" > "$tty" 2>/dev/null
fi

recompute
exit 0
