# Stage 1: Builder
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Stage 2: Production
FROM node:18-alpine
WORKDIR /app
ENV NODE_ENV=production

# Create non-root user (node user exists in official image)
USER node

# Copy dependencies and source code
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node . .

EXPOSE 3001
CMD ["node", "index.js"]
