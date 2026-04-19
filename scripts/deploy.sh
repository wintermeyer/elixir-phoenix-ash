#!/usr/bin/env bash
# Deploy two Antora sites from this repo:
#
#   - main Phoenix book -> /var/www/elixir-phoenix-ash/
#   - Elixir mini-book  -> /var/www/elixir-book/
#
# Both land via timestamped releases and an atomic `current`
# symlink swap. Runs on the `eliph` self-hosted GitHub Actions
# runner from the actions/checkout workdir.
#
# Node is provided via mise under ~eliph.

set -euo pipefail

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)"
elif [ -x "$HOME/.local/bin/mise" ]; then
  eval "$("$HOME/.local/bin/mise" activate bash)"
fi

PHOENIX_APP_DIR="/var/www/elixir-phoenix-ash"
ELIXIR_APP_DIR="/var/www/elixir-book"
KEEP_RELEASES=5
TIMESTAMP="$(date +%Y%m%d%H%M%S)"

PHOENIX_RELEASE_DIR="${PHOENIX_APP_DIR}/releases/${TIMESTAMP}"
ELIXIR_RELEASE_DIR="${ELIXIR_APP_DIR}/releases/${TIMESTAMP}"
LOCK_FILE="${PHOENIX_APP_DIR}/shared/.deploy.lock"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

mkdir -p "${PHOENIX_APP_DIR}/shared"
exec 9>"${LOCK_FILE}"
flock -n 9 || { log "ERROR: another deploy is running"; exit 1; }

REPO_DIR="$(pwd)"
log "Repo: ${REPO_DIR}"

publish_release() {
  local app_dir="$1"
  local release_dir="$2"
  local source_dir="$3"

  log "Publishing ${release_dir}..."
  mkdir -p "${release_dir}"
  cp -a "${source_dir}/." "${release_dir}/"
  chmod -R a+rX "${release_dir}"

  local current_link="${app_dir}/current"
  log "Atomic swap ${current_link} -> ${release_dir}"
  ln -sfn "${release_dir}" "${current_link}.new"
  mv -fT "${current_link}.new" "${current_link}"

  log "Pruning ${app_dir}/releases (keeping last ${KEEP_RELEASES})..."
  mapfile -t _old < <(
    find "${app_dir}/releases" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
      | sort | head -n "-${KEEP_RELEASES}"
  )
  for r in "${_old[@]}"; do
    [ -n "${r}" ] && rm -rf "${app_dir}/releases/${r:?}"
  done
}

log "Fetching latest nav + footer partials from wincon..."
./scripts/fetch-partials.sh

log "Syncing Elixir chapter into elixir-book/modules/ROOT/pages/..."
python3 elixir-book/scripts/sync.py

log "Installing Antora..."
( cd "${REPO_DIR}" && npm ci --no-audit --no-fund )

log "Rendering Phoenix book..."
# --fetch refreshes the content source and the shared UI bundle
# (wincon-antora-ui/releases/latest/ui-bundle.zip). snapshot:true
# in the playbook tells Antora not to cache across runs.
( cd "${REPO_DIR}" && npx antora --fetch antora-playbook.yml )

if [ ! -d "${REPO_DIR}/build/site/book" ]; then
  log "ERROR: expected build/site/book/ not found"
  exit 1
fi

log "Rendering Elixir mini-book..."
( cd "${REPO_DIR}" && npx antora antora-elixir-playbook.yml )

if [ ! -d "${REPO_DIR}/build/elixir-site/book" ]; then
  log "ERROR: expected build/elixir-site/book/ not found"
  exit 1
fi

publish_release "${PHOENIX_APP_DIR}" "${PHOENIX_RELEASE_DIR}" "${REPO_DIR}/build/site"
mkdir -p "${ELIXIR_APP_DIR}/shared"
publish_release "${ELIXIR_APP_DIR}" "${ELIXIR_RELEASE_DIR}" "${REPO_DIR}/build/elixir-site"

log "Deploy complete: ${TIMESTAMP}"
log "  Phoenix: ${PHOENIX_APP_DIR}/current -> $(readlink -f "${PHOENIX_APP_DIR}/current")"
log "  Elixir:  ${ELIXIR_APP_DIR}/current -> $(readlink -f "${ELIXIR_APP_DIR}/current")"
