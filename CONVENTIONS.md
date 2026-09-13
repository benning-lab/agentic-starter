# Project conventions

How a project folder is laid out, and why each piece is there. Copy what is useful; the only
part that really matters is the four files.

---

## The four files

A coding agent starts every session knowing nothing about your project. You can re-explain it
every time, or you can write it down once. These four files are that, split by how fast each
kind of information changes.

| File | Holds | Changes |
|---|---|---|
| `CLAUDE.md` | The system, the data, the people, the conventions, settled decisions | Rarely |
| `PROJECT_INDEX.md` | Overview, dated status, key links, decision log | Monthly |
| `TODO.md` | Live kanban by workstream | Constantly |
| `handoff.md` | What the last session did and what is open | Every session |

`CLAUDE.md` is loaded automatically at the start of every session in the folder. The other
three are read when they are relevant, or injected by a hook.

The split is the whole trick. One file holding all four kinds of information goes stale in the
parts that change fastest, and once any part of it is stale you stop trusting the rest.

### What goes wrong

**`CLAUDE.md` drifting into a status report.** It is loaded every time, so it is tempting to
put this week's work in it. Then it is wrong next week, and a wrong context file is worse than
no context file, because the agent believes it. Keep it to things that stay true.

**An undated status line.** `PROJECT_INDEX.md` without a date reads as current forever. Date
it on every edit.

**Deleting finished work.** Move items to Done rather than removing them. Done is what you read
when you have to write a progress report or reconstruct when something happened.

**Skipping the decision log.** This is the highest-value section and the easiest to skip. When
a choice gets made — a cutoff, a subset, a model, a protocol variant — record the date and the
**reason**. A year later the reason is the only part that matters, and it is always the part
nobody wrote down.

---

## Project layout

```
2026_Example/
├── CLAUDE.md              durable context, loaded every session
├── PROJECT_INDEX.md       overview, status, decision log
├── TODO.md                live kanban
├── handoff.md             written at session end
├── Data/                  raw and derived, clearly separated
├── Analysis/              scripts
├── Manuscript/
└── Meetings/              notes, and anything worth keeping from a call or thread
```

If the project has code in a git repo, keep **one** canonical copy of `CLAUDE.md` and `TODO.md`
and have the repo hold relative symlinks to them rather than duplicates:

```bash
cd ~/repos/<project>
ln -sfn "../../path/to/2026_Example/CLAUDE.md" CLAUDE.md
ln -sfn "../../path/to/2026_Example/TODO.md" TODO.md
```

Relative, so they resolve on any machine. Commit them. Two copies of a context file means one
of them is wrong and you will not know which.

---

## If the project is shared from a cloud drive

Google Drive permissions inherit downward and **cannot be subtracted**. You cannot share a
folder and hold one subfolder back: there is no exclude mechanism, and a leading dot hides a
folder in Finder but not in the Drive web UI. `.claude/` is an ordinary visible folder there.

Read the rule backwards and it becomes the fix: access to a child grants nothing about its
parent. So do not try to carve privacy out of a shared folder. Nest the shared folder inside a
private one:

```
2026_Example/                  private. your working files. never shared.
├── CLAUDE.md                  private context
├── handoff.md                 session record
└── example-shared/            the shared unit. one grant, per person.
    ├── CLAUDE.md              written to stand alone
    ├── PROJECT_INDEX.md, TODO.md
    └── Data/  Analysis/  Manuscript/
```

This fails safe: anything new lands private unless you deliberately move it into the shared
folder. Sharing becomes that move and nothing else.

Migrate a project to this shape only when it is actually about to be shared. Moving content
down a level breaks relative paths, so it is not free.

**Session transcripts never go in a project folder**, shared or not. They are near-verbatim:
your half-formed reasoning, the dead ends, what you said about a result before you were sure,
what you said about a person. The hooks in this repo write them to
`~/.claude-assistant/session-records/` for that reason. `handoff.md` is the artifact meant to
be read by other people; the transcript is raw material.

---

## Working norms

These are the rules that decide whether the output is trustworthy. They are not about the tool.

- **Start the agent from inside the project folder** so it loads that project's `CLAUDE.md`.

- **Never chase a result.** If an analysis choice — which population is "core", which cutoff,
  which subset, which model — happens to favour the hypothesis, that is a reason for more
  scrutiny, not less. Every such choice must be justified independently of the result it
  produces. Surface the sensitivity; do not select the favourable option.

- **Showing something is not letting it count.** Weak evidence can be displayed and must not
  drive a ranking, a score or a target. Decide up front what quality of evidence is allowed to
  influence the output, and say so.

- **Check claims against the source.** The model is confident when it is wrong, and confidence
  does not track accuracy. Anything going into a manuscript, a grant, or an email to a
  collaborator gets verified against the actual paper, the actual data, the actual output.

- **Evidence goes in the project the moment it is produced.** If a script or a run is the basis
  for a claim in a report, it belongs in the project folder, not a temp directory. Test: if
  someone asks next month how you know this, what do you open? If the answer is a path under
  `/tmp`, it is in the wrong place. This has already cost real work: a verification script in a
  scratch directory was gone the next day while the report citing its numbers remained, and the
  numbers had to be re-derived to find out whether the report was even right.

- **Gate every irreversible action** — delete, overwrite, send, submit, publish — behind human
  confirmation.

- **Run it before you claim it.** Do not assert what a tool or a model "will do" when running
  it is possible. Model behaviour changes in months, and an assertion that gets falsified in
  front of someone is worse than no assertion.

- **Update `TODO.md` and the decision log as you go**, not at the end. They are how the next
  person, usually you in three months, reconstructs what happened.
