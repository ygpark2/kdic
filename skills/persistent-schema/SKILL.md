---
name: persistent-schema
description: Modify Persistent models, migrations, or seed data for hkforum. Use when changing entities in config/models, adjusting migrations in src/Model.hs, or updating seed data in src/Application.hs.
---

# Persistent Schema Workflow

## Quick Workflow
- Update entities in `config/models`.
- Keep `src/Model.hs` pointing to `config/models`.
- Update seed data in `src/Application.hs` (`seedDefaults`).
- App runs `runMigration migrateAll` at startup.

## When Adding Fields
- Prefer defaults for non-null fields to avoid migration breakage.
- Add `createdAt`/`updatedAt` if needed and update handlers to populate them.

## Key Code References
- Entity definitions: `config/models`
- Migration entry: `src/Model.hs` (migrateAll)
- Seed data: `src/Application.hs` (seedDefaults)

## Common Pitfalls
- Adding non-null fields without defaults.
- Forgetting to update handlers that create entities.
- Breaking `Unique*` constraints used in lookups.
