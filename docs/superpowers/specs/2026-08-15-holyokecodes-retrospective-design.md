# Holyoke Codes Retrospective Site — Design Spec

**Date:** 2026-08-15
**Status:** Approved (spec reviewed and signed off by Andrew, 2026-08-18)
**Replaces:** the live WordPress site at holyokecodes.org (Closte-hosted, being decommissioned)

## Purpose

Holyoke Codes (2014–2023) is no longer running programs. This project builds a
static retrospective site that presents the program as a public historical
record: what it was, what it did, and what it leaves behind — while making
unmistakable that no programs are currently offered.

Source material: the full local archive at `/Users/drew/Sites/holyokecodes-archive/`
(wget mirror, UpdraftPlus full backup, 76 media originals, REST JSON exports)
and the research corpus in `/Users/drew/Documents/projects/holyoke_codes/`.

## Approved decisions

| Decision | Choice |
|---|---|
| Site form | New curated retrospective (not a preserved mirror) |
| Hosting | Netlify, backed by a GitHub repo (repo doubles as public archive) |
| Generator | Eleventy (Nunjucks templates, Markdown content); `_site/` gitignored, built by Netlify/CI |
| Domain | holyokecodes.org, DNS in Cloudflare, flipped after sign-off |
| Photos | Kept as originally published (Andrew holds original permissions) |
| Ending frame | "Honest arc" — pandemic loss of MGHPCC home base, gradual wind-down after 2023 |
| Visual design | Mirror the original theme closely; changes only where they are actual improvements |

### Approved framing copy (home page lede, editable during build)

> Holyoke Codes began in December 2014 with a week of free workshops at the
> Massachusetts Green High Performance Computing Center, and grew into nearly
> weekly programs reaching more than a thousand kids. When the pandemic closed
> our home at the MGHPCC in 2020, we kept going — remote summers, partner
> venues, robotics teams — but the program never regained its footing, and
> after the 2023 season we quietly wound down. This site is the record of what
> a small group of educators and a lot of curious kids built together.

## Look & feel

Faithful rebuild of the original Oxygen-built theme in hand-rolled static
HTML/CSS. Elements to reproduce (reference: archived screenshots + mirror CSS):

- Rosie-the-robot mascot logo; blue "HOLYOKE CODES" wordmark (white variant in footer)
- Blue utility strip with angled left edge at top; blue full-width footer
- White header with icon-based primary nav (calendar / potted-gadget-plant / news icons)
- Purple→blue gradient divider under the header
- Circle program tiles with pixel-art icons (rainbow, robot, kids, earth)
- Coral/red accent color for display headings ("Compute creatively." style) and buttons
- Sponsor logo row ("Some of our amazing sponsors!")
- Typography: Cardo (serif body), Inter, plus the rounded display face used for
  headings — exact font name and all hex values extracted **programmatically**
  from the archived theme CSS (`wp-backup/*-themes.zip` / the mirror's
  stylesheets), never eyeballed from screenshots

Fidelity scope (per review): the targets are the mascot, wordmark, palette,
typography, and layout structure — not a pixel-perfect reproduction of Oxygen's
generated markup. Theme-matching work is timeboxed; when in doubt, content
accuracy wins over CSS archaeology.

Permitted improvements (the "actual improvements" rule):

- Real responsive behavior on small screens
- Alt text on all images; semantic landmarks; keyboard-usable nav
- Contrast fixes only where the original fails WCAG AA
- No Oxygen/jQuery runtime, no client-side JS unless a page genuinely needs it
- Remove dead chrome: search button, admin-bar remnants, cookie/plugin artifacts

## What changes because it is an archive

- The top utility strip becomes the persistent archival notice:
  **"Holyoke Codes ran from 2014 to 2023. This site is its historical record."**
  (replaces About / Support Us / Contact links; social icons dropped or pointed
  at archived-profile equivalents if they still exist)
- Removed entirely: newsletter signup, Donate button and GiveWP flow,
  registration/ticket pages, contact forms
- All copy in past tense; sponsor row retitled to past-tense thanks
- Primary nav repurposed, same icons: **Timeline** (was Calendar),
  **Programs**, **News**

## Information architecture (~12 pages)

| Path | Content |
|---|---|
| `/` | Honest-arc story, headline numbers (~100 workshops, 1,250+ kids by 2016, 47% girls, 42% from Holyoke), circle tiles into Programs/Robotics/Projects, sponsor row |
| `/timeline/` | 2014 founding → growth years → school programs era → robotics era → 2020 remote summer (83 sessions) → 2022 relaunch → 2023 wind-down |
| `/programs/` | Index + anchored sections (explicitly structured, not one flat page): Public workshops & Lab Nights, HPS specials + 7th-grade Code Week, Got Game!, Family Creative Learning, NPS Creative Computing, Morgan School, summer camps (Boathouse "Codes & Rows", Montessori, LightHouse), tutoring |
| `/robotics/` | CyberScare (FLL, 8 yrs, state champs 2020 & 2021), Aquabots (FTC, 7 yrs), Sumobot Tournament + full ruleset |
| `/projects/` | Landing for artifacts |
| `/projects/galeforce/` | GaleForce (NSF-funded, UMass + Elms) — keeps content of old `/galeforce/` |
| `/projects/scratch-curriculum/` | The free curriculum, PDFs/slides hosted in-repo |
| `/projects/weather-station/` | SparkFun Photon build, Wunderground KMAHOLYO17 |
| `/projects/rosie/` | Rosie chatbot + mascot story |
| `/news/` | Index of the five 2022 posts, presented as period pieces |
| `/news/<original-slugs>/` | The five posts at content-equivalent URLs |
| `/people/` | Educators (2015 founding team and 2022 team), member orgs, partners, funders |

## Redirect map (Netlify `_redirects`, all 301)

`all-urls.txt` (the 34-URL legacy inventory) is checked into the repo as a
frozen artifact and is the single source of truth. A build-time script verifies
every URL in it either exists in `_site/` at the same path or has a matching
`_redirects` rule — CI fails otherwise. The redirect *test* (QA step 3)
asserts the **exact final landing path**, not just a 2xx status. After launch,
Cloudflare/Netlify 404 reporting is reviewed once a few weeks in; the map is
not frozen — newly discovered legacy URLs get rules added.

All five news posts are now confirmed from `content-posts.json`:
`scratch-curriculum-announcement`, `2022-summer-programs`,
`morgan-school-enrichment`, `galeforce`, `2022-summer-programs-3`.
Note `galeforce` and `morgan-school-enrichment` are posts, not pages —
map corrected accordingly.

```
/about/                      /                          301
/calendar/                   /timeline/                 301
/programs-2/                 /programs/                 301
/workshops/                  /programs/                 301
/school-programs/            /programs/                 301
/summer-programs/            /programs/                 301
/community-projects/         /programs/                 301
/tutoring/                   /programs/                 301
/morgan-school-enrichment/   /news/morgan-school-enrichment/ 301
/sumobot-tournament-rules/   /robotics/                 301
/galeforce/                  /projects/galeforce/       301
/scratch-curriculum/         /projects/scratch-curriculum/ 301
/scratch-curriculum-announcement/  /news/scratch-curriculum-announcement/ 301
/2022-summer-programs/       /news/2022-summer-programs/     301
/2022-summer-programs-3/     /news/2022-summer-programs-3/   301
/support-us/                 /people/                   301
/contact/                    /                          301
/donation-confirmation/      /                          301
/donation-failed/            /                          301
/donor-dashboard/            /                          301
/donations/*                 /                          301
/tickets-checkout/           /                          301
/tickets-order/              /                          301
/venue/*                     /timeline/                 301
/author/*                    /people/                   301
/category/*                  /news/                     301
/feed/                       /news/                     301
```

The news posts move from root-level slugs to `/news/<slug>/` (except
`/galeforce/`, which 301s to `/projects/galeforce/`; the news index links
there). `/robotics/` keeps its original path, so it needs no redirect entry.

## Repository layout

```
holyokecodes-retrospective/
  src/            # Eleventy input: markdown content, _includes/ nunjucks layouts
  media/          # curated images from archive originals (EXIF/GPS stripped)
  curriculum/     # Scratch curriculum PDFs/slides (public artifact)
  _redirects      # copied into _site by eleventy passthrough
  all-urls.txt    # frozen legacy-URL inventory (redirect source of truth)
  docs/superpowers/specs/   # this spec
  netlify.toml    # build cmd, publish dir
```

Netlify builds `npx @11ty/eleventy`; publish `_site`. **`_site/` is
gitignored, not committed** (review consensus: a committed build output is a
second copy of the truth that drifts silently; Netlify + a CI build check are
the deployed artifact's guarantee). The archive-of-record role stays with the
already-secured local archive, not this repo.

## Sensitive-material policy (hard rules for repo content)

**Repo boundary (explicit):** `/Users/drew/Sites/holyokecodes-archive/` is
OUTSIDE the repo and must never enter it — no copies, moves, or symlinks. The
policy is an **allowlist, not a denylist**: the only things permitted in the
repo are (1) hand-authored files under `src/`, `docs/`, and config, (2) curated
images in `media/` that were already published on the public site, passed
through EXIF/GPS stripping, (3) curriculum PDFs in `curriculum/`. Nothing is
ever copied wholesale from the archive.

- Attendance/demographic data **only as aggregates** already published in
  proposals (counts, percentages). The attendee CSV
  (`holyokecodes-api/hcdata.csv`) never enters the repo.
- No minors' names anywhere, including first-name project credits
  (e.g. FLL-2020 README) and testimonials naming children/parents.
- No contracts, budgets, EIN/tax documents, personal addresses or phone
  numbers, or the Zoom recordings.
- Photos: as originally published on the site only; no new photos from
  private folders without explicit per-photo approval.
- Grant-application deficit framing about Holyoke rewritten as celebration.

**Enforcement (not just prose):**
- A sensitive-content gate scans everything git publishes plus built output
  for a denylist (attendee CSV marker, financial-doc markers, credential
  shapes, and a privately maintained list of known participant first names).
  PDFs are scanned via extracted text and images via a metadata sweep, since
  plain grep cannot see inside binaries. The names list lives OUTSIDE the
  repo (it is itself sensitive) — locally as a private file, and as an
  encrypted secret in CI and the Netlify build so that web-UI edits and
  hook-bypassing pushes cannot skip the gate. The gate fails loudly if the
  list is missing or empty. (Enforcement layers strengthened per adversarial
  review, 2026-08-21.)
- All images pass through EXIF/GPS metadata stripping in the build pipeline.
- A `CONTRIBUTING.md` note restates these rules next to where content gets
  added, so the policy survives without this spec being re-read.

**Old-site credential hygiene (decommission step):** the WordPress DB contains
third-party API keys (Stripe, Mailchimp, reCAPTCHA and possibly others), donor
records, form submissions, and password hashes. When the Closte site is
decommissioned, those API keys are rotated/revoked at their providers and
treated as compromised — regardless of whether they ever touch this repo.

## Error handling

- Custom 404 in the site's theme, linking home and to the timeline.
- Redirect map is exhaustive over the 34 known legacy URLs (from
  `all-urls.txt`); anything else falls to the 404.

## Testing / QA

1. `eleventy` build passes in CI (GitHub Action) and on Netlify.
2. Internal link checker over `_site/` (no broken hrefs/srcs).
3. Redirect test: script curls every legacy URL from `all-urls.txt` against a
   Netlify deploy preview and asserts the **exact expected landing path**
   (from a URL→destination fixture), not merely a 2xx.
4. Redirect-map completeness check in CI: every `all-urls.txt` entry must have
   a rule or an existing same-path page, else the build fails.
5. Sensitive-content grep gate (see policy Enforcement above) runs pre-deploy.
6. Visual QA: side-by-side with archived screenshots of the original theme;
   re-run after any pre-launch CSS/content change.
7. Lighthouse: accessibility ≥ 95 on **all pages** (the site is small; no
   sampling).
8. Pre-launch content review by Andrew as a **structured walk of each policy
   rule** (photos, names, framing, docs) — not a general read-through.

## Launch sequence

1. Deploy to Netlify subdomain; Andrew reviews, then invites former
   collaborators (the named educators) to review the site — including the
   honest-arc framing and their own mentions — before DNS cutover.
2. Add holyokecodes.org custom domain in Netlify.
3. Cloudflare DNS: point apex + www at Netlify; keep old server records until verified.
4. Verify redirects live; then decommission the Closte WordPress site
   (archive already secured locally).
