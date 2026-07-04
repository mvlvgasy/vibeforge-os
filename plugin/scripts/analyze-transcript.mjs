#!/usr/bin/env node
// analyze-transcript.mjs — DETERMINISTIC extraction of metrics from a Claude Code transcript (.jsonl)
// Usage: node analyze-transcript.mjs <path.jsonl> [<path2.jsonl> ...]
//
// Pricing notes (USD per 1M tokens):
//   - <synthetic> and internal models (<...>) = ZERO cost (not billed by Anthropic)
//   - Opus 4.5+ = $5/$25 ; Opus 4.0/4.1 = legacy $15/$75 ; Sonnet = $3/$15 ; Haiku 4.5+ = $1/$5
//   - Cache: write5m x1.25, write1h x2.0, read x0.1
// Why: metric extraction is DETERMINISTIC -> a parser, not an LLM estimate
// (an LLM would hallucinate, e.g. "$34 for 426 tokens").

import fs from 'node:fs';

// USD per 1M tokens
const TABLE = {
  opus:           { in: 5,    out: 25 },
  sonnet:         { in: 3,    out: 15 },
  haiku:          { in: 1,    out: 5  },
  'opus-legacy':  { in: 15,   out: 75 },  // Opus 4.0 / 4.1
  'haiku-legacy': { in: 0.8,  out: 4  },  // Haiku 3.5
  synthetic:      { in: 0,    out: 0  },  // <synthetic>, compactions, system reminders — NOT billed
};
const MULT = { write5m: 1.25, write1h: 2.0, read: 0.1 };

function priceFor(model) {
  const id = model || '';
  if (id === '<synthetic>' || id.startsWith('<')) return TABLE.synthetic;
  const m = id.match(/^claude-(opus|sonnet|haiku)-(\d+)(?:-(\d+))?/);
  if (!m) return TABLE.sonnet; // fallback
  const fam = m[1], major = +m[2], minor = m[3] ? +m[3] : 0;
  if (fam === 'opus')   return (major >= 5 || (major === 4 && minor >= 5)) ? TABLE.opus : TABLE['opus-legacy'];
  if (fam === 'sonnet') return TABLE.sonnet;
  if (fam === 'haiku')  return major >= 4 ? TABLE.haiku : TABLE['haiku-legacy'];
  return TABLE.sonnet;
}

function analyze(file) {
  const raw = fs.readFileSync(file, 'utf8');
  const lines = raw.split(/\r?\n/).filter(Boolean);

  // DEDUP by message.id: partial streaming messages (--include-partial-messages)
  // repeat the same id -> without dedup we double-count tokens. last-wins (the
  // final version is the most complete).
  const byId = new Map();
  let order = 0, compactions = 0;
  let runtime = 'unknown';
  let firstTs = null, lastTs = null;

  for (const line of lines) {
    let rec;
    try { rec = JSON.parse(line); } catch { continue; }

    if (rec.timestamp) { firstTs = firstTs || rec.timestamp; lastTs = rec.timestamp; }
    if (rec.isCompactSummary === true || rec.type === 'compact' ||
        (rec.subtype && String(rec.subtype).includes('compact'))) compactions++;

    if (rec.type !== 'assistant') continue; // cost comes only from assistant messages
    const msg = rec.message || rec;
    const id = (msg && msg.id) ? msg.id : (rec.uuid ?? `_anon_${order++}`);
    byId.set(id, { msg, rec }); // last-wins
  }

  let inTok = 0, outTok = 0, cacheRead = 0, cw5 = 0, cw1 = 0;
  let costMicro = 0, billedTok = 0, freeTok = 0, toolUses = 0;
  const models = new Set();

  for (const { msg, rec } of byId.values()) {
    const content = msg.content;
    if (Array.isArray(content)) for (const c of content) if (c && c.type === 'tool_use') toolUses++;

    const u = msg.usage || rec.usage;
    if (!u) continue;
    const model = msg.model || rec.model;
    if (model) models.add(model);
    const p = priceFor(model);
    const i  = u.input_tokens || 0;
    const o  = u.output_tokens || 0;
    const cr = u.cache_read_input_tokens || 0;
    let c5 = 0, c1 = 0;
    if (u.cache_creation && typeof u.cache_creation === 'object') {
      c5 = u.cache_creation.ephemeral_5m_input_tokens || 0;
      c1 = u.cache_creation.ephemeral_1h_input_tokens || 0;
    } else {
      c5 = u.cache_creation_input_tokens || 0;
    }
    inTok += i; outTok += o; cacheRead += cr; cw5 += c5; cw1 += c1;
    const totTok = i + o + cr + c5 + c1;
    if (p.in === 0) freeTok += totTok; else billedTok += totTok;
    costMicro += i * p.in + o * p.out + cr * (p.in * MULT.read)
               + c5 * (p.in * MULT.write5m) + c1 * (p.in * MULT.write1h);
  }
  const messages = byId.size;
  if (runtime === 'unknown') runtime = 'cli';

  let durationMin = null;
  if (firstTs && lastTs) {
    const d = (new Date(lastTs) - new Date(firstTs)) / 60000;
    if (!isNaN(d)) durationMin = Math.round(d);
  }

  return {
    sessionFile: file.split(/[\\/]/).pop(),
    models: [...models],
    inputTokens: inTok, outputTokens: outTok,
    cacheReadTokens: cacheRead, cacheWrite5mTokens: cw5, cacheWrite1hTokens: cw1,
    billedTokens: billedTok, syntheticTokens: freeTok,
    costUsd: Math.round((costMicro / 1_000_000) * 100) / 100,
    messages, toolUses, compactions, durationMin, runtime,
  };
}

const files = process.argv.slice(2);
if (!files.length) { console.error('usage: node analyze-transcript.mjs <jsonl> [...]'); process.exit(1); }

const sessions = files.map(f => {
  try { return analyze(f); } catch (e) { return { sessionFile: f, error: String(e.message || e) }; }
});

if (sessions.length === 1) {
  console.log(JSON.stringify(sessions[0], null, 2));
} else {
  const ok = sessions.filter(s => !s.error);
  const totals = {
    sessions: sessions.length,
    costUsd: Math.round(ok.reduce((a, s) => a + (s.costUsd || 0), 0) * 100) / 100,
    inputTokens: ok.reduce((a, s) => a + (s.inputTokens || 0), 0),
    outputTokens: ok.reduce((a, s) => a + (s.outputTokens || 0), 0),
    cacheReadTokens: ok.reduce((a, s) => a + (s.cacheReadTokens || 0), 0),
    compactions: ok.reduce((a, s) => a + (s.compactions || 0), 0),
  };
  console.log(JSON.stringify({ sessions, totals }, null, 2));
}
