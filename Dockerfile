# Multi-stage Dockerfile for Next.js (App Router) production build
# Builder installs deps and compiles to standalone output
FROM node:20-alpine AS deps

WORKDIR /app

# Install OS deps needed for some npm packages (if any native modules appear)
RUN apk add --no-cache libc6-compat

# Install dependencies using npm (lockfile present)
COPY package.json package-lock.json ./
RUN npm ci

# Build stage
FROM node:20-alpine AS builder
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Ensure Next.js uses standalone output
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production

RUN npm run build

# Production runtime image
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3002

# Install runtime tools needed for healthchecks
RUN apk add --no-cache curl

# Create non-root user
RUN addgroup -S nextjs && adduser -S nextjs -G nextjs

# Copy only the necessary build artifacts
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/.next/BUILD_ID ./.next/BUILD_ID
COPY --from=builder /app/next.config.js ./next.config.js

# Next.js standalone includes server, we just need to expose and start it
EXPOSE 3002

USER nextjs

CMD ["node", "server.js"]


