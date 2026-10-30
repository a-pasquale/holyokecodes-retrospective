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
