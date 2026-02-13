# Complete Cloud Deployment Guide

## React App with Playwright E2E Tests - Full Infrastructure Setup

This guide covers deploying a React application to the cloud using:
- **Terraform** - Infrastructure as Code for AWS
- **AWS** - Cloud provider (VPC, EC2, S3, EKS)
- **Docker** - Containerization
- **Docker Compose** - Local development orchestration
- **Kubernetes** - Container orchestration
- **Helm** - Kubernetes package manager
- **ArgoCD** - GitOps continuous delivery
- **GitLab CI/CD** - Continuous Integration/Deployment pipelines

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Prerequisites](#2-prerequisites)
3. [Phase 1: Terraform & AWS](#3-phase-1-terraform--aws)
4. [Phase 2: Docker](#4-phase-2-docker)
5. [Phase 3: Docker Compose](#5-phase-3-docker-compose)
6. [Phase 4: Kubernetes](#6-phase-4-kubernetes)
7. [Phase 5: Helm](#7-phase-5-helm)
8. [Phase 6: ArgoCD](#8-phase-6-argocd)
9. [Phase 7: GitLab CI/CD](#9-phase-7-gitlab-cicd)
10. [Monitoring with Prometheus & Grafana](#10-monitoring-with-prometheus--grafana)
11. [Performance Testing with k6](#11-performance-testing-with-k6)
12. [Best Practices](#12-best-practices)

---

## 1. Project Overview

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                    │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         CLOUDFLARE (Optional)                            │
│                    CDN, DDoS Protection, SSL                             │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                              AWS CLOUD                                   │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                         VPC (10.0.0.0/16)                          │  │
│  │  ┌─────────────────────────┐  ┌─────────────────────────────────┐ │  │
│  │  │   PUBLIC SUBNET         │  │      PRIVATE SUBNET              │ │  │
│  │  │   (10.0.1.0/24)         │  │      (10.0.2.0/24)               │ │  │
│  │  │  ┌───────────────────┐  │  │  ┌───────────────────────────┐  │ │  │
│  │  │  │   EC2 Web Server  │  │  │  │   RDS PostgreSQL        │  │ │  │
│  │  │  │   (NGINX/Docker)  │  │  │  │   (Production only)     │  │ │  │
│  │  │  └───────────────────┘  │  │  └───────────────────────────┘  │ │  │
│  │  │  ┌───────────────────┐  │  │                                  │ │  │
│  │  │  │   NAT Gateway     │──┼──┼──────────────────────────────────┤ │  │
│  │  │  └───────────────────┘  │  │                                  │ │  │
│  │  └────────────┬────────────┘  └──────────────────────────────────┘ │  │
│  │               │                                                     │  │
│  │  ┌────────────▼────────────┐                                       │  │
│  │  │   Internet Gateway      │                                       │  │
│  │  └─────────────────────────┘                                       │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                    S3 + DynamoDB                                   │  │
│  │              Terraform State Storage                               │  │
│  │         (Remote state + locking for team collaboration)            │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

### Final Project Structure

```
react-app-module-21/
├── .gitlab-ci.yml          # GitLab CI/CD pipeline
├── Dockerfile              # Multi-stage build (frontend)
├── docker-compose.yml      # Local development
├── nginx.conf              # NGINX configuration
├── .dockerignore
├── package.json
├── src/                    # React source code
│   ├── services/api.js     # API client
│   ├── .env.development    # E2E: uses local data
│   └── .env.production     # Prod: uses API
├── server/                 # Express.js Backend API
│   ├── index.js            # API server
│   ├── routes/contacts.js  # CRUD endpoints
│   ├── config/database.js  # PostgreSQL connection
│   ├── Dockerfile          # API container
│   ├── .env.development    # In-memory data
│   └── .env.production     # PostgreSQL connection
├── e2e/                    # Playwright tests
├── packer/                 # Packer AMI templates
│   ├── web-server.pkr.hcl
│   ├── e2e-runner.pkr.hcl
│   └── variables.pkrvars.hcl
├── infra/                  # Terraform (Modular)
│   ├── modules/            # Reusable modules
│   │   ├── networking/     # VPC, subnets, NAT
│   │   ├── compute/        # EC2, security groups
│   │   └── database/       # RDS PostgreSQL
│   └── environments/       # Environment configs
│       ├── dev/            # Development (no DB)
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── terraform.tfvars
│       ├── perf/           # Performance testing (with DB)
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── terraform.tfvars
│       └── prod/           # Production (with DB, Multi-AZ)
│           ├── main.tf
│           ├── variables.tf
│           └── terraform.tfvars
├── monitoring/             # Prometheus & Grafana
│   ├── docker-compose.yml
│   ├── prometheus/
│   └── grafana/
├── performance/            # k6 Performance Tests
│   ├── docker-compose.yml
│   └── scripts/
│       ├── smoke-test.js
│       ├── load-test.js
│       ├── stress-test.js
│       ├── spike-test.js
│       └── soak-test.js
├── k8s/                    # Kubernetes manifests
├── helm/react-app-chart/   # Helm chart
└── argocd/                 # ArgoCD
```

---

## 2. Prerequisites

### Required Tools

```bash
# 1. Terraform
brew install terraform
terraform --version  # >= 1.7

# 2. Packer (for building AMIs)
brew install packer
packer --version

# 3. AWS CLI
brew install awscli
aws --version

# 4. Docker
brew install --cask docker
docker --version

# 5. kubectl
brew install kubectl
kubectl version --client

# 6. Helm
brew install helm
helm version

# 7. Node.js
brew install node@18
node --version  # >= 18
```

### AWS Configuration

```bash
aws configure
# Enter: Access Key ID, Secret Key, Region (us-east-1), Format (json)

# Verify
aws sts get-caller-identity
```

---

## 3. Phase 1: Terraform & AWS

### Modular Terraform Structure

The infrastructure uses a **modular** approach with separate environments:

```
infra/
├── modules/                    # Reusable modules
│   ├── networking/             # VPC, subnets, IGW, NAT Gateway
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── compute/                # EC2, security groups, key pairs
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── database/               # RDS PostgreSQL, Secrets Manager
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── environments/
    ├── dev/                    # Development (minimal resources)
    │   ├── main.tf             # Calls modules
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── terraform.tfvars
    └── prod/                   # Production (full stack + database)
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── terraform.tfvars
```

**Benefits of modular structure:**
| Feature | Benefit |
|---------|---------|
| Isolated state | Each environment has its own state file |
| No conflicts | Dev changes don't affect prod |
| Reusable | Modules shared between environments |
| Safer | Can't accidentally apply wrong config |

### Packer AMIs (Recommended)

Build custom AMIs with all dependencies pre-installed for faster boot times:

```bash
cd packer

# Build web server AMI
packer init web-server.pkr.hcl
packer build -var-file=variables.pkrvars.hcl web-server.pkr.hcl
# Note the AMI ID from output (e.g., ami-0abc123...)

# Build E2E runner AMI
packer init e2e-runner.pkr.hcl
packer build -var-file=variables.pkrvars.hcl e2e-runner.pkr.hcl
# Note the AMI ID from output
```

**Benefits of Packer vs user_data:**
| Packer AMI | user_data script |
|------------|------------------|
| Boot in seconds | 5-10 min setup |
| Tested before deploy | May fail at runtime |
| Consistent every time | Package versions vary |

### Quick Start Commands

```bash
# =============================================================================
# DEVELOPMENT ENVIRONMENT
# =============================================================================
cd infra/environments/dev

terraform init
terraform plan
terraform apply

# View outputs
terraform output

# Destroy when done
terraform destroy

# =============================================================================
# PRODUCTION ENVIRONMENT (with database)
# =============================================================================
cd infra/environments/prod

terraform init
terraform plan
terraform apply

# Get database endpoint
terraform output database_endpoint

# Get credentials from Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id playwright-react-app-prod/database/credentials
```

### Enable Remote State (After First Apply)

```bash
# 1. Get the bucket name
terraform output terraform_state_bucket

# 2. Update provider.tf - uncomment backend block, add bucket name

# 3. Migrate state to S3
terraform init -migrate-state
```

### Key Terraform Concepts

| Concept | Description |
|---------|-------------|
| **Provider** | Plugin to interact with cloud (AWS, GCP, Azure) |
| **Resource** | Infrastructure component (EC2, S3, VPC) |
| **Data Source** | Read-only query (find latest AMI) |
| **Variable** | Input parameter |
| **Output** | Exported value |
| **State** | Record of what Terraform manages |
| **Module** | Reusable group of resources |

---

## 3.5 Backend API (Environment-Aware)

The application uses an Express.js backend that automatically switches data sources based on environment:

### Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   React App     │ ──► │  Express API    │ ──► │  PostgreSQL     │
│   (Frontend)    │     │  (Backend)      │     │  (prod only)    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
       │                       │
       │ E2E/Dev              │ E2E/Dev
       ▼                       ▼
┌─────────────────┐     ┌─────────────────┐
│ Local JSON data │     │ In-memory data  │
└─────────────────┘     └─────────────────┘
```

### Environment Configuration

| Environment | Frontend | Backend | Data Source |
|-------------|----------|---------|-------------|
| **E2E/Dev** | `REACT_APP_USE_LOCAL_DATA=true` | `USE_DATABASE=false` | In-memory (contacts.json) |
| **Production** | `REACT_APP_API_URL=/api` | `USE_DATABASE=true` | PostgreSQL RDS |

### Running the Backend

```bash
# Development (in-memory data)
cd server
cp .env.development .env
npm install
npm run dev

# Production (PostgreSQL)
cd server
cp .env.production .env
# Update .env with RDS credentials from Secrets Manager
npm start
```

### API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/contacts` | List all contacts |
| GET | `/api/contacts/:id` | Get single contact |
| POST | `/api/contacts` | Create contact |
| PUT | `/api/contacts/:id` | Update contact |
| DELETE | `/api/contacts/:id` | Delete contact |
| POST | `/api/contacts/reset` | Reset to initial data (dev only) |
| GET | `/health` | Health check |

### Docker Commands

```bash
# E2E Testing (frontend only, local data)
docker-compose up

# Production (frontend + API)
docker-compose --profile production up

# With database connection
USE_DATABASE=true \
DB_HOST=your-rds-endpoint.amazonaws.com \
DB_PASSWORD=from_secrets_manager \
docker-compose --profile production up
```

---

## 4. Phase 2: Docker

### Dockerfile (Multi-stage Build)

```dockerfile
# =============================================================================
# STAGE 1: Build
# =============================================================================
FROM node:18-alpine AS build

# Set working directory
WORKDIR /app

# Copy package files first (better caching)
COPY package.json yarn.lock ./

# Install dependencies
RUN yarn install --frozen-lockfile

# Copy source code
COPY . .

# Build the React app
RUN yarn build

# =============================================================================
# STAGE 2: Production
# =============================================================================
FROM nginx:1.27.0-alpine

# Copy built files from build stage
COPY --from=build /app/build /usr/share/nginx/html

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
```

### nginx.conf

```nginx
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Handle React Router (SPA routing)
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache static assets
    location /static {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
}
```

### .dockerignore

```
node_modules
build
.git
.gitignore
*.md
e2e
infra
.idea
.env.local
```

### Docker Commands

```bash
# Build image
docker build -t react-app:latest .

# Run container
docker run -d -p 3000:80 --name react-app react-app:latest

# View logs
docker logs react-app

# Stop and remove
docker stop react-app && docker rm react-app

# Push to registry
docker tag react-app:latest your-registry/react-app:latest
docker push your-registry/react-app:latest
```

---

## 5. Phase 3: Docker Compose

### docker-compose.yml

```yaml
version: '3.8'

services:
  # ==========================================================================
  # React Application
  # ==========================================================================
  react-app:
    build:
      context: .
      dockerfile: Dockerfile
    image: react-app:latest
    container_name: react-app
    ports:
      - "80:80"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    networks:
      - app-network

  # ==========================================================================
  # E2E Tests (Optional - run with --profile test)
  # ==========================================================================
  e2e-tests:
    image: mcr.microsoft.com/playwright:v1.40.0-focal
    container_name: playwright-tests
    volumes:
      - ./e2e:/app/e2e
      - ./playwright.config.ts:/app/playwright.config.ts
      - ./package.json:/app/package.json
    working_dir: /app
    environment:
      - BASE_URL=http://react-app
    depends_on:
      react-app:
        condition: service_healthy
    command: npx playwright test
    profiles:
      - test
    networks:
      - app-network

networks:
  app-network:
    driver: bridge
```

### Docker Compose Commands

```bash
# Start application
docker-compose up -d

# View logs
docker-compose logs -f

# Run with E2E tests
docker-compose --profile test up

# Stop all
docker-compose down

# Rebuild and start
docker-compose up -d --build

# Remove volumes too
docker-compose down -v
```

---

## 6. Phase 4: Kubernetes

### k8s/namespace.yaml

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: react-app
  labels:
    app: react-app
    environment: production
```

### k8s/deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: react-app
  namespace: react-app
  labels:
    app: react-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: react-app
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: react-app
    spec:
      containers:
        - name: react-app
          image: your-registry/react-app:latest
          imagePullPolicy: Always
          ports:
            - containerPort: 80
              protocol: TCP
          resources:
            requests:
              memory: "64Mi"
              cpu: "100m"
            limits:
              memory: "128Mi"
              cpu: "200m"
          livenessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 10
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 3
```

### k8s/service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: react-app-service
  namespace: react-app
  labels:
    app: react-app
spec:
  type: ClusterIP
  selector:
    app: react-app
  ports:
    - name: http
      port: 80
      targetPort: 80
      protocol: TCP
```

### k8s/ingress.yaml

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: react-app-ingress
  namespace: react-app
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
    - hosts:
        - your-domain.com
      secretName: react-app-tls
  rules:
    - host: your-domain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: react-app-service
                port:
                  number: 80
```

### Kubernetes Commands

```bash
# Apply all manifests
kubectl apply -f k8s/

# Check status
kubectl get all -n react-app

# View pods
kubectl get pods -n react-app

# View logs
kubectl logs -f deployment/react-app -n react-app

# Scale deployment
kubectl scale deployment react-app --replicas=5 -n react-app

# Delete all
kubectl delete -f k8s/
```

---

## 7. Phase 5: Helm

### Create Helm Chart

```bash
helm create react-app-chart
```

### helm/react-app-chart/values.yaml

```yaml
# Default values for react-app-chart

replicaCount: 3

image:
  repository: your-registry/react-app
  tag: "latest"
  pullPolicy: IfNotPresent

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  create: false
  name: ""

podAnnotations: {}
podSecurityContext: {}
securityContext: {}

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: your-domain.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: react-app-tls
      hosts:
        - your-domain.com

resources:
  limits:
    cpu: 200m
    memory: 128Mi
  requests:
    cpu: 100m
    memory: 64Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80

nodeSelector: {}
tolerations: []
affinity: {}

# Environment-specific values
env:
  - name: NODE_ENV
    value: production
```

### Helm Commands

```bash
# Install chart
helm install react-app ./helm/react-app-chart -n react-app --create-namespace

# Upgrade release
helm upgrade react-app ./helm/react-app-chart -n react-app

# With custom values
helm upgrade react-app ./helm/react-app-chart -n react-app \
  --set image.tag=v1.2.3 \
  --set replicaCount=5

# Rollback
helm rollback react-app 1 -n react-app

# Uninstall
helm uninstall react-app -n react-app

# List releases
helm list -n react-app

# Show values
helm get values react-app -n react-app
```

---

## 8. Phase 6: ArgoCD

### Install ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Access at: https://localhost:8080 (username: admin)
```

### argocd/application.yaml

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: react-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  
  source:
    repoURL: https://gitlab.com/your-username/react-app.git
    targetRevision: main
    path: helm/react-app-chart
    helm:
      valueFiles:
        - values.yaml
        - values-prod.yaml
  
  destination:
    server: https://kubernetes.default.svc
    namespace: react-app
  
  syncPolicy:
    automated:
      prune: true      # Delete resources not in Git
      selfHeal: true   # Auto-fix drift from desired state
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### ArgoCD Commands

```bash
# Apply application
kubectl apply -f argocd/application.yaml

# Install ArgoCD CLI
brew install argocd

# Login
argocd login localhost:8080

# List apps
argocd app list

# Sync app manually
argocd app sync react-app

# Get app status
argocd app get react-app
```

---

## 9. Phase 7: GitLab CI/CD

### .gitlab-ci.yml

```yaml
# =============================================================================
# GitLab CI/CD Pipeline for React App
# =============================================================================

stages:
  - test
  - build
  - deploy-staging
  - e2e-test
  - deploy-production

# =============================================================================
# Variables
# =============================================================================
variables:
  DOCKER_IMAGE: $CI_REGISTRY_IMAGE
  DOCKER_TAG: $CI_COMMIT_SHORT_SHA
  DOCKER_TLS_CERTDIR: "/certs"

# =============================================================================
# Cache
# =============================================================================
cache:
  key: ${CI_COMMIT_REF_SLUG}
  paths:
    - node_modules/

# =============================================================================
# STAGE: Test
# =============================================================================
unit-tests:
  stage: test
  image: node:18-alpine
  script:
    - yarn install --frozen-lockfile
    - yarn test --coverage --watchAll=false
  coverage: /All files[^|]*\|[^|]*\s+([\d\.]+)/
  artifacts:
    when: always
    reports:
      junit: junit.xml
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml
    expire_in: 7 days

lint:
  stage: test
  image: node:18-alpine
  script:
    - yarn install --frozen-lockfile
    - yarn lint
  allow_failure: true

# =============================================================================
# STAGE: Build
# =============================================================================
build-image:
  stage: build
  image: docker:24.0.5
  services:
    - docker:24.0.5-dind
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - docker build -t $DOCKER_IMAGE:$DOCKER_TAG -t $DOCKER_IMAGE:latest .
    - docker push $DOCKER_IMAGE:$DOCKER_TAG
    - docker push $DOCKER_IMAGE:latest
  only:
    - main
    - develop

# =============================================================================
# STAGE: Deploy Staging
# =============================================================================
deploy-staging:
  stage: deploy-staging
  image: alpine/helm:3.12.0
  before_script:
    - apk add --no-cache kubectl
    - echo "$KUBE_CONFIG" | base64 -d > /tmp/kubeconfig
    - export KUBECONFIG=/tmp/kubeconfig
  script:
    - helm upgrade --install react-app ./helm/react-app-chart
      --namespace react-app-staging
      --create-namespace
      --set image.repository=$DOCKER_IMAGE
      --set image.tag=$DOCKER_TAG
      --set ingress.hosts[0].host=staging.your-domain.com
      --wait
      --timeout 5m
  environment:
    name: staging
    url: https://staging.your-domain.com
  only:
    - develop

# =============================================================================
# STAGE: E2E Tests
# =============================================================================
e2e-tests:
  stage: e2e-test
  image: mcr.microsoft.com/playwright:v1.40.0-focal
  variables:
    BASE_URL: https://staging.your-domain.com
  script:
    - cd e2e
    - npm ci
    - npx playwright install
    - npx playwright test
  artifacts:
    when: always
    paths:
      - e2e/playwright-report/
      - e2e/test-results/
    expire_in: 7 days
  only:
    - develop
  needs:
    - deploy-staging

# =============================================================================
# STAGE: Deploy Production
# =============================================================================
deploy-production:
  stage: deploy-production
  image: alpine/helm:3.12.0
  before_script:
    - apk add --no-cache kubectl
    - echo "$KUBE_CONFIG" | base64 -d > /tmp/kubeconfig
    - export KUBECONFIG=/tmp/kubeconfig
  script:
    - helm upgrade --install react-app ./helm/react-app-chart
      --namespace react-app-prod
      --create-namespace
      --set image.repository=$DOCKER_IMAGE
      --set image.tag=$DOCKER_TAG
      --set ingress.hosts[0].host=your-domain.com
      --set replicaCount=3
      --wait
      --timeout 5m
  environment:
    name: production
    url: https://your-domain.com
  only:
    - main
  when: manual
```

### GitLab CI/CD Variables

Set these in GitLab → Settings → CI/CD → Variables:

| Variable | Description | Protected | Masked |
|----------|-------------|-----------|--------|
| `CI_REGISTRY_USER` | Registry username | Yes | No |
| `CI_REGISTRY_PASSWORD` | Registry password | Yes | Yes |
| `KUBE_CONFIG` | Base64-encoded kubeconfig | Yes | Yes |

---

## 10. Monitoring with Prometheus & Grafana

### Overview

The monitoring stack includes:
- **Prometheus** - Metrics collection and alerting
- **Grafana** - Visualization dashboards
- **Alertmanager** - Alert routing (email, Slack)
- **Node Exporter** - Host metrics
- **cAdvisor** - Container metrics

### Quick Start

```bash
cd monitoring

# Start the monitoring stack
docker-compose up -d

# Access services:
# - Prometheus: http://localhost:9090
# - Grafana: http://localhost:3000 (admin/admin123)
# - Alertmanager: http://localhost:9093
```

### Pre-configured Alerts

| Alert | Condition | Severity |
|-------|-----------|----------|
| HighCpuUsage | CPU > 80% for 5m | Warning |
| HighMemoryUsage | Memory > 85% for 5m | Warning |
| LowDiskSpace | Disk < 15% for 5m | Warning |
| ContainerDown | Container missing for 1m | Critical |
| HighErrorRate | Errors > 5% for 5m | Critical |

### Grafana Dashboards

Pre-configured dashboards:
- **React App Dashboard** - CPU, Memory, Container metrics

Import popular dashboards by ID:
- Node Exporter Full: `1860`
- Docker Container: `893`

---

## 11. Performance Testing with k6

### Performance Environment

Performance tests require a **separate environment with a real database** to get accurate results.

```bash
# Deploy performance environment
cd infra/environments/perf
terraform init
terraform apply

# Get environment URLs
terraform output k6_env_vars
# export BASE_URL=http://x.x.x.x
# export API_URL=http://x.x.x.x:3001

# Get database credentials
aws secretsmanager get-secret-value \
  --secret-id playwright-react-app-perf/database/credentials
```

**Environment comparison:**

| Environment | Database | Multi-AZ | Purpose |
|-------------|----------|----------|---------|
| **dev** | None | - | Local development, E2E tests |
| **perf** | PostgreSQL | No | Performance/load testing |
| **prod** | PostgreSQL | Yes | Production workloads |

### Test Types

| Test | Purpose | Duration | VUs |
|------|---------|----------|-----|
| **Smoke** | Verify system works | 1 min | 1 |
| **Load** | Test expected load | 10 min | 50 |
| **Stress** | Find breaking point | 15 min | 200+ |
| **Spike** | Test sudden traffic | 8 min | 300 |
| **Soak** | Test stability | 1 hour | 50 |

### Quick Start

```bash
# Install k6
brew install k6

# Run smoke test
cd performance
k6 run scripts/smoke-test.js

# Run load test against staging
BASE_URL=https://staging.example.com \
API_URL=https://api.staging.example.com \
k6 run scripts/load-test.js

# Run with Docker
docker-compose run --rm k6 run /scripts/load-test.js
```

### With Real-time Visualization

```bash
cd performance

# Start InfluxDB + Grafana
docker-compose up -d influxdb grafana

# Run test with InfluxDB output
k6 run --out influxdb=http://localhost:8086/k6 scripts/load-test.js

# View results at http://localhost:3001
```

### CI/CD Integration

```yaml
# GitLab CI
performance-test:
  stage: performance
  image: grafana/k6:0.47.0
  script:
    - k6 run --out json=results.json performance/scripts/smoke-test.js
  artifacts:
    paths:
      - results.json
```

### Thresholds

| Test | P95 Response | Error Rate |
|------|--------------|------------|
| Smoke | < 500ms | < 1% |
| Load | < 1000ms | < 5% |
| Stress | < 3000ms | < 15% |
| Spike | < 5000ms | < 25% |
| Soak | < 1500ms | < 2% |

---

## 12. Best Practices

### Security

- [ ] Restrict SSH CIDR to your IP only
- [ ] Use secrets management (AWS Secrets Manager, HashiCorp Vault)
- [ ] Enable S3 bucket encryption
- [ ] Use private subnets for databases
- [ ] Rotate credentials regularly
- [ ] Enable AWS CloudTrail for auditing

### Cost Optimization

- [ ] Use spot instances for E2E tests
- [ ] Set up auto-scaling
- [ ] Use S3 lifecycle policies
- [ ] Monitor with AWS Cost Explorer
- [ ] Right-size EC2 instances

### Reliability

- [ ] Deploy across multiple AZs
- [ ] Set up health checks
- [ ] Configure auto-scaling
- [ ] Use blue-green deployments
- [ ] Set up monitoring (CloudWatch, Prometheus)

### Monitoring

```bash
# AWS CloudWatch
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=i-1234567890 \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Average
```

---

## Quick Reference

### Common Commands

```bash
# Terraform
terraform init
terraform plan -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars
terraform destroy -var-file=environments/dev/terraform.tfvars

# Docker
docker build -t react-app .
docker run -d -p 80:80 react-app
docker-compose up -d

# Kubernetes
kubectl apply -f k8s/
kubectl get pods -n react-app
kubectl logs -f deployment/react-app -n react-app

# Helm
helm install react-app ./helm/react-app-chart -n react-app
helm upgrade react-app ./helm/react-app-chart -n react-app
helm rollback react-app 1 -n react-app

# ArgoCD
argocd app sync react-app
argocd app get react-app
```

### Useful Links

- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Docker Documentation](https://docs.docker.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [Helm Documentation](https://helm.sh/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)

---

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review logs: `kubectl logs`, `docker logs`, CloudWatch
3. Verify configurations match this guide
4. Check AWS console for resource status
