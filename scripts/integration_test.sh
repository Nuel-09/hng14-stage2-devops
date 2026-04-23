#!/usr/bin/env bash
# Brings up the full stack (pre-built images), submits a job via the frontend,
# polls until the job reaches "completed", then tears the stack down (trap).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -f .env ]]; then
  echo "Missing .env — copy from .env.example and set IMAGE_TAG for CI images."
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-jobproc_ci}"

cleanup() {
  docker compose -f docker-compose.ci.yml --env-file .env down -v --remove-orphans || true
}
trap cleanup EXIT

docker compose -f docker-compose.ci.yml --env-file .env up -d --wait

FRONTEND_PORT="${FRONTEND_PORT:-3000}"
BASE="http://127.0.0.1:${FRONTEND_PORT}"

RESP="$(curl -sf -X POST "${BASE}/submit" -H 'Content-Type: application/json' -d '{}')"
JOB_ID="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['job_id'])" "${RESP}")"

for _ in $(seq 1 60); do
  STATUS_RESP="$(curl -sf "${BASE}/status/${JOB_ID}")"
  STATUS="$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('status',''))" "${STATUS_RESP}")"
  if [[ "${STATUS}" == "completed" ]]; then
    exit 0
  fi
  sleep 2
done

echo "Timed out waiting for job ${JOB_ID} to complete."
exit 1
