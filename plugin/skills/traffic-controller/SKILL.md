---
name: traffic-controller
description: Launches the Traffic Controller. Cross-lab scan, proposes promotions/demotions. Gated on ≥3 active projects. Suggested by /dream when candidate patterns are detected.
when_to_use: |
  When the threshold of 3 active/completed projects is reached across the labs.
  Otherwise, it flags that there is little material. Invoked manually or via /cloture-session full.
  Also: suggested by `/dream` (auto mode) when the dreamer flags candidate patterns
  for formalization into learnings/rules (section suggestions_traffic_controller).
allowed-tools: Task, Bash, Read
argument-hint: "[scan all | scan lab=<name> | demotion]"
---

# /traffic-controller — Cross-lab scan + metrics logging

## Step 1 — Dispatch the traffic-controller agent

Use the Task tool to invoke the `traffic-controller` subagent with:

- `subagent_type`: "traffic-controller"
- `description`: "Cross-lab traffic scan"
- `prompt`: $ARGUMENTS

The Traffic Controller sub-agent will bootstrap its context (SOUL, USER, MEMORY, doctrine/03-consolidation, doctrine/09-traffic, registers, memory-sync-report) then run its threshold pre-check (≥3 projects) before scanning and proposing promotions/demotions.

Wait for its proposals appended in `traffic-journal.md`.

## Step 2 — Log event metrics (R009 Phase A)

After the sub-agent returns, append a JSON-line event into `metrics/events.jsonl` so `/metrics-report --focus=memory-consolidation` can compute `tc_invocation_count` and `tc_follow_rate`.

First detect whether this scan follows a recent `/dream` that flagged candidates (read the last 30 lines of `events.jsonl` to find the most recent `dream_run` with `signals_tc>0` within the last 7 days):

```bash
# Count promotions proposed in the session (extract from traffic-controller return, else 0)
PROMOTIONS_PROPOSED=<N>
PROMOTIONS_ACCEPTED=<K>  # number of user acceptances

# Detect if it follows a dream with signals
FOLLOWS_DREAM_TS=$(tail -n 100 "${CLAUDE_PLUGIN_ROOT}/metrics/events.jsonl" | grep '"kind":"dream_run"' | grep '"signals_tc"' | tail -n 1 | jq -r '.ts // empty')

# Append event
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "{\"ts\":\"$TS\",\"kind\":\"traffic_controller_run\",\"args\":\"$ARGUMENTS\",\"promotions_proposed\":$PROMOTIONS_PROPOSED,\"promotions_accepted\":$PROMOTIONS_ACCEPTED,\"follows_dream_ts\":\"$FOLLOWS_DREAM_TS\"}" >> "${CLAUDE_PLUGIN_ROOT}/metrics/events.jsonl"
```

If `$FOLLOWS_DREAM_TS` is non-empty AND within the last 7 days, ALSO append a `kind:"tc_follows_dream"` event to ease ratio computation:

```bash
echo "{\"ts\":\"$TS\",\"kind\":\"tc_follows_dream\",\"dream_ts\":\"$FOLLOWS_DREAM_TS\",\"tc_run_ts\":\"$TS\"}" >> "${CLAUDE_PLUGIN_ROOT}/metrics/events.jsonl"
```

## Step 3 — Synthesis

Come back with:
- The sub-agent's proposals (from `traffic-journal.md`)
- The status "follows_dream: yes (following dream of <date>) | no (autonomous scan)"
- Confirmation that the metrics event was logged
