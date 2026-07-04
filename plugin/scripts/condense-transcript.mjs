#!/usr/bin/env node
// condense-transcript.mjs
//
// Condenses a Claude Code .jsonl transcript down to the conversational signal
// only: user messages (excluding tool_result), assistant text + thinking, and
// one line per tool_use (name + short arg). tool_result blocks are dropped
// (large volume, little "why/plan" signal). Typically 10-15x smaller.
//
// Useful as a pre-processing step before transcript recovery: condense first
// (free, deterministic), then a workflow reads the condensed file to reconstruct
// scoping memory. Avoids loading 10+ MB of jsonl into context.
//
// Usage: node condense-transcript.mjs <input.jsonl> <output.md>

import fs from "node:fs";

const [, , inPath, outPath] = process.argv;
if (!inPath || !outPath) {
  console.error("usage: node condense-transcript.mjs <in.jsonl> <out.md>");
  process.exit(1);
}

const MAX_BLOCK = 6000; // truncate an over-long text/thinking block
const MAX_TOOLARG = 160;

function clip(s, n) {
  s = String(s ?? "");
  return s.length > n ? s.slice(0, n) + " ...[truncated]" : s;
}

const lines = fs.readFileSync(inPath, "utf8").split(/\r?\n/).filter(Boolean);
const out = [];
let turn = 0;

for (const line of lines) {
  let ev;
  try {
    ev = JSON.parse(line);
  } catch {
    continue;
  }
  const type = ev.type;

  // Compaction / summary markers: valuable for understanding context loss
  if (type === "summary" && ev.summary) {
    out.push(`\n=== [COMPACTION / SUMMARY] ===\n${clip(ev.summary, MAX_BLOCK)}\n`);
    continue;
  }

  const msg = ev.message;
  if (!msg) continue;
  const role = msg.role || type;
  const content = msg.content;

  if (role === "user") {
    let text = "";
    if (typeof content === "string") {
      text = content;
    } else if (Array.isArray(content)) {
      const parts = content
        .filter((b) => b && b.type === "text")
        .map((b) => b.text);
      text = parts.join("\n");
      const hadToolResult = content.some((b) => b && b.type === "tool_result");
      if (!text && hadToolResult) continue; // turn is 100% tool_result -> skip
    }
    text = text.trim();
    if (!text) continue;
    turn++;
    out.push(`\n----- [USER - turn ${turn}] -----\n${clip(text, MAX_BLOCK)}`);
  } else if (role === "assistant") {
    if (!Array.isArray(content)) continue;
    const chunks = [];
    for (const b of content) {
      if (!b) continue;
      if (b.type === "text" && b.text?.trim()) {
        chunks.push(clip(b.text.trim(), MAX_BLOCK));
      } else if (b.type === "thinking" && b.thinking?.trim()) {
        chunks.push(`[THINKING] ${clip(b.thinking.trim(), MAX_BLOCK)}`);
      } else if (b.type === "tool_use") {
        const arg =
          b.input?.command ||
          b.input?.file_path ||
          b.input?.pattern ||
          b.input?.prompt ||
          b.input?.description ||
          "";
        chunks.push(`  - [tool:${b.name}] ${clip(arg, MAX_TOOLARG)}`);
      }
    }
    const text = chunks.join("\n");
    if (text.trim()) {
      out.push(`\n[ASSISTANT]\n${text}`);
    }
  }
}

const header = `# Condensed transcript — ${inPath}\n# Events: ${lines.length} -> user turns: ${turn}\n# Generated for memory extraction (tool_results dropped)\n`;
fs.writeFileSync(outPath, header + out.join("\n"), "utf8");
const sz = fs.statSync(outPath).size;
console.log(`OK -> ${outPath}`);
console.log(`Condensed size: ${(sz / 1024).toFixed(0)} KB (vs source ${(fs.statSync(inPath).size / 1024 / 1024).toFixed(1)} MB)`);
console.log(`User turns: ${turn}`);
