#!/usr/bin/env node
/**
 * embed-skills.mjs — Builds the vector index of the plugin's skills/agents.
 *
 * Goal: enable semantic retrieval over skills/agents (e.g. for a curator to
 * decide "duplicate vs new skill") instead of reading every file manually.
 *
 * Provider:
 *   - Primary: Voyage AI (voyage-3-lite). Read the API key from the
 *     VOYAGE_API_KEY environment variable. See https://voyageai.com
 *   - Fallback: deterministic mock embedding (hash-based). Lets you test the
 *     whole chain without a key. Re-run with VOYAGE_API_KEY set to get real
 *     embeddings.
 *
 * If VOYAGE_API_KEY is absent, the script does NOT crash: it logs a clear
 * message and uses the mock provider (still writes a usable index file).
 *
 * Paths are resolved relative to this script's location, so the plugin works
 * when installed anywhere. The script lives in <plugin>/scripts/, so the plugin
 * root is one level up.
 *
 * Usage:
 *   node scripts/embed-skills.mjs           # embed all skills + agents
 *   node scripts/embed-skills.mjs --verbose # with per-item details
 *
 * Output: skills-index.embeddings.json at the plugin root.
 *
 * Consumer read pattern:
 *   const idx = JSON.parse(fs.readFileSync('skills-index.embeddings.json'))
 *   // Compute cosine similarity against a query embedding to find the
 *   // semantically closest skills/agents.
 */

import { readFile, writeFile, readdir, stat } from "node:fs/promises";
import { join, dirname, basename } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PLUGIN_ROOT = dirname(__dirname); // scripts/.. = plugin root
const OUT_FILE = join(PLUGIN_ROOT, "skills-index.embeddings.json");

const VOYAGE_API_KEY = process.env.VOYAGE_API_KEY;
const VOYAGE_MODEL = "voyage-3-lite";
const VOYAGE_DIM = 512; // voyage-3-lite output dimension
const MOCK_DIM = 32; // lightweight for mock

const VERBOSE = process.argv.includes("--verbose");

function log(...args) {
  console.log("[embed-skills]", ...args);
}

/**
 * Minimal YAML frontmatter parse of a .md file.
 * Returns {name, description, body}. Does not attempt full YAML parsing —
 * just looks for name and description.
 */
async function parseSkillFile(filepath) {
  const raw = await readFile(filepath, "utf8");
  const fmMatch = raw.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!fmMatch) {
    return { name: basename(filepath, ".md"), description: "", body: raw };
  }
  const [, frontmatter, body] = fmMatch;
  const nameMatch = frontmatter.match(/^name:\s*(.+)$/m);
  // description can be:
  //  - one line: "description: foo"
  //  - a YAML block scalar "|": "description: |\n  foo\n  bar"
  let description = "";
  // Detect block scalar first to avoid ambiguity
  const descBlockMatch = frontmatter.match(/^description:\s*\|[-+]?\s*\n((?:[ \t]+.*\n?)+)/m);
  if (descBlockMatch) {
    description = descBlockMatch[1]
      .split("\n")
      .map((l) => l.replace(/^[ \t]+/, ""))
      .filter((l) => l.length > 0)
      .join(" ")
      .trim();
  } else {
    const descLineMatch = frontmatter.match(/^description:\s*(.+)$/m);
    if (descLineMatch) {
      description = descLineMatch[1].trim();
    }
  }
  return {
    name: nameMatch ? nameMatch[1].trim() : basename(filepath, ".md"),
    description,
    body: body.trim(),
  };
}

/** Walk skills dir and agents dir, returns list of items to embed. */
async function collectItems() {
  const items = [];

  // Skills: <plugin>/skills/<name>/SKILL.md
  const skillsDir = join(PLUGIN_ROOT, "skills");
  let skillFolders = [];
  try {
    skillFolders = await readdir(skillsDir, { withFileTypes: true });
  } catch {
    log(`No skills/ dir at ${skillsDir}, skipping skills.`);
  }
  for (const ent of skillFolders) {
    if (!ent.isDirectory()) continue;
    const skillFile = join(skillsDir, ent.name, "SKILL.md");
    try {
      await stat(skillFile);
    } catch {
      continue; // skip if no SKILL.md
    }
    const parsed = await parseSkillFile(skillFile);
    items.push({
      kind: "skill",
      path: `skills/${ent.name}/SKILL.md`,
      ...parsed,
    });
  }

  // Agents: <plugin>/agents/<name>.md
  const agentsDir = join(PLUGIN_ROOT, "agents");
  let agentFiles = [];
  try {
    agentFiles = await readdir(agentsDir);
  } catch {
    log(`No agents/ dir at ${agentsDir}, skipping agents.`);
  }
  for (const f of agentFiles) {
    if (!f.endsWith(".md")) continue;
    const parsed = await parseSkillFile(join(agentsDir, f));
    items.push({
      kind: "agent",
      path: `agents/${f}`,
      ...parsed,
    });
  }

  return items;
}

/** Build the text to embed for a single item. */
function buildEmbedText(item) {
  const bodyExcerpt = item.body.slice(0, 500);
  return `${item.kind}: ${item.name}\n${item.description}\n\n${bodyExcerpt}`;
}

/** Voyage AI embedding via fetch. */
async function embedVoyage(texts) {
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
    const errText = await res.text();
    throw new Error(`Voyage API ${res.status}: ${errText.slice(0, 500)}`);
  }
  const json = await res.json();
  return json.data.map((d) => d.embedding);
}

/** Mock embedding: hash-based deterministic vector. */
function mockEmbed(text) {
  // Simple deterministic hash -> vector. Not a real semantic embedding,
  // but lets you test the chain without a key.
  const v = new Array(MOCK_DIM).fill(0);
  for (let i = 0; i < text.length; i++) {
    const c = text.charCodeAt(i);
    v[i % MOCK_DIM] += (c * 0.001) % 1;
  }
  // L2 normalize
  const norm = Math.sqrt(v.reduce((a, b) => a + b * b, 0)) || 1;
  return v.map((x) => x / norm);
}

async function main() {
  const start = Date.now();
  log(`Plugin root: ${PLUGIN_ROOT}`);

  const items = await collectItems();
  log(`Collected ${items.length} items (skills + agents)`);

  if (items.length === 0) {
    log("No skills or agents found. Nothing to embed. Exiting.");
    process.exit(0);
  }

  const provider = VOYAGE_API_KEY ? "voyage" : "mock";
  if (provider === "voyage") {
    log(`Provider: Voyage AI (${VOYAGE_MODEL}, dim=${VOYAGE_DIM})`);
  } else {
    log(
      `Provider: MOCK (no VOYAGE_API_KEY). Deterministic hash-based embeddings, dim=${MOCK_DIM}.`,
    );
    log(`  -> For real embeddings: set VOYAGE_API_KEY and re-run this script.`);
  }

  const texts = items.map(buildEmbedText);
  let embeddings;
  if (provider === "voyage") {
    // Voyage allows batches up to 128; we typically have far fewer items.
    embeddings = await embedVoyage(texts);
  } else {
    embeddings = texts.map(mockEmbed);
  }

  const out = {
    model: provider === "voyage" ? VOYAGE_MODEL : "mock-hash",
    provider,
    dim: embeddings[0]?.length ?? 0,
    generated_at: new Date().toISOString(),
    items: items.map((item, i) => ({
      kind: item.kind,
      name: item.name,
      path: item.path,
      description: item.description.slice(0, 280),
      embedding: embeddings[i],
    })),
  };

  await writeFile(OUT_FILE, JSON.stringify(out, null, 2), "utf8");
  log(
    `Wrote ${out.items.length} embeddings to ${OUT_FILE} (${Date.now() - start}ms)`,
  );

  if (VERBOSE) {
    for (const it of out.items) {
      console.log(`  - ${it.kind}/${it.name}: ${it.description.slice(0, 60)}...`);
    }
  }
}

main().catch((err) => {
  console.error("[embed-skills] FATAL:", err.message);
  process.exit(1);
});
