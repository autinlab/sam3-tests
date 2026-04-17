#!/usr/bin/env bash
set -euo pipefail

# Run from the sam3-tests repo root, inside the desired Python environment.
# This is intentionally sequential: the next run starts only after the previous
# python process exits.

CONFIG="${CONFIG:-configs/custom/custom_capsid_test.yaml}"
DATA_ROOT_BASE="${DATA_ROOT_BASE:-/mnt/forli/group/qtallon/sam/coco}"
LOG_ROOT="${LOG_ROOT:-/mnt/forli/group/qtallon/sam/logs}"

run_one() {
  local dataset="$1"
  local supercategory="$2"
  local log_name="$3"

  echo
  echo "== ${log_name} =="
  echo "data_root=${DATA_ROOT_BASE}/${dataset}"
  echo "supercategory=${supercategory}"
  echo "log_dir=${LOG_ROOT}/${log_name}"

  python sam3/train/train.py \
    -c "${CONFIG}" \
    --data-root "${DATA_ROOT_BASE}/${dataset}" \
    --experiment-log-dir "${LOG_ROOT}/${log_name}" \
    --supercategory "${supercategory}"
}

run_one "capsid_default_dozen_5neg" "fill" "capsid_default_fill_dozen_5neg_logs"
run_one "capsid_default_dozen_10neg" "fill" "capsid_default_fill_dozen_10neg_logs"
run_one "capsid_default_fifty_5neg" "fill" "capsid_default_fill_fifty_5neg_logs"
run_one "capsid_default_hundred_5neg" "fill" "capsid_default_fill_hundred_5neg_logs"

run_one "capsid_default_dozen_5neg" "semantic__semantic:shell" "capsid_default_shell_dozen_5neg_logs"
run_one "capsid_default_dozen_10neg" "semantic__semantic:shell" "capsid_default_shell_dozen_10neg_logs"
run_one "capsid_default_fifty_5neg" "semantic__semantic:shell" "capsid_default_shell_fifty_5neg_logs"
run_one "capsid_default_hundred_5neg" "semantic__semantic:shell" "capsid_default_shell_hundred_5neg_logs"
