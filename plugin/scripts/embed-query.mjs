#!/usr/bin/env node
/**
 * embed-query.mjs — Semantic search over the skills/agents index.
 *
 * Used to find existing items semantically closest to a new skill draft
 * (e.g. an overlap check before adding a skill).
 *
 * Usage:
 *   node scripts/embed-query.mjs "<query text>"           # top 5 default
 *   node scripts/embed-query.mjs --topk 10 "<query>"      # top N
 *   node scripts/embed-query.mjs --json "<query>"         # pure JSON (no human label)
 *
 * Output (human, default):
 *   sim=0.823  skill/code-reviewer      Systematic code review before push...
 *   sim=0.741  agent/code-reviewer      Systematic code review...
 *   ...
 *
 * Output (--json): JSON array [{kind, name, similarity, description}]
 *
 * Prerequisites:
 *   - VOYAGE_API_KEY in the environment.
 *   - skills-index.embeddings.json present at the plugin root (run
 *     'node scripts/embed-skills.mjs' first to generate it).
 *
 * Graceful degradation: if VOYAGE_API_KEY is absent, the script prints a clear
 * message and exits 0 WITHOUT crashing (semantic search is simply skipped).
 *
 * Paths are resolved relative to this script's location, so the plugin works
 * when installed anywhere. The script lives in <plugin>/scripts/, so the plugin
 * root is one level up.
 */

import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PLUGIN_ROOT = dirname(__dirname);
const INDEX_FILE = join(PLUGIN_ROOT, "skills-index.embeddings.json");

// === Args parsing ===
const args = process.argv.slice(2);
let topk = 5;
let outputJson = false;
let queryText = "";
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--topk") {
    topk = parseInt(args[++i], 10);
  } else if (args[i] === "--json") {
    outputJson = true;
  } else {
    queryText = args[i];
  }
}

if (!queryText) {
  console.error(
    'Usage: node scripts/embed-query.mjs [--topk N] [--json] "<query text>"',
  );
  process.exit(2);
}

// === Load VOYAGE_API_KEY (env only) ===
const VOYAGE_API_KEY = process.env.VOYAGE_API_KEY;
if (!VOYAGE_API_KEY) {
  console.error(
    "VOYAGE_API_KEY not set — semantic search is unavailable, skipping.",
  );
  console.error(
    "-> Set VOYAGE_API_KEY in your environment, then retry.",
  );
  process.exit(0); // graceful: not an error, just nothing to do
}

// === Load index ===
let index;
try {
  index = JSON.parse(readFileSync(INDEX_FILE, "utf8"));
} catch (err) {
  console.error(`FATAL: cannot read ${INDEX_FILE}: ${err.message}`);
  console.error(
    `-> Run 'node scripts/embed-skills.mjs' to generate the index first.`,
  );
  process.exit(4);
}

if (index.provider !== "voyage") {
  console.error(
    `WARN: index is in MOCK mode (provider=${index.provider}). Similarity is not semantic.`,
  );
  console.error(`-> Re-run 'node scripts/embed-skills.mjs' with VOYAGE_API_KEY set.`);
}

// === Embed the query via Voyage ===
async function embedQuery(text) {
  const res = await fetch("https://api.voyageai.com/v1/embeddings", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${VOYAGE_API_KEY}`,
    },
    body: JSON.stringify({
      input: [text],
      model: index.model || "voyage-3-lite",
      input_type: "query", // optimized for query vs document
    }),
  });
  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Voyage API ${res.status}: ${errText.slice(0, 500)}`);
  }
  const json = await res.json();
  return json.data[0].embedding;
}

function cosine(a, b) {
  let dot = 0,
    na = 0,
    nb = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  return dot / (Math.sqrt(na) * Math.sqrt(nb) || 1);
}

const queryEmbedding = await embedQuery(queryText);

// === Rank ===
const ranked = index.items
  .map((it) => ({
    kind: it.kind,
    name: it.name,
    similarity: cosine(queryEmbedding, it.embedding),
    description: it.description,
    path: it.path,
  }))
  .sort((a, b) => b.similarity - a.similarity)
  .slice(0, topk);

// === Output ===
if (outputJson) {
  console.log(JSON.stringify(ranked, null, 2));
} else {
  for (const r of ranked) {
    const sim = r.similarity.toFixed(3);
    const label = `${r.kind}/${r.name}`.padEnd(40);
    const desc = (r.description || "").slice(0, 80);
    console.log(`sim=${sim}  ${label}  ${desc}`);
  }
}
