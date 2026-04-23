#!/usr/bin/env bash
# Rolling-style API update: start a candidate API container, wait up to 60s for
# /health; on success stop the old API and recreate from Compose; on failure remove
# candidate and leave the previous API running.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -f .env ]]; then
  echo "Missing .env"
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

: "${IMAGE_TAG:?IMAGE_TAG must be set (e.g. git SHA)}"

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-jobproc_deploy}"

COMPOSE=(docker compose -f docker-compose.ci.yml --env-file .env)

"${COMPOSE[@]}" up -d redis
sleep 3
"${COMPOSE[@]}" up -d worker
"${COMPOSE[@]}" up -d api

CID_OLD="$("${COMPOSE[@]}" ps -q api)"
if [[ -z "${CID_OLD}" ]]; then
  echo "Could not find running API container id."
  exit 1
fi

docker rm -f api_roll_candidate 2>/dev/null || true

docker run -d --name api_roll_candidate \
  --network app_net \
  -e "REDIS_HOST=${REDIS_HOST:-redis}" \
  -e "REDIS_PORT=${REDIS_PORT:-6379}" \
  "jobproc-api:${IMAGE_TAG}"

HEALTH_OK=0
for _ in $(seq 1 60); do
  if docker exec api_roll_candidate python -c \
    "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=3)" \
    2>/dev/null; then
    HEALTH_OK=1
    break
  fi
  sleep 1
done

if [[ "${HEALTH_OK}" != "1" ]]; then
  docker rm -f api_roll_candidate
  echo "New API failed health check within 60s; leaving existing API running."
  exit 1
fi

docker stop "${CID_OLD}"
docker rm "${CID_OLD}"
docker rm -f api_roll_candidate

"${COMPOSE[@]}" up -d api
"${COMPOSE[@]}" up -d frontend
"${COMPOSE[@]}" ps
