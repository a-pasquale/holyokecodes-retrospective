# Contributing to the Holyoke Codes retrospective

This repo is the public retrospective site for Holyoke Codes (2014–2023).
Content rules are hard requirements, not style preferences. Full policy:
`docs/superpowers/specs/2026-08-15-holyokecodes-retrospective-design.md`.

## Content rules (allowlist)
Only three kinds of files may be added:
1. Hand-authored content under `src/`, `docs/`, and config files.
2. Images in `media/` that were already published on the original public
   site, processed through `node scripts/process-media.mjs` (strips EXIF/GPS).
3. Curriculum PDFs in `curriculum/`.

Never add: anything copied wholesale from the local archive; minors' names
(including first names); attendee data (only already-published aggregates);
contracts, budgets, tax documents, addresses, phone numbers, recordings.
All copy is past tense.

## One-time setup
```
npm install
git config core.hooksPath .githooks
```
The pre-push hook runs the build and the redirect-completeness check.

`npm run check:sensitive` is an optional manual check. It scans the content
against a private names file at `~/.holyokecodes/participant-names.txt`
(never committed). Run it yourself before publishing new content if you have
that file.
