# AGENTS

## Purpose

This repo is a lightweight sandbox for upstream SAM3 experimentation and feasibility checks.

## In Scope

- exploratory changes to upstream SAM3 behavior
- capsid-specific feasibility experiments
- experiments that may later be promoted into maintained repos

## Out Of Scope

- long-term maintained workflow code that belongs in `sam-capsids`
- hub-level planning
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
5. Sync meaningful outcome back to the hub.

## Definition Of Done

Work is done when:

- the experiment has a clear result
- the promotion decision is explicit
- any hub-level routing consequence is synced back

## Hub Sync Rule

Sync back when the experiment changes repo routing, creates a blocker, or produces a result worth promoting.
