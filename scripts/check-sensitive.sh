#!/usr/bin/env bash
# Sensitive-content gate (spec: Sensitive-material policy / Enforcement).
# Fails CLOSED: a missing/empty names file, an unscannable input, or any
# internal error is a failure — never a silent skip. Hits are reported as
# file:line with the matched text redacted (names are never printed).
#
# grep cannot see inside binaries, so this gate partitions by type: text via
# grep, PDFs via pdftotext, raster images via scripts/check-media-metadata.mjs,
# and any other binary is itself a failure (cannot be scanned).
# All file lists are NUL-separated so any path (spaces, non-ASCII) is handled.
set -uo pipefail
fail=0

TMPS=()
cleanup() { [[ ${#TMPS[@]} -gt 0 ]] && rm -f "${TMPS[@]}"; }
trap cleanup EXIT
tmp() { local t; t=$(mktemp) || { echo "FATAL: mktemp failed"; exit 1; }; TMPS+=("$t"); REPLY_TMP="$t"; }

NAMES_FILE="${HOLYOKECODES_NAMES_FILE:-$HOME/.holyokecodes/participant-names.txt}"
if [[ ! -s "$NAMES_FILE" ]]; then
  echo "FATAL: participant-names denylist missing or EMPTY at $NAMES_FILE"
  echo "Zero names checked means zero name protection; populate it first."
  exit 1
fi

# Normalize names: strip CR and UTF-8 BOM, trim whitespace, drop blanks and
# comments. Everything below loops over this normalized copy.
tmp; NAMES="$REPLY_TMP"
if ! LC_ALL=C tr -d '\r' < "$NAMES_FILE" \
   | LC_ALL=C sed -e $'s/\xef\xbb\xbf//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
   | LC_ALL=C grep -v -e '^$' -e '^#' > "$NAMES"; then
  : # grep -v exits 1 when nothing remains; handled by the count check below
fi
n=$(wc -l < "$NAMES" | tr -d ' ')
if [[ "$n" -eq 0 ]]; then
  echo "FATAL: participant-names file has zero usable names (blank/comment-only) at $NAMES_FILE"
  exit 1
fi

command -v pdftotext >/dev/null 2>&1 || {
  echo "FATAL: pdftotext not installed; PDFs cannot be scanned (install poppler-utils / poppler)."
  exit 1
}

# In CI the logs are public and a path can contain a participant name, so print
# an index instead of the path there. where <index> <path>
where() { if [[ -n "${CI:-}" ]]; then echo "worklist item #$1"; else echo "$2"; fi; }

# Scope: everything git would publish (tracked + untracked-unignored),
# plus built output when present — NOT a hardcoded directory list.
tmp; WORKLIST="$REPLY_TMP"
git ls-files -z > "$WORKLIST" || { echo "FATAL: git ls-files failed"; exit 1; }
git ls-files -o --exclude-standard -z >> "$WORKLIST" || { echo "FATAL: git ls-files -o failed"; exit 1; }
if [[ -d _site ]]; then find _site -type f -print0 >> "$WORKLIST" || { echo "FATAL: find failed"; exit 1; }; fi

# The spec's policy is an allowlist — enforce it: a tracked file outside the
# approved roots is itself a violation, whatever it contains.
ti=0
while IFS= read -r -d '' f; do
  ti=$((ti+1))
  case "$f" in
    src/*|docs/*|media/*|curriculum/*|scripts/*|.github/*|.githooks/*) ;;
    package.json|package-lock.json|eleventy.config.js|netlify.toml) ;;
    .gitignore|.nvmrc|_redirects|all-urls.txt|CONTRIBUTING.md|README.md) ;;
    *) echo "ALLOWLIST VIOLATION: tracked file outside approved roots: $(where "$ti" "$f") (tracked-file index)"; fail=1 ;;
  esac
done < <(git ls-files -z)

# Extension classification is case-insensitive; nothing else is.
kind() {
  shopt -s nocasematch
  case "$1" in
    *.pdf) K=pdf ;;
    *.png|*.jpg|*.jpeg|*.gif|*.webp) K=img ;;
    *.ico|*.woff|*.woff2) K=opaque ;;
    *) K=other ;;
  esac
  shopt -u nocasematch
}

# List files hold NUL-terminated "<worklist index> <path>" records (IMGS: bare paths).
tmp; TEXTS="$REPLY_TMP"; tmp; PDFS="$REPLY_TMP"; tmp; POLICY="$REPLY_TMP"
tmp; ALLTEXT="$REPLY_TMP"; tmp; IMGS="$REPLY_TMP"
idx=0
while IFS= read -r -d '' f; do
  idx=$((idx+1))
  [[ -f "$f" ]] || continue   # tracked-but-deleted files have nothing to publish
  kind "$f"
  case "$K" in
    pdf) printf '%s %s\0' "$idx" "$f" >> "$PDFS" ;;
    img) printf '%s\0' "$f" >> "$IMGS" ;;
    opaque) echo "UNSCANNABLE binary type: $(where "$idx" "$f")"; fail=1 ;;
    *)
      # grep -I with an empty pattern: text files (even whitespace-only) match, binaries do not.
      if [[ -s "$f" ]] && ! grep -Iq '' "$f"; then
        echo "UNSCANNABLE binary type: $(where "$idx" "$f")"; fail=1
      elif [[ "$f" == docs/* || "$f" == scripts/check-sensitive.sh ]]; then
        printf '%s %s\0' "$idx" "$f" >> "$POLICY" # policy docs + this script name the markers on purpose
      else
        printf '%s %s\0' "$idx" "$f" >> "$TEXTS"
      fi ;;
  esac
done < "$WORKLIST"
cat "$TEXTS" "$POLICY" > "$ALLTEXT"

count0() { tr -cd '\0' < "$1" | wc -c | tr -d ' '; }

# Fail closed on an empty scan set (an empty file list must never read as clean).
if [[ ! -s "$TEXTS" ]]; then
  echo "FATAL: no text files found to scan; refusing to report clean."
  exit 1
fi

# scan <record-list> <label> <grep-args…>: greps each file. A match prints
# location:line (location redacted in CI); a grep error also fails the gate.
scan() {
  local list="$1" label="$2" rec i f out rc; shift 2
  while IFS= read -r -d '' rec; do
    i=${rec%% *}; f=${rec#* }
    out=$(grep -n "$@" "$f" 2>&1); rc=$?
    if [[ $rc -eq 0 ]]; then
      echo "HIT ($label): $(where "$i" "$f") line(s) $(printf '%s\n' "$out" | cut -d: -f1 | tr '\n' ' ')"; fail=1
    elif [[ $rc -ne 1 ]]; then
      echo "ERROR ($label): grep failed on $(where "$i" "$f")"; fail=1
    fi
  done < "$list"
}

# Markers and credential shapes (shared by text files and extracted PDF text).
# chk <file> <label> <grep-args…>: grep exit 0 = hit, 1 = clean, other = error.
chk() {
  local file="$1" label="$2" rc; shift 2
  grep -q "$@" "$file" 2>/dev/null; rc=$?
  if [[ $rc -eq 0 ]]; then echo "HIT ($label)"; fail=1
  elif [[ $rc -ne 1 ]]; then echo "ERROR ($label): grep failed rc=$rc"; fail=1; fi
}

scan "$TEXTS" "attendee data marker" -F -- "hcdata"
scan "$TEXTS" "tax marker EIN" -Fw -- "EIN"
scan "$TEXTS" "tax marker W-9" -F -- "W-9"
scan "$TEXTS" "tax marker Form 990" -F -- "Form 990"
scan "$TEXTS" "live Stripe key" -E -- "sk_live_[A-Za-z0-9]+"
scan "$TEXTS" "AWS access key" -E -- "AKIA[A-Z0-9]{16}"
scan "$TEXTS" "private key block" -F -- "-----BEGIN"

# Participant first names: fixed-string, whole-word, case-insensitive, over
# every text file including policy docs, and over the file PATHS themselves.
# Path check: punctuation (incl. "_", which grep -w treats as a word char) becomes
# a space so IMG_<name>_01.jpg matches. Prints only worklist line numbers.
tmp; PATHS_TXT="$REPLY_TMP"; tmp; PHIT="$REPLY_TMP"
tr '\0' '\n' < "$WORKLIST" | LC_ALL=C tr '[:punct:]' ' ' > "$PATHS_TXT"
i=0
while IFS= read -r name; do
  i=$((i+1))
  scan "$ALLTEXT" "participant name #$i (redacted)" -Fiw -- "$name"
  pname=$(printf '%s' "$name" | LC_ALL=C tr '[:punct:]' ' ')
  grep -Fiw -n -- "$pname" "$PATHS_TXT" 2>&1 | cut -d: -f1 > "$PHIT"
  if [[ -s "$PHIT" ]]; then
    echo "HIT (participant name #$i in a file PATH, worklist item(s): $(tr '\n' ' ' < "$PHIT"))"; fail=1
  fi
done < "$NAMES"

# PDFs: extracted text only. Extraction failure, or empty/whitespace-only text
# (image-only, encrypted), is itself a failure needing human review.
npdf=0
while IFS= read -r -d '' rec; do
  npdf=$((npdf+1))
  pi=${rec%% *}; pdf=${rec#* }
  loc=$(where "$pi" "$pdf")
  tmp; PT="$REPLY_TMP"
  if ! pdftotext "$pdf" "$PT" 2>/dev/null; then
    echo "unscannable PDF: $loc"; fail=1; continue
  fi
  if [[ -z "$(tr -d '[:space:]' < "$PT")" ]]; then
    echo "unscannable PDF (no extractable text; needs human review): $loc"; fail=1; continue
  fi
  pre="in PDF $loc"
  chk "$PT" "attendee marker $pre" -Fi -- "hcdata"
  chk "$PT" "tax marker EIN $pre" -Fw -- "EIN"
  chk "$PT" "tax marker W-9 $pre" -F -- "W-9"
  chk "$PT" "tax marker Form 990 $pre" -F -- "Form 990"
  chk "$PT" "Stripe key $pre" -E -- "sk_live_[A-Za-z0-9]+"
  chk "$PT" "AWS key $pre" -E -- "AKIA[A-Z0-9]{16}"
  chk "$PT" "private key $pre" -F -- "-----BEGIN"
  j=0
  while IFS= read -r name; do
    j=$((j+1))
    chk "$PT" "participant name #$j $pre" -Fiw -- "$name"
  done < "$NAMES"
done < "$PDFS"

# Raster images anywhere in the worklist: metadata sweep (EXIF/XMP/IPTC/PNG text).
if [[ -s "$IMGS" ]]; then
  xargs -0 node scripts/check-media-metadata.mjs < "$IMGS" || fail=1
else
  echo "no raster images in worklist"
fi

# History: names only (markers are legitimately cited in docs history). Report
# commit SHAs only. A shallow clone cannot be verified, so it fails.
nc=0
if [[ "$(git rev-parse --is-shallow-repository 2>/dev/null)" != "false" ]]; then
  echo "FATAL: shallow or unknown repository; history cannot be scanned (use full clone / fetch-depth: 0)."
  fail=1
else
  tmp; HC="$REPLY_TMP"; tmp; HP="$REPLY_TMP"
  # Text diffs only (no -a): binary diffs read "Binary files differ" and random bytes
  # false-match short names; binary content is covered in-tree by the metadata sweep
  # and PDF extraction. HEAD, not --all: the pass scans what is being built and pushed;
  # other local refs (e.g. preserved pre-public history) are not published.
  while IFS= read -r sha; do
    nc=$((nc+1))
    git show --no-textconv --no-ext-diff --no-color --format='commit %H%n%B' "$sha" > "$HC" 2>/dev/null \
      || { echo "ERROR: cannot read commit $sha"; fail=1; continue; }
    git -c core.quotePath=false show --no-renames --name-only --format= "$sha" 2>/dev/null \
      | LC_ALL=C tr '[:punct:]' ' ' > "$HP" || { echo "ERROR: cannot list paths of commit $sha"; fail=1; continue; }
    k=0
    while IFS= read -r name; do
      k=$((k+1))
      grep -q -Fiw -- "$name" "$HC" 2>/dev/null; rc=$?
      if [[ $rc -eq 0 ]]; then echo "HIT (participant name #$k in history content, commit $sha)"; fail=1
      elif [[ $rc -ne 1 ]]; then echo "ERROR: grep failed on commit $sha"; fail=1; fi
      pname=$(printf '%s' "$name" | LC_ALL=C tr '[:punct:]' ' ')
      grep -q -Fiw -- "$pname" "$HP" 2>/dev/null; rc=$?
      if [[ $rc -eq 0 ]]; then echo "HIT (participant name #$k in a path in history, commit $sha)"; fail=1
      elif [[ $rc -ne 1 ]]; then echo "ERROR: path grep failed on commit $sha"; fail=1; fi
    done < "$NAMES"
  done < <(git rev-list HEAD)
  [[ $nc -gt 0 ]] || { echo "FATAL: no commits found to scan"; fail=1; }
fi

echo "gate: $n names, $(count0 "$ALLTEXT") text files, $npdf PDFs, $(count0 "$IMGS") images, $nc commits scanned — $([[ $fail -eq 0 ]] && echo CLEAN || echo FAIL)"
exit $fail
