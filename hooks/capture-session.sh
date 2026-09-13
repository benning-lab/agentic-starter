#!/usr/bin/env bash
# Stop hook: keep a condensed copy of the CURRENT session's transcript so the NEXT session
# can be grounded in what actually happened (real dialogue + actions), not just the handoff.
#
# The record is written to ~/.claude-assistant/session-records/<project>/last-session.md,
# deliberately OUTSIDE the project folder.
#
# Why: a transcript is near-verbatim. It holds your half-formed reasoning, the dead ends, and
# whatever you said about a result before you were sure. Cloud-drive permissions inherit
# downward and cannot be subtracted, so a transcript written inside a project folder is
# readable by everyone that folder is shared with. A leading dot does not help: `.claude/` is
# hidden in Finder but an ordinary visible folder in the Drive web UI.
#
# The property being relied on is "never shared", NOT "not in a cloud drive". If your
# ~/.claude-assistant/ is itself synced, records still travel between your own machines and
# are still safe, as long as that folder is never shared with anyone. handoff.md stays the
# artifact meant to be read by other people.
#
# Fires after every assistant turn. The transcript on disk is always current, so each fire
# re-condenses it and the final turn leaves a complete record. All heavy work is backgrounded
# so the turn is never blocked, and the script always exits 0 fast.
set -u

INPUT=$(cat 2>/dev/null)

# One python call: parse stdin JSON, walk up for the nearest non-global CLAUDE.md,
# resolve its symlink to the real project dir. Emit "PROJ<TAB>TRANSCRIPT".
IFS=$'\t' read -r PROJ TRANSCRIPT < <(printf '%s' "$INPUT" | python3 -c '
import json,sys,os
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
tp=d.get("transcript_path","") or ""
cwd=d.get("cwd","") or os.getcwd()
if not tp or not os.path.isfile(tp): sys.exit(0)
dir=cwd
for _ in range(12):
    cm=os.path.join(dir,"CLAUDE.md")
    if os.path.exists(cm):
        if os.path.realpath(dir)==os.path.realpath(os.path.expanduser("~/.claude")): sys.exit(0)
        print(os.path.dirname(os.path.realpath(cm))+"\t"+tp); sys.exit(0)
    parent=os.path.dirname(dir)
    if parent==dir: break
    dir=parent
sys.exit(0)
' 2>/dev/null)

[ -n "${PROJ:-}" ] && [ -n "${TRANSCRIPT:-}" ] && [ -d "$PROJ" ] || exit 0

# Slug from the project dir name, so records are one-per-project and never collide.
SLUG=$(printf '%s' "$(basename "$PROJ")" | tr -c 'A-Za-z0-9._-' '_')
RECORD_DIR="$HOME/.claude-assistant/session-records/$SLUG"
OUT="$RECORD_DIR/last-session.md"
SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/condense-transcript.py"
[ -f "$SCRIPT" ] || exit 0

# Heavy work backgrounded; atomic write; never blocks the turn.
(
  mkdir -p "$RECORD_DIR" 2>/dev/null
  printf '%s\n' "$PROJ" > "$RECORD_DIR/.project-path" 2>/dev/null
  tmp="$OUT.tmp.$$"
  if python3 "$SCRIPT" "$TRANSCRIPT" >"$tmp" 2>/dev/null && [ -s "$tmp" ]; then
    mv -f "$tmp" "$OUT" 2>/dev/null
  else
    rm -f "$tmp" 2>/dev/null
  fi
) >/dev/null 2>&1 &

exit 0
