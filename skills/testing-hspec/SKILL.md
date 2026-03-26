---
name: testing-hspec
description: Add or update tests for hkforum. Use when writing Hspec or yesod-test specs in test/**, or when updating test setup in test/TestImport.hs.
---

# Testing Workflow

## Quick Workflow
- Add specs under `test/Handler/*` or `test/Spec.hs`.
- Reuse helpers in `test/TestImport.hs`.
- Run with `stack test`.

## 핵심 스펙 파일
- `test/Handler/HomeSpec.hs`
- `test/Handler/AuthSpec.hs`
- `test/Handler/CommonSpec.hs`

## Key Code References
- Test entry: `test/Spec.hs`
- Helpers: `test/TestImport.hs`
- Handler specs: `test/Handler/*`

## Conventions
- Focus on request/response behavior and DB side effects.
- Keep fixtures minimal; favor setup helpers.

## Common Pitfalls
- Hardcoding IDs without inserting fixtures.
- Not updating selectors after template changes.
