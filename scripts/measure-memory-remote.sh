#!/usr/bin/env bash
# Invoked only by measure-memory.sh with its task-owned temporary directory.
set -euo pipefail
set +x
work=$1
[[ "$work" =~ ^/tmp/vibes-memory\.[a-zA-Z0-9]+$ ]]
source "$work/config.env"
mkdir -p "$work/results" "$work/certs" "$work/docker"
chmod 700 "$work/docker"
export DOCKER_CONFIG="$work/docker"
prefix=${work##*/}
network=$prefix
pg="$prefix-pg"
app_a="$prefix-a"
app_b="$prefix-b"
client="$prefix-client"
release_container="$prefix-release"
postgres=postgres:18.1-alpine
python=python:3.13-slim
sampler=''
cleanup() {
  trap - EXIT INT TERM HUP
  if [[ -n "$sampler" ]]; then kill "$sampler" 2>/dev/null || true; wait "$sampler" 2>/dev/null || true; fi
  for container in "$app_a" "$app_b" "$pg"; do docker logs "$container" > "$work/results/$container.log" 2>&1 || true; done
  docker rm -f -v "$client" "$release_container" "$app_a" "$app_b" "$pg" >/dev/null 2>&1 || true
  docker network rm "$network" >/dev/null 2>&1 || true
  rm -rf "$work/docker" "$work/config.env" "$work/app.env" "$work/certs"
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP
exec 9>/tmp/vibes-memory.lock
flock -n 9 || { echo 'Another memory measurement is running'; exit 1; }
available=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
[[ "$available" -ge 800000 ]] || { echo 'Insufficient memory headroom for isolated measurement'; exit 1; }
[[ $(df -Pk /var/lib/docker | awk 'NR==2 {print $4}') -ge 2500000 ]] || { echo 'Insufficient disk headroom'; exit 1; }
docker ps --filter label=service=vibes --format '{{json .}}' > "$work/results/production-before.jsonl"
docker stats --no-stream --format '{{json .}}' > "$work/results/baseline-stats.jsonl"
cp /proc/meminfo "$work/results/baseline-meminfo.txt"
printf '%s' "$KAMAL_REGISTRY_PASSWORD" | docker login ghcr.io -u "$KAMAL_REGISTRY_USERNAME" --password-stdin >/dev/null
unset KAMAL_REGISTRY_PASSWORD
for image in "$CANDIDATE_IMAGE" "$postgres" "$python"; do docker pull "$image" >/dev/null; done
docker image inspect "$CANDIDATE_IMAGE" --format '{{json .}}' > "$work/results/candidate-image.json"
# A task-local CA preserves the release's normal verified TLS database setup.
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$work/certs/ca.key" -out "$work/certs/ca.crt" -days 1 -subj /CN=Vibes-memory-CA >/dev/null 2>&1
openssl req -newkey rsa:2048 -nodes -keyout "$work/certs/server.key" -out "$work/certs/server.csr" -subj /CN=pg >/dev/null 2>&1
printf 'subjectAltName=DNS:pg\nextendedKeyUsage=serverAuth\n' > "$work/certs/server.ext"
openssl x509 -req -in "$work/certs/server.csr" -CA "$work/certs/ca.crt" -CAkey "$work/certs/ca.key" -CAcreateserial -out "$work/certs/server.crt" -days 1 -extfile "$work/certs/server.ext" >/dev/null 2>&1
chmod 644 "$work/certs/ca.crt" "$work/certs/server.crt"
chmod 600 "$work/certs/server.key"
docker run --rm -u 0 -v "$work/certs:/certs" "$postgres" chown 70:70 /certs/server.key
password=$(openssl rand -hex 24)
admin=$(openssl rand -hex 24)
{
  printf 'DATABASE_URL=ecto://postgres:%s@pg:5432/vibes_memory\n' "$password"
  printf 'DIRECT_DATABASE_URL=ecto://postgres:%s@pg:5432/vibes_memory\n' "$password"
  printf 'SECRET_KEY_BASE=%s\n' "$(openssl rand -hex 64)"
  printf 'ADMIN_PASSWORD=%s\n' "$admin"
  printf 'PHX_HOST=vibes-memory.invalid\nPOOL_SIZE=5\n'
} > "$work/app.env"
chmod 600 "$work/app.env"
docker network create --internal "$network" >/dev/null
docker run -d --name "$pg" --label "vibes-memory=$prefix" --network "$network" --network-alias pg --memory 192m --cpus .3 -e "POSTGRES_PASSWORD=$password" -e POSTGRES_DB=vibes_memory -v "$work/certs:/certs:ro" "$postgres" -c ssl=on -c ssl_cert_file=/certs/server.crt -c ssl_key_file=/certs/server.key >/dev/null
for attempt in {1..60}; do
  if docker exec "$pg" pg_isready -U postgres -d vibes_memory >/dev/null; then break; fi
  sleep 1
done
docker exec "$pg" pg_isready -U postgres -d vibes_memory >/dev/null
release() {
  docker run --rm --name "$release_container" --label "service=$prefix" --network "$network" --memory 384m --cpus .5 --env-file "$work/app.env" -v "$work/certs/ca.crt:/etc/ssl/certs/ca-certificates.crt:ro" "$CANDIDATE_IMAGE" "$@"
}
release /app/bin/migrate > "$work/results/migration.log" 2>&1
release /app/bin/cafe eval Cafe.Release.seed >> "$work/results/migration.log" 2>&1
start_app() {
  docker run -d --name "$1" --label "service=$prefix" --label "vibes-memory=$prefix" --network "$network" --memory 384m --cpus .5 --env-file "$work/app.env" -v "$work/certs/ca.crt:/etc/ssl/certs/ca-certificates.crt:ro" "$CANDIDATE_IMAGE" >/dev/null
  local ip
  ip=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$1")
  for attempt in {1..60}; do
    if curl -fsS -H 'X-Forwarded-Proto: https' -H 'Host: vibes-memory.invalid' "http://$ip:4000/healthz" >/dev/null; then return; fi
    sleep 1
  done
  docker logs "$1" >&2
  return 1
}
start_app "$app_a"
docker exec "$app_a" sh -c 'du -sk /app/lib/cafe-*/priv/static/images/themes' > "$work/results/candidate-theme-kib.txt"
# Sampling is separate from the load client and remains bounded to this run.
(
  while true; do
    phase=$(cat "$work/phase" 2>/dev/null || echo idle)
    available=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
    printf '%s,%s,%s\n' "$(date -u +%FT%TZ)" "$phase" "$available" >> "$work/results/host-memory.csv"
    docker stats --no-stream --format '{{json .}}' "$app_a" "$app_b" "$pg" "$client" 2>/dev/null | while IFS= read -r row; do printf '{"phase":"%s","stats":%s}\n' "$phase" "$row"; done >> "$work/results/container-stats.jsonl" || true
    if [[ "$available" -lt 250000 ]]; then echo 'Host memory headroom below 250 MB' > "$work/results/pressure-abort.txt"; docker stop "$client" >/dev/null 2>&1 || true; exit 1; fi
    sleep 1
  done
) &
sampler=$!
sleep 5
phase() {
  local name=$1 listeners=$2
  shift 2
  test ! -e "$work/results/pressure-abort.txt"
  # Reset only the disposable database so every phase starts with the same catalog.
  docker exec "$pg" psql -U postgres -d vibes_memory -v ON_ERROR_STOP=1 -c 'TRUNCATE stations' >/dev/null
  release /app/bin/cafe eval Cafe.Release.seed >/dev/null 2>&1
  printf '%s\n' "$name" > "$work/phase"
  docker run --rm --name "$client" --label "vibes-memory=$prefix" --network "$network" --memory 256m --cpus .5 -e "BENCHMARK_ADMIN_PASSWORD=$admin" -v "$work/measure-memory-client.py:/client.py:ro" -v "$work/results:/results" "$python" python /client.py --clients "$listeners" --duration 25 --output "/results/$name.json" "$@"
  test ! -e "$work/results/pressure-abort.txt"
}
phase listeners-25 25 --endpoint "http://$app_a:4000"
phase listeners-100 100 --endpoint "http://$app_a:4000"
start_app "$app_b"
phase overlap-100 100 --endpoint "http://$app_a:4000" --endpoint "http://$app_b:4000"
docker ps --filter label=service=vibes --format '{{json .}}' > "$work/results/production-after.jsonl"
cp /proc/meminfo "$work/results/final-meminfo.txt"
echo 'Isolated memory measurement completed; task containers are being removed.'
