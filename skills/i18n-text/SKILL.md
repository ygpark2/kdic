---
name: i18n-text
description: Update user-facing text, labels, and copy in hkforum. Use when editing templates, default settings, or message strings, and when introducing i18n patterns.
---

# Text and i18n Workflow

## Quick Workflow
- Update copy in `templates/**`.
- Update defaults in `config/settings.yml` if needed.
- Keep validation messages in line with Yesod defaults unless specified.

## 현재 상태
- 별도 i18n 리소스 파일이나 다국어 라우팅은 없음.

## Key Code References
- Templates: `templates/**`
- Settings defaults: `config/settings.yml`
- Layouts: `templates/layout/*`

## Conventions
- Keep copy consistent with existing tone.
- Prefer short, scannable labels.

## Common Pitfalls
- Hardcoding user-specific data without escaping.
- Inconsistent terminology across templates.
