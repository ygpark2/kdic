---
name: storage-uploads
description: Work on file upload and storage behavior for hkforum. Use when changing local/S3 storage logic in src/Storage.hs, upload handlers, or storage-related settings in config/settings.yml.
---

# Storage/Upload Workflow

## Quick Workflow
- Review settings in `config/settings.yml` and `src/Settings.hs`.
- Update backend logic in `src/Storage.hs` (local vs S3).
- Update upload handler in `src/Handler/Upload.hs` and routes in `config/routes`.

## 핵심 엔드포인트
- `POST /upload` -> Upload API
- `GET /files/#Text` -> File download

## 핵심 핸들러
- `postUploadR` (`src/Handler/Upload.hs`)
- `getFileR` (`src/Handler/Upload.hs`)

## Key Code References
- Storage logic: `src/Storage.hs`
- Upload handler: `src/Handler/Upload.hs`
- File routes: `config/routes` (`/files/#Text`)
- Settings: `config/settings.yml`, `src/Settings.hs`

## Local Storage
- Files saved under `data/uploads` by default.
- Public URLs generated via `/files/<key>`.

## S3 Storage
- Uploads via `aws s3api put-object` in `src/Storage.hs`.
- Requires `aws` CLI and env configuration.
- `endpoint` and `forcePathStyle` support S3-compatible services.

## Common Pitfalls
- Forgetting to create or permission `data/uploads`.
- Misconfigured `publicBaseUrl` causing broken links.
