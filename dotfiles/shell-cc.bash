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
# Install: source this from ~/.bashrc and set CC_PROJECT_ROOTS to where your projects live.
#
#   export CC_PROJECT_ROOTS="$HOME/projects:$HOME/work/active"
#   source /path/to/agentic-starter/dotfiles/shell-cc.bash
#
# Requires bash (including the 3.2 that ships with macOS) and tmux (`brew install tmux`).
# This is a bash port of shell-cc.zsh; behavior matches it exactly.

# Colon-separated list of directories whose immediate children are projects.
: ${CC_PROJECT_ROOTS:="$HOME/projects"}

# The command each new window runs. Override to change permission mode, add flags, etc.
: ${CC_CLAUDE_CMD:='claude'}

# Name of the tmux session that holds all the windows.
: ${CC_SESSION:='cc'}

# Lowercase a string and strip everything but letters/digits, for fuzzy comparison.
_cc_norm() {
  printf '%s' "$1" | tr 'A-Z' 'a-z' | LC_ALL=C tr -cd 'a-z0-9'
}

# Fuzzy-resolve a name to a project directory.
# Matching is case- and punctuation-insensitive, and a leading YYYY_ or YYYY- is ignored, so
# `cc spacetime` finds `2026_CxSpaceTime`. One match wins; an exact match breaks a tie
# between several substring matches; otherwise the candidates are listed and nothing opens.
# Return: 0 resolved (path printed), 1 no match, 2 ambiguous (list printed to stderr).
_cc_resolve() {
  local q="$1"
  local qn
  qn="$(_cc_norm "$q")"
  local -a roots=()
  IFS=':' read -ra roots <<< "$CC_PROJECT_ROOTS"

  local -a matches=()
  local root d base full short
  for root in "${roots[@]}"; do
    [ -d "$root" ] || continue
    for d in "$root"/*/; do
      [ -d "$d" ] || continue
      d="${d%/}"
      base="${d##*/}"
      full="$(_cc_norm "$base")"
      short="$(_cc_norm "${base#[0-9][0-9][0-9][0-9][_-]}")"
      case "$full" in
        *"$qn"*) matches+=("$d"); continue ;;
      esac
      case "$short" in
        *"$qn"*) matches+=("$d") ;;
      esac
    done
  done

  # Dedupe, preserving order (a name could appear under more than one root).
  local -a uniq=()
  local m u seen
  for m in "${matches[@]}"; do
    seen=0
    for u in "${uniq[@]}"; do [ "$u" = "$m" ] && { seen=1; break; }; done
    [ "$seen" -eq 0 ] && uniq+=("$m")
  done
  matches=("${uniq[@]}")

  [ "${#matches[@]}" -eq 0 ] && return 1
  if [ "${#matches[@]}" -eq 1 ]; then printf '%s\n' "${matches[0]}"; return 0; fi

  # Several substring matches: an exact name match, if there is exactly one, wins.
  local -a exact=()
  local c cbase cfull cshort
  for c in "${matches[@]}"; do
    cbase="${c##*/}"
    cfull="$(_cc_norm "$cbase")"
    cshort="$(_cc_norm "${cbase#[0-9][0-9][0-9][0-9][_-]}")"
    if [ "$cfull" = "$qn" ] || [ "$cshort" = "$qn" ]; then exact+=("$c"); fi
  done
  if [ "${#exact[@]}" -eq 1 ]; then printf '%s\n' "${exact[0]}"; return 0; fi

  echo "cc: '$q' matches several projects:" >&2
  for c in "${matches[@]}"; do echo "  ${c##*/}" >&2; done
  return 2
}

cc() {
  local launch="$CC_CLAUDE_CMD" want_resume=0

  # A trailing "resume" or "r" switches to the session picker.
  if [ "$#" -gt 0 ]; then
    local last="${@: -1}"
    if [ "$last" = "resume" ] || [ "$last" = "r" ]; then
      want_resume=1
      launch="$CC_CLAUDE_CMD --resume"
      set -- "${@:1:$(($#-1))}"
    fi
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
      if [ "$rc" -ne 0 ]; then
        [ "$rc" -eq 1 ] && echo "cc: no project matching '$1' under $CC_PROJECT_ROOTS" >&2
        return 1
      fi
    fi

    local name="${dir##*/}" existing=""
    # One window per project: if it is already open, switch to it instead of duplicating.
    # Resume is exempt, since each --resume is a throwaway picker window.
    if [ "$want_resume" -eq 0 ]; then
      existing="$(tmux list-windows -t "$CC_SESSION" \
          -F '#{window_id} #{window_name}' 2>/dev/null | awk -v n="$name" '$2==n{print $1; exit}')"
    fi

    if [ -n "$existing" ]; then
      tmux select-window -t "$existing"
    else
      # Target the new window by ID, not name, because names can collide.
      local win
      win="$(tmux new-window -t "$CC_SESSION" -n "$name" -c "$dir" -P -F '#{window_id}')"
      tmux send-keys -t "$win" "$launch" C-m
    fi
  elif [ "$want_resume" -eq 1 ]; then
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
