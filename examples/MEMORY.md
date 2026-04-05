# Claude Code Memory

## User

- Senior backend engineer, new to React frontend
- Primary language: Python, learning TypeScript

## Project

- **Auth rewrite**: Migrating from session tokens to JWT. See `auth_migration.md`.
- **API v2**: Breaking changes in /users endpoint. Target: 2026-05-01.

## Feedback

- Always run tests before committing — CI is slow, catch failures locally.
- Prefer single bundled PRs for refactors, not many small ones.
- Don't add type annotations to files I didn't modify.

## Session Brief (2026-04-05 #1)

- **Done**: Implemented JWT middleware, updated 3 route handlers.
- **Changed**: src/middleware/auth.ts, src/routes/users.ts, src/routes/admin.ts
- **Key insight**: Express middleware ordering matters — auth must come after CORS.
