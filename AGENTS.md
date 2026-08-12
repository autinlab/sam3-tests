# AGENTS

## Purpose

This repo is a lightweight sandbox for upstream SAM3 experimentation and feasibility checks.

## Control plane

Planning for this work lives in RootRoute at `/home/qtallon/Documents/code/scripps-root-route`.

- Start from an item in that repo's `STATE/now.md`, or from a local need — and if it is a
  local need, say so there.
- Local rules win here. That repo decides what to work on and what must not happen;
  this repo decides how it gets done.
- When you finish, or get blocked, or learn something that changes the plan, write it back
  into that item. Nothing else needs to go back.
- Do not copy plans, priorities, or decisions into this repo. Point at them.

Installed: 2026-08-12

## In Scope

- exploratory changes to upstream SAM3 behavior
- capsid-specific feasibility experiments
- experiments that may later be promoted into maintained repos

## Out Of Scope

- long-term maintained workflow code that belongs in `sam-capsids`
- benchmark ownership that belongs in `capsid-learning`

## Local Constraints

- treat this repo as an experimental fork
- keep promotion decisions explicit
- do not assume exploratory changes belong in maintained workflows

## Spec Location

Local specs live in `docs/specs/`.

## Standard Workflow

1. Create `docs/specs/<feature-slug>/feature.md` for non-trivial experiments.
2. Write `plan.md` and `tasks.md`.
3. Implement in the repo.
4. Record whether the result should be promoted, discarded, or kept as sandbox-only.
5. Write the meaningful outcome back into the RootRoute item.

## Definition Of Done

Work is done when:

- the experiment has a clear result
- the promotion decision is explicit
- any cross-repo routing consequence is written back to the RootRoute item

## Reporting Back

Write back to the RootRoute item only at meaningful checkpoints:

- the experiment changes repo routing → the item's `Next action`
- a blocker appeared or cleared → the item's `Status:` and `Next action`
- branch / PR exists → the item's `Handoff:`
- a result worth promoting exists → the item's `Next action`

Any of these advances the item's `Updated:`.
