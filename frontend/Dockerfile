# Dependencies (devDependencies excluded by npm ci --omit=dev)
FROM node:22-bookworm-slim AS deps
WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev \
    && (npm audit fix --omit=dev || true)

# Production runtime — Debian bookworm patches faster than Alpine for many glibc/openssl CVEs
FROM node:22-bookworm-slim AS runtime

RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV NODE_ENV=production

COPY --from=deps /app/node_modules ./node_modules
COPY app.js ./app.js
COPY views ./views

RUN groupadd --system appgroup \
    && useradd --system --gid appgroup --home-dir /app --no-create-home appuser \
    && chown -R appuser:appgroup /app

USER appuser
EXPOSE 3000

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "const http=require('http');const req=http.get('http://127.0.0.1:3000/',res=>{process.exit(res.statusCode===200?0:1)});req.on('error',()=>process.exit(1));req.setTimeout(4000,()=>{req.destroy();process.exit(1);});"

CMD ["node", "app.js"]
