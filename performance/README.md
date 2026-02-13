# Performance Testing with k6

## Overview

This directory contains performance tests using [k6](https://k6.io/), a modern load testing tool.

## Test Types

| Test | Purpose | Duration | VUs |
|------|---------|----------|-----|
| **Smoke** | Verify system works | 1 min | 1 |
| **Load** | Test expected load | 10 min | 50 |
| **Stress** | Find breaking point | 15 min | 200+ |
| **Spike** | Test sudden traffic | 8 min | 300 |
| **Soak** | Test stability | 1 hour | 50 |

## Quick Start

### Prerequisites

```bash
# Install k6 locally
brew install k6

# Or use Docker
docker pull grafana/k6
```

### Running Tests Locally

```bash
# Smoke test
k6 run scripts/smoke-test.js

# Load test with custom target
BASE_URL=http://localhost API_URL=http://localhost:3001 k6 run scripts/load-test.js

# Stress test
k6 run scripts/stress-test.js
```

### Running with Docker

```bash
# Start the app first
cd .. && docker-compose up -d

# Run smoke test
docker-compose run --rm k6 run /scripts/smoke-test.js

# Run load test
docker-compose run --rm k6 run /scripts/load-test.js

# Run stress test
docker-compose run --rm k6 run /scripts/stress-test.js
```

### Running with InfluxDB + Grafana (Real-time Metrics)

```bash
# Start InfluxDB and Grafana
docker-compose up -d influxdb grafana

# Run test with InfluxDB output
k6 run --out influxdb=http://localhost:8086/k6 scripts/load-test.js

# Open Grafana at http://localhost:3001
# Default credentials: admin / admin123
```

## Thresholds

Each test has defined thresholds that determine pass/fail:

### Smoke Test
- P95 response time < 500ms
- Error rate < 1%

### Load Test
- P95 response time < 1000ms
- P99 response time < 2000ms
- Error rate < 5%

### Stress Test
- P95 response time < 3000ms
- Error rate < 15%

### Spike Test
- P95 response time < 5000ms
- Error rate < 25%

### Soak Test
- P95 response time < 1500ms
- P99 response time < 3000ms
- Error rate < 2%

## CI/CD Integration

### GitLab CI

```yaml
performance-test:
  stage: performance
  image: grafana/k6:0.47.0
  script:
    - k6 run --out json=results.json scripts/smoke-test.js
  artifacts:
    paths:
      - results.json
    expire_in: 1 week
  only:
    - main
    - merge_requests
```

### GitHub Actions

```yaml
- name: Run k6 smoke test
  uses: grafana/k6-action@v0.3.1
  with:
    filename: performance/scripts/smoke-test.js
```

## Results

Test results are saved to `/results/` directory:
- `results.json` - Raw metrics data
- `*-summary.json` - Test summary

## Customization

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `BASE_URL` | Frontend URL | `http://localhost` |
| `API_URL` | Backend API URL | `http://localhost:3001` |
| `K6_VUS` | Override VU count | (from script) |
| `K6_DURATION` | Override duration | (from script) |

### Example: Custom Load Test

```bash
k6 run \
  -e BASE_URL=https://staging.example.com \
  -e API_URL=https://api.staging.example.com \
  --vus 100 \
  --duration 30m \
  scripts/load-test.js
```
