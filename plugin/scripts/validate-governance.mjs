#!/usr/bin/env node
/**
 * validate-governance.mjs — CI validation of the plugin's own governance components.
 *
 * Principle: "a governance repo must validate its own components."
 *
 * Validators (zero dependencies, Node built-ins only):
 *  1. rules.md  — no duplicate rule IDs
 *  2. rules.md  — each rule (## Rxxx / ## R-<scope>-N) has a frontmatter block with id/type/status
 *  3. rules.md  — the frontmatter `id:` matches the section title
 *  4. hooks.json — valid JSON + every referenced .ps1 script exists on disk
 *  5. .claude-plugin/plugin.json + marketplace.json — valid JSON (if present)
 *
 * Non-zero exit code if at least one validator fails (CI gate).
 *
 * Paths are resolved relative to this script's location, so the plugin works
 * when installed anywhere. The script lives in <plugin>/scripts/, so the plugin
 * root is one level up.
 *
 * Usage: node scripts/validate-governance.mjs
 */

import { readFileSync, existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");

let errors = 0;
let checks = 0;
const fail = (msg) => { console.error(`  x ${msg}`); errors++; };
const ok = (msg) => { console.log(`  ok ${msg}`); };
const section = (name) => { console.log(`\n[${name}]`); };

// ---------------------------------------------------------------------------
// 1-3. rules.md
// ---------------------------------------------------------------------------
section("rules.md");
const rulesPath = path.join(ROOT, "registres", "rules.md");
if (!existsSync(rulesPath)) {
  fail(`not found: ${rulesPath}`);
} else {
  const txt = readFileSync(rulesPath, "utf8");
  const lines = txt.split(/\r?\n/);

  // Rule titles: "## R001 — ..." or "## R-<scope>-12 — ..."
  const titleIds = [];
  const titleRe = /^##\s+(R(?:-[a-z]+)?-?\d+)\b/;
  for (const line of lines) {
    const m = line.match(titleRe);
    if (m) titleIds.push(m[1]);
  }
  checks++;
  // 1. duplicates
  const seen = new Map();
  const dups = new Set();
  for (const id of titleIds) {
    seen.set(id, (seen.get(id) || 0) + 1);
    if (seen.get(id) > 1) dups.add(id);
  }
  if (dups.size > 0) {
    fail(`duplicate rule IDs: ${[...dups].join(", ")}`);
  } else {
    ok(`${titleIds.length} rules, no duplicate IDs`);
  }

  // 2-3. frontmatter id/type/status + id<->title match
  // Parse the ```yaml ... ``` blocks that follow each title.
  checks++;
  let fmIssues = 0;
  const blockRe = /^##\s+(R(?:-[a-z]+)?-?\d+)\b[^\n]*\n+```yaml\n([\s\S]*?)\n```/gm;
  let bm;
  let blocksFound = 0;
  while ((bm = blockRe.exec(txt)) !== null) {
    blocksFound++;
    const titleId = bm[1];
    const fm = bm[2];
    const idM = fm.match(/^\s*id:\s*(\S+)/m);
    const typeM = fm.match(/^\s*type:\s*(\S+)/m);
    const statusM = fm.match(/^\s*status:\s*(\S+)/m);
    if (!idM) { fail(`${titleId}: frontmatter missing 'id:'`); fmIssues++; continue; }
    if (!typeM) { fail(`${titleId}: frontmatter missing 'type:'`); fmIssues++; }
    if (!statusM) { fail(`${titleId}: frontmatter missing 'status:'`); fmIssues++; }
    if (idM[1] !== titleId) { fail(`${titleId}: frontmatter id='${idM[1]}' != title`); fmIssues++; }
  }
  if (fmIssues === 0) ok(`${blocksFound} frontmatter blocks valid (id/type/status consistent)`);
}

// ---------------------------------------------------------------------------
// 4. hooks.json
// ---------------------------------------------------------------------------
section("hooks.json");
const hooksPath = path.join(ROOT, "hooks", "hooks.json");
if (!existsSync(hooksPath)) {
  fail(`not found: ${hooksPath}`);
} else {
  checks++;
  let hooksJson;
  try {
    hooksJson = JSON.parse(readFileSync(hooksPath, "utf8"));
    ok("valid JSON");
  } catch (e) {
    fail(`invalid JSON: ${e.message}`);
    hooksJson = null;
  }
  if (hooksJson) {
    checks++;
    const raw = readFileSync(hooksPath, "utf8");
    const scriptRe = /hooks\\\\([\w.-]+\.ps1)/g;
    let sm;
    const referenced = new Set();
    while ((sm = scriptRe.exec(raw)) !== null) referenced.add(sm[1]);
    let missing = 0;
    for (const script of referenced) {
      const p = path.join(ROOT, "hooks", script);
      if (!existsSync(p)) { fail(`referenced script missing: hooks/${script}`); missing++; }
    }
    if (missing === 0) ok(`${referenced.size} referenced .ps1 scripts all exist`);
  }
}

// ---------------------------------------------------------------------------
// 5. plugin.json / marketplace.json
// ---------------------------------------------------------------------------
section("plugin manifests");
for (const rel of [".claude-plugin/plugin.json", ".claude-plugin/marketplace.json"]) {
  const p = path.join(ROOT, rel);
  if (!existsSync(p)) continue; // optional
  checks++;
  try {
    JSON.parse(readFileSync(p, "utf8"));
    ok(`${rel}: valid JSON`);
  } catch (e) {
    fail(`${rel}: invalid JSON — ${e.message}`);
  }
}

// ---------------------------------------------------------------------------
console.log(`\n${"=".repeat(50)}`);
if (errors > 0) {
  console.error(`FAILED: ${errors} error(s) across ${checks} validators.`);
  process.exit(1);
} else {
  console.log(`OK: ${checks} validators passed, 0 errors.`);
  process.exit(0);
}
