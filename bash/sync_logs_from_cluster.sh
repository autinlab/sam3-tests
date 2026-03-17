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
SSH_MASTER_OPTS=(
	-o ControlMaster=yes
	-o ControlPath="$SSH_SOCKET"
	-o ControlPersist=60
	-p "$PORT"
)
SSH_REUSE_OPTS=(
	-o ControlMaster=no
	-o ControlPath="$SSH_SOCKET"
	-p "$PORT"
)

ssh "${SSH_MASTER_OPTS[@]}" -fN "$REMOTE"
SSH_CMD=(ssh "${SSH_REUSE_OPTS[@]}")
RSYNC_SSH="ssh ${SSH_REUSE_OPTS[*]}"

trap 'ssh -o ControlPath="$SSH_SOCKET" -O exit "$REMOTE" 2>/dev/null || true' EXIT

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

if [[ "$DRY_RUN" == "true" ]]; then
	AFFECTED_RUN_DIRS=""
	while IFS= read -r run_dir; do
		[[ -z "$run_dir" ]] && continue
		src="$REMOTE_DIR/$run_dir/"
		dst="$LOCAL_DIR/$run_dir/"
		DRY_OUTPUT="$(rsync -a --ignore-existing --itemize-changes --human-readable --dry-run -e "$RSYNC_SSH" "$REMOTE:$src" "$dst")"
		if printf '%s\n' "$DRY_OUTPUT" | grep -Eq '^[^[:space:]]*\+{9}[[:space:]]|^created directory[[:space:]]'; then
			AFFECTED_RUN_DIRS+="$run_dir"$'\n'
		fi
	done <<< "$RUN_DIRS"

	AFFECTED_RUN_DIRS="$(printf '%s' "$AFFECTED_RUN_DIRS" | sed '/^$/d' | sort -u)"

	if [[ -n "$AFFECTED_RUN_DIRS" ]]; then
		echo "Directories that would be affected:"
		printf '%s\n' "$AFFECTED_RUN_DIRS"
	else
		echo "Directories that would be affected: none"
	fi

	echo "Dry run complete."
	exit 0
fi

echo "Run directories referenced by logs:"
printf '%s\n' "$RUN_DIRS"

if [[ "$ASSUME_YES" != "true" ]]; then
	read -r -p "Proceed with syncing these directories to $LOCAL_DIR? [y/N] " reply
	if [[ ! "$reply" =~ ^[Yy]$ ]]; then
		echo "Cancelled."
		exit 0
	fi
fi

while IFS= read -r run_dir; do
	[[ -z "$run_dir" ]] && continue
	src="$REMOTE_DIR/$run_dir/"
	dst="$LOCAL_DIR/$run_dir/"
	echo "Syncing: $run_dir"
	rsync -a --ignore-existing --itemize-changes --human-readable -e "$RSYNC_SSH" "$REMOTE:$src" "$dst"
done <<< "$RUN_DIRS"

echo "Sync complete."
