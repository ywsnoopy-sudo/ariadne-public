# Ariadne — Session Wrap-Up for Claude Code

Ariadne is a [Claude Code](https://docs.anthropic.com/en/docs/claude-code) custom skill that prevents context loss between sessions. It enforces memory hygiene — catching stale files, orphan references, ghost links, and index bloat before they degrade Claude's context quality.

## The Problem

Claude Code's auto-memory system accumulates `.md` files in `~/.claude/projects/<id>/memory/` across sessions. Without maintenance:

- Memory files go **stale** (referencing deleted features or old versions)
- **Orphan** files pile up (exist on disk but aren't indexed in MEMORY.md)
- **Ghost** references linger (MEMORY.md points to files that no longer exist)
- The index **bloats** past useful size, wasting context window

There's no built-in tooling to manage this. Ariadne fills that gap.

## What It Does

A 3-step procedure run at session end:

1. **File Audit** — Finds files modified during the session, checks for orphan artifacts
2. **Memory Lifecycle Audit** — Version verification, staleness sweep, orphan/ghost detection, index enforcement, anti-pattern checks
3. **Session Brief** — Writes a structured summary to MEMORY.md

Plus a **PreToolUse hook** (`ariadne_thread.sh`) that blocks bad memory files at write time.

### How the Hook Works

The hook runs a precedence chain — it exits early at the first matching condition:

```
Write tool called
  │
  ├─ File not in memory dir?  → PASS (not our concern)
  ├─ File is MEMORY.md?       → PASS (index edits are always allowed)
  ├─ Tool is not Write?       → PASS (Edit to existing files is allowed)
  ├─ File already exists?     → PASS (only gates new file creation)
  │
  ├─ Check 1: Body ≤3 lines? → BLOCK "Write inline in MEMORY.md instead"
  └─ Check 2: type: feedback? → BLOCK "Feedback belongs inline in MEMORY.md"
```

**Note on check order**: If a feedback-type file also has ≤3 lines, Check 1 fires first.
The user sees "too short" instead of "feedback must be inline." Both are correct — but
if you add more lines to bypass Check 1, Check 2 still blocks it. Feedback files are
always rejected regardless of length.

## Installation

### 1. Copy the skill

```bash
mkdir -p ~/.claude/skills/ariadne-public
cp SKILL.md ~/.claude/skills/ariadne-public/SKILL.md
```

### 2. Copy the hook

```bash
cp hooks/ariadne_thread.sh ~/.claude/hooks/ariadne_thread.sh
chmod +x ~/.claude/hooks/ariadne_thread.sh
```

### 3. Register the hook

Add to your `~/.claude/settings.json` under `hooks.PreToolUse`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/ariadne_thread.sh",
            "timeout": 3
          }
        ]
      }
    ]
  }
}
```

See [`examples/settings.json`](examples/settings.json) for a complete snippet.

### 4. Set your memory directory (optional)

```bash
export ARIADNE_MEMORY_DIR="$HOME/.claude/projects/<your-project-id>/memory"
```

If not set, the hook auto-detects by searching `~/.claude/projects/*/memory/MEMORY.md`.

## Usage

At the end of a session, tell Claude:

```
/wrap-up
```

Or simply say "wrap up" — Ariadne will run its 3-step procedure and produce a wrap-up report.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (custom skills support)
- `jq` (used by ariadne_thread.sh — pre-installed on most systems)

## License

GPL-3.0 — see [LICENSE](LICENSE).
