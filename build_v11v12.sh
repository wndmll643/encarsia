#!/usr/bin/env bash
# Build the encarsia-v11v12 Docker image. Must be invoked with the repo
# root as the build context so the COPY paths inside Dockerfile.v11v12
# resolve (encarsia-yosys/..., encarsia-meta/..., hierfuzz/...).
#
# Usage:
#     ./encarsia/build_v11v12.sh                 # builds tag encarsia-v11v12
#     IMAGE_TAG=my-tag ./encarsia/build_v11v12.sh
#
# Takes ~15-30 min the first time (Yosys rebuild dominates). Subsequent
# builds reuse cached layers and only re-run the Yosys make if
# instrument_hierfuzz.cc changed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

IMAGE_TAG="${IMAGE_TAG:-encarsia-v11v12}"
DOCKERFILE="$SCRIPT_DIR/Dockerfile.v11v12"

if [[ ! -f "$DOCKERFILE" ]]; then
  echo "ERROR: $DOCKERFILE not found." >&2
  exit 1
fi

# Verify the required source files exist before kicking off a 30-min build.
for f in \
  encarsia-yosys/passes/hierfuzz/instrument_hierfuzz.cc \
  encarsia-meta/host.py \
  encarsia-meta/multi_run_ttb.py \
  encarsia-meta/run_experiments_v11v12.sh \
  encarsia-meta/fuzzers/hierfuzz_v11a_dut.py \
  encarsia-meta/fuzzers/hierfuzz_v11b_dut.py \
  encarsia-meta/fuzzers/hierfuzz_v12a_dut.py \
  encarsia-meta/fuzzers/hierfuzz_v12b_dut.py \
  hierfuzz/rtl_host_total.py \
  hierfuzz/fuzzer.py; do
  if [[ ! -f "$REPO_ROOT/$f" ]]; then
    echo "ERROR: required source file missing: $REPO_ROOT/$f" >&2
    echo "       (did you forget to 'git pull' in encarsia-meta or encarsia-yosys?)" >&2
    exit 1
  fi
done

echo "Building Docker image $IMAGE_TAG ..."
echo "  Dockerfile:    $DOCKERFILE"
echo "  Build context: $REPO_ROOT"

# Pull the base image first so we get a clean error if it's missing rather
# than 30 min into the build.
docker pull ethcomsec/encarsia-artifacts:latest

docker build \
  -t "$IMAGE_TAG" \
  -f "$DOCKERFILE" \
  "$REPO_ROOT"

echo
echo "Built image: $IMAGE_TAG"
echo "Next: ./encarsia/run_v11v12.sh -d /path/to/EnCorpus -H rocket boom -p 40 -N 10"
