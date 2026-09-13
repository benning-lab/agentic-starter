#!/usr/bin/env python3
"""Condense a Claude Code session transcript (.jsonl) into a compact, faithful
markdown record of "what we actually did" — the real user/assistant dialogue plus
a one-line marker per tool action. Drops thinking blocks and tool-result payloads
(the bulk of transcript size) while preserving the sequence of what happened.

Purpose: give the NEXT session more grounding than the handoff summary alone, and
make that record durable (the caller decides where the output is written).

Usage:  condense-transcript.py <transcript.jsonl> [--max-chars N]
Writes markdown to stdout. Never raises on malformed input; bad lines are skipped.
"""
import json, sys, os, datetime

MAX_CHARS = 32000          # cap injected size; keep the most-recent tail if larger


def short(s, n=2000):
    s = " ".join(str(s).split())
    return s if len(s) <= n else s[:n] + " …[trimmed]"


def strip_reminders(text):
    # Drop <system-reminder>…</system-reminder> spans (harness-injected, not user voice)
    out, depth, i = [], 0, 0
    low = text
    while True:
        a = low.find("<system-reminder>", i)
        if a < 0:
            out.append(text[i:]); break
        out.append(text[i:a])
        b = low.find("</system-reminder>", a)
        if b < 0:
            break
        i = b + len("</system-reminder>")
    return "".join(out).strip()


def tool_descriptor(name, inp):
    """One short, human line describing a tool call."""
    if not isinstance(inp, dict):
        return name
    def base(p): return os.path.basename(str(p).rstrip("/")) or str(p)
    if name == "Bash":
        return f"Bash: {short(inp.get('description') or inp.get('command',''), 100)}"
    if name in ("Read", "Write", "NotebookEdit"):
        return f"{name} {base(inp.get('file_path') or inp.get('notebook_path',''))}"
    if name == "Edit":
        return f"Edit {base(inp.get('file_path',''))}"
    if name in ("Grep", "Glob"):
        return f"{name} {short(inp.get('pattern',''), 60)}"
    if name == "Task" or name == "Agent":
        return f"Agent: {short(inp.get('description') or inp.get('subagent_type',''), 80)}"
    if name == "TodoWrite":
        return "TodoWrite (task list update)"
    if name.startswith("mcp__"):
        parts = name.split("__")
        tail = parts[-1] if parts else name
        # surface the most telling arg if present
        for k in ("query", "subject", "to", "title", "name", "file_path", "summary"):
            if inp.get(k):
                return f"{tail}: {short(inp[k], 80)}"
        return tail
    # generic: name + first scalar arg
    for k, v in inp.items():
        if isinstance(v, (str, int, float)):
            return f"{name} {k}={short(v, 60)}"
    return name


def msg_blocks(rec):
    m = rec.get("message")
    if isinstance(m, dict):
        c = m.get("content")
        if isinstance(c, list):
            return c
        if isinstance(c, str):
            return [{"type": "text", "text": c}]
    return []


def condense(path):
    lines = []
    first_ts = last_ts = None
    cwd = None
    n_user = n_asst = n_tool = 0

    with open(path, "r", errors="replace") as f:
        for raw in f:
            raw = raw.strip()
            if not raw or not raw.startswith("{"):
                continue
            try:
                rec = json.loads(raw)
            except Exception:
                continue
            t = rec.get("type")
            ts = rec.get("timestamp")
            if ts:
                first_ts = first_ts or ts
                last_ts = ts
            cwd = cwd or rec.get("cwd")

            if t == "user":
                texts = []
                for b in msg_blocks(rec):
                    if not isinstance(b, dict):
                        continue
                    if b.get("type") == "text":
                        txt = strip_reminders(b.get("text", ""))
                        if txt:
                            texts.append(txt)
                    # tool_result blocks: skip (that's tool output coming back)
                joined = "\n".join(texts).strip()
                if joined:
                    n_user += 1
                    lines.append(f"\n### ▸ You\n{short(joined, 4000)}")

            elif t == "assistant":
                said, actions = [], []
                for b in msg_blocks(rec):
                    if not isinstance(b, dict):
                        continue
                    bt = b.get("type")
                    if bt == "text" and b.get("text", "").strip():
                        said.append(b["text"].strip())
                    elif bt == "tool_use":
                        n_tool += 1
                        actions.append("  ↳ " + tool_descriptor(b.get("name", "?"), b.get("input")))
                if said or actions:
                    n_asst += 1
                    chunk = ["\n### ◂ Claude"]
                    if said:
                        chunk.append(short("\n".join(said), 4000))
                    if actions:
                        chunk.append("\n".join(actions))
                    lines.append("\n".join(chunk))

    body = "\n".join(lines).strip()
    truncated = False
    if len(body) > MAX_CHARS:
        body = body[-MAX_CHARS:]
        truncated = True

    def fmt(ts):
        try:
            return datetime.datetime.fromisoformat(str(ts).replace("Z", "+00:00")).strftime("%Y-%m-%d %H:%M")
        except Exception:
            return str(ts or "?")

    machine = "?"
    if cwd:
        # /Users/<user>/... -> the account name hints at which machine this ran on
        parts = cwd.split("/")
        if len(parts) > 2:
            machine = parts[2]

    header = [
        "# Last session — condensed transcript",
        f"_Project cwd: `{cwd or '?'}` · machine user: `{machine}`_",
        f"_Span: {fmt(first_ts)} → {fmt(last_ts)} · {n_user} you / {n_asst} claude turns / {n_tool} tool calls_",
        "",
        "> Faithful-but-compact record of the previous session (dialogue + actions; "
        "thinking and tool output omitted). Complements the handoff summary.",
    ]
    if truncated:
        header.append("> ⚠️ Older portion trimmed to fit; this is the most recent tail.")
    return "\n".join(header) + "\n\n" + body + "\n"


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        sys.exit("usage: condense-transcript.py <transcript.jsonl>")
    path = args[0]
    if "--max-chars" in sys.argv:
        global MAX_CHARS
        try:
            MAX_CHARS = int(sys.argv[sys.argv.index("--max-chars") + 1])
        except Exception:
            pass
    if not os.path.isfile(path):
        sys.exit(f"no such transcript: {path}")
    try:
        sys.stdout.write(condense(path))
    except Exception as e:
        sys.exit(f"condense failed: {e}")


if __name__ == "__main__":
    main()
