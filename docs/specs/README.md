# Specs

Use this directory for non-trivial sandbox experiments that need more than ad hoc notes.

## When To Create A Spec

Create a spec when the experiment:

- touches multiple files
- needs explicit validation
- may lead to promotion into another repo

## Naming

Use:

```text
docs/specs/<feature-slug>/
```

## Files

- `feature.md`: local experimental goal and constraints
- `plan.md`: implementation and validation path
- `tasks.md`: execution checklist

## Validation

Validation should end in a clear disposition:

- promote
- keep sandbox-only
- discard

## Hub Relationship

The hub decides when a sandbox result matters.
This repo only supports the experimental execution.
