"""Tests for this repo's own surface — not for the vendored `sam3/` tree.

Added 2026-08-28. This repo had no tests. Almost everything under `sam3/` is upstream
(facebookresearch/sam3) and testing it here would only duplicate their suite; what *is* ours is two
bash scripts, one training config, and the assumption that both agree with `sam-capsids`. That last
one is a cross-repo contract nothing else checks, and it is the thing most likely to drift.

    micromamba run -n sam python3 -m pytest tests/

Note the environment is `sam`, not `sam-dev` (which lacks `decord`) and not `sam3` (which does not
exist — the README said `conda activate sam3` until 2026-08-28).
"""
import re
import subprocess
import sys
from pathlib import Path

import pytest
import yaml

REPO = Path(__file__).resolve().parents[1]
SCRIPTS = [REPO / "bash/launch_batch_training.sh", REPO / "bash/sync_logs_from_cluster.sh"]
CONFIG = REPO / "sam3/train/configs/custom/custom_capsid_test.yaml"
SAM_CAPSIDS = Path.home() / "Documents/code/sam-capsids"


# --- the two scripts that are ours ---------------------------------------------------------------

@pytest.mark.parametrize("script", SCRIPTS, ids=lambda p: p.name)
def test_script_exists_and_parses(script):
    assert script.exists(), f"missing: {script}"
    r = subprocess.run(["bash", "-n", str(script)], capture_output=True, text=True)
    assert r.returncode == 0, f"syntax error: {r.stderr}"


@pytest.mark.parametrize("script", SCRIPTS, ids=lambda p: p.name)
def test_script_help_exits_cleanly_and_says_something(script):
    """`--help` must not require the cluster to be reachable."""
    r = subprocess.run(["bash", str(script), "--help"], capture_output=True, text=True,
                       cwd=REPO, timeout=60)
    assert r.returncode == 0, f"--help exited {r.returncode}: {r.stderr[:300]}"
    out = r.stdout + r.stderr
    assert len(out.strip()) > 50, "--help printed almost nothing"
    assert "sage" in out or "USAGE" in out, "--help should show usage"


def test_sync_logs_pulls_to_the_recorded_bigdata_location():
    """`LOCAL_DIR` must stay `/media/qtallon/BIGDATA/sam/logs`.

    That path is what `scripps-rr`'s `GOVERNANCE/places.md` records as the home of the 22 SAM
    fine-tuning runs, and what `sam-capsids/configs/sam_training_runs.yaml` names as its
    `sam_log_root`. Three files, one path; this pins the one that would silently pull elsewhere.
    """
    text = (REPO / "bash/sync_logs_from_cluster.sh").read_text()
    assert 'LOCAL_DIR="/media/qtallon/BIGDATA/sam/logs"' in text
    assert 'REMOTE_DIR="/mnt/forli/group/qtallon/sam/logs"' in text


# --- the training config -------------------------------------------------------------------------

def test_config_parses_and_has_the_blocks_the_trainer_needs():
    d = yaml.safe_load(CONFIG.read_text())
    for key in ("defaults", "paths", "custom_train", "trainer", "launcher"):
        assert key in d, f"missing top-level block: {key}"


def test_config_targets_the_cluster_not_a_local_path():
    """Training runs on garibaldi. A local `data_root` here means someone edited it to debug and
    left it, which is exactly what had happened to the copy in the `sam3` clone before 2026-08-28."""
    text = CONFIG.read_text()
    local = re.findall(r"(?:data_root|experiment_log_dir):\s*(/home/\S+)", text)
    assert not local, f"config points at local paths instead of the cluster: {local}"


# --- the cross-repo contract nothing else checks --------------------------------------------------

@pytest.mark.skipif(not SAM_CAPSIDS.exists(), reason="sam-capsids not present on this machine")
def test_dataset_names_match_sam_capsids_export_ids():
    """`launch_batch_training.sh` builds dataset names as `<DATASET_PREFIX>_<spec>`. Every one it can
    build must exist as a `dataset_exports` id in `sam-capsids`, or a batch launch trains on a
    dataset that was never exported.
    """
    script = (REPO / "bash/launch_batch_training.sh").read_text()
    prefix = re.search(r'DATASET_PREFIX="\$\{DATASET_PREFIX:-([^}"]+)\}"', script)
    specs = re.search(r'DATASET_SPECS="\$\{DATASET_SPECS:-([^}"]+)\}"', script)
    assert prefix and specs, "could not read the script's defaults"
    built = {f"{prefix.group(1)}_{s.strip()}" for s in specs.group(1).split(",")}

    manifest = yaml.safe_load((SAM_CAPSIDS / "configs/sam_training_runs.yaml").read_text())
    known = {e["id"] for e in manifest["dataset_exports"]}
    missing = built - known
    assert not missing, (
        f"launch_batch_training.sh would train on datasets sam-capsids never exported: "
        f"{sorted(missing)}")


@pytest.mark.skipif(not SAM_CAPSIDS.exists(), reason="sam-capsids not present on this machine")
def test_log_root_agrees_with_sam_capsids_manifest():
    manifest = yaml.safe_load((SAM_CAPSIDS / "configs/sam_training_runs.yaml").read_text())
    assert manifest["defaults"]["sam_log_root"] == "/media/qtallon/BIGDATA/sam/logs"


# --- the vendored package must still import ------------------------------------------------------

def test_vendored_sam3_imports_from_this_repo():
    """`import sam3` must resolve to this repo's copy, not a site-packages one."""
    r = subprocess.run([sys.executable, "-c", "import sam3; print(sam3.__file__)"],
                       capture_output=True, text=True, cwd=REPO, timeout=300)
    assert r.returncode == 0, r.stderr[-500:]
    assert str(REPO) in r.stdout, f"sam3 resolved outside this repo: {r.stdout.strip()}"
