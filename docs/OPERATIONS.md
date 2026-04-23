# Operations Guide

## Health Checks

- `GET /healthz`
  - Use for uptime monitors and post-deploy smoke checks.
- `GET /sitemap.xml`
  - Confirm crawler-facing routes are available after deploys.

## Backup

Create a backup archive:

```sh
./scripts/backup.sh
```

This captures:

- `data/kdic.sqlite3`
- `data/uploads/`
- backup metadata with timestamp and git revision

## Restore

Restore from an archive:

```sh
./scripts/restore.sh /path/to/archive.tar.gz
```

Recommended restore flow:

1. Stop the running app.
2. Restore the archive.
3. Start the app and let migrations run.
4. Verify `/healthz`, `/sitemap.xml`, and a few public pages.

## Error Monitoring

- Watch application logs for:
  - failed migrations
  - ad embed validation failures
  - unexpected 5xx responses
- Add an external uptime check against `/healthz`.
- Review `/admin/ops` after moderation or configuration sessions.

## Deploy Checklist

1. Run `stack test`.
2. Run `cd frontend && npm run build`.
3. Create a fresh backup with `./scripts/backup.sh`.
4. Deploy the new build.
5. Verify:
   - `/healthz`
   - `/sitemap.xml`
   - homepage
   - one word detail page
   - `/admin/ops`
