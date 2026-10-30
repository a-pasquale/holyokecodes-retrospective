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
