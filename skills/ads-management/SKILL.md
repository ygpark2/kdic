---
name: ads-management
description: Work on ad management features in hkforum. Use when modifying Ad models, admin ad routes, ad placement templates, or activation logic.
---

# Ads Workflow

## Quick Workflow
- Update ad routes in `config/routes` (admin ads).
- Implement logic in `src/Handler/Admin.hs`.
- Update templates in `templates/admin/*` and any front-facing ad slots.
- Use `Ad` entity in `config/models`.

## 핵심 엔드포인트
- `GET /admin/ads`, `POST /admin/ads`
- `GET /admin/ads/new`
- `GET /admin/ads/#AdId/view`, `POST /admin/ads/#AdId/view`

## 핵심 핸들러
- `getAdminAdsR`, `postAdminAdsR` (`src/Handler/Admin.hs`)
- `getAdminAdNewR`, `getAdminAdR`, `postAdminAdR` (`src/Handler/Admin.hs`)

## Key Code References
- Model: `config/models` (Ad)
- Admin handler: `src/Handler/Admin.hs`
- Admin templates: `templates/admin/*`
- Routes: `config/routes`

## Conventions
- Respect `isActive`, `position`, and `sortOrder` fields.
- Filter inactive ads in front-end rendering.

## Common Pitfalls
- Exposing inactive ads in templates.
- Missing authorization on admin ad actions.
