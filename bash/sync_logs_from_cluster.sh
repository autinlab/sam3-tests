#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Sync experiment folders from a cluster based on paths found in remote logs.

The script connects to a cluster, scans all files under --remote-dir,
extracts absolute paths that live under --remote-dir, infers run folders,
and then syncs missing files for those run folders to --local-dir.

Usage:
	bash/sync_logs_from_cluster.sh \
		[--remote user@cluster] \
		[--remote-dir /path/to/experiment/root] \
		[--local-dir /path/to/local/experiments] \
		[--port 22] \
		[--yes] \
		[--dry-run]

Options:
	--remote          SSH destination (default: qtallon@garibaldi)
	--remote-dir      Remote directory to scan for logs and sync from
										(default: /mnt/forli/group/qtallon/sam/logs)
	--local-dir       Local destination root for synced runs
										(default: /media/qtallon/BIGDATA/sam/logs)
	--port            SSH port (default: 22)
	--yes             Skip confirmation prompt
	--dry-run         Print what would be synced without copying
	-h, --help        Show help

Examples:
	# Preview what run directories would be pulled from cluster
	bash/sync_logs_from_cluster.sh --dry-run

	# Pull all runs referenced by submitit logs
	bash/sync_logs_from_cluster.sh --yes
EOF
}

REMOTE="qtallon@garibaldi"
REMOTE_DIR="/mnt/forli/group/qtallon/sam/logs"
LOCAL_DIR="/media/qtallon/BIGDATA/sam/logs"
PORT="22"
ASSUME_YES="false"
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
	case "$1" in
		--remote)
			REMOTE="${2:-}"
			shift 2
			;;
		--remote-dir)
			REMOTE_DIR="${2:-}"
			shift 2
			;;
		--local-dir)
			LOCAL_DIR="${2:-}"
			shift 2
			;;
		--port)
			PORT="${2:-}"
			shift 2
			;;
		--yes)
			ASSUME_YES="true"
			shift
			;;
		--dry-run)
			DRY_RUN="true"
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			echo "Unknown option: $1" >&2
			usage
			exit 1
			;;
	esac
done

REMOTE_DIR="${REMOTE_DIR%/}"
mkdir -p "$LOCAL_DIR"

if ! command -v ssh >/dev/null 2>&1; then
	echo "Error: ssh is not installed locally." >&2
	exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
	echo "Error: rsync is not installed locally." >&2
	exit 1
fi

SSH_SOCKET="$(mktemp -u /tmp/ssh-ctrl-XXXXXX)"
RUN_LIST="$(mktemp /tmp/sam-log-runs-XXXXXX)"
DRY_OUTPUT_FILE="$(mktemp /tmp/sam-log-rsync-dry-XXXXXX)"
SSH_MASTER_OPTS=(
	-o ControlMaster=yes
	-o ControlPath="$SSH_SOCKET"
	-o ControlPersist=60
	-p "$PORT"
)
SSH_REUSE_OPTS=(
	-o ControlMaster=auto
	-o ControlPath="$SSH_SOCKET"
	-p "$PORT"
)

ssh "${SSH_MASTER_OPTS[@]}" -fN "$REMOTE"
SSH_CMD=(ssh "${SSH_REUSE_OPTS[@]}")
RSYNC_SSH="ssh ${SSH_REUSE_OPTS[*]}"

cleanup() {
	ssh -o ControlPath="$SSH_SOCKET" -O exit "$REMOTE" 2>/dev/null || true
	rm -f "$RUN_LIST" "$DRY_OUTPUT_FILE"
}
trap cleanup EXIT

if ! "${SSH_CMD[@]}" "$REMOTE" "test -d '$REMOTE_DIR'"; then
	echo "Error: remote directory does not exist: $REMOTE_DIR" >&2
	exit 1
fi

echo "Scanning remote logs for experiment paths..."
RAW_PATHS="$(
	"${SSH_CMD[@]}" "$REMOTE" bash -s -- "$REMOTE_DIR" <<'EOF'
set -euo pipefail
base_dir="${1%/}"

find "$base_dir" -type f -print0 |
	xargs -0 grep -hEo '(/[^[:space:]"'"'"'<>]+)+' 2>/dev/null |
	awk -v pfx="$base_dir/" '
		{
			path=$0
			gsub(/[),.;:]+$/, "", path)
			if (index(path, pfx) == 1) {
				print path
			}
		}
	' |
	sort -u
EOF
)"

if [[ -z "$RAW_PATHS" ]]; then
	echo "No paths under $REMOTE_DIR were found while scanning files in $REMOTE_DIR."
	exit 0
fi

RUN_DIRS="$(
	printf '%s\n' "$RAW_PATHS" |
		awk -v base="$REMOTE_DIR/" '
			{
				rel=$0
				sub("^" base, "", rel)
				split(rel, parts, "/")
				if (parts[1] != "") {
					print parts[1]
				}
			}
		' |
		sort -u
)"

if [[ -z "$RUN_DIRS" ]]; then
	echo "No run directories could be inferred from extracted paths."
	exit 1
fi

printf '%s\n' "$RUN_DIRS" | sed 's|$|/|' > "$RUN_LIST"

echo "Checking which referenced run directories have missing local files..."
rsync -a -r --ignore-existing --itemize-changes --human-readable --dry-run \
	--out-format='%i %n%L' \
	--files-from="$RUN_LIST" \
	-e "$RSYNC_SSH" \
	"$REMOTE:$REMOTE_DIR/" "$LOCAL_DIR/" > "$DRY_OUTPUT_FILE"

AFFECTED_RUN_DIRS="$(
	awk '
		$1 ~ /\+/ || $1 ~ /^[>chLS]/ {
			path=$2
			sub(/\/.*/, "", path)
			if (path != "") {
				print path
			}
		}
	' "$DRY_OUTPUT_FILE" |
		sort -u
)"

if [[ "$DRY_RUN" == "true" ]]; then
	if [[ -n "$AFFECTED_RUN_DIRS" ]]; then
		echo "Directories that would be affected:"
		printf '%s\n' "$AFFECTED_RUN_DIRS"
	else
		echo "Directories that would be affected: none"
	fi

	echo "Dry run complete."
	exit 0
fi

if [[ -z "$AFFECTED_RUN_DIRS" ]]; then
	echo "All referenced run directories already have their remote files locally."
	exit 0
fi

printf '%s\n' "$AFFECTED_RUN_DIRS" | sed 's|$|/|' > "$RUN_LIST"

echo "Run directories with missing local files:"
printf '%s\n' "$AFFECTED_RUN_DIRS"

if [[ "$ASSUME_YES" != "true" ]]; then
	read -r -p "Proceed with syncing these directories to $LOCAL_DIR? [y/N] " reply
	if [[ ! "$reply" =~ ^[Yy]$ ]]; then
		echo "Cancelled."
		exit 0
	fi
fi

rsync -a -r --ignore-existing --itemize-changes --human-readable \
	--files-from="$RUN_LIST" \
	-e "$RSYNC_SSH" \
	"$REMOTE:$REMOTE_DIR/" "$LOCAL_DIR/"

echo "Sync complete."
