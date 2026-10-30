#!/usr/bin/env bash
# Netlify build: nothing deploys without passing every gate.
set -euo pipefail
command -v pdftotext >/dev/null 2>&1 || { echo "pdftotext (poppler) is not available in this build image; the PDF gate cannot run." >&2; exit 1; }
if [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then
  git fetch --unshallow || { echo "git fetch --unshallow failed; history cannot be scanned." >&2; exit 1; }
fi
npx @11ty/eleventy
node scripts/check-redirects.mjs
umask 077
NAMES_TMP=$(mktemp)
trap 'rm -f "$NAMES_TMP"' EXIT
printf '%s\n' "${PARTICIPANT_NAMES:?PARTICIPANT_NAMES env var not set in Netlify}" > "$NAMES_TMP"
HOLYOKECODES_NAMES_FILE="$NAMES_TMP" bash scripts/check-sensitive.sh
