#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: ./scripts/restore.sh /path/to/archive.tar.gz" >&2
  exit 1
fi

ARCHIVE_PATH="$1"
ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
DB_DIR="${ROOT_DIR}/data"
UPLOADS_DIR="${ROOT_DIR}/data/uploads"

if [ ! -f "${ARCHIVE_PATH}" ]; then
  echo "Archive not found: ${ARCHIVE_PATH}" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT INT TERM

tar -xzf "${ARCHIVE_PATH}" -C "${TMP_DIR}"
mkdir -p "${DB_DIR}"

if [ -f "${TMP_DIR}/kdic.sqlite3" ]; then
  cp "${TMP_DIR}/kdic.sqlite3" "${DB_DIR}/kdic.sqlite3"
fi

if [ -d "${TMP_DIR}/uploads" ]; then
  rm -rf "${UPLOADS_DIR}"
  cp -R "${TMP_DIR}/uploads" "${UPLOADS_DIR}"
fi

echo "Restore completed from ${ARCHIVE_PATH}"
