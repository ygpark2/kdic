---
name: profile-settings
description: Work on user profile and account settings in hkforum. Use when modifying profile handlers, templates, or user fields in config/models.
---

# Profile Workflow

## Quick Workflow
- Update profile routes in `config/routes`.
- Implement logic in `src/Handler/Profile.hs`.
- Update templates in `templates/profile.hamlet` and related layouts.
- If user fields change, update `config/models` and related handlers.

## 핵심 엔드포인트
- `GET /profile`
- `POST /profile`

## 핵심 핸들러
- `getProfileR`, `postProfileR` (`src/Handler/Profile.hs`)

## Key Code References
- Handler: `src/Handler/Profile.hs`
- Template: `templates/profile.hamlet`
- Models: `config/models` (User)
- Routes: `config/routes`

## Common Pitfalls
- Allowing profile updates without authentication.
- Forgetting to validate input and sanitize text.
