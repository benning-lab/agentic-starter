# Building a skill that knows your domain

A **skill** is a folder containing a `SKILL.md` and whatever reference files it needs. Claude
Code loads the description line always and the body only when the work calls for it, so a
skill can carry a large reference corpus without costing anything until it is used. That is
the difference that matters: a slash command is a flat file loaded whole, a skill is a
directory loaded on demand.

```
~/.claude/skills/<name>/
├── SKILL.md          what to do, and when. loaded on demand.
├── references/       the corpus. grepped, not loaded wholesale.
├── scripts/          things the skill runs, including its verifier
└── examples/         worked cases, with their saved output
```

This folder holds a `SKILL.md` template and `build-corpus.py`, which turns a folder of PDFs
into a corpus with the extraction traps already handled.

## When a skill is the right tool

Write one when a model's general knowledge about your domain is **wrong or unusable**, in one
of two specific ways.

**It is stale.** Simulation frameworks, analysis packages and APIs move faster than training
data. A model will write code that parses cleanly and uses a property that was renamed two
major versions ago. No amount of prompting fixes this; the model does not know what it does
not know. A version-pinned local corpus does.

**It is in the wrong register.** Some documentation is complete, correct, and written for a
different reader. Statistical methods literature is the clear case: the answers are all there,
in exponential-family language that a field biologist cannot map onto a census sheet. Here the
corpus is not the hard part, the translation layer is, and that layer is the thing worth
building.

Do not write a skill because a topic is important. Write one when you can name the specific
failure you are fixing.

## The recipe

**1. Pick the corpus and pin the version.** Manual, API reference, official examples, the
papers that actually set the conventions. Record which version, because a corpus whose
version is unknown is a corpus you cannot trust later.

**2. Prefer source over rendered output.** If a LaTeX, Markdown or HTML original exists, build
from it. Extraction from PDF is a reconstruction, and for older documents a lossy one. Run
`python3 build-corpus.py --help-source` for the two silent failure modes, ligature loss and
meaning-destroying de-TeXing, with the specific cases that caused real damage.

**3. Build an API index, separately from the prose.** Prose tells you how to think; signatures
tell you what exists. Keeping them apart lets the skill answer "is this function real" without
reading a chapter. Where the tool can emit its own function list, use that rather than
scraping the manual.

**4. Write the translation layer, if the register is the barrier.** A short set of documents
that restate the domain's concepts in the vocabulary of the person who will use it. For a
statistical method, that means census sheets and experimental blocks rather than sufficient
statistics. This is usually the highest-value part of the skill and it cannot be generated
from the corpus, because it is the thing the corpus is missing.

**5. Write a verifier, and make the skill run it.** This is the step people skip, and it is
the one that separates a skill that works from a skill that sounds right.

**6. Write down the traps.** One file of specific, reproducible failures. Each entry: what
looks right, what actually happens, how to tell. This is where the skill accumulates value
over time.

## Verification is not syntax checking

A syntax check passes code that cannot run. In one case a simulation framework's checker
accepted a property renamed in the previous major version: it parsed clean and failed only on
execution. Two other errors found the same way were also runtime-only. So the rule became: a
generated model that has not been **executed** is not finished, and the skill's check script
runs a short smoke run as a mandatory second stage.

For statistical fitting, the bar is higher again, because running is not the question. A model
fit can converge to garbage and report no error. One fit inverted its information matrix
without complaint at a reciprocal condition number of 3e-13, and produced meaningless standard
errors. `solve()` succeeding is not reassurance. The verifier has to check the thing that
actually indicates health: conditioning, separation, empty cells, directions of recession.

Ask what "wrong but silent" looks like in your domain, and test for that.

## Write the trap file from real failures

The traps worth recording are the ones where the tool lies to you. A found example: a
prediction function silently ignored its `newdata` argument, because the object's class
dispatched to a method that has no such parameter and `...` swallowed it. Twenty-seven rows
requested, 5130 returned, no error, no warning.

Two things made that entry durable. It shipped with a **script that reproduces it**, and that
script is written to **fail loudly if a future release fixes the bug** — so the trap file
cannot quietly go stale and start lying in the other direction.

## Expert-lens skills: a panel, never a blend

A different kind of skill: review work through named expert perspectives, built from their
actual published writing.

The design decision that makes it work is to keep the lenses **separate**. Merging several
experts into one reviewer produces a generic wise skeptic, which is what you already get by
asking for criticism. The value is that independent lenses attack different axes and disagree
with each other, so the output is separate memos plus a synthesis that **preserves** the
conflict rather than resolving it. On one real run, the single most useful output was an
unresolved disagreement between two lenses about a scope decision that had already been made:
the job was to name the cost, not relitigate it.

Four rules that came out of building one:

- **A lens must own an axis no other lens owns.** A near-duplicate lens is worse than no lens,
  because two memos agreeing tells you nothing, and it destroys the signal that agreement
  between genuinely independent lenses is meaningful. Reject a proposed lens whose distinct
  contribution you cannot state in one sentence.
- **Never run all of them.** Select by the work's actual exposure. If an exposed axis has no
  owner, saying so is itself a finding, and it is better evidence for adding a lens than
  reasoning about coverage in the abstract.
- **Require citation from the corpus.** A memo that cites nothing was written from vibes. This
  is the only real defence, because the failure mode here is not staleness but a plausible
  generic skeptic wearing a name tag.
- **Fetch both halves of a published exchange.** A critique read without its reply reads as a
  rout, and a lens that has only read the attack manufactures severity.

And never attribute the output to the real person. It is a simulation built from public
writing: "the Coop lens", not "Graham Coop says your Aim 2 is underpowered". The moment a line
gets pasted into a collaborator thread, that distinction is the only thing standing between
you and misattributing an opinion to someone who never held it.
