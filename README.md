# hng14-stage2-devops

Job processing stack: **frontend** (Node/Express), **API** (FastAPI), **worker** (Python), and **Redis**. Configuration is driven by environment variables; see `.env.example`.

---

## Prerequisites

- **Docker** and **Docker Compose v2** (Docker Desktop on Windows includes both).
- **Git**.
- For local development without Docker: **Python 3.12+**, **Node.js 22** (matches the frontend Docker image and CI lint job), **npm**.

---

## Clone and configure

```bash
git clone https://github.com/Nuel-09/hng14-stage2-devops.git
cd hng14-stage2-devops
```

Create your local env file from the template (do **not** commit `.env`):

```bash
cp .env.example .env
```

Edit `.env` if you need different ports or resource limits. Important keys:

| Variable | Role |
|----------|------|
| `API_URL` | Base URL the **frontend container** uses to reach the API (use `http://api:8000` under Compose). |
| `FRONTEND_PORT` | Host port mapped to the frontend (default `3000`). |
| `REDIS_HOST` / `REDIS_PORT` | Redis service hostname (`redis`) and port inside the stack. |
| `*_MEM_LIMIT` / `*_CPUS` | Compose resource limits per service. |
| `IMAGE_TAG` | Tag for pre-built images when using `docker-compose.ci.yml` (CI uses the git SHA). |

---

## Run the full stack with Docker (recommended)

From the repository root:

```bash
docker compose --env-file .env up -d --build
```

Check status:

```bash
docker compose ps
```

Expected: **redis**, **api**, **worker**, and **frontend** are **running**; redis and api should become **healthy** (Compose waits on healthchecks).

Open a browser:

- **http://localhost:3000** (or `http://localhost:<FRONTEND_PORT>` from `.env`).

Click **Submit New Job**. After a few seconds the job line should show status **completed** (worker simulates ~2s of work).

View logs if needed:

```bash
docker compose logs -f api
docker compose logs -f worker
docker compose logs -f frontend
```

Tear down (removes containers and the Compose volume for Redis data):

```bash
docker compose down -v
```

Redis is **not** published to the host in `docker-compose.yml`; only the frontend port is mapped.

---

## Local development without Docker

**API**

```bash
cd api
pip install -r requirements.txt -r requirements-dev.txt
# Start Redis separately or point REDIS_HOST/REDIS_PORT at a running instance.
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

**Worker**

```bash
cd worker
pip install -r requirements.txt
python worker.py
```

**Frontend**

```bash
cd frontend
npm ci
npm start
```

Set `API_URL` (e.g. `http://localhost:8000`) when the API runs on the host.

**Quality checks (same tools as CI)**

```bash
cd api && python -m pytest tests/ --cov=main && python -m flake8 main.py tests/
cd ../frontend && npm run lint
```

---

## CI/CD (GitHub Actions)

Workflow file: `.github/workflows/ci.yml`.

The **lint** job runs ESLint on **Node 22**, matching `frontend/Dockerfile`. The **build** job uses **`docker build --pull`** so each run uses current base images from the registry before **Trivy** scans them.

When you **push** to this repository on GitHub, Actions runs automatically:

1. **Lint** — `flake8`, `eslint`, Hadolint on all Dockerfiles.
2. **Test** — `pytest` with Redis mocked; uploads **coverage-xml** artifact.
3. **Build** — builds three images, tags them with the commit SHA and `latest`, pushes to an ephemeral **local registry** inside the job, saves images as artifacts.
4. **Security** — **Trivy** scans images; **CRITICAL** findings fail the job; SARIF uploaded as **trivy-sarif**.
5. **Integration** — loads images, runs `scripts/integration_test.sh` against `docker-compose.ci.yml`.
6. **Deploy** — runs **only** on **push to `main`**: `scripts/deploy_rolling.sh` (API health gate, 60s).

Jobs are chained with `needs:` so a failure stops later stages.

**Fork workflow:** clone your fork, add commits, `git push origin main`. Open **Actions** on the fork to see runs. No extra account linking is required beyond pushing to GitHub.

---

## Repository layout (high level)

| Path | Purpose |
|------|---------|
| `docker-compose.yml` | Local/full stack with `build:` and health-ordered startup. |
| `docker-compose.ci.yml` | CI: pre-built `jobproc-*` images and `IMAGE_TAG`. |
| `scripts/integration_test.sh` | E2E test used in CI (bash; Linux runner). |
| `scripts/deploy_rolling.sh` | Rolling API update used on `main` deploy job. |
| `FIXES.md` | Table of every bug fixed (file, line, change). |

---

## Troubleshooting

- **Frontend cannot reach API in Compose:** ensure `API_URL=http://api:8000` in `.env` (not `localhost`).
- **Worker idle / jobs stuck queued:** confirm **worker** and **redis** are running and on the same network (`docker compose ps`).
- **Port already in use:** change `FRONTEND_PORT` in `.env`.
- **Actions fail on Trivy CRITICAL:** the workflow fails when Trivy finds **fixable CRITICAL** issues (`--ignore-unfixed` skips CVEs with no patched package yet). Images use **bookworm** bases with **`apt-get upgrade`**; the frontend image uses **Node bookworm-slim** and **`npm audit fix`**. Re-run after `docker compose build --pull`. Inspect the **security** job log and **trivy-sarif** artifact for CVE IDs if needed.
