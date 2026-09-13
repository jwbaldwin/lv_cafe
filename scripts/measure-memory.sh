#!/usr/bin/env bash
set -euo pipefail
set +x
: "${CANDIDATE_IMAGE:?Set the exact candidate image}"
: "${MEMORY_BENCHMARK_SERVER:?Set the existing Hetzner address}"
: "${KAMAL_REGISTRY_USERNAME:?Set registry username}"
: "${KAMAL_REGISTRY_PASSWORD:?Set registry token}"
case "$CANDIDATE_IMAGE" in ghcr.io/jwbaldwin/vibes:*) ;; *) exit 1 ;; esac
repo=$(cd "$(dirname "$0")/.." && pwd)
output=${MEMORY_BENCHMARK_OUTPUT:-artifacts/memory}
mkdir -p "$output"
local_work=$(mktemp -d)
chmod 700 "$local_work"
server="deploy@$MEMORY_BENCHMARK_SERVER"
remote_work=''
cleanup() {
  rm -rf "$local_work"
  if [[ "$remote_work" == /tmp/vibes-memory.* ]]; then
    scp -q -r "$server:$remote_work/results/." "$output/" || true
    ssh "$server" "rm -rf '$remote_work'" || true
  fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP
remote_work=$(ssh "$server" 'umask 077; mktemp -d /tmp/vibes-memory.XXXXXXXX')
[[ "$remote_work" =~ ^/tmp/vibes-memory\.[a-zA-Z0-9]+$ ]]
python3 - "$local_work/config.env" <<'PY'
import os, shlex, sys
with open(sys.argv[1], 'w') as f:
    for name in ('CANDIDATE_IMAGE', 'KAMAL_REGISTRY_USERNAME', 'KAMAL_REGISTRY_PASSWORD'):
        f.write(name + '=' + shlex.quote(os.environ[name]) + '\n')
os.chmod(sys.argv[1], 0o600)
PY
scp -q "$local_work/config.env" "$repo/scripts/measure-memory-remote.sh" "$repo/scripts/measure-memory-client.py" "$server:$remote_work/"
ssh "$server" "timeout --signal=TERM 600 bash '$remote_work/measure-memory-remote.sh' '$remote_work'" | tee "$output/run.log"
