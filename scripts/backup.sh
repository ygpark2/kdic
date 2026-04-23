#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
TIMESTAMP="$(date +"%Y%m%d-%H%M%S")"
BACKUP_DIR="${ROOT_DIR}/backups"
ARCHIVE_PATH="${BACKUP_DIR}/kdic-backup-${TIMESTAMP}.tar.gz"
DB_PATH="${ROOT_DIR}/data/kdic.sqlite3"
UPLOADS_DIR="${ROOT_DIR}/data/uploads"

mkdir -p "${BACKUP_DIR}"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT INT TERM

if [ -f "${DB_PATH}" ]; then
  cp "${DB_PATH}" "${TMP_DIR}/kdic.sqlite3"
fi

if [ -d "${UPLOADS_DIR}" ]; then
  cp -R "${UPLOADS_DIR}" "${TMP_DIR}/uploads"
fi

cat > "${TMP_DIR}/metadata.txt" <<EOF
timestamp=${TIMESTAMP}
app_root=${ROOT_DIR}
git_commit=$(git -C "${ROOT_DIR}" rev-parse --short HEAD 2>/dev/null || echo unknown)
EOF

tar -czf "${ARCHIVE_PATH}" -C "${TMP_DIR}" .
echo "Backup created at ${ARCHIVE_PATH}"
