# Contributing

This repo is the file half of a set of guides at <https://benninglab.org/agentic/>. It is small on
purpose: the parts of a research Claude Code setup that generalise, with the personal and
lab-specific parts left out.

## What belongs here

Something belongs in this repo if a researcher outside the Benning Lab could use it without editing
their own name into it. The hooks, the project templates, the terminal config and the corpus builder
all pass that test.

Things that do not: anything wired to one person's email, calendar, folder layout, or reference
library. Those live in a private setup and are described in the guides rather than shipped.

## Reporting something broken

Open an issue. The useful ones say what you ran, what you expected, and what happened, and name your
OS and shell. "The `cc` launcher does nothing on bash" is a fine issue; every script here assumes
zsh and macOS unless it says otherwise, and that assumption is worth knowing about.

## Sending a change

1. Fork, branch, and keep the change to one thing.
2. Test it. Shell scripts should pass `bash -n` (or `zsh -n`), and anything with behaviour should be
   run at least once against a real folder. `install.sh --check` exists so you can see what an
   install would do without doing it.
3. Say in the pull request what you ran to convince yourself it works. A change to a session hook
   that has not been run in a session is not finished.

## Style

Match what is there. Scripts are POSIX-ish bash with a comment block at the top saying what the
script is for and why it is shaped that way — the *why* matters more than the *what*, because the
reasoning is the part that is expensive to reconstruct.

Prose in this repo is plain. No metaphors, no lines that land, no jargon coined on the spot. If a
sentence sounds like a line rather than a statement, write the literal thing instead.
