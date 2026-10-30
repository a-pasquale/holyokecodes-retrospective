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
