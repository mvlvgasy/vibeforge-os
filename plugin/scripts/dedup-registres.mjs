#!/usr/bin/env node
/**
 * dedup-registres.mjs — Detects similar BDR/learnings entries in the registers
 * via Voyage AI semantic embeddings.
 *
 * Instruments systematic duplicate detection to anticipate register debt as the
 * entry count grows past 100+.
 *
 * Pattern: reuses the embed-skills.mjs approach (Voyage AI voyage-3-lite, 512
 * dim, hash-based mock fallback when no API key is present).
 *
 * Usage:
 *   node scripts/dedup-registres.mjs                              # dry-run, both registers
 *   node scripts/dedup-registres.mjs --threshold 0.75            # custom threshold (default 0.70)
 *   node scripts/dedup-registres.mjs --registre learnings        # learnings only
 *   node scripts/dedup-registres.mjs --registre bdr              # bdr only
 *   node scripts/dedup-registres.mjs --verbose                   # per-entry details
 *
 * Output: <plugin>/audits/dedup-registres-<YYYY-MM-DD-HH-mm>.md
 *
 * Modes:
 *   --dry-run (default)  : analysis + report, applies NOTHING
 *   --threshold N        : cosine similarity threshold (default 0.70)
 *   --registre <type>    : learnings | bdr | both (default both)
 *   --verbose            : detailed logging
 *
 * Recommendations (per pair):
 *   - MERGE   : sim >= 0.85 — very similar, merge suggested
 *   - REVIEW  : 0.70 <= sim < 0.85 — grey zone, needs arbitration
 *   - KEEP    : sim >= 0.70 but distinguishable (edge case — informational)
 *
 * Idempotent: re-running writes a new timestamped audit; in dry-run mode it
 * does not modify the registers.
 *
 * Graceful degradation: if VOYAGE_API_KEY is absent, falls back to deterministic
 * hash-based mock embeddings (clearly flagged in the report) and does NOT crash.
 *
 * Paths are resolved relative to this script's location, so the plugin works
 * when installed anywhere. The script lives in <plugin>/scripts/, so the plugin
 * root is one level up.
 */

import { readFile, writeFile, mkdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PLUGIN_ROOT = dirname(__dirname);
const REGISTRES_DIR = join(PLUGIN_ROOT, "registres");
const AUDITS_DIR = join(PLUGIN_ROOT, "audits");

const VOYAGE_MODEL = "voyage-3-lite";
const VOYAGE_DIM = 512;
const MOCK_DIM = 32;

// === Args parsing ===
const args = process.argv.slice(2);
let threshold = 0.70;
let registreFilter = "both"; // learnings | bdr | both
let dryRun = true;
let verbose = false;

for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a === "--threshold") {
    const v = parseFloat(args[++i]);
    if (!Number.isFinite(v) || v <= 0 || v > 1) {
      console.error(`[dedup] FATAL: --threshold expects a float in ]0, 1], got: ${args[i]}`);
      process.exit(2);
    }
    threshold = v;
  } else if (a === "--registre") {
    const v = args[++i];
    if (!["learnings", "bdr", "both"].includes(v)) {
      console.error(`[dedup] FATAL: --registre expects learnings|bdr|both, got: ${v}`);
      process.exit(2);
    }
    registreFilter = v;
  } else if (a === "--dry-run") {
    dryRun = true;
  } else if (a === "--verbose") {
    verbose = true;
  } else if (a === "--help" || a === "-h") {
    console.log(`Usage: node scripts/dedup-registres.mjs [options]

Options:
  --threshold N        Cosine similarity threshold (default 0.70, range ]0,1])
  --registre <type>    learnings | bdr | both (default both)
  --dry-run            Analysis only, does not write to the registers (default)
  --verbose            Detailed logging
  -h, --help           This help

Output: <plugin>/audits/dedup-registres-<TS>.md
`);
    process.exit(0);
  } else {
    console.error(`[dedup] WARN: unknown argument ignored: ${a}`);
  }
}

function log(...a) {
  console.log("[dedup]", ...a);
}
function vlog(...a) {
  if (verbose) console.log("[dedup:verbose]", ...a);
}

// === Voyage API key (env only) ===
const VOYAGE_API_KEY = process.env.VOYAGE_API_KEY || null;

// =====================================================================
// Register parsing
// =====================================================================

/**
 * Parse a register file (learnings.md or bdr.md) into individual entries.
 *
 * Expected format: sections delimited by "## <ID> — <title>" up to the next
 * "## " at the same level (or EOF). Entries start AFTER the leading index
 * section of the file.
 *
 * @param {string} filePath
 * @param {"learning"|"bdr"} kind
 */
async function parseRegistre(filePath, kind) {
  const raw = await readFile(filePath, "utf8");
  const lines = raw.split(/\r?\n/);

  // Find where entries start (after the INDEX): the first `## <ID> ...` section
  // that is not "## Index".
  const entries = [];
  let i = 0;
  // Skip until the first section with an ID
  while (i < lines.length) {
    if (/^##\s+([A-Z][A-Za-z0-9_-]*\d+|BDR\d+|L\d+|R\d+|L-[a-zA-Z0-9-]+|R-[a-zA-Z0-9-]+)\s*[—\-]/.test(lines[i])) {
      break;
    }
    i++;
  }

  while (i < lines.length) {
    const line = lines[i];
    const headerMatch = line.match(/^##\s+(.+?)\s*$/);
    // ID match: must begin with a recognizable identifier
    // Patterns: L1, L53, L-<scope>-1, R001, R-<scope>-1, BDR01, BDR-XX
    const idMatch = line.match(/^##\s+(BDR[\w-]+|L[\w-]*\d+[\w-]*|R[\w-]*\d+[\w-]*|L-[\w-]+|R-[\w-]+)\s*[—\-]\s*(.+)$/);

    if (idMatch && headerMatch) {
      const id = idMatch[1].trim();
      const title = idMatch[2].trim();
      const lineStart = i + 1; // 1-indexed
      // Collect body until the next `^## ` or EOF
      const bodyLines = [];
      let j = i + 1;
      while (j < lines.length && !/^##\s+/.test(lines[j])) {
        bodyLines.push(lines[j]);
        j++;
      }
      const lineEnd = j; // last line, 1-indexed (exclusive)
      const body = bodyLines.join("\n");

      // Extract status from frontmatter if present
      let status = "active";
      const fmMatch = body.match(/```yaml\n---\n([\s\S]*?)\n---\n```/);
      if (fmMatch) {
        const statusMatch = fmMatch[1].match(/^status:\s*(\S+)/m);
        if (statusMatch) status = statusMatch[1].trim();
      }

      // Description: preferred sections, fallback to body excerpt
      const description = extractDescription(body);

      entries.push({
        id,
        title,
        description,
        body: body.trim(),
        kind,
        file: filePath,
        lineStart,
        lineEnd,
        status,
      });

      i = j;
    } else {
      i++;
    }
  }

  return entries;
}

/**
 * Extract a representative description from an entry body.
 * Preferences:
 *   1. "### Contexte" / "### Context" section
 *   2. "### Quoi" / "### Pattern" section
 *   3. "### Leçon" / "### Décision" / "### Règle" section
 *   4. Fallback: first 10 non-empty lines after the frontmatter
 *
 * (Supports both French and English section headings for portability across
 * registers written in either language.)
 */
function extractDescription(body) {
  // Strip frontmatter (code-fenced yaml block)
  let work = body.replace(/```yaml\n---\n[\s\S]*?\n---\n```/, "");

  // Try preferred sections (French + English)
  const preferredSections = [
    /### Contexte\n([\s\S]*?)(?=\n###|\n##|$)/,
    /### Context\n([\s\S]*?)(?=\n###|\n##|$)/,
    /### Quoi\n([\s\S]*?)(?=\n###|\n##|$)/,
    /### What\n([\s\S]*?)(?=\n###|\n##|$)/,
    /### Pattern\n([\s\S]*?)(?=\n###|\n##|$)/,
    /### Leçon\n([\s\S]*?)(?=\n###|\n##|$)/,
    /### Lesson\n([\s\S]*?)(?=\n###|\n##|$)/,
    /### Décision\n([\s\S]*?)(?=\n###|\n##|$)/,
    /### Decision\n([\s\S]*?)(?=\n###|\n##|$)/,
    /### Règle\n([\s\S]*?)(?=\n###|\n##|$)/,
    /### Rule\n([\s\S]*?)(?=\n###|\n##|$)/,
    /### Symptôme\n([\s\S]*?)(?=\n###|\n##|$)/,
    /### Symptom\n([\s\S]*?)(?=\n###|\n##|$)/,
    /### Root cause\n([\s\S]*?)(?=\n###|\n##|$)/,
  ];
  for (const re of preferredSections) {
    const m = work.match(re);
    if (m && m[1].trim().length > 20) {
      return m[1].trim().slice(0, 1500);
    }
  }

  // Fallback: first 10 non-empty lines
  const lines = work.split("\n").map((l) => l.trim()).filter((l) => l.length > 0);
  return lines.slice(0, 10).join(" ").slice(0, 1500);
}

// =====================================================================
// Embeddings
// =====================================================================

/**
 * Embed via Voyage AI (1 call per batch). Retries on 429 (rate limit).
 *
 * Free tier without a payment method is heavily rate-limited (a few RPM /
 * low TPM). We handle:
 *   - adaptive batch size (estimates tokens ~= chars/4, capped per batch)
 *   - a delay between batches
 *   - retry with backoff on 429
 */
async function embedVoyageOnce(texts) {
  const res = await fetch("https://api.voyageai.com/v1/embeddings", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${VOYAGE_API_KEY}`,
    },
    body: JSON.stringify({
      input: texts,
      model: VOYAGE_MODEL,
      input_type: "document",
    }),
  });
  if (!res.ok) {
    const err = await res.text();
    const e = new Error(`Voyage API ${res.status}: ${err.slice(0, 500)}`);
    e.status = res.status;
    throw e;
  }
  const json = await res.json();
  return json.data.map((d) => d.embedding);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function embedVoyageWithRetry(texts, attempt = 1) {
  try {
    return await embedVoyageOnce(texts);
  } catch (err) {
    if (err.status === 429 && attempt <= 3) {
      const wait = attempt * 25_000; // 25s, 50s, 75s
      log(`Voyage 429 rate limit (attempt ${attempt}/3) — waiting ${wait / 1000}s before retry...`);
      await sleep(wait);
      return embedVoyageWithRetry(texts, attempt + 1);
    }
    throw err;
  }
}

/**
 * Deterministic mock embedding (hash-based). Not a real semantic embedding,
 * but lets you test the chain without a Voyage key.
 */
function mockEmbed(text) {
  const v = new Array(MOCK_DIM).fill(0);
  for (let i = 0; i < text.length; i++) {
    const c = text.charCodeAt(i);
    v[i % MOCK_DIM] += (c * 0.001) % 1;
  }
  const norm = Math.sqrt(v.reduce((a, b) => a + b * b, 0)) || 1;
  return v.map((x) => x / norm);
}

/**
 * Cosine similarity between 2 vectors.
 */
function cosine(a, b) {
  if (!a || !b || a.length !== b.length) return 0;
  let dot = 0;
  let na = 0;
  let nb = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  const denom = Math.sqrt(na) * Math.sqrt(nb);
  return denom === 0 ? 0 : dot / denom;
}

/**
 * Build the text to embed for an entry.
 * Combines title + description (which already holds the key context).
 */
function buildEmbedText(entry) {
  // Cap at ~2000 chars to stay within Voyage budgets and keep a strong signal
  const txt = `${entry.kind}: ${entry.id} — ${entry.title}\n\n${entry.description}`;
  return txt.slice(0, 2000);
}

// =====================================================================
// Recommendations
// =====================================================================

function classify(sim) {
  if (sim >= 0.85) return "MERGE";
  if (sim >= threshold) return "REVIEW";
  return "KEEP";
}

// =====================================================================
// Markdown report generation
// =====================================================================

function fmtTimestamp() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}-${pad(d.getHours())}-${pad(d.getMinutes())}`;
}

function previewBody(body, maxLines = 30) {
  const lines = body.split("\n").slice(0, maxLines);
  return lines.join("\n");
}

function generateReport({
  pairs,
  totalEntries,
  totalsByKind,
  provider,
  modelName,
  timestamp,
}) {
  const lines = [];
  lines.push(`# Register dedup audit — ${timestamp}`);
  lines.push("");
  lines.push(`> Automatic detection of learnings/BDR duplicates via semantic embeddings.`);
  lines.push(`> Script: \`scripts/dedup-registres.mjs\``);
  lines.push("");
  lines.push(`## Metadata`);
  lines.push("");
  lines.push(`- **Date**: ${new Date().toISOString()}`);
  lines.push(`- **Mode**: dry-run (read-only, no modification)`);
  lines.push(`- **Similarity threshold**: \`${threshold.toFixed(2)}\``);
  lines.push(`- **Embedding provider**: ${provider} (${modelName})`);
  lines.push(`- **Registers scanned**: ${registreFilter}`);
  lines.push(`- **Total entries analyzed**: ${totalEntries}`);
  for (const [kind, n] of Object.entries(totalsByKind)) {
    lines.push(`  - ${kind}: ${n}`);
  }
  lines.push("");

  if (provider === "mock") {
    lines.push(`> **MOCK MODE**: hash-based embeddings, NOT semantic.`);
    lines.push(`> Set \`VOYAGE_API_KEY\` in your environment, then re-run for reliable results.`);
    lines.push("");
  }

  // Counter summary
  const counts = { MERGE: 0, REVIEW: 0, KEEP: 0 };
  for (const p of pairs) counts[p.recommendation]++;

  lines.push(`## Summary`);
  lines.push("");
  lines.push(`| Recommendation | Count | Definition |`);
  lines.push(`|---|---|---|`);
  lines.push(`| MERGE  | ${counts.MERGE}  | sim >= 0.85 — very similar, merge suggested |`);
  lines.push(`| REVIEW | ${counts.REVIEW} | ${threshold.toFixed(2)} <= sim < 0.85 — grey zone, arbitrate |`);
  lines.push(`| KEEP   | ${counts.KEEP}   | sim >= ${threshold.toFixed(2)} but distinguishable (info) |`);
  lines.push("");

  if (pairs.length === 0) {
    lines.push(`**No candidates detected** at threshold \`${threshold.toFixed(2)}\`. Try a lower threshold (\`--threshold 0.60\`) for a broader search.`);
    lines.push("");
    return lines.join("\n");
  }

  // Candidates table
  lines.push(`## Candidates table`);
  lines.push("");
  lines.push(`| Recommendation | sim | ID1 | ID2 | Title1 | Title2 |`);
  lines.push(`|---|---|---|---|---|---|`);
  for (const p of pairs) {
    const reco = p.recommendation;
    // Escape pipes in titles
    const t1 = p.a.title.replace(/\|/g, "\\|").slice(0, 70);
    const t2 = p.b.title.replace(/\|/g, "\\|").slice(0, 70);
    lines.push(`| ${reco} | ${p.similarity.toFixed(3)} | \`${p.a.id}\` | \`${p.b.id}\` | ${t1} | ${t2} |`);
  }
  lines.push("");

  // Per-pair detail (side-by-side preview)
  lines.push(`## Candidate pairs detail`);
  lines.push("");

  for (const p of pairs) {
    lines.push(`### Pair ${p.a.id} <-> ${p.b.id} — sim=${p.similarity.toFixed(3)} — ${p.recommendation}`);
    lines.push("");
    lines.push(`**Type**: ${p.a.kind}`);
    lines.push(`**File**: \`${p.a.file.replace(/\\/g, "/").split("/").slice(-2).join("/")}\``);
    lines.push(`**Location A**: line ${p.a.lineStart}-${p.a.lineEnd}`);
    lines.push(`**Location B**: line ${p.b.lineStart}-${p.b.lineEnd}`);
    lines.push(`**Status A**: ${p.a.status}`);
    lines.push(`**Status B**: ${p.b.status}`);
    lines.push("");
    lines.push(`#### Entry A: ${p.a.id} — ${p.a.title}`);
    lines.push("");
    lines.push("```markdown");
    lines.push(previewBody(p.a.body, 25));
    lines.push("```");
    lines.push("");
    lines.push(`#### Entry B: ${p.b.id} — ${p.b.title}`);
    lines.push("");
    lines.push("```markdown");
    lines.push(previewBody(p.b.body, 25));
    lines.push("```");
    lines.push("");

    if (p.recommendation === "MERGE") {
      lines.push(`**Suggested action**: merge B into A. Keep the lowest ID (\`${p.a.id}\`), append B's unique info, mark B as \`status: deprecated\` (or move to \`_archived/\`).`);
    } else if (p.recommendation === "REVIEW") {
      lines.push(`**Suggested action**: human review. The two entries are semantically close but may cover distinct aspects of the same domain. Decide manually: merge vs keep separate.`);
    } else {
      lines.push(`**Suggested action**: none. The two entries share vocabulary but are probably distinct. Listed for information only.`);
    }
    lines.push("");
    lines.push(`---`);
    lines.push("");
  }

  // Footer
  lines.push(`## How to apply a merge`);
  lines.push("");
  lines.push(`For each MERGE pair, the merge workflow should:`);
  lines.push(`1. Present the proposed merge`);
  lines.push(`2. Ask for your confirmation`);
  lines.push(`3. Apply the merge: keep the older entry, append unique info, mark the other \`deprecated\` or move it to \`_archived/\``);
  lines.push(`4. Update the INDEX TOC at the top of the file`);
  lines.push(`5. Log the merge in \`<plugin>/audits/dedup-applied-<ts>.md\` for traceability`);
  lines.push("");

  return lines.join("\n");
}

// =====================================================================
// Main
// =====================================================================

async function main() {
  const start = Date.now();
  log(`Plugin root: ${PLUGIN_ROOT}`);
  log(`Mode: ${dryRun ? "DRY-RUN" : "APPLY"} (always dry-run in this script — applying merges is a separate workflow)`);
  log(`Threshold: ${threshold.toFixed(2)}`);
  log(`Registers: ${registreFilter}`);

  // === Collect entries ===
  const entries = [];
  const files = [];

  if (registreFilter === "learnings" || registreFilter === "both") {
    const p = join(REGISTRES_DIR, "learnings.md");
    if (existsSync(p)) {
      const parsed = await parseRegistre(p, "learning");
      log(`Parsed ${parsed.length} learnings from ${p}`);
      entries.push(...parsed);
      files.push(p);
    } else {
      log(`WARN: ${p} not found, skipping learnings`);
    }
  }
  if (registreFilter === "bdr" || registreFilter === "both") {
    const p = join(REGISTRES_DIR, "bdr.md");
    if (existsSync(p)) {
      const parsed = await parseRegistre(p, "bdr");
      log(`Parsed ${parsed.length} BDR from ${p}`);
      entries.push(...parsed);
      files.push(p);
    } else {
      log(`WARN: ${p} not found, skipping BDR`);
    }
  }

  if (entries.length === 0) {
    log("No entries found, nothing to compare. Exit.");
    process.exit(0);
  }

  // Filter out empty entries or those with too-short descriptions (< 20 chars)
  const validEntries = entries.filter((e) => {
    if (!e.description || e.description.length < 20) {
      vlog(`Skip ${e.id}: description too short (${e.description?.length || 0} chars)`);
      return false;
    }
    return true;
  });

  log(`${validEntries.length} valid entries out of ${entries.length} (skip if description < 20 chars)`);

  if (validEntries.length < 2) {
    log("Fewer than 2 valid entries — no pair possible. Exit.");
    process.exit(0);
  }

  // === Embed ===
  const provider = VOYAGE_API_KEY ? "voyage" : "mock";
  const modelName = provider === "voyage" ? VOYAGE_MODEL : "mock-hash";
  log(`Embedding provider: ${provider} (${modelName}, dim=${provider === "voyage" ? VOYAGE_DIM : MOCK_DIM})`);
  if (provider === "mock") {
    log(`  MOCK: hash-based embeddings, NOT semantic. Set VOYAGE_API_KEY for real results.`);
  }

  const texts = validEntries.map(buildEmbedText);
  let embeddings;
  try {
    if (provider === "voyage") {
      // Free tier without a payment method is rate-limited. Estimate ~1 token
      // per 4 chars (standard heuristic). Target a conservative per-batch token
      // budget to stay under the TPM cap.
      const MAX_TOKENS_PER_BATCH = 8000;
      const estimateTokens = (s) => Math.ceil(s.length / 4);

      // Build dynamic batches
      const batches = [];
      let currentBatch = [];
      let currentTokens = 0;
      for (const t of texts) {
        const tk = estimateTokens(t);
        if (currentTokens + tk > MAX_TOKENS_PER_BATCH && currentBatch.length > 0) {
          batches.push(currentBatch);
          currentBatch = [];
          currentTokens = 0;
        }
        currentBatch.push(t);
        currentTokens += tk;
      }
      if (currentBatch.length > 0) batches.push(currentBatch);

      log(`Voyage: ${batches.length} batch(es) (target <=${MAX_TOKENS_PER_BATCH} tokens/batch)`);

      embeddings = [];
      for (let bi = 0; bi < batches.length; bi++) {
        const slice = batches[bi];
        const tk = slice.reduce((s, t) => s + estimateTokens(t), 0);
        log(`Voyage batch ${bi + 1}/${batches.length} (${slice.length} texts, ~${tk} tokens)...`);

        if (bi > 0) {
          // Throttle between batches to respect free-tier rate limits.
          log(`Waiting 22s (free-tier rate limit)...`);
          await sleep(22_000);
        }

        const part = await embedVoyageWithRetry(slice);
        embeddings.push(...part);
      }
    } else {
      embeddings = texts.map(mockEmbed);
    }
  } catch (err) {
    console.error(`[dedup] FATAL: embedding failed: ${err.message}`);
    if (err.status === 429) {
      console.error(`[dedup] Tip: add a payment method at https://dashboard.voyageai.com for standard limits.`);
      console.error(`[dedup] Or re-run later. The mock fallback can also be used to test parsing.`);
    }
    process.exit(5);
  }

  log(`${embeddings.length} embeddings computed`);

  // === Compute pairs (same kind only) ===
  log(`Computing pair similarity (same kind only)...`);
  const pairs = [];
  for (let i = 0; i < validEntries.length; i++) {
    for (let j = i + 1; j < validEntries.length; j++) {
      const a = validEntries[i];
      const b = validEntries[j];
      // Same kind only (learning vs learning, bdr vs bdr — no cross)
      if (a.kind !== b.kind) continue;
      // Ignore already deprecated/promoted entries
      if (["deprecated", "promoted", "archived", "merged"].includes(a.status) ||
          ["deprecated", "promoted", "archived", "merged"].includes(b.status)) {
        continue;
      }
      const sim = cosine(embeddings[i], embeddings[j]);
      if (sim >= threshold) {
        pairs.push({
          a,
          b,
          similarity: sim,
          recommendation: classify(sim),
        });
      }
    }
  }

  // Sort by sim desc
  pairs.sort((x, y) => y.similarity - x.similarity);

  log(`${pairs.length} pairs detected with sim >= ${threshold.toFixed(2)}`);

  // === Generate report ===
  await mkdir(AUDITS_DIR, { recursive: true });
  const ts = fmtTimestamp();
  const reportPath = join(AUDITS_DIR, `dedup-registres-${ts}.md`);

  const totalsByKind = {};
  for (const e of validEntries) {
    totalsByKind[e.kind] = (totalsByKind[e.kind] || 0) + 1;
  }

  const report = generateReport({
    pairs,
    totalEntries: validEntries.length,
    totalsByKind,
    provider,
    modelName,
    timestamp: ts,
  });

  await writeFile(reportPath, report, "utf8");
  log(`Report written: ${reportPath} (${Date.now() - start}ms)`);

  // Console summary: top 5
  if (pairs.length > 0) {
    console.log(`\n=== Top 5 candidates detected ===`);
    for (const p of pairs.slice(0, 5)) {
      const reco = p.recommendation.padEnd(7);
      const sim = p.similarity.toFixed(3);
      console.log(`  ${reco} sim=${sim}  ${p.a.id} <-> ${p.b.id}  | ${p.a.title.slice(0, 50)} <> ${p.b.title.slice(0, 50)}`);
    }
    if (pairs.length > 5) {
      console.log(`  ... ${pairs.length - 5} more in the full report.`);
    }
  } else {
    console.log(`\nNo candidates detected. You can lower the threshold with \`--threshold 0.60\`.`);
  }

  console.log(`\nFull report: ${reportPath.replace(/\\/g, "/")}`);
}

main().catch((err) => {
  console.error(`[dedup] FATAL: ${err.stack || err.message}`);
  process.exit(1);
});
