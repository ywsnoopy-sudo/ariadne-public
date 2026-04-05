# Ariadne — Claude Code 세션 정리 스킬

<p align="center">
  <img src="assets/banner.png" alt="Ariadne — 세션 사이의 실" width="600">
</p>

> [English version below](#ariadne--session-wrap-up-for-claude-code)

Ariadne는 [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 커스텀 스킬로, 세션 간 컨텍스트 손실을 방지합니다. 오래된 메모리 파일, orphan 참조, ghost 링크, index bloat를 감지하고 정리합니다.

## 문제

Claude Code의 자동 메모리 시스템은 세션마다 `~/.claude/projects/<id>/memory/`에 `.md` 파일을 축적합니다. 관리 없이는:

- 메모리 파일이 **낡아짐** (삭제된 기능이나 이전 버전을 참조)
- **Orphan** 파일 누적 (디스크에 존재하지만 MEMORY.md에 미등록)
- **Ghost** 참조 잔존 (MEMORY.md가 존재하지 않는 파일을 가리킴)
- Index가 **bloat**되어 컨텍스트 윈도우 낭비

이를 관리하는 빌트인 도구는 없습니다. Ariadne가 이 공백을 채웁니다.

## 기능

세션 종료 시 실행하는 3단계 절차:

1. **File Audit** — 세션 중 수정된 파일 탐지, orphan 아티팩트 확인
2. **Memory Lifecycle Audit** — 버전 검증, staleness 검사, orphan/ghost 탐지, index 규칙 적용, anti-pattern 점검
3. **세션 브리프** — MEMORY.md에 구조화된 세션 요약 작성

추가로 **PreToolUse 훅** (`ariadne_thread.sh`)이 잘못된 메모리 파일 생성을 사전 차단합니다.

### 훅 작동 방식

훅은 우선순위 체인을 따르며 첫 번째 매칭 조건에서 조기 종료합니다:

```
Write 도구 호출
  │
  ├─ 메모리 디렉토리 밖?      → 통과 (관할 외)
  ├─ MEMORY.md 파일?          → 통과 (인덱스 편집은 항상 허용)
  ├─ Write 도구가 아님?       → 통과 (기존 파일 Edit은 허용)
  ├─ 파일이 이미 존재?        → 통과 (새 파일 생성만 검사)
  │
  ├─ 검사 1: 본문 ≤3줄?      → 차단 "MEMORY.md에 인라인으로 작성하세요"
  └─ 검사 2: type: feedback?  → 차단 "피드백은 MEMORY.md에 인라인으로"
```

**검사 순서 참고**: feedback 타입 파일이 3줄 이하인 경우, 검사 1이 먼저 작동합니다.
검사 1을 우회하기 위해 줄을 추가해도 검사 2가 차단합니다. feedback 파일은 길이와
무관하게 항상 거부됩니다.

## 설치

### 1. 스킬 복사

```bash
mkdir -p ~/.claude/skills/ariadne-public
cp SKILL.md ~/.claude/skills/ariadne-public/SKILL.md
```

### 2. 훅 복사

```bash
cp hooks/ariadne_thread.sh ~/.claude/hooks/ariadne_thread.sh
chmod +x ~/.claude/hooks/ariadne_thread.sh
```

### 3. 훅 등록

`~/.claude/settings.json`의 `hooks.PreToolUse`에 추가:

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

[`examples/settings.json`](examples/settings.json)에서 전체 예시를 확인하세요.

### 4. 메모리 디렉토리 설정 (선택)

```bash
export ARIADNE_MEMORY_DIR="$HOME/.claude/projects/<your-project-id>/memory"
```

미설정 시 `~/.claude/projects/*/memory/MEMORY.md`에서 자동 탐지합니다.

## 사용법

세션 종료 시 Claude에게:

```
/wrap-up
```

또는 "wrap up"이라고 말하면 Ariadne가 3단계 절차를 실행하고 정리 보고서를 출력합니다.

## 요구사항

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (커스텀 스킬 지원)
- `jq` (ariadne_thread.sh에서 사용 — 대부분의 시스템에 기본 설치)

## 라이선스

GPL-3.0 — [LICENSE](LICENSE) 참조.

---

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
