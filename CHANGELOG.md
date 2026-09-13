# Changelog

Notable changes to this repo. Dates are when the change landed.

## 2026-09-13

- `CONTRIBUTING.md`, `SECURITY.md` and this file added, ahead of the repo going public.
- Credit to [Chris Blattman](https://claudeblattman.com/) in the README, naming the specific
  conventions adapted from his published setup.

## 2026-09-12

Initial contents.

- `templates/` — the four project scaffolding files (`CLAUDE.md`, `PROJECT_INDEX.md`, `TODO.md`,
  `handoff.md`), with comments explaining what belongs in each.
- `bin/new-project.sh` — scaffolds a project from the templates; skips anything that already exists.
- `hooks/session-start-handoff.sh` — injects the project's handoff note at session start, with its
  age in days so a stale one is visible.
- `hooks/capture-session.sh` + `hooks/condense-transcript.py` — save a condensed transcript outside
  the project folder.
- `dotfiles/` — tmux and Ghostty config, and `shell-cc.zsh`, a fuzzy project launcher.
- `skills/build-corpus.py` — builds a text corpus from PDFs with PyMuPDF and checks the result for
  ligature loss, the silent failure that makes an extracted corpus unsearchable.
- `skills/README.md` and `skills/SKILL-template.md` — how to write a skill grounded in your own
  domain's sources.
- `install.sh` — symlinks into `~/.claude/`; `--check` reports without changing anything.
- `CONVENTIONS.md` — project layout, the cloud-drive sharing rule, and the working norms.
