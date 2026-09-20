/**
 * Demo env loader (no dependencies).
 *
 * Reads KEY=VALUE lines from, in order, <dashboard>/.env then <repo>/.env and
 * assigns them to process.env. Values in these files OVERRIDE the shell on
 * purpose: the demo dashboard must never inherit a production DATABASE_URL
 * that happens to be exported in the developer's shell. First file wins per key.
 */
import fs from "fs";
import path from "path";

const candidates = [
  path.resolve(process.cwd(), ".env"),
  path.resolve(process.cwd(), "..", ".env"),
];

const seen = new Set<string>();
for (const file of candidates) {
  if (!fs.existsSync(file)) continue;
  for (const raw of fs.readFileSync(file, "utf8").split("\n")) {
    const line = raw.trim();
    if (!line || line.startsWith("#")) continue;
    const eq = line.indexOf("=");
    if (eq < 1) continue;
    const key = line.slice(0, eq).trim();
    let val = line.slice(eq + 1).trim();
    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
      val = val.slice(1, -1);
    }
    if (seen.has(key)) continue;
    seen.add(key);
    process.env[key] = val;
  }
}
