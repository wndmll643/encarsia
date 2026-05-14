#!/usr/bin/env bash
# Run the v11/v12 TTB experiment inside the encarsia-v11v12 Docker image.
#
# - Mounts your EnCorpus directory into /encarsia-meta/out/EnCorpus
# - Mounts a host results directory into /encarsia-meta/out/ttb_results so
#   results persist across container runs and can be inspected from the host
# - Forwards CLI flags to run_experiments_v11v12.sh inside the container
#
# Usage:
#     ./encarsia/run_v11v12.sh -d <host_EnCorpus_dir> [-r <host_results_dir>] \
#         [-H rocket boom] [-p N] [-N RUNS] [--phase0-only|--aggregate-only|--skip-phase0]
#
# Example:
#     ./encarsia/run_v11v12.sh \
#         -d /home/sinu/encarsia/out/EnCorpus \
#         -r /home/sinu/ttb_results_v11v12 \
#         -H rocket boom -p 40 -N 10
#
# Tip — preflight only (compile every fuzzer for every bug, no fuzz yet):
#     ./encarsia/run_v11v12.sh -d /path/to/EnCorpus --phase0-only
#
# Tip — re-aggregate an existing results dir:
#     ./encarsia/run_v11v12.sh -d /path/to/EnCorpus -r /existing/results --aggregate-only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

IMAGE_TAG="${IMAGE_TAG:-encarsia-v11v12}"
CONTAINER_NAME="${CONTAINER_NAME:-encarsia_v11v12_run}"

# Defaults if user doesn't pass -r
DEFAULT_RESULTS_HOST_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/out/ttb_results_v11v12"

HOST_ENCORPUS=""
HOST_RESULTS="$DEFAULT_RESULTS_HOST_DIR"
FORWARDED_ARGS=()

# Pop -d / -r out and keep the rest for the inner script.
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--directory)  HOST_ENCORPUS="$2"; shift 2 ;;
    -r|--results)    HOST_RESULTS="$2";  shift 2 ;;
    -h|--help)       sed -n '1,30p' "$0"; exit 0 ;;
    *)               FORWARDED_ARGS+=("$1"); shift ;;
  esac
done

if [[ -z "$HOST_ENCORPUS" ]]; then
  echo "ERROR: -d <host_EnCorpus_dir> is required." >&2
  echo "       (the directory containing rocket/{driver,multiplexer} and boom/{driver,multiplexer})" >&2
  exit 1
fi

if [[ ! -d "$HOST_ENCORPUS" ]]; then
  echo "ERROR: EnCorpus dir not found on host: $HOST_ENCORPUS" >&2
  exit 1
fi

# Verify the image is built.
if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
  echo "ERROR: Docker image '$IMAGE_TAG' not built yet." >&2
  echo "       Run: $SCRIPT_DIR/build_v11v12.sh" >&2
  exit 1
fi

mkdir -p "$HOST_RESULTS"

# Resolve to absolute paths because docker -v wants absolute.
HOST_ENCORPUS_ABS="$(cd "$HOST_ENCORPUS" && pwd)"
HOST_RESULTS_ABS="$(cd "$HOST_RESULTS" && pwd)"

echo "encarsia-v11v12 image: $IMAGE_TAG"
echo "EnCorpus on host:      $HOST_ENCORPUS_ABS  →  /encarsia-meta/out/EnCorpus"
echo "Results on host:       $HOST_RESULTS_ABS  →  /encarsia-meta/out/ttb_results"
echo "Forwarded to inner:    ${FORWARDED_ARGS[*]:-(none)}"
echo

# Run interactively, with the experiment script as the entrypoint. --rm so
# the run-instance container is cleaned up; data persists via the volume mounts.
docker run \
  --rm -it \
  --name "$CONTAINER_NAME" \
  -v "$HOST_ENCORPUS_ABS":/encarsia-meta/out/EnCorpus \
  -v "$HOST_RESULTS_ABS":/encarsia-meta/out/ttb_results \
  "$IMAGE_TAG" \
  ./run_experiments_v11v12.sh \
    -d /encarsia-meta/out/EnCorpus \
    --results-dir /encarsia-meta/out/ttb_results \
    "${FORWARDED_ARGS[@]}"

echo
echo "Results on host: $HOST_RESULTS_ABS"
