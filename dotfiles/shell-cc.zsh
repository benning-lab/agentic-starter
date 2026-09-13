# cc — open a Claude Code session for a project, in tmux, by fuzzy name.
#
#   cc                    attach to the "cc" tmux session
#   cc spacetime          fuzzy-match a project folder, open a window there, start Claude
#   cc some/path          an argument containing "/" is treated as a literal path
#   ccr spacetime         same, but `claude --resume` (the past-session picker)
#
# Why tmux: it owns the terminal, so sessions survive closing the window and you can keep
# one live session per project instead of one at a time.
#
# Install: source this from ~/.zshrc and set CC_PROJECT_ROOTS to where your projects live.
#
#   export CC_PROJECT_ROOTS="$HOME/projects:$HOME/work/active"
#   source /path/to/agentic-starter/dotfiles/shell-cc.zsh
#
# Requires zsh and tmux (`brew install tmux`).

# Colon-separated list of directories whose immediate children are projects.
: ${CC_PROJECT_ROOTS:="$HOME/projects"}

# The command each new window runs. Override to change permission mode, add flags, etc.
: ${CC_CLAUDE_CMD:='claude'}

# Name of the tmux session that holds all the windows.
: ${CC_SESSION:='cc'}

# Fuzzy-resolve a name to a project directory.
# Matching is case- and punctuation-insensitive, and a leading YYYY_ or YYYY- is ignored, so
# `cc spacetime` finds `2026_CxSpaceTime`. One match wins; an exact match breaks a tie
# between several substring matches; otherwise the candidates are listed and nothing opens.
# Return: 0 resolved (path printed), 1 no match, 2 ambiguous (list printed to stderr).
_cc_resolve() {
  setopt local_options bare_glob_qual no_sh_glob
  local q="$1"
  local qn="${(L)q//[^a-zA-Z0-9]/}"
  local -a matches roots
  local root d base full short

  roots=("${(@s/:/)CC_PROJECT_ROOTS}")
  for root in "${roots[@]}"; do
    [ -d "$root" ] || continue
    for d in "$root"/*(N/); do
      base="${d:t}"
      full="${(L)base//[^a-zA-Z0-9]/}"
      short="${(L)${base#[0-9][0-9][0-9][0-9][_-]}//[^a-zA-Z0-9]/}"
      [[ "$full" == *"$qn"* || "$short" == *"$qn"* ]] && matches+=("$d")
    done
  done

  matches=(${(u)matches})
  (( ${#matches} == 0 )) && return 1
  if (( ${#matches} == 1 )); then print -r -- "${matches[1]}"; return 0; fi

  # Several substring matches: an exact name match, if there is exactly one, wins.
  local -a exact
  local c cbase
  for c in "${matches[@]}"; do
    cbase="${c:t}"
    [[ "${(L)cbase//[^a-zA-Z0-9]/}" == "$qn" || \
       "${(L)${cbase#[0-9][0-9][0-9][0-9][_-]}//[^a-zA-Z0-9]/}" == "$qn" ]] && exact+=("$c")
  done
  if (( ${#exact} == 1 )); then print -r -- "${exact[1]}"; return 0; fi

  print -u2 "cc: '$q' matches several projects:"
  for c in "${matches[@]}"; do print -u2 "  ${c:t}"; done
  return 2
}

cc() {
  local launch="$CC_CLAUDE_CMD" want_resume=0

  # A trailing "resume" or "r" switches to the session picker.
  if [ "$#" -gt 0 ] && { [ "${@[-1]}" = "resume" ] || [ "${@[-1]}" = "r" ]; }; then
    want_resume=1; launch="$CC_CLAUDE_CMD --resume"; set -- "${@[1,-2]}"
  fi

  if ! tmux has-session -t "$CC_SESSION" 2>/dev/null; then
    tmux new-session -d -s "$CC_SESSION" -n main
    tmux send-keys -t "$CC_SESSION:main" "$CC_CLAUDE_CMD" C-m
  fi

  if [ -n "${1:-}" ]; then
    local dir rc
    if [ -d "$1" ]; then
      dir="$1"
    else
      dir="$(_cc_resolve "$1")"; rc=$?
      if (( rc != 0 )); then
        (( rc == 1 )) && print -u2 "cc: no project matching '$1' under $CC_PROJECT_ROOTS"
        return 1
      fi
    fi

    local name="${dir:t}" existing=""
    # One window per project: if it is already open, switch to it instead of duplicating.
    # Resume is exempt, since each --resume is a throwaway picker window.
    (( want_resume == 0 )) && existing="$(tmux list-windows -t "$CC_SESSION" \
        -F '#{window_id} #{window_name}' 2>/dev/null | awk -v n="$name" '$2==n{print $1; exit}')"

    if [ -n "$existing" ]; then
      tmux select-window -t "$existing"
    else
      # Target the new window by ID, not name, because names can collide.
      local win
      win="$(tmux new-window -t "$CC_SESSION" -n "$name" -c "$dir" -P -F '#{window_id}')"
      tmux send-keys -t "$win" "$launch" C-m
    fi
  elif (( want_resume )); then
    local win
    win="$(tmux new-window -t "$CC_SESSION" -c "$PWD" -P -F '#{window_id}')"
    tmux send-keys -t "$win" "$launch" C-m
  fi

  if [ -n "${TMUX:-}" ]; then
    tmux switch-client -t "$CC_SESSION"
  else
    tmux attach -t "$CC_SESSION"
  fi
}

ccr() { cc "$@" resume; }
