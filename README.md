# Testing Talks Hub React App

A React application with comprehensive cloud infrastructure, E2E testing with Playwright, performance testing with k6, and monitoring with Prometheus/Grafana.

## Quick Start

```bash
# Install dependencies
npm install

# Start development server
npm start

# Run E2E tests
cd e2e && npm install && npx playwright test
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

### Frontend Only (E2E/Dev mode)
```bash
npm start
# Uses in-memory data from contacts.json
```

### With Backend API
```bash
# Terminal 1: Start API
cd server && npm install && npm run dev

# Terminal 2: Start frontend
REACT_APP_USE_LOCAL_DATA=false npm start
```

### With Docker
```bash
# E2E mode (no backend)
docker-compose up

# Production mode (with API)
docker-compose --profile production up
```

## Testing

### E2E Tests (Playwright)
```bash
cd e2e
npm install
npx playwright test
npx playwright test --ui  # Interactive mode
```

### Performance Tests (k6)
```bash
cd performance
k6 run scripts/smoke-test.js
k6 run scripts/load-test.js
k6 run scripts/stress-test.js
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
- **Testing**: Playwright, Cucumber, k6
- **Infrastructure**: Terraform, Packer, Docker
- **Orchestration**: Kubernetes, Helm, ArgoCD
- **CI/CD**: GitLab CI (with security scanning)
- **Monitoring**: Prometheus, Grafana, Alertmanager
- **Test Reporting**: ReportPortal (self-hosted)