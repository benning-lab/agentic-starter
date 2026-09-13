#!/usr/bin/env bash
# SessionStart hook: inject the project's handoff note into a new session's context.
#
# A new Claude Code session starts with no knowledge of the last one. This hook fixes that
# by finding the project you are in and pasting its handoff note into the opening context.
#
# How it finds the project: walk up from the current directory looking for the nearest
# CLAUDE.md, then resolve symlinks, so a project whose CLAUDE.md is a link to a canonical
# copy elsewhere still resolves to that canonical folder. The global ~/.claude/CLAUDE.md is
# skipped, because being outside any project is not a project.
#
# Silent no-op when there is no project or no handoff. A hook that prints noise on every
# session start is a hook you will turn off.
set -u

dir="$PWD"
depth=0

while [ "$depth" -lt 12 ]; do
  if [ -e "$dir/CLAUDE.md" ]; then
    # The global config directory is not a project.
    [ "$dir" = "$HOME/.claude" ] && exit 0

    real=$(python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$dir/CLAUDE.md" 2>/dev/null)
    [ -z "$real" ] && real="$dir/CLAUDE.md"
    project_dir=$(dirname "$real")

    [ -f "$project_dir/handoff.md" ] || exit 0

    # Age is printed so a stale handoff is visible rather than silently believed.
    age=$(python3 -c "
import os,time
try: print(int((time.time()-os.path.getmtime('$project_dir/handoff.md'))//86400))
except Exception: print('?')
" 2>/dev/null)

    printf '=== Handoff from the previous session (%s, %s day(s) old) ===\n' \
      "$(basename "$project_dir")" "$age"
    cat "$project_dir/handoff.md"
    printf '\n=== end handoff ===\n'
    exit 0
  fi
  parent=$(dirname "$dir")
  [ "$parent" = "$dir" ] && break
  dir="$parent"
  depth=$((depth + 1))
done

exit 0
