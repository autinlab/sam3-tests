# Repo audit — 2026-08-28

Written by a `/root-route` crossing from `scripps-rr`, which read **every file in this repo** —
syntax, imports, configs, markdown links, and every path referenced by anything. This is the record
of what was checked so the next person does not repeat it.

## Verdict: passes, with upstream extras absent by design

## What was broken, and fixed

`README.md` told you to `conda activate sam3`. **There is no `sam3` environment and `conda` is not
installed on this machine at all.** The working environment is `sam`, verified by importing the
vendored package: `micromamba run -n sam python3 -c "import sam3"` resolves to this repo's own
`sam3/__init__.py`. `sam-dev` does **not** work — it is missing `decord`. Corrected, with the
upstream from-scratch instructions kept for a fresh machine.

## What was checked

- No syntax errors in 155 Python files; no invalid YAML in 39 configs; no broken markdown links —
  both `assets/model_diagram.png` and `assets/sa_co_dataset.jpg` exist.
- **Unresolved imports are confined to upstream evaluation scripts for datasets this lab does not
  use**: `scripts/eval/silver/` (fathomnet, av) and `scripts/eval/veval/` (YT1B), plus nine
  optional extras inside the vendored `sam3/` tree (detectron2, torchcodec, flash_attn_interface,
  tidecv, panopticapi, openai, tensordict, cc_torch, torch_generic_nms). Nothing capsid-related is
  affected.
- `/mnt/forli/group/qtallon/...` paths are garibaldi's and correctly absent here.

## The unresolved imports are unreachable, not a gap

Checked 2026-08-28 rather than assumed: `scripts/eval/silver/` and `scripts/eval/veval/` both arrived
with upstream's `a13e358 Initial commit`, and **no lab entry point references them.** The only two
things run here are `bash/launch_batch_training.sh` and `bash/sync_logs_from_cluster.sh`; both pass
`bash -n` and neither touches `scripts/eval/`. So `av`, `fathomnet`, `saco_yt1b_frame_prep_util` and
the sibling-module `utils` imports are dead weight from the vendored tree, not broken capsid code.

## Left open

No test suite exists. Recorded as having none rather than skipped silently.
