# Testing Talks Hub React App

A React application with comprehensive cloud infrastructure, E2E testing with Playwright, performance testing with k6, and monitoring with Prometheus/Grafana.

## Quick Start

```bash
# Install dependencies
yarn install

# Start development server
yarn start

# In a separate terminal — run E2E tests
cd e2e && yarn install && yarn cucumber:localhost -p smoke
```

## Project Structure

```
├── src/                    # React frontend
│   └── services/api.js     # API client (env-aware)
├── server/                 # Express.js backend API
├── e2e/                    # Playwright E2E tests
├── infra/                  # Terraform infrastructure
│   ├── modules/            # Reusable modules
│   └── environments/       # dev, perf, prod
├── monitoring/             # Prometheus & Grafana
├── performance/            # k6 load tests
├── k8s/                    # Kubernetes manifests
├── helm/                   # Helm charts
└── packer/                 # AMI templates
```

## Environments

| Environment | Database | Purpose |
|-------------|----------|---------|
| **dev** | None (in-memory) | Development, E2E tests |
| **perf** | PostgreSQL | Performance/load testing |
| **prod** | PostgreSQL (Multi-AZ) | Production |

## Running Locally

### Option 1: Without Docker (fastest for development)

```bash
# Terminal 1 — Start the React app
yarn install
yarn start
# App runs at http://localhost:3000 (uses in-memory data from contacts.json)
# Wait for "Compiled successfully" before running tests

# Terminal 2 — Run E2E tests
cd e2e
yarn install
yarn cucumber:localhost -p smoke       # smoke tests
yarn cucumber:localhost -p regression  # full regression
yarn cucumber:localhost -p dev         # dev tagged tests
```

> **Note:** The `.env` file must contain `REACT_APP_USE_LOCAL_DATA=true` for the app to work without a backend.

### Option 2: App in Docker, Tests Locally (best for debugging)

Run the React app in a Docker container and execute tests from your machine with full Playwright debugging support.

```bash
# Start the app container (serves at http://localhost:80)
docker compose up -d react-app --build

# Run smoke tests locally against the Docker container
cd e2e
yarn install
yarn cucumber:docker -p smoke          # smoke tests (headed)
yarn cucumber:docker -p regression     # full regression

# Debug with Playwright Inspector (step-through, DOM picker)
yarn cucumber:docker:debug -p smoke

# When done
docker compose down
```

### Option 3: Fully Containerized (CI / one command)

Both the app and the tests run inside Docker containers — no local dependencies needed.

```bash
# App + smoke tests (builds everything, runs headlessly)
docker compose --profile test run --build e2e-tests

# App + regression tests
docker compose --profile test run --build -e CUCUMBER_PROFILE=regression e2e-tests

# Start app in background, run tests whenever you want
docker compose up -d react-app --build
docker compose --profile test run e2e-tests
docker compose down
```

Test reports are saved to `./e2e/reports/` on your host machine.

### Option 4: With Backend API (production-like)

```bash
# Terminal 1: Start API
cd server && npm install && npm run dev

# Terminal 2: Start frontend against the API
REACT_APP_USE_LOCAL_DATA=false yarn start

# Or with Docker Compose
docker compose --profile production up
```

## Testing

### E2E Tests (Cucumber + Playwright)

This project uses **Cucumber** as the test runner with **Playwright** for browser automation.

All test commands run from the `e2e/` directory:

```bash
cd e2e
yarn install
```

### Available Scripts

| Script | Description |
|--------|-------------|
| `yarn cucumber:localhost -p smoke` | Run against local dev server (`localhost:3000`) |
| `yarn cucumber:docker -p smoke` | Run against Docker container (`localhost:80`) |
| `yarn cucumber:docker:debug -p smoke` | Debug against Docker container with Playwright Inspector |
| `yarn cucumber:debug -p smoke` | Debug against local dev server with Playwright Inspector |
| `yarn cucumber:production -p smoke` | Run against production |
| `yarn cucumber:reportportal -p smoke` | Run with ReportPortal reporting |

### Profiles

| Profile | Description |
|---------|-------------|
| `-p smoke` | Smoke tests (fast subset) |
| `-p regression` | Full regression suite |
| `-p dev` | Dev tagged tests only |

### Playwright Debugging Tools

Since the project uses Cucumber (not `npx playwright test`), Playwright's `--ui` mode is not available directly. Instead:

| Tool | Command | Description |
|------|---------|-------------|
| **Playwright Inspector** | `yarn cucumber:debug -p smoke` | Step-through debugger with DOM picker (like Cypress) |
| **Playwright Inspector (Docker)** | `yarn cucumber:docker:debug -p smoke` | Same, but against the Docker container |
| **Trace Viewer** | `yarn trace:show ./path/to/trace.zip` | Timeline of actions, screenshots, network, DOM snapshots |
| **Headed mode** | Already enabled (`HEADLESS=false` in `env/common.env`) | Browsers open visually |
| **Headless mode** | `HEADLESS=true yarn cucumber:localhost -p smoke` | Run without opening browsers |

### Performance Tests (k6)

```bash
cd performance
k6 run scripts/smoke-test.js
k6 run scripts/load-test.js
k6 run scripts/stress-test.js
```

### Docker Compose Cleanup

```bash
docker compose down              # stop containers
docker compose down --rmi local  # stop + remove built images
docker compose down -v           # stop + remove volumes
```

## Infrastructure

### Deploy to AWS
```bash
# Development
cd infra/environments/dev
terraform init && terraform apply

# Performance testing
cd infra/environments/perf
terraform init && terraform apply

# Production
cd infra/environments/prod
terraform init && terraform apply
```

### Deploy to Kubernetes
```bash
# Using Helm
helm upgrade --install react-app ./helm/react-app-chart

# Using ArgoCD
kubectl apply -f argocd/application.yaml
```

## Monitoring

```bash
cd monitoring
docker-compose up -d

# Grafana: http://localhost:3000 (admin/admin123)
# Prometheus: http://localhost:9090
```

## Documentation

See [CLOUD_DEPLOYMENT_GUIDE.md](./CLOUD_DEPLOYMENT_GUIDE.md) for comprehensive deployment instructions including:
- Terraform & AWS setup
- Docker & Docker Compose
- Kubernetes & Helm
- ArgoCD GitOps
- GitLab CI/CD pipelines
- Prometheus & Grafana monitoring
- k6 performance testing

## Requirements Compliance

### Required (All Met ✅)

| Requirement | Implementation |
|-------------|----------------|
| **Two environments (dev/prod)** | `infra/environments/dev`, `infra/environments/prod` + perf |
| **Services work in containers** | Multi-stage Dockerfile, docker-compose.yml |
| **Resources as Helm charts** | `helm/react-app-chart/` with all YAML manifests |
| **Reliability & auto-balance** | 3+ replicas, PodDisruptionBudget, pod anti-affinity |
| **Zero-downtime deployment** | RollingUpdate (maxUnavailable: 0), health probes |

### Extra Requirements (4/4 Met ✅)

| Requirement | Implementation |
|-------------|----------------|
| **CI/CD security analysis** | GitLab SAST, Dependency Scanning, Secret Detection, Container Scanning |
| **Pod-level autoscaling** | HPA with CPU/Memory targets (2-20 replicas) |
| **Daily DB backups** | RDS automated backups (7-14 day retention) |
| **Pod-level monitoring** | Prometheus ServiceMonitor, pod annotations for scraping |

### Key Files

```bash
# Helm Charts
helm/react-app-chart/
├── values.yaml           # Default values (with all features)
├── values-dev.yaml       # Dev environment overrides
├── values-prod.yaml      # Prod environment overrides
└── templates/
    ├── deployment.yaml   # Zero-downtime, health probes
    ├── hpa.yaml          # Horizontal Pod Autoscaler
    ├── pdb.yaml          # Pod Disruption Budget
    └── servicemonitor.yaml # Prometheus monitoring

# CI/CD with Security
.gitlab-ci.yml            # SAST, dependency scanning, container scanning
```

### Deploy Commands

```bash
# Development
helm upgrade --install react-app ./helm/react-app-chart \
  -f ./helm/react-app-chart/values-dev.yaml \
  --namespace react-app-dev --create-namespace

# Production
helm upgrade --install react-app ./helm/react-app-chart \
  -f ./helm/react-app-chart/values-prod.yaml \
  --namespace react-app-prod --create-namespace
```

## Test Reporting with ReportPortal

Self-hosted test reporting platform for DevOps skill development.

```bash
# Start ReportPortal
cd reportportal
docker-compose up -d

# Access: http://localhost:8080 (superadmin/erebus)

# Run tests with ReportPortal
cd e2e
RP_TOKEN=your_api_token npm run cucumber:reportportal
```

**DevOps Technologies:**
- PostgreSQL, MinIO, RabbitMQ, OpenSearch, Traefik

See [reportportal/README.md](./reportportal/README.md) for full setup guide.

## Tech Stack

- **Frontend**: React 17, Material-UI, Bootstrap
- **Backend**: Express.js, PostgreSQL
- **Testing**: Playwright 1.59, Cucumber 8, k6
- **Infrastructure**: Terraform, Packer, Docker
- **Orchestration**: Kubernetes, Helm, ArgoCD
- **CI/CD**: GitLab CI (with security scanning)
- **Monitoring**: Prometheus, Grafana, Alertmanager
- **Test Reporting**: ReportPortal (self-hosted)