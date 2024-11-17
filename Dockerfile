# Build stage
FROM node:20-alpine AS builder

WORKDIR /gen3

# Install Python 3.11
RUN apk add --no-cache python3 python3-dev py3-pip && ln -sf python3 /usr/bin/python
#RUN apk update && \
#    apk add python3.11 python3.11-dev python3-pip && \
#    rm -rf /var/lib/apt/lists/*

# Set the default Python version to 3.11
#RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1

# Copy only the files needed for dependency installation
COPY package*.json ./
COPY ./jupyter-lite/requirements.txt ./jupyter-lite/requirements.txt

# Install dependencies
RUN npm ci
RUN rm /usr/lib/python*/EXTERNALLY-MANAGED && \
    pip3 install -r ./jupyter-lite/requirements.txt

# Copy source files
COPY . .

# Build jupyter-lite and Next.js application
RUN jupyter lite build --contents ./jupyter-lite/contents/files --lite-dir ./jupyter-lite/contents --output-dir ./public/jupyter
RUN npm run build

# Production stage
FROM node:20-alpine AS runner

WORKDIR /gen3

# Create non-root user
RUN addgroup --system --gid 1001 nextjs && \
    adduser --system --uid 1001 nextjs

# Set production environment
ENV NODE_ENV=production
ENV PORT=3000

# Copy only necessary files from builder
COPY --from=builder --chown=nextjs:nextjs /gen3/.next ./.next
COPY --from=builder /gen3/node_modules ./node_modules
COPY --from=builder /gen3/package.json ./package.json
COPY --from=builder /gen3/public ./public
COPY --from=builder /gen3/config ./config
# Switch to non-root user
USER nextjs

EXPOSE 3000

CMD ["npm", "start"]
