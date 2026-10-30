# Holyoke Codes Retrospective Site Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and launch the static Eleventy retrospective site for Holyoke Codes (2014–2023) that replaces the WordPress site at holyokecodes.org.

**Architecture:** Eleventy 3 (ESM config, Nunjucks layouts, Markdown content) builds `src/` into a gitignored `_site/`, deployed by Netlify. Design tokens are extracted programmatically from the archived Oxygen theme CSS into committed token files. Guardrail scripts (redirect completeness, sensitive-content gate, link checker, Lighthouse, redirect landing-path test) run in CI, a git pre-push hook, and against deploy previews.

**Tech Stack:** Node 22, `@11ty/eleventy@^3`, `sharp` (EXIF stripping), `linkinator`, `lighthouse`, GitHub Actions, Netlify, Cloudflare DNS.

**Spec:** `docs/superpowers/specs/2026-08-15-holyokecodes-retrospective-design.md`

## Global Constraints

- **Repo boundary:** `/Users/drew/Sites/holyokecodes-archive/` never enters the repo — no copies, moves, or symlinks. Allowlist only: hand-authored `src/`/`docs/`/config, EXIF-stripped previously-published images in `media/`, curriculum PDFs in `curriculum/`.
- **No minors' names anywhere** (including first names). No attendee CSV (`hcdata.csv`), contracts, budgets, EIN/tax docs, addresses, phone numbers, Zoom recordings.
- Attendance/demographics **only as already-published aggregates** (~100 workshops, 1,250+ kids by 2016, 47% girls, 42% from Holyoke).
- All copy **past tense**. Grant-application deficit framing about Holyoke rewritten as celebration.
- **No client-side JavaScript** unless a page genuinely needs it. No Oxygen/jQuery runtime.
- Design tokens (fonts, hex values) come **programmatically** from archived theme CSS, never eyeballed.
- Archival notice in the utility strip on every page: **"Holyoke Codes ran from 2014 to 2023. This site is its historical record."**
- `_site/` is **gitignored**, never committed.
- Accessibility: Lighthouse ≥ 95 on all pages; alt text on all images; semantic landmarks; keyboard-usable nav.
- Theme fidelity targets: mascot, wordmark, palette, typography, layout structure — timeboxed, content accuracy wins over CSS archaeology.

**Source paths (read-only, outside repo):**
- Archive root: `/Users/drew/Sites/holyokecodes-archive/`
- Oxygen CSS: `<archive>/mirror/holyokecodes.org/wp-content/uploads/oxygen/css/` (files: `universal.css?cache=1722181152&ver=6.7.4.css`, `site-header-254.css?…`, `footer-258.css?…`, `page-with-title-255.css?…`)
- Content JSON: `<archive>/content-pages.json`, `content-posts.json`, `content-users.json`, `content-tribe_venue.json`
- Media originals (76 files): `<archive>/media-originals/wp-content/uploads/`
- Theme backup: `<archive>/wp-backup/backup_2026-08-15-1144_Holyoke_Codes_e97c4314d76f-themes.zip`
- Research corpus: `/Users/drew/Documents/projects/holyoke_codes/` (incl. `FLL-2020/`, `FTC-2021/`, `FTC-2023/`, proposals/PDFs for aggregate stats)

---

### Task 1: Eleventy scaffold with CI build check

**Files:**
- Create: `package.json`, `eleventy.config.js`, `netlify.toml`, `.gitignore`, `.nvmrc`, `src/index.md`, `src/_includes/base.njk`, `.github/workflows/ci.yml`

**Interfaces:**
- Produces: layout name `base.njk` (all pages use `layout: base.njk`); build output `_site/`; npm scripts `build`, `serve`; Eleventy dirs `input: src`, `includes: _includes`, `data: _data`, `output: _site`; passthrough mappings `media/ → /media/`, `curriculum/ → /curriculum/`, `_redirects → /_redirects`, `src/css/ → /css/`.

- [ ] **Step 1: Write `package.json`**

```json
{
  "name": "holyokecodes-retrospective",
  "private": true,
  "type": "module",
  "engines": { "node": ">=22" },
  "scripts": {
    "build": "eleventy",
    "serve": "eleventy --serve",
    "check:redirects": "node scripts/check-redirects.mjs",
    "check:sensitive": "bash scripts/check-sensitive.sh",
    "check:links": "linkinator http://localhost:8899 --recurse --silent"
  },
  "devDependencies": {
    "@11ty/eleventy": "^3.0.0",
    "http-server": "^14.1.1",
    "linkinator": "^6.1.1",
    "sharp": "^0.33.5"
  }
}
```

- [ ] **Step 2: Write `eleventy.config.js`**

```js
export default function (eleventyConfig) {
  eleventyConfig.addPassthroughCopy({
    media: "media",
    curriculum: "curriculum",
    _redirects: "_redirects",
    "src/css": "css",
  });
  return {
    dir: { input: "src", includes: "_includes", data: "_data", output: "_site" },
    markdownTemplateEngine: "njk",
    htmlTemplateEngine: "njk",
  };
}
```

- [ ] **Step 3: Write `netlify.toml`, `.gitignore`, `.nvmrc`**

`netlify.toml`:
```toml
[build]
  command = "npx @11ty/eleventy"
  publish = "_site"

[build.environment]
  NODE_VERSION = "22"
```

(Deliberately minimal: Task 7 extends the command with the redirect gate and Task 8 replaces it with `scripts/netlify-build.sh` including the sensitive gate. Referencing scripts that don't exist yet would break every deploy if Netlify gets connected earlier than planned.)

`.gitignore`:
```
node_modules/
_site/
.DS_Store
```

`.nvmrc`:
```
22
```

- [ ] **Step 4: Write minimal `src/_includes/base.njk`**

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{% if title %}{{ title }} — {% endif %}Holyoke Codes</title>
</head>
<body>
  <main id="main">
    {{ content | safe }}
  </main>
</body>
</html>
```

- [ ] **Step 5: Write stub `src/index.md`**

```markdown
---
layout: base.njk
title: Home
permalink: /
---

# Holyoke Codes

Placeholder home page — replaced in Task 5.
```

- [ ] **Step 6: Install and verify the build fails-then-passes**

Run: `npm install` then `npx eleventy`
Expected: build succeeds, `_site/index.html` exists and contains `<main id="main">`.
Verify `_site/` is ignored: `git status --porcelain` must not list `_site/`.

- [ ] **Step 7: Write `.github/workflows/ci.yml`**

```yaml
name: CI
on:
  push:
  pull_request:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: npm
      - run: npm ci
      - run: npx eleventy
      - name: Redirect-map completeness
        run: test -f scripts/check-redirects.mjs && node scripts/check-redirects.mjs || echo "check-redirects not yet present (pre-Task-7)"
```

(Task 7 replaces the tolerant redirect step with a hard-failing one.)

- [ ] **Step 8: Commit**

```bash
git add package.json package-lock.json eleventy.config.js netlify.toml .gitignore .nvmrc src/ .github/
git commit -m "feat: Eleventy scaffold with CI build check"
```

---

### Task 2: Design-token extraction from archived theme CSS

**Files:**
- Create: `scripts/extract-tokens.mjs`, `src/_data/tokens.json` (generated, committed), `src/css/tokens.css` (hand-mapped from generated data)

**Interfaces:**
- Produces: CSS custom properties consumed by every later styling task: `--c-accent`, `--c-accent-dark`, `--c-blue`, `--c-blue-alt`, `--c-ink`, `--c-paper`, `--font-display`, `--font-body`, `--font-serif`. Also `src/_data/tokens.json` with `{ fonts: string[], colors: [hex, count][] }` as the audit trail.

- [ ] **Step 1: Write `scripts/extract-tokens.mjs`**

```js
// Reads the archived Oxygen theme CSS (outside the repo) and records the
// fonts and hex colors actually used. Run locally once; output is committed
// as the audit trail behind src/css/tokens.css.
import { readFileSync, readdirSync, writeFileSync, mkdirSync } from "node:fs";
import path from "node:path";

const CSS_DIR =
  process.argv[2] ??
  "/Users/drew/Sites/holyokecodes-archive/mirror/holyokecodes.org/wp-content/uploads/oxygen/css";

const css = readdirSync(CSS_DIR)
  .filter((f) => f.includes(".css"))
  .map((f) => readFileSync(path.join(CSS_DIR, f), "utf8"))
  .join("\n");

const fonts = [
  ...new Set(
    [...css.matchAll(/font-family:\s*'?([A-Za-z ]+?)'?\s*[;,!}]/g)].map((m) => m[1].trim())
  ),
];

const counts = {};
for (const [hex] of css.matchAll(/#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b/g)) {
  const h = hex.toLowerCase();
  counts[h] = (counts[h] ?? 0) + 1;
}
const colors = Object.entries(counts).sort((a, b) => b[1] - a[1]);

mkdirSync("src/_data", { recursive: true });
writeFileSync("src/_data/tokens.json", JSON.stringify({ fonts, colors }, null, 2) + "\n");
console.log("fonts:", fonts.join(", "));
console.log("top colors:", colors.slice(0, 12).map(([h, n]) => `${h} (${n})`).join("  "));
```

- [ ] **Step 2: Run extraction and confirm expected signal**

Run: `node scripts/extract-tokens.mjs`
Expected: `fonts:` includes `Inter` and `Poppins`; `top colors:` includes `#db2a3f`, `#a50e20`, `#225fb3`, `#1e73be` (verified present during planning).

- [ ] **Step 3: Confirm the body serif font programmatically**

The spec names Cardo as the serif body face; it does not appear in the Oxygen CSS dir, so locate it in the wider theme:

```bash
grep -rl "Cardo" "/Users/drew/Sites/holyokecodes-archive/mirror/holyokecodes.org/" --include="*.css*" | head
unzip -p "/Users/drew/Sites/holyokecodes-archive/wp-backup/backup_2026-08-15-1144_Holyoke_Codes_e97c4314d76f-themes.zip" | grep -ao "Cardo" | head -1
grep -o "fonts.googleapis.com[^\"']*" "/Users/drew/Sites/holyokecodes-archive/mirror/holyokecodes.org/index.html" | head
```

Expected: at least one hit establishing Cardo (or, if none, the actual serif the site loaded — use what the evidence says, and note the finding in `src/css/tokens.css` as a comment). Record the exact Google Fonts request URL found in the mirror's `index.html` for Task 4.

- [ ] **Step 4: Hand-map extraction output to `src/css/tokens.css`**

Every value must appear in `tokens.json` or the Step-3 grep output — no invented values:

```css
/* Values extracted from the archived Oxygen theme CSS.
   Audit trail: src/_data/tokens.json (scripts/extract-tokens.mjs). */
:root {
  --c-accent: #db2a3f;      /* coral/red display headings + buttons */
  --c-accent-dark: #a50e20; /* hover/darker accent */
  --c-blue: #225fb3;        /* wordmark / utility strip blue */
  --c-blue-alt: #1e73be;    /* link blue */
  --c-ink: #333333;
  --c-paper: #ffffff;
  --font-display: "Poppins", system-ui, sans-serif;
  --font-body: "Inter", system-ui, sans-serif;
  --font-serif: "Cardo", Georgia, serif; /* confirm via Step 3; adjust if evidence differs */
}
```

Adjust which blue is which by opening the mirror home page (`file:///Users/drew/Sites/holyokecodes-archive/mirror/holyokecodes.org/index.html`) with devtools and checking the computed color of the utility strip and wordmark — this is verification of role assignment, not of values (values stay extraction-sourced).

- [ ] **Step 5: Build and commit**

Run: `npx eleventy` — passes.

```bash
git add scripts/extract-tokens.mjs src/_data/tokens.json src/css/tokens.css
git commit -m "feat: extract design tokens from archived theme CSS"
```

---

### Task 3: Media pipeline (EXIF strip) and core brand assets

**Files:**
- Create: `scripts/process-media.mjs`, `scripts/check-media-metadata.mjs`, `media/` (brand assets: mascot logo, wordmark variants, nav icons, circle-tile pixel icons, sponsor logos)

**Interfaces:**
- Consumes: `media-originals/wp-content/uploads/` and the mirror's `wp-content/uploads/` (read-only).
- Produces: `scripts/process-media.mjs <source-abs-path> <dest-rel-under-media/>`; stripped images under `media/` referenced by later tasks as `/media/<dest>`. Naming convention: `media/brand/`, `media/icons/`, `media/sponsors/`, `media/photos/`.

- [ ] **Step 1: Write `scripts/process-media.mjs`**

```js
// Copies one already-published image into media/ via sharp re-encode,
// which drops all EXIF/GPS metadata. .rotate() bakes in EXIF orientation
// first so stripping doesn't visually rotate photos.
import sharp from "sharp";
import path from "node:path";
import { mkdirSync } from "node:fs";

const [src, dest] = process.argv.slice(2);
if (!src || !dest) {
  console.error("usage: node scripts/process-media.mjs <source-image> <dest-under-media/>");
  process.exit(1);
}
const out = path.join("media", dest);
mkdirSync(path.dirname(out), { recursive: true });
await sharp(src).rotate().toFile(out);
const meta = await sharp(out).metadata();
// EXIF alone is not enough: the archive's originals carry more XMP tags than
// EXIF, including XMP face-region metadata identifying faces in photos of
// children (verified on 2023/02/sumobot_tournament.jpg).
for (const k of ["exif", "xmp", "iptc"]) {
  if (meta[k]) {
    console.error(`FATAL: ${k} metadata survived in ${out}`);
    process.exit(1);
  }
}
console.log("wrote (metadata-free):", out);
```

Note: the archive contains zero SVG files (verified). If an SVG is ever wanted, treat it as a policy exception — it bypasses sharp entirely, so it needs explicit review for `<script>`, `on*` event attributes, external references, and RDF/metadata blocks before entering `media/`.

- [ ] **Step 2: Inventory the home page's actual asset files**

Discover exact filenames from the mirror instead of guessing:

```bash
grep -oE '(src|href)="[^"]*uploads[^"]*\.(png|jpg|jpeg|svg|gif|webp)' \
  "/Users/drew/Sites/holyokecodes-archive/mirror/holyokecodes.org/index.html" | sort -u
```

Expected: a list including the Rosie mascot/logo, nav icons (calendar / plant / news), circle-tile pixel icons (rainbow, robot, kids, earth), and sponsor logos. Record the list in the task notes.

- [ ] **Step 3: Process each brand asset through the pipeline**

For each discovered file (resolve it under `media-originals/wp-content/uploads/` first, falling back to the mirror's copy):

```bash
node scripts/process-media.mjs "<abs-source>" "brand/<name>"    # logo/wordmark
node scripts/process-media.mjs "<abs-source>" "icons/<name>"    # nav + tile icons
node scripts/process-media.mjs "<abs-source>" "sponsors/<name>" # sponsor row
```

- [ ] **Step 4: Write `scripts/check-media-metadata.mjs` (reused by the Task-8 gate) and run it**

```js
// Fails if any raster image in media/ (or built output) carries EXIF, XMP,
// or IPTC metadata. Called standalone and by scripts/check-sensitive.sh.
import sharp from "sharp";
import { readdirSync, statSync, existsSync } from "node:fs";

const roots = ["media", "_site/media"].filter(existsSync);
const walk = (d) =>
  readdirSync(d).flatMap((f) => {
    const p = `${d}/${f}`;
    return statSync(p).isDirectory() ? walk(p) : [p];
  });

let bad = 0;
let checked = 0;
for (const f of roots.flatMap(walk).filter((f) => /\.(png|jpe?g|webp|gif)$/i.test(f))) {
  checked++;
  const m = await sharp(f).metadata();
  for (const k of ["exif", "xmp", "iptc"]) {
    if (m[k]) {
      console.error(`METADATA (${k}) FOUND: ${f}`);
      bad++;
    }
  }
}
console.log(`media metadata sweep: ${checked} raster images checked, ${bad} with metadata`);
process.exit(bad ? 1 : 0);
```

Run: `node scripts/check-media-metadata.mjs`
Expected: `media metadata sweep: N raster images checked, 0 with metadata`, exit 0. (N must equal the number of raster files you processed — a count of 0 means the sweep looked at nothing and is itself a failure to investigate.)

- [ ] **Step 5: Build and commit**

Run: `npx eleventy` — passes; `_site/media/` contains the assets.

```bash
git add scripts/process-media.mjs scripts/check-media-metadata.mjs media/
git commit -m "feat: metadata-stripping media pipeline and core brand assets"
```

---

### Task 4: Base theme — header, utility strip, nav, footer, typography

**Files:**
- Modify: `src/_includes/base.njk`
- Create: `src/css/site.css`

**Interfaces:**
- Consumes: `src/css/tokens.css` custom properties (Task 2); `media/brand/`, `media/icons/` assets (Task 3).
- Produces: the sitewide chrome every page renders inside; nav landmark structure (`header > nav`, `main#main`, `footer`); Google Fonts loaded via `<link>` (Inter, Poppins, and the confirmed serif), no JS.

- [ ] **Step 1: Rewrite `src/_includes/base.njk` with full chrome**

Reference the mirror home page for structure. Required elements (spec "Look & feel" + "What changes"):

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{% if title %}{{ title }} — {% endif %}Holyoke Codes</title>
  <meta name="description" content="{{ description or 'Holyoke Codes (2014–2023) — the historical record of free coding and robotics programs for kids in Holyoke, Massachusetts.' }}">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <!-- Use the exact families/weights recorded from the mirror in Task 2 Step 3 -->
  <link href="https://fonts.googleapis.com/css2?family=Cardo:ital@0;1&family=Inter:wght@400;600&family=Poppins:wght@600;700&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="/css/tokens.css">
  <link rel="stylesheet" href="/css/site.css">
</head>
<body>
  <a class="skip-link" href="#main">Skip to content</a>
  <div class="utility-strip" role="note">
    Holyoke Codes ran from 2014 to 2023. This site is its historical record.
  </div>
  <header class="site-header">
    <a class="brand" href="/">
      <img src="/media/brand/{{ '<logo file from Task 3>' }}" alt="Holyoke Codes — Rosie the robot mascot" width="220" height="60">
    </a>
    <nav aria-label="Primary">
      <ul>
        <li><a href="/timeline/"><img src="/media/icons/{{ '<calendar icon>' }}" alt="" width="28" height="28"> Timeline</a></li>
        <li><a href="/programs/"><img src="/media/icons/{{ '<plant icon>' }}" alt="" width="28" height="28"> Programs</a></li>
        <li><a href="/news/"><img src="/media/icons/{{ '<news icon>' }}" alt="" width="28" height="28"> News</a></li>
      </ul>
    </nav>
  </header>
  <div class="gradient-divider" aria-hidden="true"></div>
  <main id="main">
    {{ content | safe }}
  </main>
  <footer class="site-footer">
    <img src="/media/brand/{{ '<white wordmark file>' }}" alt="Holyoke Codes" width="180" height="48">
    <p>Holyoke Codes ran free coding and robotics programs for kids from 2014 to 2023 at the Massachusetts Green High Performance Computing Center in Holyoke, MA.</p>
    <p><a href="/people/">People &amp; partners</a> · <a href="/timeline/">Timeline</a></p>
  </footer>
</body>
</html>
```

The `{{ '<…>' }}` placeholders are filled with the exact filenames recorded in Task 3 Step 2 — they are the only permitted deferred values in this plan, because they come from a discovery step inside the same build.

- [ ] **Step 2: Write `src/css/site.css`**

Style against the mirror (open `file:///…/mirror/holyokecodes.org/index.html` side by side). Required, all colors via tokens:

```css
* { box-sizing: border-box; }
body {
  margin: 0;
  font-family: var(--font-serif);
  color: var(--c-ink);
  background: var(--c-paper);
  line-height: 1.6;
}
h1, h2, h3 { font-family: var(--font-display); color: var(--c-accent); }
a { color: var(--c-blue-alt); }
.skip-link { position: absolute; left: -999px; }
.skip-link:focus { left: 8px; top: 8px; background: var(--c-paper); padding: 0.5rem; }

/* Blue utility strip with angled left edge (original had a clipped notch) */
.utility-strip {
  background: var(--c-blue);
  color: var(--c-paper);
  font-family: var(--font-body);
  padding: 0.4rem 1.25rem 0.4rem 3rem;
  clip-path: polygon(1.5rem 0, 100% 0, 100% 100%, 0 100%);
  text-align: right;
}
.site-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 0.75rem 1.25rem; background: var(--c-paper);
  flex-wrap: wrap; gap: 0.75rem;
}
.site-header nav ul {
  display: flex; gap: 1.5rem; list-style: none; margin: 0; padding: 0;
}
.site-header nav a {
  display: flex; align-items: center; gap: 0.4rem;
  font-family: var(--font-body); text-decoration: none; color: var(--c-ink);
}
.gradient-divider {
  height: 6px;
  background: linear-gradient(90deg, #7b2ff7, var(--c-blue-alt));
}
main { max-width: 64rem; margin: 0 auto; padding: 1.5rem 1.25rem 3rem; }
.site-footer {
  background: var(--c-blue); color: var(--c-paper);
  font-family: var(--font-body); padding: 2rem 1.25rem; text-align: center;
}
.site-footer a { color: var(--c-paper); }
@media (max-width: 40rem) {
  .site-header { justify-content: center; }
}
```

The gradient's purple endpoint: check the mirror CSS for the actual gradient rule (`grep -o "linear-gradient[^;]*" <oxygen css files>`) and use its exact stops; `#7b2ff7` above is a stand-in that MUST be replaced by the extracted value (add it to `tokens.css` as `--c-gradient-start`).

- [ ] **Step 3: Build and eyeball**

Run: `npx eleventy --serve`, open `http://localhost:8080/`.
Expected: utility strip with angled edge and archival notice, logo header with 3-icon nav, gradient divider, blue footer. Compare against the mirror home page in a second tab.

- [ ] **Step 4: Commit**

```bash
git add src/_includes/base.njk src/css/site.css src/css/tokens.css
git commit -m "feat: sitewide theme chrome from extracted tokens"
```

---

### Task 5: Home page + stub pages — DESIGN CHECKPOINT

**Files:**
- Modify: `src/index.md` (becomes `src/index.njk`)
- Create: `src/timeline.md`, `src/programs.md`, `src/robotics.md`, `src/projects/index.md`, `src/news/index.md`, `src/people.md` (stubs so no nav/tile link ever dangles)
- Create: `src/css/home.css` (or extend `site.css` — keep circle-tile styles reusable, Programs uses them too)

**Interfaces:**
- Consumes: chrome from Task 4; tile icons + sponsor logos from Task 3.
- Produces: permalinks `/`, `/timeline/`, `/programs/`, `/robotics/`, `/projects/`, `/news/`, `/people/`; a `.circle-tiles` CSS component reused by later pages.

- [ ] **Step 1: Create the six stub pages**

Each stub (example for timeline; repeat with the right title/permalink for programs, robotics, projects/index, news/index, people):

```markdown
---
layout: base.njk
title: Timeline
permalink: /timeline/
---

# Timeline

*Content arrives in a later task.*
```

- [ ] **Step 2: Write `src/index.njk` with the approved lede and real content**

```html
---
layout: base.njk
title: Home
permalink: /
---

<section class="hero">
  <h1>Compute creatively.</h1>
  <p class="lede">
    Holyoke Codes began in December 2014 with a week of free workshops at the
    Massachusetts Green High Performance Computing Center, and grew into nearly
    weekly programs reaching more than a thousand kids. When the pandemic closed
    our home at the MGHPCC in 2020, we kept going — remote summers, partner
    venues, robotics teams — but the program never regained its footing, and
    after the 2023 season we quietly wound down. This site is the record of what
    a small group of educators and a lot of curious kids built together.
  </p>
</section>

<section class="numbers" aria-label="Program highlights">
  <ul>
    <li><strong>~100</strong> workshops</li>
    <li><strong>1,250+</strong> kids reached by 2016</li>
    <li><strong>47%</strong> girls</li>
    <li><strong>42%</strong> from Holyoke</li>
  </ul>
</section>

<section class="circle-tiles" aria-label="Explore the record">
  <a href="/programs/"><img src="/media/icons/<rainbow icon>" alt=""><span>Programs</span></a>
  <a href="/robotics/"><img src="/media/icons/<robot icon>" alt=""><span>Robotics</span></a>
  <a href="/programs/"><img src="/media/icons/<kids icon>" alt=""><span>Workshops</span></a>
  <a href="/projects/"><img src="/media/icons/<earth icon>" alt=""><span>Projects</span></a>
</section>

<section class="sponsors" aria-label="Sponsors">
  <h2>Thanks to our amazing sponsors</h2>
  <div class="sponsor-row">
    <!-- one <img> per sponsor logo from media/sponsors/, alt = sponsor name -->
  </div>
</section>
```

(`<… icon>` filled from Task 3's inventory. Sponsor names for alt text come from the mirror home page's sponsor row.)

- [ ] **Step 3: Style tiles, numbers, sponsor row in `site.css`**

```css
.hero .lede { font-size: 1.15rem; max-width: 44rem; }
.numbers ul { display: flex; flex-wrap: wrap; gap: 2rem; list-style: none; padding: 0; font-family: var(--font-body); }
.numbers strong { display: block; font-size: 2rem; font-family: var(--font-display); color: var(--c-accent); }
.circle-tiles { display: flex; flex-wrap: wrap; gap: 2rem; justify-content: center; padding: 2rem 0; }
.circle-tiles a { display: grid; place-items: center; gap: 0.5rem; text-decoration: none; font-family: var(--font-body); color: var(--c-ink); }
.circle-tiles img { width: 8rem; height: 8rem; border-radius: 50%; background: var(--c-paper); box-shadow: 0 2px 8px rgb(0 0 0 / 0.15); padding: 1.25rem; object-fit: contain; }
.sponsor-row { display: flex; flex-wrap: wrap; gap: 2rem; align-items: center; justify-content: center; }
.sponsor-row img { max-height: 3.5rem; width: auto; }
```

- [ ] **Step 4: Build and verify**

Run: `npx eleventy` then `npx eleventy --serve`.
Expected: home renders with lede, numbers, four tiles, sponsor row; all six stub URLs resolve; zero client-side JS (`grep -r "<script" _site/ | grep -v "^Binary"` returns nothing).

- [ ] **Step 5: Commit**

```bash
git add src/ 
git commit -m "feat: home page with approved lede, tiles, sponsor row; stub pages"
```

- [ ] **Step 6: ⛔ DESIGN CHECKPOINT — STOP for Andrew's review**

Present the local site (`npx eleventy --serve`) side-by-side with the mirror (`file:///Users/drew/Sites/holyokecodes-archive/mirror/holyokecodes.org/index.html`) and archived screenshots. Andrew reviews fidelity: mascot, wordmark, palette, typography, strip/divider/footer, tiles. Iterate on CSS here until approved. **Do not proceed to content fan-out (Tasks 9+) until this checkpoint passes.** Theme work is timeboxed per spec — if a detail resists reproduction, note it and move on; content accuracy wins.

---

### Task 6: GitHub repo + Netlify site (Andrew-assisted)

**Files:**
- None (external service setup); Modify: `.github/workflows/ci.yml` only if the default branch name differs.

**Interfaces:**
- Produces: `origin` remote; Netlify site building `main` with deploy previews; the Netlify subdomain URL (record it — Task 15's redirect test runs against it).

- [ ] **Step 1: Create the GitHub repo and push**

```bash
gh repo create holyokecodes-retrospective --public --source . --push
```

(Public: the repo doubles as the public archive per spec. If `gh` isn't authenticated, Andrew runs `! gh auth login`.)

- [ ] **Step 2: Verify CI runs green**

```bash
gh run watch --exit-status
```

Expected: the CI workflow from Task 1 passes.

- [ ] **Step 3: Andrew connects Netlify**

Andrew (in browser): Netlify → Add new site → Import from GitHub → pick the repo. Build settings auto-read from `netlify.toml`. Record the assigned `*.netlify.app` URL here in the plan file.

- [ ] **Step 4: Verify the deploy**

Open the Netlify URL; expect the Task-5 home page. Confirm deploy previews are enabled for PRs (Netlify default).

---

### Task 7: Redirect map + completeness check (hard CI gate)

**Files:**
- Create: `_redirects`, `scripts/check-redirects.mjs`
- Modify: `.github/workflows/ci.yml` (make the redirect step hard-fail)

**Interfaces:**
- Consumes: `all-urls.txt` (frozen inventory, already in repo).
- Produces: `node scripts/check-redirects.mjs` — exits 1 with a list of uncovered legacy URLs; also runs in the Netlify build command (already wired in Task 1's `netlify.toml`).

- [ ] **Step 1: Write the failing check first — `scripts/check-redirects.mjs`**

```js
// Verifies every URL in all-urls.txt (frozen legacy inventory) either
// exists in _site/ at the same path or has a matching _redirects rule.
import { readFileSync, existsSync } from "node:fs";

const paths = readFileSync("all-urls.txt", "utf8")
  .trim().split("\n")
  .map((u) => new URL(u).pathname);

let rules = [];
if (existsSync("_redirects")) {
  rules = readFileSync("_redirects", "utf8")
    .trim().split("\n")
    .filter((l) => l.trim() && !l.startsWith("#"))
    .map((l) => l.trim().split(/\s+/)[0]);
}

const covered = (p) =>
  existsSync(`_site${p}index.html`) ||
  rules.includes(p) ||
  rules.some((r) => r.endsWith("/*") && p.startsWith(r.slice(0, -1)));

const missing = paths.filter((p) => !covered(p));
if (missing.length) {
  console.error(`UNCOVERED legacy URLs (${missing.length}):\n` + missing.join("\n"));
  process.exit(1);
}
console.log(`All ${paths.length} legacy URLs covered (page or redirect).`);
```

- [ ] **Step 2: Run it and verify it FAILS**

Run: `npx eleventy && node scripts/check-redirects.mjs`
Expected: exit 1 listing the legacy paths that are neither pages nor rules (about 25 of the 34 — `/`, `/news/`, `/robotics/` are covered by pages/stubs).

- [ ] **Step 3: Write `_redirects` (verbatim from the spec's map)**

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

- [ ] **Step 4: Run the check and verify it PASSES**

Run: `npx eleventy && node scripts/check-redirects.mjs`
Expected: `All 34 legacy URLs covered (page or redirect).`

- [ ] **Step 5: Harden CI and the Netlify build**

In `.github/workflows/ci.yml`, replace the tolerant redirect step with:

```yaml
      - name: Redirect-map completeness
        run: node scripts/check-redirects.mjs
```

In `netlify.toml`, extend the build command:

```toml
  command = "npx @11ty/eleventy && node scripts/check-redirects.mjs"
```

Note for readers: this check proves *coverage* (every legacy URL has a rule or a page), not *destination correctness* — Netlify applies `_redirects` rules first-match-wins in file order, which this check does not simulate. Destination correctness is `scripts/test-redirects.sh`'s job (Task 16), which hits the real deploy.

- [ ] **Step 6: Commit**

```bash
git add _redirects scripts/check-redirects.mjs .github/workflows/ci.yml netlify.toml
git commit -m "feat: legacy redirect map with hard completeness gate in CI and Netlify build"
```

---

### Task 8: Sensitive-content gate (local + CI + Netlify), CONTRIBUTING.md

**Files:**
- Create: `scripts/check-sensitive.sh`, `scripts/netlify-build.sh`, `.githooks/pre-push`, `CONTRIBUTING.md`
- Modify: `.github/workflows/ci.yml` (add hard-failing gate step), `netlify.toml` (build runs the gate)

**Interfaces:**
- Consumes: a names denylist OUTSIDE the repo — locally at `$HOME/.holyokecodes/participant-names.txt` (override via `HOLYOKECODES_NAMES_FILE`), in CI as the GitHub secret `PARTICIPANT_NAMES`, in Netlify as an env var of the same name. Andrew authors it (one first name per line) — it is itself sensitive and never committed. Also consumes `scripts/check-media-metadata.mjs` (Task 3).
- Produces: `npm run check:sensitive` (exit 1 on any hit, on a missing OR EMPTY names file, or on any internal scan error — the gate fails closed); enforcement at three layers: pre-push hook (fast local), CI (hard gate on every push/PR), Netlify build (nothing deploys ungated — this covers GitHub-web-UI edits and `--no-verify` pushes, which bypass local hooks entirely).

- [ ] **Step 1: Write `scripts/check-sensitive.sh`**

```bash
#!/usr/bin/env bash
# Sensitive-content gate (spec: Sensitive-material policy / Enforcement).
# Fails CLOSED: a missing/empty names file, an unscannable input, or any
# internal error is a failure — never a silent skip. Hits are reported as
# file:line with the matched text redacted.
#
# grep cannot see inside binaries (-I silently skips them), so this gate
# partitions by type: text via grep, PDFs via extracted text, raster images
# via scripts/check-media-metadata.mjs.
set -uo pipefail
fail=0

NAMES_FILE="${HOLYOKECODES_NAMES_FILE:-$HOME/.holyokecodes/participant-names.txt}"
if [[ ! -s "$NAMES_FILE" ]]; then
  echo "FATAL: participant-names denylist missing or EMPTY at $NAMES_FILE"
  echo "Zero names checked means zero name protection; populate it first."
  exit 1
fi

# Scope: everything git would publish (tracked + untracked-unignored),
# plus built output when present — NOT a hardcoded directory list.
WORKLIST=$(mktemp)
{ git ls-files; git ls-files -o --exclude-standard; } > "$WORKLIST"
[[ -d _site ]] && find _site -type f >> "$WORKLIST"

# The spec's policy is an allowlist — enforce it: a tracked file outside the
# approved roots is itself a violation, whatever it contains.
while IFS= read -r f; do
  case "$f" in
    src/*|docs/*|media/*|curriculum/*|scripts/*|.github/*|.githooks/*) ;;
    package.json|package-lock.json|eleventy.config.js|netlify.toml) ;;
    .gitignore|.nvmrc|_redirects|all-urls.txt|CONTRIBUTING.md|README.md) ;;
    *) echo "ALLOWLIST VIOLATION: tracked file outside approved roots: $f"; fail=1 ;;
  esac
done < <(git ls-files)

TEXTS=$(mktemp); PDFS=$(mktemp); POLICY=$(mktemp); ALLTEXT=$(mktemp)
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  case "$f" in
    *.pdf) echo "$f" >> "$PDFS" ;;
    *.png|*.jpg|*.jpeg|*.gif|*.webp|*.ico|*.woff|*.woff2) ;; # covered by metadata sweep below
    docs/*|scripts/check-sensitive.sh) echo "$f" >> "$POLICY" ;; # policy docs + this script name the markers on purpose
    *) echo "$f" >> "$TEXTS" ;;
  esac
done < "$WORKLIST"
cat "$TEXTS" "$POLICY" > "$ALLTEXT"

# scan <list> <label> <grep-args…>: greps a file list. ANY output — a match
# OR a grep error — fails the gate (fail-closed); silence means clean.
scan() {
  local list="$1" label="$2"; shift 2
  local out
  out=$(tr '\n' '\0' < "$list" | xargs -0 grep -nH "$@" 2>&1 | cut -d: -f1,2)
  if [[ -n "$out" ]]; then
    echo "HIT/ERROR ($label):"; echo "$out"; fail=1
  fi
}

# Fixed markers for material that must never appear. Scanned over $TEXTS —
# NOT $POLICY, whose files (spec, plan, this script) cite these markers
# descriptively and would otherwise be permanent false positives.
scan "$TEXTS" "attendee data marker" -F -- "hcdata"
scan "$TEXTS" "tax marker EIN" -Fw -- "EIN"
scan "$TEXTS" "tax marker W-9" -F -- "W-9"
scan "$TEXTS" "tax marker Form 990" -F -- "Form 990"

# Credential shapes — defence against a stray paste from the WordPress DB dump
scan "$TEXTS" "live Stripe key" -E -- "sk_live_[A-Za-z0-9]+"
scan "$TEXTS" "AWS access key" -E -- "AKIA[A-Z0-9]{16}"
scan "$TEXTS" "private key block" -F -- "-----BEGIN"

# Participant first names: FIXED-STRING (-F, names must never be treated as
# regexes), whole-word, case-insensitive, over EVERY text file including the
# policy docs — no file may carry a participant name. Output redacts the name.
n=0
while IFS= read -r name; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  n=$((n+1))
  scan "$ALLTEXT" "participant name #$n (redacted)" -Fiw -- "$name"
done < "$NAMES_FILE"

# PDFs: grep the EXTRACTED TEXT (raw bytes are invisible to grep). Fall back
# to strings when extraction yields nothing — an image-only or malformed PDF
# must not scan as trivially clean.
while IFS= read -r pdf; do
  txt=""
  command -v pdftotext >/dev/null 2>&1 && txt=$(pdftotext "$pdf" - 2>/dev/null)
  [[ -z "$txt" ]] && txt=$(strings "$pdf")
  grep -Fiq -- "hcdata" <<<"$txt" && { echo "HIT (attendee marker in PDF): $pdf"; fail=1; }
  j=0
  while IFS= read -r name; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    j=$((j+1))
    grep -Fiwq -- "$name" <<<"$txt" && { echo "HIT (participant name #$j in PDF): $pdf"; fail=1; }
  done < "$NAMES_FILE"
done < "$PDFS"

# Raster images: metadata sweep (EXIF/XMP/IPTC — grep can't do this either)
node scripts/check-media-metadata.mjs || fail=1

echo "gate: $n names, $(wc -l < "$ALLTEXT" | tr -d ' ') text files, $(wc -l < "$PDFS" | tr -d ' ') PDFs scanned — $([[ $fail -eq 0 ]] && echo CLEAN || echo FAIL)"
exit $fail
```

Caveat to expect: educator/adult names on `/people/` are intentional; the denylist holds **participant** (minor) first names only. If a participant shares a first name with a named educator, do NOT weaken or remove the denylist entry — the resolution is a `# narrowed: <reason, date>` comment in the names file plus Andrew manually verifying each reported file:line hit. The gate reporting file:line (not just filenames) exists precisely to make that triage cheap enough that nobody is tempted to soften the list.

- [ ] **Step 2: Verify fail-closed behavior, then Andrew populates the denylist — HARD GATE for Tasks 9–15**

Run: `HOLYOKECODES_NAMES_FILE=/nonexistent bash scripts/check-sensitive.sh`
Expected: exit 1, `FATAL: participant-names denylist missing or EMPTY`.

Run: `HOLYOKECODES_NAMES_FILE=/dev/null bash scripts/check-sensitive.sh` (empty input)
Expected: exit 1 — an empty list must be rejected exactly like a missing one.

Andrew then creates and **populates** the real file from the archive's known participant credits (FLL-2020 README, testimonials) — done by Andrew, since the source material is sensitive:
```bash
mkdir -p ~/.holyokecodes
$EDITOR ~/.holyokecodes/participant-names.txt   # one first name per line
```

**No content task (9–15) may start until `bash scripts/check-sensitive.sh` reports a nonzero name count** (e.g. `gate: 23 names, …`). A gate run showing `0 names` or the FATAL error blocks the fan-out — this is the plan's protection against writing the robotics page with an unpopulated denylist.

- [ ] **Step 3: Prove the gate detects plants in both text AND binary form, then clean up**

```bash
echo "hcdata.csv" > src/PLANT.md
bash scripts/check-sensitive.sh; echo "exit=$?"   # expect exit=1, HIT with src/PLANT.md:1
rm src/PLANT.md
mkdir -p curriculum && printf '%%PDF-1.4 hcdata roster' > curriculum/PLANT.pdf   # marker inside a "binary"
bash scripts/check-sensitive.sh; echo "exit=$?"   # expect exit=1 via the PDF text path
rm curriculum/PLANT.pdf
npx eleventy && bash scripts/check-sensitive.sh   # expect CLEAN, exit 0
```

The binary plant matters: the naive `grep -rI` this script deliberately avoids would report clean on it.

- [ ] **Step 4: Wire the pre-push hook (fast local layer)**

`.githooks/pre-push`:
```bash
#!/usr/bin/env bash
set -euo pipefail
npx @11ty/eleventy
node scripts/check-redirects.mjs
bash scripts/check-sensitive.sh
```

```bash
chmod +x .githooks/pre-push scripts/check-sensitive.sh
git config core.hooksPath .githooks
```

Note: `core.hooksPath` is per-clone and trivially bypassed (`--no-verify`, GitHub web edits, other machines) — it is a convenience layer only. The enforcing layers are Step 5.

- [ ] **Step 5: Enforce in CI and the Netlify build (the real gates)**

Andrew uploads the names list as a secret to both services (it stays outside the repo; secrets are encrypted and never appear in logs — the gate writes it only to a temp file):

```bash
gh secret set PARTICIPANT_NAMES < ~/.holyokecodes/participant-names.txt
```

and in the Netlify UI: Site settings → Environment variables → add `PARTICIPANT_NAMES` with the same content.

Add to `.github/workflows/ci.yml` after the redirect step:

```yaml
      - name: Sensitive-content gate
        env:
          PARTICIPANT_NAMES: ${{ secrets.PARTICIPANT_NAMES }}
        run: |
          if [ -z "$PARTICIPANT_NAMES" ]; then
            echo "PARTICIPANT_NAMES secret is not set — gate cannot run."; exit 1
          fi
          printf '%s\n' "$PARTICIPANT_NAMES" > "$RUNNER_TEMP/names.txt"
          HOLYOKECODES_NAMES_FILE="$RUNNER_TEMP/names.txt" bash scripts/check-sensitive.sh
```

Write `scripts/netlify-build.sh` and point `netlify.toml` at it:

```bash
#!/usr/bin/env bash
# Netlify build: nothing deploys without passing every gate.
set -euo pipefail
npx @11ty/eleventy
node scripts/check-redirects.mjs
printf '%s\n' "${PARTICIPANT_NAMES:?PARTICIPANT_NAMES env var not set in Netlify}" > /tmp/participant-names.txt
HOLYOKECODES_NAMES_FILE=/tmp/participant-names.txt bash scripts/check-sensitive.sh
```

`netlify.toml`:
```toml
  command = "bash scripts/netlify-build.sh"
```

Verify: push a branch with a plant file (as in Step 3) and confirm both the CI run and the Netlify deploy preview FAIL; remove the plant, confirm both go green.

- [ ] **Step 6: Write `CONTRIBUTING.md`**

```markdown
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
The pre-push hook runs the build, the redirect-completeness check, and the
sensitive-content gate. The gate requires a private names file at
`~/.holyokecodes/participant-names.txt` (never committed) and fails loudly
if the file is missing OR empty. The same gate also runs in CI and in the
Netlify build (via the PARTICIPANT_NAMES secret), so bypassing the local
hook does not bypass the gate.
```

- [ ] **Step 7: Commit**

```bash
git add scripts/check-sensitive.sh scripts/netlify-build.sh .githooks/ CONTRIBUTING.md .github/workflows/ci.yml netlify.toml
git commit -m "feat: fail-closed sensitive-content gate enforced locally, in CI, and in the Netlify build"
```

---

### Task 9: Custom 404 page

**Files:**
- Create: `src/404.md`

**Interfaces:**
- Produces: `_site/404.html` (Netlify serves any unmatched path with it automatically).

- [ ] **Step 1: Write `src/404.md`**

```markdown
---
layout: base.njk
title: Page not found
permalink: /404.html
---

# That page isn't part of the record

Holyoke Codes ran from 2014 to 2023; this site is its historical archive,
and the address you followed doesn't match anything in it.

- [Start at the home page](/)
- [Browse the timeline](/timeline/)
```

- [ ] **Step 2: Build, verify, commit**

Run: `npx eleventy`; expect `_site/404.html` with the theme chrome.

```bash
git add src/404.md
git commit -m "feat: themed 404 page"
```

---

### Task 10: Timeline page

**Files:**
- Modify: `src/timeline.md` (replace stub)

**Interfaces:**
- Consumes: `content-pages.json`, `content-posts.json`, `content-tribe_venue.json` (archive); research corpus for era details; photos via Task 3 pipeline into `media/photos/`.
- Produces: `/timeline/` with anchored era sections: `#founding`, `#growth`, `#school-programs`, `#robotics`, `#remote`, `#relaunch`, `#wind-down`.

- [ ] **Step 1: Extract source material**

```bash
cd /Users/drew/Sites/holyokecodes-archive
jq -r '.[] | "\(.date)  \(.slug)  \(.title.rendered)"' content-posts.json
jq -r '.[] | "\(.slug)  \(.title.rendered)"' content-pages.json
jq -r '.[] | .title.rendered' content-tribe_venue.json
```

Also read the mirror's `/calendar/` page and the research corpus for era facts (2020 remote summer = 83 sessions; state champs 2020 & 2021 per spec).

- [ ] **Step 2: Write the page**

Structure (fill each section with 1–3 past-tense paragraphs sourced from Step 1; every factual claim traceable to archive/corpus; aggregates only):

```markdown
---
layout: base.njk
title: Timeline
permalink: /timeline/
description: Holyoke Codes from founding in 2014 to wind-down in 2023.
---

# Timeline

## 2014 — Founding {#founding}
December 2014: a week of free workshops at the MGHPCC…

## 2015–2017 — Growth years {#growth}
Nearly weekly programs; 1,250+ kids reached by 2016…

## 2017–2019 — School programs era {#school-programs}
HPS specials, 7th-grade Code Week, Morgan School…

## 2018–2023 — Robotics era {#robotics}
CyberScare (FLL) and Aquabots (FTC); links to [/robotics/](/robotics/)…

## 2020–2021 — Remote summer {#remote}
Pandemic closed the MGHPCC home base; 83 remote sessions in summer 2020…

## 2022 — Relaunch {#relaunch}
Partner venues: Holyoke Boathouse ("Codes & Rows"), Montessori of
Northampton, LightHouse Holyoke, UMass ISB…

## 2023 — Wind-down {#wind-down}
Final season; the program quietly wound down…
```

(The ellipsis lines are section briefs, not final copy — the executor writes full past-tense prose from the Step-1 sources. Venue names for the relaunch section come from `content-tribe_venue.json`, which is why `/venue/*` redirects here.)

- [ ] **Step 3: Verify and commit**

Run: `npx eleventy && bash scripts/check-sensitive.sh` — clean.

```bash
git add src/timeline.md media/
git commit -m "feat: timeline page (founding through wind-down)"
```

---

### Task 11: Programs page

**Files:**
- Modify: `src/programs.md` (replace stub)

**Interfaces:**
- Consumes: mirror pages `/workshops/`, `/school-programs/`, `/summer-programs/`, `/community-projects/`, `/tutoring/`, `/programs-2/`; `content-pages.json`.
- Produces: `/programs/` with anchored sections (spec: explicitly structured, not one flat page): `#workshops`, `#school`, `#got-game`, `#fcl`, `#nps`, `#morgan`, `#camps`, `#tutoring`.

- [ ] **Step 1: Extract the source pages**

```bash
cd /Users/drew/Sites/holyokecodes-archive
jq -r '.[] | select(.slug=="workshops" or .slug=="school-programs" or .slug=="summer-programs" or .slug=="community-projects" or .slug=="tutoring" or .slug=="programs-2") | "== \(.slug) ==\n\(.content.rendered)"' content-pages.json > /tmp/programs-source.html
```

Read `/tmp/programs-source.html` for the actual program descriptions; rewrite past tense.

- [ ] **Step 2: Write the page**

Required sections, each an `h2` with the anchor id above, sourced from Step 1:
Public workshops & Lab Nights (`#workshops`); HPS specials + 7th-grade Code Week (`#school`); Got Game! (`#got-game`); Family Creative Learning (`#fcl`); NPS Creative Computing (`#nps`); Morgan School (`#morgan`); Summer camps — Boathouse "Codes & Rows", Montessori, LightHouse (`#camps`); Tutoring (`#tutoring`). Open with a short index list linking each anchor. Reuse `.circle-tiles` if tile imagery fits.

- [ ] **Step 3: Verify and commit**

Run: `npx eleventy && bash scripts/check-sensitive.sh` — clean.

```bash
git add src/programs.md media/
git commit -m "feat: programs page with anchored program sections"
```

---

### Task 12: Robotics page

**Files:**
- Modify: `src/robotics.md` (replace stub)

**Interfaces:**
- Consumes: mirror `/robotics/` and `/sumobot-tournament-rules/` pages; `content-pages.json`; research corpus `FLL-2020/`, `FTC-2021/`, `FTC-2023/` (for facts only — **no student names**; the FLL-2020 README is explicitly flagged as containing minors' first names).
- Produces: `/robotics/` with `#cyberscare`, `#aquabots`, `#sumobot` anchors (the `/sumobot-tournament-rules/` redirect lands here).

- [ ] **Step 1: Extract sources**

```bash
cd /Users/drew/Sites/holyokecodes-archive
jq -r '.[] | select(.slug=="robotics" or .slug=="sumobot-tournament-rules") | "== \(.slug) ==\n\(.content.rendered)"' content-pages.json > /tmp/robotics-source.html
```

- [ ] **Step 2: Write the page**

Sections: CyberScare — FLL, 8 years, state champions 2020 & 2021 (`#cyberscare`); Aquabots — FTC, 7 years (`#aquabots`); Sumobot Tournament with the **full ruleset** reproduced from the source page (`#sumobot`). Team accomplishments in team-level terms only — zero member names.

- [ ] **Step 3: Verify and commit**

Run: `npx eleventy && bash scripts/check-sensitive.sh` — clean (this page is the highest name-risk page; if the gate flags it, fix the copy, never the gate).

```bash
git add src/robotics.md media/
git commit -m "feat: robotics page (CyberScare, Aquabots, Sumobot ruleset)"
```

---

### Task 13: Projects landing + four project pages

**Files:**
- Modify: `src/projects/index.md` (replace stub)
- Create: `src/projects/galeforce.md`, `src/projects/scratch-curriculum.md`, `src/projects/weather-station.md`, `src/projects/rosie.md`, `curriculum/` PDFs

**Interfaces:**
- Consumes: `content-posts.json` (slug `galeforce`), `content-pages.json` (slug `scratch-curriculum`), mirror pages; curriculum PDFs/slides from the research corpus or archive uploads.
- Produces: permalinks `/projects/`, `/projects/galeforce/`, `/projects/scratch-curriculum/`, `/projects/weather-station/`, `/projects/rosie/`; curriculum files served at `/curriculum/…`.

- [ ] **Step 1: Extract sources**

```bash
cd /Users/drew/Sites/holyokecodes-archive
jq -r '.[] | select(.slug=="galeforce") | .content.rendered' content-posts.json > /tmp/galeforce.html
jq -r '.[] | select(.slug=="scratch-curriculum") | .content.rendered' content-pages.json > /tmp/scratch.html
```

Weather station facts: SparkFun Photon build, Wunderground station KMAHOLYO17 (spec); check research corpus for build details. Rosie: mascot story + chatbot; check the corpus's Alexa/chatbot directories and the mirror for published material.

- [ ] **Step 2: Write the four project pages + landing**

Each page front matter (example):
```markdown
---
layout: base.njk
title: GaleForce
permalink: /projects/galeforce/
---
```
- **GaleForce:** keeps the content of the old `/galeforce/` post (NSF-funded, UMass + Elms collaboration), past tense.
- **Scratch curriculum:** the free curriculum, with the PDFs sourced by explicit discovery — **never glob the corpus**: `/Users/drew/Documents/projects/holyoke_codes/` also contains `Holyoke Codes Budget 2015.pdf` and `MGHPCC Tax Exempt MA Form ST 5.pdf` (verified present), which are spec-forbidden and one careless wildcard away from a public repo. Discover the real artifact filenames:

  ```bash
  grep -oE 'href="[^"]*\.(pdf|pptx?|key)"' /tmp/scratch.html
  find "/Users/drew/Documents/projects/holyoke_codes" -maxdepth 2 -iname "*scratch*" \( -iname "*.pdf" -o -iname "*.pptx" \)
  ```

  Record the resulting explicit file list in the task notes, then copy each **named** file through a metadata scrub (exiftool is installed on this machine; the corpus PDFs carry Author metadata — verified, including a third party's name):

  ```bash
  exiftool -all= -o "curriculum/<name>.pdf" "<abs-source>.pdf"
  exiftool -Author -Creator -Producer -Title "curriculum/<name>.pdf"   # expect: no output (all empty)
  ```

  Link each at `/curriculum/<file>`.
- **Weather station:** SparkFun Photon build, KMAHOLYO17.
- **Rosie:** mascot origin + chatbot story.
- **Landing (`/projects/`):** one paragraph + linked list of the four.

- [ ] **Step 3: Verify and commit**

Run: `npx eleventy && bash scripts/check-sensitive.sh && node scripts/check-redirects.mjs` — all clean (galeforce + scratch-curriculum redirects now land on real pages).

```bash
git add src/projects/ curriculum/ media/
git commit -m "feat: projects section (GaleForce, Scratch curriculum, weather station, Rosie)"
```

---

### Task 14: News index + five posts

**Files:**
- Modify: `src/news/index.md` (replace stub)
- Create: `src/news/scratch-curriculum-announcement.md`, `src/news/2022-summer-programs.md`, `src/news/morgan-school-enrichment.md`, `src/news/galeforce.md` → **no** (galeforce lives in /projects/; the index links there) — create only the four non-galeforce posts: `scratch-curriculum-announcement`, `2022-summer-programs`, `2022-summer-programs-3`, `morgan-school-enrichment`

**Interfaces:**
- Consumes: `content-posts.json` (all five posts confirmed there per spec).
- Produces: `/news/` index; posts at `/news/<original-slug>/` with original publication dates; each post carries a period-piece note.

- [ ] **Step 1: Extract all five posts**

```bash
cd /Users/drew/Sites/holyokecodes-archive
jq -r '.[] | "\(.slug)\t\(.date)\t\(.title.rendered)"' content-posts.json
jq -r '.[] | select(.slug=="2022-summer-programs") | .content.rendered' content-posts.json > /tmp/post1.html
# …repeat per slug
```

- [ ] **Step 2: Write the four post pages**

Front matter per post (example):
```markdown
---
layout: base.njk
title: 2022 Summer Programs
permalink: /news/2022-summer-programs/
date: 2022-05-XX   # exact date from content-posts.json
---

> *Published in 2022, while programs were still running. Preserved here as
> part of the record.*

[original post content, cleaned of WP markup; images through the media
pipeline; registration/ticket links removed or replaced with plain text
noting registration is long closed]
```

Period pieces keep their original present-tense voice — the blockquote note is what frames them; this is the one deliberate exception to the past-tense rule and should be called out in the commit message.

- [ ] **Step 3: Write `/news/` index**

List all five posts newest-first with dates; the GaleForce entry links to `/projects/galeforce/` instead of a `/news/` URL.

- [ ] **Step 4: Verify and commit**

Run: `npx eleventy && node scripts/check-redirects.mjs && bash scripts/check-sensitive.sh` — all clean (the three news-post redirects now land on real pages).

```bash
git add src/news/ media/
git commit -m "feat: news index and four period-piece posts (galeforce lives in /projects/)"
```

---

### Task 15: People page

**Files:**
- Modify: `src/people.md` (replace stub)

**Interfaces:**
- Consumes: `content-users.json` (authors), mirror `/about/` + `/support-us/` pages, research corpus for the 2015 founding team and 2022 team, member orgs, partners, funders.
- Produces: `/people/` (the `/support-us/` and `/author/*` redirects land here).

- [ ] **Step 1: Extract sources**

```bash
cd /Users/drew/Sites/holyokecodes-archive
jq -r '.[] | "\(.slug)\t\(.name)"' content-users.json
jq -r '.[] | select(.slug=="about" or .slug=="support-us") | "== \(.slug) ==\n\(.content.rendered)"' content-pages.json > /tmp/people-source.html
```

- [ ] **Step 2: Write the page**

Sections: Educators (2015 founding team; 2022 team) — **adults only, as named on the public site**; Member organizations; Partners; Funders (past-tense thanks, consistent with the retitled sponsor row). Any deficit-framed grant language about Holyoke rewritten as celebration per Global Constraints.

- [ ] **Step 3: Verify and commit**

Run: `npx eleventy && bash scripts/check-sensitive.sh` — clean.

```bash
git add src/people.md media/
git commit -m "feat: people page (educators, member orgs, partners, funders)"
```

---

### Task 16: QA harness — link check, Lighthouse, redirect landing-path test

**Files:**
- Create: `scripts/redirect-fixture.txt`, `scripts/test-redirects.sh`, `scripts/lighthouse-all.sh`
- Modify: `.github/workflows/ci.yml` (add link check, Lighthouse gate, dispatchable redirect test), `scripts/check-redirects.mjs` (fixture-drift cross-check)

**Ordering note:** this task must run AFTER Tasks 9–15 — the redirect test asserts real landing content, and before the content tasks the stub pages ("Content arrives in a later task") would make a landing-path pass meaningless.

**Interfaces:**
- Consumes: a deployed Netlify URL (Task 6) for the redirect test; `_site/` for links/Lighthouse.
- Produces: `bash scripts/test-redirects.sh <base-url>` asserting exact landing paths for all 34 legacy URLs; `bash scripts/lighthouse-all.sh` asserting accessibility ≥ 95 on every page.

- [ ] **Step 1: Write `scripts/redirect-fixture.txt` (all 34 URLs → exact expected landing path)**

```
/	/
/2022-summer-programs-3/	/news/2022-summer-programs-3/
/2022-summer-programs/	/news/2022-summer-programs/
/about/	/
/author/andrew/	/people/
/author/lfein/	/people/
/calendar/	/timeline/
/category/school-programs/	/news/
/category/uncategorized/	/news/
/community-projects/	/programs/
/contact/	/
/donation-confirmation/	/
/donation-failed/	/
/donations/242/	/
/donor-dashboard/	/
/galeforce/	/projects/galeforce/
/morgan-school-enrichment/	/news/morgan-school-enrichment/
/news/	/news/
/programs-2/	/programs/
/robotics/	/robotics/
/school-programs/	/programs/
/scratch-curriculum-announcement/	/news/scratch-curriculum-announcement/
/scratch-curriculum/	/projects/scratch-curriculum/
/summer-programs/	/programs/
/sumobot-tournament-rules/	/robotics/
/support-us/	/people/
/tickets-checkout/	/
/tickets-order/	/
/tutoring/	/programs/
/venue/holyoke-boathouse/	/timeline/
/venue/lighthouse-holyoke/	/timeline/
/venue/montessori-of-northampton/	/timeline/
/venue/umass-amherst-isb-building/	/timeline/
/workshops/	/programs/
```

(Tab-separated: request-path, expected-final-path. Derived from `all-urls.txt` × the `_redirects` map; same-path rows assert "no redirect happened".)

- [ ] **Step 2: Write `scripts/test-redirects.sh`**

```bash
#!/usr/bin/env bash
# Curls every legacy URL against a deploy (preview) and asserts the EXACT
# final landing path AND a 200 there (QA step 3 in the spec) — one request
# captures both values so the pair can never disagree (two separate requests
# could straddle a mid-test redeploy).
set -uo pipefail
BASE="${1:?usage: test-redirects.sh https://<site>.netlify.app}"
BASE="${BASE%/}"
fail=0
while IFS=$'\t' read -r reqpath expected; do
  [[ -z "$reqpath" || "$reqpath" == \#* ]] && continue
  read -r final status < <(curl -s -o /dev/null -w '%{url_effective} %{http_code}' -L "$BASE$reqpath")
  final_path="${final#"$BASE"}"
  if [[ "$final_path" == "$expected" && "$status" == "200" ]]; then
    echo "ok    $reqpath -> $expected"
  else
    echo "FAIL  $reqpath -> $final_path ($status), expected $expected + 200"
    fail=1
  fi
done < scripts/redirect-fixture.txt

# Landing on the right PATH is not enough if the page there is still a
# Task-5 stub — cheap content sanity check on one destination per section.
for p in /timeline/ /programs/ /news/ /people/; do
  if curl -s "$BASE$p" | grep -q "Content arrives in a later task"; then
    echo "FAIL  $p is still stub content — content tasks incomplete"
    fail=1
  fi
done
exit $fail
```

- [ ] **Step 3: Write `scripts/lighthouse-all.sh`**

```bash
#!/usr/bin/env bash
# Lighthouse accessibility >= 95 on ALL pages (spec QA step 7: no sampling).
set -uo pipefail
npx http-server _site -p 8899 --silent &
SERVER=$!
trap 'kill $SERVER 2>/dev/null' EXIT
# Readiness poll, not a fixed sleep — CI runners make 1-second guesses flaky
for _ in $(seq 1 100); do
  curl -sf http://localhost:8899/ >/dev/null 2>&1 && break
  sleep 0.2
done
curl -sf http://localhost:8899/ >/dev/null || { echo "FATAL: http-server never came up"; exit 1; }
fail=0
while read -r page; do
  score=$(npx lighthouse "http://localhost:8899$page" \
    --only-categories=accessibility --output=json --quiet \
    --chrome-flags="--headless" 2>/dev/null |
    node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{console.log(Math.round(JSON.parse(d).categories.accessibility.score*100))})')
  if [[ -z "$score" ]]; then
    echo "FAIL: lighthouse produced no score for $page (crashed or timed out — rerun that page without --quiet/2>/dev/null to diagnose)"
    fail=1
    continue
  fi
  echo "$page: $score"
  if [[ "$score" -lt 95 ]]; then echo "FAIL (<95): $page"; fail=1; fi
done < <(cd _site && find . -name index.html | sed 's|^\.||; s|index\.html$||' && echo /404.html)
exit $fail
```

- [ ] **Step 4: Add a fixture-drift cross-check to `scripts/check-redirects.mjs`**

The fixture and `_redirects` describe the same mapping in two hand-maintained places; the spec says the map is "not frozen", so they WILL be edited post-launch. Append to `check-redirects.mjs` (after the existing coverage check) so CI catches desync:

```js
// Fixture drift: the fixture's expected column must agree with what
// _redirects actually resolves each path to. Resolution is first-match-wins
// in file order — the same semantics Netlify applies.
if (existsSync("scripts/redirect-fixture.txt")) {
  const ruleLines = readFileSync("_redirects", "utf8")
    .trim().split("\n")
    .filter((l) => l.trim() && !l.startsWith("#"))
    .map((l) => l.trim().split(/\s+/));
  const resolve = (p) => {
    for (const [from, to] of ruleLines) {
      if (from === p) return to;
      if (from.endsWith("/*") && p.startsWith(from.slice(0, -1))) return to;
    }
    return p; // no rule → same-path page
  };
  const drift = readFileSync("scripts/redirect-fixture.txt", "utf8")
    .trim().split("\n")
    .map((l) => l.split("\t"))
    .filter(([p, expected]) => resolve(p) !== expected);
  if (drift.length) {
    console.error("FIXTURE DRIFT (fixture expected ≠ _redirects resolution):");
    for (const [p, expected] of drift) console.error(`  ${p}: fixture=${expected} rules=${resolve(p)}`);
    process.exit(1);
  }
  console.log("redirect fixture agrees with _redirects.");
}
```

Run: `node scripts/check-redirects.mjs`
Expected: both the coverage line and `redirect fixture agrees with _redirects.`

- [ ] **Step 5: Wire link check, Lighthouse, and a dispatchable redirect test into CI**

In `.github/workflows/ci.yml`, extend the `on:` block and add steps/jobs:

```yaml
on:
  push:
  pull_request:
  workflow_dispatch:
    inputs:
      deploy_url:
        description: "Deploy URL to run the redirect landing-path test against"
        required: false
```

After the sensitive-gate step in the `build` job:

```yaml
      - name: Internal link check
        run: |
          npx http-server _site -p 8899 --silent &
          for i in $(seq 1 100); do curl -sf http://localhost:8899/ >/dev/null && break; sleep 0.2; done
          # linkinator's exit code must stay the last command's — don't append commands after it
          npx linkinator http://localhost:8899 --recurse --skip "^(?!http://localhost:8899)"
      - name: Lighthouse accessibility gate
        run: bash scripts/lighthouse-all.sh
```

And a separate job for the redirect test (needs a live deploy, so it can't run on plain pushes — trigger it manually with the preview/production URL whenever redirects or the fixture change, and at launch):

```yaml
  redirect-landing-paths:
    if: github.event_name == 'workflow_dispatch' && inputs.deploy_url != ''
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: bash scripts/test-redirects.sh "${{ inputs.deploy_url }}"
```

(`--skip` external URLs on the link check: the QA requirement is *internal* hrefs/srcs; external archived-profile links may legitimately rot.)

- [ ] **Step 6: Run everything locally**

```bash
npx eleventy
node scripts/check-redirects.mjs
bash scripts/check-sensitive.sh
bash scripts/lighthouse-all.sh
bash scripts/test-redirects.sh https://<netlify-subdomain>.netlify.app
```

Expected: all pass. Fix any Lighthouse/link failures now (contrast fixes only where the original fails WCAG AA, per spec).

- [ ] **Step 7: Commit and push; verify CI green, then dispatch the redirect test**

```bash
chmod +x scripts/test-redirects.sh scripts/lighthouse-all.sh
git add scripts/ .github/workflows/ci.yml
git commit -m "feat: QA harness — redirect landing-path test, Lighthouse gate, link check"
git push && gh run watch --exit-status
gh workflow run ci.yml -f deploy_url="https://<netlify-subdomain>.netlify.app" && gh run watch --exit-status
```

---

### Task 17: Launch runbook (Andrew-driven, assisted)

**Files:**
- Create: `docs/LAUNCH.md` (checklist below, so launch state survives across sessions)

**Interfaces:**
- Consumes: green QA harness (Task 16); Netlify site (Task 6).

- [ ] **Step 1: Write `docs/LAUNCH.md` with this checklist and work through it**

```markdown
# Launch checklist

## Pre-launch content review (spec QA step 8 — structured policy walk)
- [ ] Photos: every image in media/ was on the original public site; EXIF verified stripped
- [ ] Names: no minors anywhere (gate green AND a manual read of /robotics/ and /news/ posts)
- [ ] Framing: honest arc intact; no deficit framing of Holyoke; all thanks past tense
- [ ] Docs: no contracts/budgets/tax/attendee data; curriculum PDFs spot-checked

## Collaborator review (before DNS cutover)
- [ ] Andrew reviews the Netlify-subdomain deploy end to end
- [ ] Invite the named educators to review — including the honest-arc framing
      and their own mentions on /people/ — collect sign-offs
- [ ] Apply requested changes; re-run full QA harness

## Cutover
- [ ] Netlify: add holyokecodes.org custom domain (+ www)
- [ ] Cloudflare DNS: point apex + www at Netlify; KEEP old server records until verified
- [ ] Verify live: bash scripts/test-redirects.sh https://holyokecodes.org
- [ ] Lighthouse + link check against production

## Decommission (only after cutover verified)
- [ ] Rotate/revoke ALL third-party API keys found in the WordPress DB
      (Stripe, Mailchimp, reCAPTCHA, and any others discovered) — treat as
      compromised regardless of exposure
- [ ] Decommission the Closte WordPress site (archive already secured locally)
- [ ] Remove stale Cloudflare records pointing at the old server

## Post-launch (a few weeks in)
- [ ] Review Cloudflare/Netlify 404 reports; add _redirects rules for any
      newly discovered legacy URLs (the map is not frozen — update
      scripts/redirect-fixture.txt in the same commit; CI enforces agreement)

## Incident response: sensitive content reached the public repo
Every gate above is preventive; this is the remediation path if one fails.
Treat the exposure as PERMANENT — forks, clones, and third-party mirrors may
already hold it; removal limits further spread, it does not unpublish.
- [ ] `git rm` the content and push immediately (stops the bleeding)
- [ ] Rewrite history: git filter-repo to purge the blob, force-push
- [ ] Contact GitHub Support to purge cached views of the affected commits
- [ ] If the exposure involved a minor's name or lasted more than briefly:
      delete the repository entirely and recreate it from a cleaned local
      copy — history rewriting is not sufficient assurance for minors' PII
- [ ] If a credential was exposed: rotate it at the provider immediately
```

- [ ] **Step 2: Commit**

```bash
git add docs/LAUNCH.md
git commit -m "docs: launch runbook"
```

---

## Self-review notes

- **Spec coverage:** every spec section maps to a task — decisions table (T1/T6), framing copy (T5), look & feel (T2–T5), archive changes (T4 strip, T5–T15 past tense, removed features nowhere reintroduced), IA 12 pages (T5, T9–T15), redirect map (T7) + landing-path test + post-launch 404 review (T16, T17), repo layout (T1), sensitive policy + enforcement + CONTRIBUTING (T3 EXIF, T8), credential hygiene (T17), error handling (T9), QA steps 1–8 (T1, T7, T8, T16, T17), launch sequence (T17).
- **Deliberate deviation (one):** the spec's Enforcement section says the sensitive-content check "runs locally/pre-deploy"; after adversarial review (2026-08-21) the gate additionally runs in CI and the Netlify build via a secret copy of the names list, because local-only hooks are bypassed by GitHub web edits, `--no-verify`, and unconfigured clones. This strengthens, not weakens, the policy; the spec's Enforcement bullet was updated to match. News posts keep original voice with a period-piece note (T14) — consistent with "presented as period pieces".
- **Deferred values:** asset filenames (T3-Step-2 inventory command), the gradient stop (T4-Step-2 grep), and curriculum PDF filenames (T13-Step-2 discovery commands) — each has an explicit discovery command in-plan.
- **Adversarial review (2026-08-21):** three reviewers (devil's advocate, security, tests) ran against this plan; their accepted findings are folded in above. Highest-impact fixes: fail-closed gate that can actually see binaries, XMP/IPTC (not just EXIF) assertions, CI+Netlify gate enforcement, empty-names-file hard stop before content tasks, explicit curriculum PDF allowlist (the corpus contains a budget and a tax form), single-request redirect assertions, and an incident runbook. Rejected as over-engineering: per-name context-regex denylist columns, phone/address regex scanning (alarm-fatigue risk; covered by the structured policy walk), and auto-triggered post-deploy redirect tests (manual dispatch suffices at this scale).
