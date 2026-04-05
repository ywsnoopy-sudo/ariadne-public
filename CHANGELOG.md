# Changelog

## [0.1.0] — 2026-04-05

### Added
- Initial public release
- 3-step session wrap-up procedure (File Audit → Memory Lifecycle → Session Brief)
- Memory lifecycle audit with version verification, staleness sweep, orphan/ghost detection
- 8 memory anti-patterns
- Index enforcement (170-line warn, 200-line hard limit)
- `memory_guard.sh` PreToolUse hook with auto-detection of memory directory
- Installation guide and examples

### Origin
- Generalized from private Ariadne v1.2.1
- Removed personal skill references
- Made memory directory configurable via `ARIADNE_MEMORY_DIR` env var
