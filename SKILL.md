---
name: ariadne-public
version: 0.1.0
date: 2026-04-05
description: >-
  Session wrap-up and memory lifecycle skill for Claude Code.
  Checks for unsaved context, enforces memory hygiene (staleness, orphans,
  version drift, bloat), and writes session briefs.
  Use when: /wrap-up, "wrap up", before ending a session.
---

# Ariadne — The Thread (Session Close Checklist)

Run this before ending any session that involved significant work.
Prevents context loss, stale memory, and orphan artifacts.

## When to Run

- End of any session with file modifications
- Before sleep / leaving the terminal unattended
- After completing a multi-step project
- User says "wrap up", "wrap-up", or `/wrap-up`

## Prerequisites

Set the `ARIADNE_MEMORY_DIR` environment variable to your memory directory:

```bash
export ARIADNE_MEMORY_DIR="$HOME/.claude/projects/<your-project-id>/memory"
```

To find your project ID, check `~/.claude/projects/` — it contains directories named
after your working directory path (e.g., `-Users-jane` for `/Users/jane`).

If `ARIADNE_MEMORY_DIR` is not set, Ariadne falls back to the first match of:
`~/.claude/projects/*/memory/MEMORY.md`

## 3-Step Procedure

### Step 1: File Audit

Scan for files created or modified during this session.

```bash
# Find files modified in the last N hours (adjust based on session length)
find ~/.claude/skills/ ~/.claude/hooks/ ~/.claude/agents/ -name "*.md" -mmin -360 2>/dev/null
```

For each modified file, verify:
- Is the modification intentional and complete?
- Is there a corresponding update needed elsewhere (dependency)?

Check for orphan files:
- `/tmp/` artifacts that should be in a persistent location
- Project-specific artifacts that belong in persistent storage

### Step 2: Memory Lifecycle Audit

Read MEMORY.md and the memory directory. Execute ALL checks below — do not skip.

#### 2a. Version Verification

For every version number in MEMORY.md, read the actual source file and compare:

```bash
# Example checks (adapt to your setup)
head -5 ~/.claude/CLAUDE.md                    # CLAUDE.md version
head -5 ~/.claude/skills/*/SKILL.md            # All skill versions
```

Any mismatch → fix MEMORY.md immediately.

#### 2b. Staleness Sweep

For each `.md` file in the memory directory:

| Type | Rule |
|------|------|
| `project` | >14 days old → verify claims against current state. Delete if completed or derivable from code. |
| `feedback` | Permanent. But check referenced versions/features still exist. |
| `reference` | Check referenced paths still exist. Delete if path gone. |
| `user` | Permanent unless contradicted. |

Files with "Remaining Tasks: NOT DONE" or similar incomplete markers that are >14 days old → confirm status with user or delete.

#### 2c. Orphan & Ghost Detection

```bash
cd "$ARIADNE_MEMORY_DIR"

# Orphans: files not referenced in MEMORY.md
for f in *.md; do
  [ "$f" = "MEMORY.md" ] && continue
  grep -q "$f" MEMORY.md || echo "ORPHAN: $f"
done

# Ghosts: MEMORY.md references to nonexistent files (See `file` and [Title](file) formats)
{ grep -oE 'See `[^`]+`' MEMORY.md | sed 's/See `//;s/`//'; \
  grep -oE '\]\([^)]+\.md\)' MEMORY.md | sed 's/\](//;s/)//'; } | sort -u | while read f; do
  [ ! -f "$f" ] && echo "GHOST: $f"
done
```

Orphans → add to MEMORY.md or delete.
Ghosts → remove reference from MEMORY.md.

#### 2d. Index Enforcement

- MEMORY.md must stay under **170 lines** (hard limit 200, warn at 170)
- Each entry under 150 characters
- Session briefs: **max 2** in MEMORY.md. Older briefs → delete (transcripts in `.jsonl`)
- No archive files — delete or keep, never copy

#### 2e. Anti-Patterns

- **No history files**: Do not store version history in memory. History lives in the source file or git.
- **No code snapshots**: Code status files rot immediately. The code itself is the source of truth.
- **No completed task notes**: Once implemented, delete the task memory. The implementation is the record.
- **No archive copies**: Archiving is hoarding. Delete or keep.
- **No single-line files**: If the memory fits in one line of MEMORY.md, do not create a separate file. Separate files are for substantial content only (project details, config references, multi-step workflows).
- **No derivable information**: If the content can be obtained by reading an existing file or folder structure, do not store it in memory.
- **Feedback stays inline**: Feedback rules belong as one-liners in MEMORY.md's Feedback section, not as separate files. Only create a file if the feedback requires multi-paragraph context.
- **Auto-memory files are not sacred**: Files created by CC's auto-memory (`extractMemories`) are subject to the same rules. Delete if single-line, derivable, or stale.

### Step 3: Session Brief

Write a brief summary to MEMORY.md. Format:

```
## Session Brief (YYYY-MM-DD #N)

- **Done**: 1-3 sentences
- **Changed**: list of modified files
- **Key insight**: (if any)
```

If >2 briefs exist in MEMORY.md, delete the oldest before adding.

## Output Format

```
## Wrap-Up Report — [date]

### File Audit
- Modified: [N] files
- Orphans: [list or "none"]

### Memory Lifecycle
- Versions checked: [N], mismatches fixed: [N]
- Stale files: [N] deleted, [N] updated
- Orphans resolved: [N]
- Ghosts removed: [N]
- Index: [N]/170 lines

### Session Brief
- Written to MEMORY.md
```

## What Wrap-Up Does NOT Do

- Does not make design decisions (that is the user's role)
- Does not modify skill logic
- Does not create new features — only preserves existing work
- Does not create archive files — delete or keep, no copies
