---
name: harness-story
description: Use when intake classified work as normal or high-risk and it needs a tracked story with a test matrix before implementation — creates the story record, defines its verification command and proof matrix, and hands execution to the implementation workflow.
---

# Harness Story

## Overview

A story is the single active unit of work. It carries a behavior contract, a **verification command**, and a four-axis **proof matrix** (unit / integration / e2e / platform). The harness — not you — owns whether a story is proven.

## Output shape (recipe)

Produce, in this order:

1. **Story record** with an id (`US-NNN`), title, lane, and — required — a mechanical verify command:

   ```bash
   .harness/harness story add --id US-001 --title "Login rate limiting" --lane high-risk \
     --verify "npm test -- rate-limit" [--contract docs/product/auth.md]
   ```

2. **One active feature per session.** Mark it in progress when you start:

   ```bash
   .harness/harness story update --id US-001 --status in_progress
   ```

   Do not open a second story while this one is unproven.

3. **Proof matrix**, recorded with numeric booleans as each axis is genuinely covered (never `yes`/`no`):

   ```bash
   .harness/harness story update --id US-001 --unit 1 --integration 1 --e2e 0 --platform 0
   ```

   Set an axis to `1` only after that test class actually exists and passes — proof is recorded by `claude-harness:harness-verification-before-completion`, not aspirationally here.

## Execution: defer to superpowers when available

claude-harness tracks the story; it does not reimplement engineering discipline. For the actual build:

- **REQUIRED SUB-SKILL (when installed):** `superpowers:subagent-driven-development` (or `superpowers:executing-plans`) to implement task-by-task with TDD and review.
- For **high-risk** stories, design first with `superpowers:brainstorming` → `superpowers:writing-plans`, then execute.
- Subagents follow `superpowers:test-driven-development`.

If superpowers is not installed, implement directly but still follow TDD and keep the story's status/proof current in the CLI.

## Status values

`planned → in_progress → implemented → changed → retired` (CLI-enforced).

## Terminal state

When the work is believed complete → `claude-harness:harness-verification-before-completion` (it runs the verify command and records proof), then `claude-harness:harness-trace-and-friction`.

## Red Flags

- Adding a story with no `--verify` command — there is then nothing to gate on.
- Setting `--unit 1` etc. before the test class exists and passes.
- Starting a second `in_progress` story before the current one is proven.
- Hand-editing proof in the DB instead of letting verification record it.
