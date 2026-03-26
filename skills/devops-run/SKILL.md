---
name: devops-run
description: Run, build, or operate hkforum locally. Use when invoking Stack/Makefile commands, starting/stopping the server, or managing the local SQLite DB.
---

# Run/Build Workflow

## Quick Workflow
- Build: `stack build`
- Run: `stack run hkforum`
- Dev run: `stack build --flag hkforum:dev && stack exec hkforum`
- Tailwind: `make tailwind`
- Background start/stop: `make start-bg` and `make stop`.
- Clean DB: `make clean` (removes `data/*.sqlite*`).

## Key Code References
- Build config: `stack.yaml`, `package.yaml`
- Commands: `Makefile`
- DB path: `config/settings.yml`

## Common Pitfalls
- Missing `.env` values for OAuth or storage.
- Forgetting to rebuild Tailwind after template changes.
