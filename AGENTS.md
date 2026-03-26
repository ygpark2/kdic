# HKForum Agent Notes

## Overview
- Haskell/Yesod web app for a forum with boards, threads, posts, comments, admin, and uploads.
- Build tool: Stack (resolver `lts-24.28`). Project metadata in `package.yaml` and `kdic.cabal`.
- DB: SQLite via Persistent; migrations in `src/Model.hs` from `config/models`.
- Templates: Hamlet/Lucius/Julius in `templates/`.
- Static assets in `static/`. Tailwind CSS build in `config/front/`.

## Key Paths
- App entry: `app/main.hs`, `src/Application.hs`, `src/Foundation.hs`.
- Routes: `config/routes`.
- Models: `config/models` (compiled by `src/Model.hs`).
- Settings: `config/settings.yml`, `src/Settings.hs`.
- Handlers: `src/Handler/**`.
- Storage (local/S3): `src/Storage.hs`.
- Templates: `templates/**`.
- Tests: `test/**`.

## Runtime & Config
- Settings load order:
  - `config/settings.yml` compiled into the binary.
  - `.env` (loaded at runtime) and environment variables override settings.
- Default DB path: `data/kdic.sqlite3`.
- Storage backend:
  - `STORAGE_BACKEND=local|s3`.
  - Local uploads stored under `data/uploads` and served from `/files/<key>`.
  - S3 uploads use the `aws` CLI (must be installed); optional endpoint and path-style.
- OAuth2: Google/Kakao/Naver configured via env vars in `config/settings.yml`.

## Development Commands
- Build: `stack build`
- Run (prod-ish): `stack run kdic`
- Run (dev flags): `stack build --flag kdic:dev && stack exec kdic`
- Tests: `stack test`
- Tailwind build: `make tailwind` (uses `config/front/package.json`)

## Seed Data
- On startup, migrations run and seed defaults:
  - Inserts a `general` board and `thread_preview_chars` site setting.
  - Ensures admin user `ygpark2` exists (default password `1234`) and is role `admin`.

## Notes For Changes
- Add or change routes in `config/routes`, then implement handlers in `src/Handler/**`.
- Change the data model in `config/models` and run migrations at app start (already wired in `src/Application.hs`).
- Templates are wired via `$(widgetFile "path")` and live under `templates/`.
