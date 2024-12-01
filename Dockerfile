# Build stage
FROM node:20-alpine AS builder

WORKDIR /gen3

# Add build argument for basePath
ARG BASE_PATH="/ff"
ENV BASE_PATH=$BASE_PATH

# Install Python and build dependencies
RUN apk add --no-cache python3 python3-dev py3-pip build-base linux-headers \
    && ln -sf python3 /usr/bin/python \
    && rm -rf /var/cache/apk/*

# Copy only package files first to leverage cache
COPY package*.json ./
COPY ./jupyter-lite/requirements.txt ./jupyter-lite/requirements.txt

# Combine npm installations and cleanup in single layer
RUN npm ci \
    && npm install "@swc/core" "@napi-rs/magic-string" \
    && rm -rf /root/.npm/* \
    && rm /usr/lib/python*/EXTERNALLY-MANAGED \
    && pip3 install -r ./jupyter-lite/requirements.txt \
    && rm -rf /root/.cache/pip/*

# Copy only necessary source files
COPY . .

# Build applications
RUN jupyter lite build --contents ./jupyter-lite/contents/files --lite-dir ./jupyter-lite/contents --output-dir ./public/jupyter \
    && npm run build \
    && rm -rf ./jupyter-lite/contents/files

# Production stage
FROM node:20-alpine AS runner

WORKDIR /gen3

# Create non-root user
RUN addgroup --system --gid 1001 nodejs \
    && adduser --system --uid 1001 nextjs

# Set production environment
ENV NODE_ENV=production \
    PORT=3000 \
    BASE_PATH="/ff"

# Copy only production necessary files
COPY --from=builder --chown=nextjs:nodejs /gen3/.next ./.next
COPY --from=builder --chown=nextjs:nodejs /gen3/public ./public
COPY --from=builder --chown=nextjs:nodejs /gen3/package.json ./package.json
COPY --from=builder --chown=nextjs:nodejs /gen3/node_modules ./node_modules
COPY --from=builder --chown=nextjs:nodejs /gen3/config ./config

USER nextjs

EXPOSE 3000

CMD ["npm", "start"]
