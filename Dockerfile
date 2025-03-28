# docker build -t ff .
# docker run -p 3000:3000 -it ff
# Build stage
FROM node:20-alpine AS builder

ARG NODE_VERSION=20

ARG BASE_PATH
ARG NEXT_PUBLIC_PORTAL_BASENAME
ENV NPM_CONFIG_PREFIX=/home/node/.npm-global
ENV PATH=$PATH:/home/node/.npm-global/bin
FROM node:20-slim AS builder

WORKDIR /gen3

# Install Python 3.11
RUN apk add --no-cache python3 python3-dev py3-pip build-base linux-headers && ln -sf python3 /usr/bin/python

# Copy only the files needed for dependency installation
COPY package*.json ./
COPY ./jupyter-lite/requirements.txt ./jupyter-lite/requirements.txt

# Install dependencies
COPY ./package.json ./package-lock.json ./next.config.js ./tsconfig.json ./.env.development  ./tailwind.config.js ./postcss.config.js ./start.sh ./.env.production ./
RUN npm ci
RUN npm install \
    "@swc/core" \
    "@napi-rs/magic-string"
RUN rm /usr/lib/python*/EXTERNALLY-MANAGED && \
    pip3 install -r ./jupyter-lite/requirements.txt

# Copy source files
COPY ./package.json ./package-lock.json ./next.config.js /tsconfig.json  ./tailwind.config.js ./postcss.config.js ./start.sh ./
COPY ./src ./src
COPY ./public ./public
COPY ./config ./config
COPY ./jupyter-lite ./jupyter-lite

# Build jupyter-lite and Next.js application
RUN jupyter lite build --contents ./jupyter-lite/contents/files --lite-dir ./jupyter-lite/contents --output-dir ./public/jupyter
RUN npm run build
COPY ./start.sh ./
RUN npm install @swc/core @napi-rs/magic-string && \
    npm run build

# Production stage
FROM node:20-alpine AS runner
FROM node:20-slim AS runner

WORKDIR /gen3

# Create non-root user
RUN addgroup --system --gid 1001 nodejs && \
RUN addgroup --system --gid 1001 nextjs && \
    adduser --system --uid 1001 nextjs

# Set production environment
ENV NODE_ENV=production
ENV PORT=3000

# Copy only necessary files from builder
COPY --from=builder --chown=nextjs:nodejs /gen3/.next ./.next
COPY --from=builder /gen3/node_modules ./node_modules
COPY --from=builder /gen3/package.json ./package.json
COPY --from=builder /gen3/public ./public
COPY --from=builder /gen3/config ./config
# Switch to non-root user
USER nextjs
COPY --from=builder /gen3/public ./public
COPY --from=builder /gen3/.next/standalone ./
COPY --from=builder /gen3/.next/static ./.next/static
COPY --from=builder /gen3/start.sh ./start.sh
RUN chown nextjs:nextjs /gen3/.next
VOLUME  /gen3/.next

EXPOSE 3000

CMD ["npm", "start"]
