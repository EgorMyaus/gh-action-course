# ReportPortal - Self-Hosted Test Reporting

Self-hosted test reporting platform with AI-powered failure analysis.

## AWS Infrastructure Deployment

ReportPortal is a **test results dashboard** - it does NOT run tests. Tests run against staging/dev, and results are sent to ReportPortal.

## Test Flow

```
┌──────────────────────────────────────────────────────────────────────┐
│                         TEST FLOW                                     │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  1. CI/CD runs tests      2. Tests execute against     3. Results    │
│     (GitLab Runner)          STAGING/DEV environment      sent to    │
│                                                           REPORTPORTAL│
│                                                                       │
│  ┌─────────────┐          ┌─────────────┐           ┌─────────────┐  │
│  │ GitLab CI   │─────────▶│  Staging    │           │ ReportPortal│  │
│  │ (e2e tests) │          │  (app+DB)   │           │ (dashboard) │  │
│  └──────┬──────┘          └─────────────┘           └──────▲──────┘  │
│         │                                                  │          │
│         └──────────────────────────────────────────────────┘          │
│                        sends test results                             │
│                                                                       │
│  ❌ NEVER test against PRODUCTION                                    │
│  ✅ Test against STAGING/DEV only                                    │
└──────────────────────────────────────────────────────────────────────┘
```

## ReportPortal vs Prometheus/Grafana

**They serve different purposes — keep both.**

| Tool | Purpose | Monitors |
|------|---------|----------|
| **ReportPortal** | Test results & analytics | Pass/fail, flaky tests, execution history, failure analysis |
| **Prometheus/Grafana** | Infra & app observability | CPU, memory, latency, error rates, container health |

```
┌─────────────────────────────────────────────────────────────────────┐
│                    MONITORING LANDSCAPE                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────────────┐    ┌─────────────────────────┐        │
│  │      ReportPortal       │    │   Prometheus/Grafana    │        │
│  │   (Test Results)        │    │   (Infrastructure)      │        │
│  ├─────────────────────────┤    ├─────────────────────────┤        │
│  │ • Test pass/fail rates  │    │ • CPU/Memory usage      │        │
│  │ • Flaky test detection  │    │ • Response times        │        │
│  │ • Test execution time   │    │ • Error rates (5xx)     │        │
│  │ • Failure analysis (AI) │    │ • Container health      │        │
│  │ • Test history/trends   │    │ • Database connections  │        │
│  └─────────────────────────┘    └─────────────────────────┘        │
│           │                              │                          │
│           ▼                              ▼                          │
│    "Are my TESTS healthy?"       "Is my APP healthy?"              │
└─────────────────────────────────────────────────────────────────────┘
```

ReportPortal requires a dedicated EC2 instance with sufficient resources.

### Deploy with Terraform

```bash
cd infra/environments/reportportal
terraform init
terraform apply

# Get outputs
terraform output

# SSH and setup
ssh -i ~/.ssh/id_rsa ubuntu@$(terraform output -raw public_ip)
```

### Resource Requirements

| Instance Type | vCPU | RAM | Monthly Cost | Recommended For |
|--------------|------|-----|--------------|-----------------|
| t3.large | 2 | 8 GB | ~$60 | Small teams (dev) |
| t3.xlarge | 4 | 16 GB | ~$120 | **Recommended** |
| t3.2xlarge | 8 | 32 GB | ~$240 | Large teams |

### After Terraform Deploy

```bash
# 1. SSH into server
ssh -i ~/.ssh/id_rsa ubuntu@<PUBLIC_IP>

# 2. Copy docker-compose.yml
scp reportportal/docker-compose.yml ubuntu@<PUBLIC_IP>:/opt/reportportal/

# 3. Start ReportPortal
cd /opt/reportportal
docker compose up -d

# 4. Verify services
docker compose ps
```

---

## DevOps Skills Covered

| Technology | Purpose | Learning Outcome |
|------------|---------|------------------|
| **Docker Compose** | Multi-container orchestration | Container networking, volumes, health checks |
| **PostgreSQL** | Primary database | Database management, backups |
| **MinIO** | S3-compatible object storage | Object storage, binary data |
| **RabbitMQ** | Message queue | Async communication, queuing |
| **OpenSearch** | Search &amp; analytics | Full-text search, log analysis |
| **Traefik** | Reverse proxy | Load balancing, routing, TLS |

## Quick Start

```bash
# Start ReportPortal stack
cd reportportal
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f api

# Access UI
open http://localhost:8080
```

## Default Credentials

| Service | URL | Username | Password |
|---------|-----|----------|----------|
| **ReportPortal** | http://localhost:8080 | superadmin | erebus |
| **RabbitMQ** | http://localhost:15672 | rabbitmq | rabbitmq |
| **MinIO Console** | http://localhost:9001 | minio | minio123 |
| **Traefik** | http://localhost:8081 | - | - |

## Architecture

### Internal Services (Docker Compose)

```
                    +------------------+
                    |    Traefik       |
                    |  (Load Balancer) |
                    +--------+---------+
                             |
       +----------+----------+----------+----------+
       |          |          |          |          |
  +----+----+ +---+---+ +----+----+ +---+----+ +---+----+
  |   UI    | |  API  | |   UAT   | | Index  | |Analyzer|
  +---------+ +---+---+ +----+----+ +--------+ +---+----+
                  |          |                     |
       +----------+----------+----------+----------+
       |          |          |          |
  +----+----+ +---+---+ +----+----+ +---+----+
  |PostgreSQL| |MinIO | |RabbitMQ | |OpenSearch|
  +---------+ +-------+ +---------+ +---------+
```

### AWS Deployment (EC2 host)

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS (ReportPortal)                        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐    │
│  │              EC2 (t3.xlarge)                         │    │
│  │  ┌─────────────────────────────────────────────┐    │    │
│  │  │           Docker Compose                     │    │    │
│  │  │  ┌──────────┐ ┌──────────┐ ┌──────────┐    │    │    │
│  │  │  │PostgreSQL│ │  MinIO   │ │ RabbitMQ │    │    │    │
│  │  │  └──────────┘ └──────────┘ └──────────┘    │    │    │
│  │  │  ┌──────────┐ ┌──────────┐ ┌──────────┐    │    │    │
│  │  │  │OpenSearch│ │ Traefik  │ │   API    │    │    │    │
│  │  │  └──────────┘ └──────────┘ └──────────┘    │    │    │
│  │  └─────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────┘    │
│                          │                                   │
│                     Elastic IP                               │
└─────────────────────────────────────────────────────────────┘
```

## Services

### Core Services
- **api** - Main API service (port 8585)
- **uat** - Authorization service (port 9999)
- **ui** - Web interface (port 8080)

### Infrastructure Services
- **postgres** - Database (port 5432)
- **minio** - Object storage (port 9000, console 9001)
- **rabbitmq** - Message queue (port 5672, management 15672)
- **opensearch** - Search engine (port 9200)

### Optional Services
- **analyzer** - AI-based failure analysis
- **index** - Search indexing service

## Configuration

### Environment Variables

Create `.env` file to customize:

```bash
# Database
POSTGRES_USER=rpuser
POSTGRES_PASSWORD=rppass
POSTGRES_DB=reportportal

# MinIO
MINIO_ROOT_USER=minio
MINIO_ROOT_PASSWORD=minio123

# RabbitMQ
RABBITMQ_DEFAULT_USER=rabbitmq
RABBITMQ_DEFAULT_PASS=rabbitmq
```

## Integration with Playwright/Cucumber

### 1. Install Agent

```bash
cd e2e
npm install --save-dev @reportportal/agent-js-cucumber
```

### 2. Configure Cucumber

Update `cucumber.js`:

```javascript
module.exports = {
  default: {
    format: [
      '@reportportal/agent-js-cucumber',
      'progress'
    ],
    formatOptions: {
      reportportal: {
        token: 'YOUR_API_TOKEN',
        endpoint: 'http://localhost:8080/api/v1',
        project: 'default_personal',
        launch: 'Cucumber Playwright Tests',
        attributes: [
          { key: 'browser', value: 'chromium' },
          { key: 'env', value: 'local' }
        ]
      }
    }
  }
};
```

### 3. Get API Token

1. Login to ReportPortal (http://localhost:8080)
2. Go to User Profile (top right)
3. Click "API Keys"
4. Generate new key

## Production Deployment

### Resource Requirements

| Service | CPU | Memory |
|---------|-----|--------|
| API | 1 core | 1-2 GB |
| UAT | 0.5 core | 512 MB |
| UI | 0.25 core | 256 MB |
| PostgreSQL | 1 core | 1 GB |
| OpenSearch | 1 core | 1-2 GB |
| RabbitMQ | 0.5 core | 512 MB |
| MinIO | 0.5 core | 512 MB |
| **Total** | **~5 cores** | **~6-8 GB** |

### Kubernetes Deployment

See `helm/reportportal-chart/` for Helm chart deployment.

```bash
helm upgrade --install reportportal ./helm/reportportal-chart \
  --namespace reportportal --create-namespace
```

## Maintenance

### Backup Database

```bash
docker exec reportportal-postgres pg_dump -U rpuser reportportal > backup.sql
```

### Restore Database

```bash
cat backup.sql | docker exec -i reportportal-postgres psql -U rpuser reportportal
```

### Clear Old Data

```bash
# Access PostgreSQL
docker exec -it reportportal-postgres psql -U rpuser reportportal

# Delete launches older than 30 days
DELETE FROM launch WHERE start_time < NOW() - INTERVAL '30 days';
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f api

# Last 100 lines
docker-compose logs --tail=100 api
```

## Troubleshooting

### Services Not Starting

```bash
# Check health
docker-compose ps

# Restart unhealthy service
docker-compose restart api

# Full restart
docker-compose down && docker-compose up -d
```

### Out of Memory

Increase Docker memory allocation or adjust Java heap:

```yaml
environment:
  JAVA_OPTS: "-Xmx2g"  # Increase from 1g
```

### OpenSearch Issues

```bash
# Check cluster health
curl http://localhost:9200/_cluster/health

# Increase vm.max_map_count (Linux)
sudo sysctl -w vm.max_map_count=262144
```
