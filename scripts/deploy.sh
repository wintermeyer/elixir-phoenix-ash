#!/usr/bin/env bash
# Deploy the Phoenix book (Antora) to bremen2 under
# /var/www/phoenix-book/releases/<timestamp>/ and atomically
# swap the `current` symlink.
#
# Runs on the `books` self-hosted GitHub Actions runner from the
# actions/checkout workdir. Invoked as `./scripts/deploy.sh`.
#
# The Antora build needs Node (provided via mise under ~books).

set -euo pipefail

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)"
elif [ -x "$HOME/.local/bin/mise" ]; then
  eval "$("$HOME/.local/bin/mise" activate bash)"
fi

APP_DIR="/var/www/phoenix-book"
RELEASES_DIR="${APP_DIR}/releases"
CURRENT_LINK="${APP_DIR}/current"
SHARED_DIR="${APP_DIR}/shared"
LOCK_FILE="${SHARED_DIR}/.deploy.lock"
KEEP_RELEASES=5
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
RELEASE_DIR="${RELEASES_DIR}/${TIMESTAMP}"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

mkdir -p "${SHARED_DIR}"
exec 9>"${LOCK_FILE}"
flock -n 9 || { log "ERROR: another deploy is running"; exit 1; }

REPO_DIR="$(pwd)"
log "Repo: ${REPO_DIR}"

log "Fetching latest nav + footer partials from wincon..."
./scripts/fetch-partials.sh

log "Installing Antora..."
npm ci --no-audit --no-fund

log "Rendering site..."
# --fetch refreshes the content source and the shared UI bundle
# (wincon-antora-ui/releases/latest/ui-bundle.zip).
npx antora --fetch antora-playbook.yml

if [ ! -d "${REPO_DIR}/build/site/book" ]; then
  log "ERROR: expected build/site/book/ not found"
  exit 1
fi

log "Publishing release ${TIMESTAMP}..."
mkdir -p "${RELEASE_DIR}"
cp -a "${REPO_DIR}/build/site/." "${RELEASE_DIR}/"
chmod -R a+rX "${RELEASE_DIR}"

# Pre-compress text assets so nginx can serve .br / .gz siblings
# directly via brotli_static / gzip_static with zero CPU per request.
# Drop any sibling that did not actually shrink the payload.
log "Pre-compressing text assets..."
_jobs="$(nproc 2>/dev/null || echo 4)"
_text=( -name '*.html' -o -name '*.css' -o -name '*.js' -o -name '*.mjs'
        -o -name '*.svg' -o -name '*.json' -o -name '*.xml'
        -o -name '*.txt' -o -name '*.map' )
if command -v brotli >/dev/null 2>&1; then
  find "${RELEASE_DIR}" -type f \( "${_text[@]}" \) -print0 \
    | xargs -0 -r -n 8 -P "${_jobs}" brotli -k -q 11 -f --
else
  log "WARN: brotli not installed; skipping .br siblings"
fi
find "${RELEASE_DIR}" -type f \( "${_text[@]}" \) -print0 \
  | xargs -0 -r -n 8 -P "${_jobs}" gzip -k -9 -n -f --
find "${RELEASE_DIR}" -type f \( -name '*.br' -o -name '*.gz' \) -print0 \
  | while IFS= read -r -d '' _c; do
      _o="${_c%.*}"
      [ -f "${_o}" ] || continue
      _cs=$(stat -c%s "${_c}" 2>/dev/null || echo 0)
      _os=$(stat -c%s "${_o}" 2>/dev/null || echo 1)
      if [ "${_cs}" -ge "${_os}" ]; then rm -f "${_c}"; fi
    done

log "Atomic swap..."
ln -sfn "${RELEASE_DIR}" "${CURRENT_LINK}.new"
mv -fT "${CURRENT_LINK}.new" "${CURRENT_LINK}"

log "Pruning old releases (keeping last ${KEEP_RELEASES})..."
mapfile -t _old < <(
  find "${RELEASES_DIR}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
    | sort | head -n "-${KEEP_RELEASES}"
)
for r in "${_old[@]}"; do
  [ -n "${r}" ] && rm -rf "${RELEASES_DIR:?}/${r}"
done

log "Deploy complete: ${TIMESTAMP}"
log "  Active: ${CURRENT_LINK} -> $(readlink -f "${CURRENT_LINK}")"
