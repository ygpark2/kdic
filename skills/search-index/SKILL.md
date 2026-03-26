---
name: search-index
description: Implement or modify search functionality in hkforum. Use when adding search routes, handlers, or templates, or when introducing indexing or query logic across boards, threads, posts, and comments.
---

# Search Workflow

## Quick Workflow
- Add search routes in `config/routes`.
- Implement handlers in `src/Handler/**` (create new if needed).
- Use `runDB` queries across `Thread`, `Post`, and `Comment`.
- Render results in a new template under `templates/`.

## 현재 상태
- 검색 전용 라우트와 핸들러는 아직 없음.

## Key Code References
- Routes: `config/routes`
- Models: `config/models` (Thread/Post/Comment)
- Common helpers: `src/Handler/Common.hs`

## Conventions
- Keep search parameters explicit and validated.
- Prefer pagination for large result sets.
- Consider full-text search limits with SQLite.

## Common Pitfalls
- Missing indexes for frequent search fields.
- Unbounded queries on large tables.
