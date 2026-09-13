#!/usr/bin/env bash
# Install the hooks and settings from this repo into ~/.claude/.
#
# Symlinks rather than copies, so `git pull` here updates your setup with no reinstall.
# Never overwrites an existing real file — it reports the collision and skips.
#
#   ./install.sh             install / update
#   ./install.sh --check     report what would happen, change nothing
#   ./install.sh --dotfiles  also link tmux.conf and the Ghostty config (opt-in)
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
RECORDS="$HOME/.claude-assistant/session-records"
DRY=0; DOTFILES=0

for a in "$@"; do
  case "$a" in
    --check) DRY=1 ;;
    --dotfiles) DOTFILES=1 ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

ok=0; collided=0

say()   { printf '  %s\n' "$*"; }
head_() { printf '\n%s\n' "$*"; }

link() {                       # link <target> <linkname>
  local target="$1" name="$2"
  if [ -L "$name" ]; then
    if [ "$(readlink "$name")" = "$target" ]; then
      say "ok        $(basename "$name") (already linked)"; ok=$((ok+1)); return
    fi
    if [ "$DRY" = 1 ]; then say "would relink $(basename "$name")"; else
      ln -sfn "$target" "$name"; say "relinked  $(basename "$name")"; fi
    ok=$((ok+1)); return
  fi
  if [ -e "$name" ]; then
    say "COLLISION $(basename "$name") exists and is not a symlink — skipping."
    say "          move it aside and re-run if you want this repo's version."
    collided=$((collided+1)); return
  fi
  if [ "$DRY" = 1 ]; then say "would link   $(basename "$name")"; else
    ln -sfn "$target" "$name"; say "linked    $(basename "$name")"; fi
  ok=$((ok+1))
}

head_ "agentic-starter → $CLAUDE_DIR"
[ "$DRY" = 1 ] && say "(--check: nothing will be changed)"

if [ "$DRY" = 0 ]; then
  mkdir -p "$CLAUDE_DIR/commands" "$CLAUDE_DIR/skills" "$RECORDS"
fi

# --- hooks -----------------------------------------------------------------
head_ "Hooks"
if [ "$DRY" = 0 ]; then chmod +x "$REPO"/hooks/*.sh 2>/dev/null; fi
say "scripts live in $REPO/hooks and are referenced by absolute path from settings.json"
say "session records → $RECORDS"
say "(that folder is never shared with anyone — see hooks/capture-session.sh for why)"

# --- skills (per-item, so your own are untouched) ---------------------------
head_ "Skills"
shopt -s nullglob
found=0
for d in "$REPO"/skills/*/; do
  [ -f "$d/SKILL.md" ] || continue
  found=1; link "${d%/}" "$CLAUDE_DIR/skills/$(basename "${d%/}")"
done
[ "$found" = 0 ] && say "(none here yet — skills/README.md is the recipe for writing one)"

# --- settings --------------------------------------------------------------
head_ "Settings"
SETTINGS="$CLAUDE_DIR/settings.json"
if [ -e "$SETTINGS" ]; then
  say "$SETTINGS exists — not touching it."
  say "To turn the hooks on, merge the \"hooks\" block from:"
  say "  $REPO/settings.template.json"
  say "replacing __REPO__ with:"
  say "  $REPO"
else
  if [ "$DRY" = 0 ]; then
    sed "s|__REPO__|$REPO|g" "$REPO/settings.template.json" > "$SETTINGS"
    say "wrote $SETTINGS from the template"
  else
    say "would write $SETTINGS from the template"
  fi
fi

# --- dotfiles (opt-in) -----------------------------------------------------
if [ "$DOTFILES" = 1 ]; then
  head_ "Dotfiles"
  link "$REPO/dotfiles/tmux.conf" "$HOME/.tmux.conf"
  if [ "$DRY" = 0 ]; then mkdir -p "$HOME/.config/ghostty"; fi
  link "$REPO/dotfiles/ghostty.config" "$HOME/.config/ghostty/config"
  say ""
  say "For the cc launcher, add to ~/.zshrc:"
  say "  export CC_PROJECT_ROOTS=\"\$HOME/projects\""
  say "  source $REPO/dotfiles/shell-cc.zsh"
else
  head_ "Dotfiles"
  say "skipped (pass --dotfiles to link tmux.conf and the Ghostty config)"
fi

head_ "Summary"
say "linked: $ok   collisions: $collided"
if [ "$collided" -gt 0 ]; then
  say ""
  say "Some items were skipped because you already have your own version."
  say "Nothing was overwritten."
fi
head_ "Next: read CONVENTIONS.md, then restart any running Claude Code session."
printf '\n'
