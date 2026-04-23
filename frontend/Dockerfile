# First stage: install production dependencies
FROM node:20-alpine AS deps
WORKDIR /app

COPY package*.json ./
# this is used to install the dependencies in the production environment
RUN npm ci --omit=dev

# Second stage: build the application
FROM node:20-alpine AS runtime

RUN apk upgrade --no-cache

WORKDIR /app

ENV NODE_ENV=production

COPY --from=deps /app/node_modules ./node_modules
COPY app.js ./app.js
COPY views ./views

RUN addgroup -S appgroup && adduser -S appuser -G appgroup \
    && chown -R appuser:appgroup /app
# this is used to run the application as a non-root user
USER appuser
EXPOSE 3000
# this is used to check if the application is running
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "const http=require('http');const req=http.get('http://127.0.0.1:3000/',res=>{process.exit(res.statusCode===200?0:1)});req.on('error',()=>process.exit(1));req.setTimeout(4000,()=>{req.destroy();process.exit(1);});"

CMD ["node", "app.js"]
