# =============================================================================
# Multi-stage Dockerfile for React Application
# =============================================================================
# Stage 1: Build the React app
# Stage 2: Serve with NGINX
# =============================================================================

# =============================================================================
# STAGE 1: Build
# =============================================================================
FROM node:18-alpine AS build

# Set working directory
WORKDIR /app

# Copy package files first (better layer caching)
COPY package.json yarn.lock ./

# Install dependencies
RUN yarn install --frozen-lockfile

# Copy source code
COPY public ./public
COPY src ./src

# Build the React app for production
RUN yarn build

# =============================================================================
# STAGE 2: Production
# =============================================================================
FROM nginx:1.27.0-alpine

# Copy built files from build stage
COPY --from=build /app/build /usr/share/nginx/html

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/ || exit 1

# Start nginx in foreground
CMD ["nginx", "-g", "daemon off;"]
