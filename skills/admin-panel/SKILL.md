---
name: admin-panel
description: Work on admin pages and workflows for hkforum. Use when changing admin routes, templates, or handlers under src/Handler/Admin.hs and templates/admin/*.
---

# Admin Panel Workflow

## Quick Workflow
- Update routes in `config/routes`.
- Implement logic in `src/Handler/Admin.hs`.
- Update templates in `templates/admin/*`.
- Ensure authorization in `src/Foundation.hs` via `isAdmin`.

## 핵심 엔드포인트
- `GET /admin`
- `GET /admin/boards`, `POST /admin/boards`
- `GET /admin/boards/new`
- `GET /admin/boards/#BoardId/view`, `POST /admin/boards/#BoardId/view`
- `GET /admin/users`, `POST /admin/users`
- `GET /admin/users/new`
- `GET /admin/users/#UserId/view`, `POST /admin/users/#UserId/view`
- `GET /admin/settings`, `POST /admin/settings`
- `GET /admin/settings/new`
- `GET /admin/settings/#SiteSettingId/view`
- `GET /admin/ads`, `POST /admin/ads`
- `GET /admin/ads/new`
- `GET /admin/ads/#AdId/view`, `POST /admin/ads/#AdId/view`

## 핵심 핸들러
- `getAdminR`
- `getAdminBoardsR`, `postAdminBoardsR`
- `getAdminBoardNewR`, `getAdminBoardR`, `postAdminBoardR`
- `getAdminUsersR`, `postAdminUsersR`
- `getAdminUserNewR`, `getAdminUserR`, `postAdminUserR`
- `getAdminSettingsR`, `postAdminSettingsR`
- `getAdminSettingNewR`, `getAdminSettingR`
- `getAdminAdsR`, `postAdminAdsR`
- `getAdminAdNewR`, `getAdminAdR`, `postAdminAdR`

## Key Code References
- Admin handler: `src/Handler/Admin.hs`
- Admin templates: `templates/admin/*`
- Admin layout: `templates/layout/admin-layout.hamlet`
- Auth checks: `src/Foundation.hs` (isAdmin)

## Conventions
- Use admin layout for all admin pages.
- Keep admin-only actions behind `isAdmin`.

## Common Pitfalls
- Unprotected admin routes.
- Inconsistent layout usage.
