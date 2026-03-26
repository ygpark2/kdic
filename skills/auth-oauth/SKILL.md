---
name: auth-oauth
description: Work on authentication and OAuth2 integrations in hkforum. Use when modifying login flows, HashDB user auth, OAuth2 providers (Google/Kakao/Naver), or auth routes/templates.
---

# Auth and OAuth Workflow

## Quick Workflow
- Confirm auth routes in `config/routes` (AuthR).
- Update `YesodAuth` instance in `src/Foundation.hs`.
- Update provider wiring in `src/Auth/OAuth2Providers.hs`.
- Update templates in `templates/auth/*`.

## 핵심 엔드포인트
- `GET /auth` (Yesod Auth subsite)
- Internal Auth routes under `AuthR` (login, logout, etc.)

## 핵심 함수
- `authPlugins` (`src/Foundation.hs`)
- `authenticate` (`src/Foundation.hs`)
- `authRoute`, `loginDest`, `logoutDest` (`src/Foundation.hs`)

## Key Code References
- Auth wiring: `src/Foundation.hs` (YesodAuth instance)
- OAuth providers: `src/Auth/OAuth2Providers.hs`
- Auth templates: `templates/auth/*`
- Settings: `config/settings.yml`, `src/Settings.hs`

## Conventions
- HashDB users keyed by `UniqueUser`.
- OAuth users stored as `plugin:ident`.
- Keep `authRoute`, `loginDest`, `logoutDest` consistent.

## Common Pitfalls
- Missing OAuth env vars in `config/settings.yml`.
- Forgetting to add new provider to `authPlugins`.
