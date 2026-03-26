---
name: yesod-feature
description: Add or modify Yesod routes, handlers, widgets, or templates in this hkforum app. Use for tasks like adding endpoints in config/routes, creating handlers in src/Handler/**, wiring templates in templates/**, and updating layout or auth/authorization behavior.
---

# Yesod Feature Workflow

## Quick Workflow
- Add or change routes in `config/routes`.
- Implement handlers in `src/Handler/**`.
- Render UI with `$(widgetFile "path")` and templates under `templates/**`.
- Use `runDB` for persistence and model types from `config/models`.
- Confirm auth rules in `src/Foundation.hs` (`isAuthorized`).

## Wiring Steps
- Route added in `config/routes`.
- Handler module exported and imported in `src/Application.hs`.
- Template referenced in handler via `$(widgetFile "...")`.

## 핵심 엔드포인트 (요약)
- Forum: `/boards`, `/board/#BoardId`, `/thread/#ThreadId`
- Auth: `/auth`
- Register/Profile: `/register`, `/profile`
- Uploads: `/upload`, `/files/#Text`
- Admin: `/admin/*`

## 핵심 핸들러 (요약)
- Common: `getFaviconR`, `getRobotsR` (`src/Handler/Common.hs`)
- Register: `getRegisterR`, `postRegisterR` (`src/Handler/Register.hs`)
- Profile: `getProfileR`, `postProfileR` (`src/Handler/Profile.hs`)

## Key Code References
- Route table: `config/routes`
- Dispatch wiring: `src/Foundation.hs` (mkYesodData)
- App imports: `src/Application.hs` (handler imports)
- Template layout: `templates/layout/default-layout.*`, `templates/layout/admin-layout.hamlet`

## Conventions
- Keep handlers thin; extract shared helpers into `src/Handler/Common.hs`.
- Use existing layouts for consistent chrome.
- Favor template-driven UI over inline HTML.

## Common Pitfalls
- Forgetting to add handler import in `src/Application.hs`.
- Using the wrong HTTP method in `config/routes`.
- Missing authorization updates in `src/Foundation.hs`.
