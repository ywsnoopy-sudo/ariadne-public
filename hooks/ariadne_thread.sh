#!/usr/bin/env bash
# MEMORY_GUARD — Prevent bad memory files at write time.
# Rules defined in: Ariadne SKILL.md §2e
# This hook enforces two mechanical checks only.
# All policy decisions live in Ariadne — do not duplicate rules here.

TOOL_NAME="$1"
INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | jq -r '.file_path // empty' 2>/dev/null)
[[ -z "$FILE_PATH" ]] && exit 0

# Auto-detect memory directory
if [[ -n "$ARIADNE_MEMORY_DIR" ]]; then
  MEMORY_DIR="$ARIADNE_MEMORY_DIR"
else
  # Fallback: find the first memory directory under ~/.claude/projects/
  MEMORY_DIR=$(dirname "$(ls ~/.claude/projects/*/memory/MEMORY.md 2>/dev/null | head -1)" 2>/dev/null)
fi
[[ -z "$MEMORY_DIR" ]] && exit 0

[[ "$FILE_PATH" != "$MEMORY_DIR"/* ]] && exit 0
[[ "$(basename "$FILE_PATH")" == "MEMORY.md" ]] && exit 0

# Only gate new file creation (Write), not edits to existing files
[[ "$TOOL_NAME" != "Write" ]] && exit 0
[[ -f "$FILE_PATH" ]] && exit 0

CONTENT=$(echo "$INPUT" | jq -r '.content // empty' 2>/dev/null)

# Check 1: Body too short (≤3 non-frontmatter lines)
BODY_LINES=$(echo "$CONTENT" | sed '/^---$/,/^---$/d' | grep -c '[^[:space:]]')
if [[ "$BODY_LINES" -le 3 ]]; then
  echo "⚠️ MEMORY_GUARD: ≤3 lines. Write inline in MEMORY.md instead. (Ariadne §2e)"
  exit 2
fi

# Check 2: Feedback type → must be inline
if echo "$CONTENT" | grep -q "^type: feedback"; then
  echo "⚠️ MEMORY_GUARD: Feedback belongs inline in MEMORY.md. (Ariadne §2e)"
  exit 2
fi

exit 0
