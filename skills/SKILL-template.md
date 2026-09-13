---
name: <skill-name>
description: <One sentence on what this does, then when to use it, then the trigger words. This line is the only part loaded into every session, so it is doing the routing: if it does not name the words someone would actually type, the skill never fires. Be specific about the domain and name the file extensions, function names and jargon that should trigger it.>
---

# <Skill name>

<!-- Open by telling the model what it has and why it must not work from memory. Be blunt:
"You have a complete, version-pinned X reference on disk. Use it. Do not write X from memory —
most X code in your training data predates the Y rename, and ungrounded code looks right and
fails." The reason for the bluntness is that the model's default is to answer from recall, and
recall is exactly what this skill exists to override. -->

## What is here

| Path | What it is | When to read it |
|---|---|---|
| `references/api/_SIGNATURES.txt` | Complete API surface | Every time, before writing code |
| `references/<topic>/` | Prose reference | Grep when a signature is not enough |
| `references/traps.md` | What pretrained knowledge gets wrong | Before the first code in a session |
| `scripts/check.sh` | The verifier | Before reporting anything as working |
| `examples/` | Worked cases with saved output | Find precedent before writing |

<!-- The "when to read it" column is the part that makes a large corpus usable. Without it the
model either reads everything or nothing. -->

## Workflow

### 1. Pin the question before touching code

<!-- What has to be decided before code is the right move. -->

### 2. Find precedent before writing

<!-- Point at the examples and the corpus, and say to grep them first. A worked case from the
corpus beats generated code. -->

### 3. Write it

<!-- House style, conventions, the specific things this domain gets wrong. -->

### 4. Verify — non-negotiable

<!-- The verifier, and what it checks. State plainly that syntax checking is not verification
and that unexecuted output is not finished. Name what "wrong but silent" looks like here, and
make the check test for it. -->

### 5. Report honestly

<!-- What to tell the user: what was run, what the numbers were, what is still uncertain.
Where the evidence gets saved, so a claim made in a report can be checked later without
re-running anything. -->

## Standing constraints

<!-- The short list of rules that hold across every use. Things that, if violated, make the
output untrustworthy rather than merely imperfect. -->

## Extending this skill

<!-- How to rebuild the corpus, where the build scripts are, what to check after a rebuild.
A skill whose corpus cannot be rebuilt is a skill that expires. -->
