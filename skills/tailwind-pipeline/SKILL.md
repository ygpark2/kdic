---
name: tailwind-pipeline
description: Build or modify the Tailwind CSS pipeline for hkforum. Use when editing Tailwind config or input CSS in config/front, or updating static/css/tailwind.css output and build commands.
---

# Tailwind Pipeline Workflow

## Quick Workflow
- Edit input at `config/front/tailwind.input.css`.
- Adjust config in `config/front/tailwind.config.js`.
- Build CSS via `make tailwind` or `npm --prefix config/front run build:css`.
- Output is `static/css/tailwind.css`.

## Key Code References
- Tailwind config: `config/front/tailwind.config.js`
- Tailwind input: `config/front/tailwind.input.css`
- Output CSS: `static/css/tailwind.css`
- Build script: `config/front/package.json`
- Make target: `Makefile` (tailwind)

## Conventions
- Keep generated `static/css/tailwind.css` in sync after template changes.
- Avoid committing `config/front/node_modules` changes unless required.

## Common Pitfalls
- Forgetting to rebuild after adding new template classes.
- Editing the output CSS directly.
