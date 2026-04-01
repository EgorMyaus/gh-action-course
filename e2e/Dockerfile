# =============================================================================
# Dockerfile for Cucumber-Playwright E2E Tests
# =============================================================================
# Uses official Playwright image with pre-installed browsers
# =============================================================================

FROM mcr.microsoft.com/playwright:v1.59.1-noble

WORKDIR /app

# Copy package files first (better layer caching)
COPY package.json yarn.lock* ./

# Install dependencies
RUN npm install --legacy-peer-deps

# Copy test source code
COPY . .

# Transpile TypeScript before running
RUN npx rimraf dist && npx babel --extensions .ts --out-dir dist src

# Default: run smoke tests against localhost (overridable via CUCUMBER_PROFILE)
ENV NODE_ENV=localhost
ENV COMMON_CONFIG_FILE=env/common.env
ENV HEADLESS=true

CMD ["sh", "-c", "rm -rf reports/* && echo {} > reports/report.json && npx cucumber-js -p ${CUCUMBER_PROFILE:-smoke}"]
