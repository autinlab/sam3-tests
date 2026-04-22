#!/usr/bin/env bash
set -euo pipefail

# Launch maintained training runs sequentially from the sam3-tests repo root.
#
# Defaults target the current fill + shell reruns. Override the environment
# variables below to switch dataset families, labels, or run subsets.
#
# Examples:
#   ./bash/launch_batch_training.sh
#   DATASET_PREFIX=capsid_salk_noisy LOG_PREFIX=capsid_salk_noisy ./bash/launch_batch_training.sh
#   DATASET_SPECS='dozen_5neg,dozen_10neg' TARGETS='fill,shell' ./bash/launch_batch_training.sh

CONFIG="${CONFIG:-configs/custom/custom_capsid_test.yaml}"
DATA_ROOT_BASE="${DATA_ROOT_BASE:-/mnt/forli/group/qtallon/sam/coco}"
LOG_ROOT="${LOG_ROOT:-/mnt/forli/group/qtallon/sam/logs}"
DATASET_PREFIX="${DATASET_PREFIX:-capsid_default}"
LOG_PREFIX="${LOG_PREFIX:-${DATASET_PREFIX}}"
SHELL_LABEL="${SHELL_LABEL:-shell}"
SHELL_SUPERCATEGORY="${SHELL_SUPERCATEGORY:-semantic__semantic:${SHELL_LABEL}}"
DATASET_SPECS="${DATASET_SPECS:-dozen_5neg,dozen_10neg,fifty_5neg,hundred_5neg}"
TARGETS="${TARGETS:-fill,shell}"
PYTHON_BIN="${PYTHON_BIN:-python}"

usage() {
  cat <<EOF
Usage: ./bash/launch_batch_training.sh

Environment variables:
  CONFIG              Training config path
  DATA_ROOT_BASE      Base COCO root visible to sam3-tests
  LOG_ROOT            Base experiment log root
  DATASET_PREFIX      Dataset family prefix, e.g. capsid_salk_noisy
  LOG_PREFIX          Log name prefix, defaults to DATASET_PREFIX
  SHELL_LABEL         Single-class semantic label used in log names
  SHELL_SUPERCATEGORY Semantic supercategory passed to train.py
  DATASET_SPECS       Comma-separated dataset suffixes, e.g. dozen_5neg,fifty_5neg
  TARGETS             Comma-separated targets: fill,shell
  PYTHON_BIN          Python executable to use

Examples:
  DATASET_PREFIX=capsid_salk_noisy LOG_PREFIX=capsid_salk_noisy ./bash/launch_batch_training.sh
  DATASET_SPECS='dozen_5neg,dozen_10neg' TARGETS='shell' ./bash/launch_batch_training.sh
EOF
}

require_repo_root() {
  if [[ ! -f "sam3/train/train.py" ]]; then
    echo "run this script from the sam3-tests repo root" >&2
    exit 1
  fi
}

parse_csv() {
  local value="$1"
  local -n out_ref="$2"
  IFS=',' read -r -a out_ref <<< "${value}"
}

run_one() {
  local dataset="$1"
  local supercategory="$2"
  local log_name="$3"

  echo
  echo "== ${log_name} =="
  echo "data_root=${DATA_ROOT_BASE}/${dataset}"
  echo "supercategory=${supercategory}"
  echo "log_dir=${LOG_ROOT}/${log_name}"

  "${PYTHON_BIN}" sam3/train/train.py \
    -c "${CONFIG}" \
    --data-root "${DATA_ROOT_BASE}/${dataset}" \
    --experiment-log-dir "${LOG_ROOT}/${log_name}" \
    --supercategory "${supercategory}"
}

run_fill_series() {
  local -n specs_ref="$1"
  local suffix
  for suffix in "${specs_ref[@]}"; do
    run_one "${DATASET_PREFIX}_${suffix}" "fill" "${LOG_PREFIX}_fill_${suffix}_logs"
  done
}

run_shell_series() {
  local -n specs_ref="$1"
  local suffix
  for suffix in "${specs_ref[@]}"; do
    run_one "${DATASET_PREFIX}_${suffix}" "${SHELL_SUPERCATEGORY}" "${LOG_PREFIX}_${SHELL_LABEL}_${suffix}_logs"
  done
}

main() {
  local target
  local specs=()
  local targets=()

  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
  fi

  require_repo_root
  parse_csv "${DATASET_SPECS}" specs
  parse_csv "${TARGETS}" targets

  for target in "${targets[@]}"; do
    case "${target}" in
      fill)
        run_fill_series specs
        ;;
      shell)
        run_shell_series specs
        ;;
      *)
        echo "unsupported target: ${target}" >&2
        exit 1
        ;;
    esac
  done
}

main "$@"
