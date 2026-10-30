// Fails if any raster image carries EXIF, XMP, IPTC, or PNG text chunks.
// With file paths as argv, checks exactly those; with none, sweeps media/ and
// _site/media. Called standalone and by scripts/check-sensitive.sh.
import sharp from "sharp";
import { readdirSync, statSync, existsSync } from "node:fs";

const roots = ["media", "_site/media"].filter(existsSync);
const walk = (d) =>
  readdirSync(d).flatMap((f) => {
    const p = `${d}/${f}`;
    return statSync(p).isDirectory() ? walk(p) : [p];
  });

const files = process.argv.length > 2
  ? process.argv.slice(2)
  : roots.flatMap(walk).filter((f) => /\.(png|jpe?g|webp|gif)$/i.test(f));

// In CI the logs are public and a path can contain a participant name, so print
// only the argument index there.
const where = (i, f) => (process.env.CI ? `image argument #${i}` : f);

let bad = 0;
let checked = 0;
for (const f of files) {
  checked++;
  const w = where(checked, f);
  let m;
  try {
    m = await sharp(f).metadata();
  } catch (e) {
    console.error(`UNREADABLE IMAGE: ${w}`);
    bad++;
    continue;
  }
  for (const k of ["exif", "xmp", "iptc"]) {
    if (m[k]) {
      console.error(`METADATA (${k}) FOUND: ${w}`);
      bad++;
    }
  }
  if (Array.isArray(m.comments) && m.comments.length) {
    console.error(`METADATA (png text chunks) FOUND: ${w}`);
    bad++;
  }
}
console.log(`media metadata sweep: ${checked} raster images checked, ${bad} with metadata`);
process.exit(bad ? 1 : 0);
