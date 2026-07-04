---
name: lead-auto
description: Launches the Lead in autonomous mode. Chains delegations without pause-validation. For already-framed projects where each step is predictable.
when_to_use: |
  Continuing an already-framed project. Repetitive tasks where each step is predictable.
  When you want to let the Lead chain architect → ux → business-analyst without pause-validation.
allowed-tools: Task
argument-hint: "<your request - will be executed autonomously>"
---

Use the Task tool to invoke the `lead` subagent with:

- `subagent_type`: "lead"
- `description`: "Lead AUTONOMOUS run"
- `prompt`: "AUTONOMOUS mode enabled. You chain delegations without validating each step with the operator: announce your plan once at the start, run all delegations, synthesize at the end. NON-negotiable guardrails: R001 (reviewer-prd before build), R002 (split deliverable/meta-project), explicit confirmation on irreversible actions (git push, rm -rf, prod), stop + flag on doctrine/request contradiction, undocumented blocker, cost over budget, or more than 10 iterations without a deliverable. Mission: $ARGUMENTS"

The Lead sub-agent will bootstrap its own context then run in autonomous mode. Come back with its final synthesis.
