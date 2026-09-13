# agentic-starter

[![check](https://github.com/benning-lab/agentic-starter/actions/workflows/check.yml/badge.svg)](https://github.com/benning-lab/agentic-starter/actions/workflows/check.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

The working parts of a research Claude Code setup: the files that give it project memory, the
hooks that carry context between sessions, a terminal config for running several sessions at
once, and a recipe for teaching it a technical domain it gets wrong.

Written for academic research, by [John Benning](https://benninglab.org) (Cornell EEB). The
guides that explain *why* each piece is shaped this way are at
**<https://benninglab.org/agentic/>**; this repo is the files.

Nothing here is required to use Claude Code. Start with the four files and add the rest when a
specific thing annoys you.

```bash
git clone https://github.com/benning-lab/agentic-starter.git
cd agentic-starter
./install.sh --check      # see what it would do
./install.sh              # do it
```

The installer symlinks into `~/.claude/`, so updating is `git pull` and nothing else. It never
overwrites a file you already have: it reports the collision and skips.

## What is here

| | |
|---|---|
| `CONVENTIONS.md` | Project layout, the four files, and the working norms. **Read this first.** |
| `templates/` | The four files, with comments explaining what belongs in each |
| `bin/new-project.sh` | Scaffold a project from the templates |
| `hooks/` | Inject the last session's handoff at startup; save a condensed transcript at the end |
| `dotfiles/` | tmux + Ghostty config, and `cc`, a fuzzy project launcher |
| `skills/` | How to build a skill that knows your domain, plus a PDF corpus builder |
| `settings.template.json` | A starting `~/.claude/settings.json` if you have none |

## Start a project

```bash
./bin/new-project.sh ~/projects/2026_MyProject --name "Clarkia demography" --code cx-demo
```

Writes `CLAUDE.md`, `PROJECT_INDEX.md` and `TODO.md`, and skips anything that already exists.
Then open `CLAUDE.md` and fill it in; that file is most of the value.

## The hooks

Two hooks, both optional, both solving the same problem: a new session knows nothing about the
last one.

**`session-start-handoff.sh`** walks up from your working directory to the nearest `CLAUDE.md`,
resolves symlinks to find the real project folder, and pastes `handoff.md` into the opening
context with its age. A stale handoff is then visible rather than silently believed.

**`capture-session.sh`** writes a condensed transcript at the end of each session — the real
dialogue plus one line per tool call, with thinking blocks and tool output dropped. It goes to
`~/.claude-assistant/session-records/<project>/`, deliberately **outside** the project folder,
because a transcript is near-verbatim and a project folder can be shared. The reasoning is in
the header of the script.

Neither prints anything when there is nothing to say. A hook that produces noise on every
session start is a hook you will turn off within a week.

## The terminal setup

Optional, and the thing that changes daily use most if you work on several projects.

`dotfiles/shell-cc.zsh` defines `cc`: fuzzy-match a project folder by name, open a tmux window
there, start Claude Code in it. One live session per project, all of them persisting, instead of
one at a time.

```bash
export CC_PROJECT_ROOTS="$HOME/projects:$HOME/work/active"
source /path/to/agentic-starter/dotfiles/shell-cc.zsh

cc spacetime       # matches 2026_CxSpaceTime, opens a window, starts Claude
cc                 # attach to the session
ccr spacetime      # same, but claude --resume
```

Matching ignores case, punctuation and a leading `YYYY_`. An exact name breaks a tie between
several substring matches; otherwise it lists the candidates and opens nothing.

tmux is what makes the sessions persist, because tmux owns the terminal rather than the window
you are looking at. `brew install tmux`, then `./install.sh --dotfiles`.

## Skills

A skill is a folder Claude Code loads on demand, so it can carry a large reference corpus
without costing context until it is used. The case for writing one is narrow and specific: the
model's knowledge of your domain is either **stale** (it writes code against an API that was
renamed two versions ago, which parses clean and fails at runtime) or **in the wrong register**
(the documentation is correct and written for a statistician).

`skills/README.md` is the recipe, including the parts that are not obvious:

- `build-corpus.py` extracts PDFs with PyMuPDF and checks the result, because `pdftotext` drops
  fi/fl ligatures and turns `fitness` into ` tness` — the exact words you would search for.
- Prefer LaTeX or Markdown source over the rendered PDF when it exists.
- Syntax checking is not verification. Unexecuted output is not finished.
- For statistical fitting, "it ran" is not the bar either: a fit can converge to garbage and
  report no error.
- For expert-review skills, keep the lenses separate and let them disagree. A blend is a generic
  skeptic, which is what you already had.

## Credit

The shape of this — publishing a working setup as a public resource, with the actual files
attached rather than described — I took from **[Chris Blattman](https://claudeblattman.com/)**
(political economist, UChicago Harris), whose site is where I learned most of what I know about
running research through a coding agent. Several conventions here started as his and were adapted
rather than invented: the project-context file as the centre of the setup, writing procedures down
as reusable commands, and publishing the files so someone can copy a working thing instead of
assembling one. His site is MIT-licensed and so is this.

Read his first if you are starting out: <https://claudeblattman.com/>

The prose guides that accompany this repo are at <https://benninglab.org/agentic/>.

## Licence

MIT. Use any of it.
