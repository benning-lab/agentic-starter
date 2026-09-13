# Security

## What this repo can do to your machine

The hooks in `hooks/` are shell scripts that Claude Code runs automatically — one at session start,
one at the end of each turn. `install.sh` writes their absolute paths into `~/.claude/settings.json`.
That is the whole mechanism, and it is worth understanding before you install:

- **Anything in `hooks/` runs without being invoked**, on every session in a project. Read the two
  scripts before installing. They are short.
- **`install.sh` symlinks rather than copies**, so a `git pull` changes what runs on your machine.
  That is the convenience, and it is also the risk: treat a pull here the way you would treat any
  other code you execute.
- **The installer never overwrites** a file you already have. It reports the collision and skips.

Nothing here sends anything anywhere. There is no network call in any script in this repo.

## Where session transcripts go

`capture-session.sh` writes a condensed transcript of each session to
`~/.claude-assistant/session-records/`, outside your project folder.

This is deliberate. A transcript is near-verbatim: half-formed reasoning, dead ends, what you said
about a result before you were sure, and what you said about other people. Cloud-drive permissions
inherit downward and cannot be subtracted, so a transcript written inside a project folder is
readable by everyone that folder is shared with — and a leading dot does not hide it, since
`.claude/` is invisible in Finder but an ordinary visible folder in the Drive web UI.

The property being relied on is **never shared**, not "not in a cloud drive". If your
`~/.claude-assistant/` is itself synced between your own machines, the records still travel and are
still safe, provided that folder is never shared with anyone.

If you do not want transcripts kept at all, do not install the `Stop` hook. The session-start hook
works fine on its own.

## Reporting a vulnerability

Open an issue for anything that is not sensitive. For something you would rather not post publicly,
contact John Benning through <https://benninglab.org/>.
