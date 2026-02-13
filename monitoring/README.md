# Monitoring with Prometheus & Grafana

## Overview

This directory contains a complete monitoring stack:
- **Prometheus** - Metrics collection and storage
- **Grafana** - Visualization and dashboards
- **Alertmanager** - Alert routing and notifications
- **Node Exporter** - Host metrics
- **cAdvisor** - Container metrics

## Quick Start

```bash
cd monitoring

# Start the monitoring stack
docker-compose up -d

# Access services:
# - Prometheus: http://localhost:9090
# - Grafana: http://localhost:3000 (admin/admin123)
# - Alertmanager: http://localhost:9093
```

## Architecture

```
┌─────────────────┐     ┌─────────────────┐
│   React App     │     │   Express API   │
│   (Frontend)    │     │   (Backend)     │
└────────┬────────┘     └────────┬────────┘
         │                       │
         │     metrics           │  metrics
         ▼                       ▼
┌─────────────────────────────────────────┐
│              Prometheus                  │
│         (Metrics Collection)             │
└────────────────┬────────────────────────┘
                 │
    ┌────────────┼────────────┐
    ▼            ▼            ▼
┌───────┐  ┌──────────┐  ┌────────────┐
│Grafana│  │Alertmgr  │  │  Storage   │
│(View) │  │(Alerts)  │  │ (15 days)  │
└───────┘  └──────────┘  └────────────┘
```

## Dashboards

### Pre-configured Dashboards

1. **React App Dashboard** - Application metrics
   - CPU, Memory, Disk usage
   - Container metrics
   - Request rates

### Importing Additional Dashboards

Popular Grafana dashboards:
- Node Exporter Full: ID `1860`
- Docker Container: ID `893`
- Prometheus Stats: ID `2`

To import: Grafana → + → Import → Enter ID

## Alerts

### Configured Alerts

| Alert | Condition | Severity |
|-------|-----------|----------|
| HighCpuUsage | CPU > 80% for 5m | Warning |
| HighMemoryUsage | Memory > 85% for 5m | Warning |
| LowDiskSpace | Disk < 15% for 5m | Warning |
| ContainerDown | Container missing for 1m | Critical |
| HighErrorRate | Errors > 5% for 5m | Critical |
| HighResponseTime | P95 > 1s for 5m | Warning |

### Configuring Email Alerts

Edit `alertmanager/alertmanager.yml`:

```yaml
receivers:
  - name: 'critical-alerts'
    email_configs:
      - to: 'your-email@example.com'
        from: 'alerts@example.com'
        smarthost: 'smtp.gmail.com:587'
        auth_username: 'your-email@gmail.com'
        auth_password: 'your-app-password'
```

### Slack Integration

```yaml
receivers:
  - name: 'critical-alerts'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
        channel: '#alerts'
        send_resolved: true
```

## Adding Custom Metrics

### Express.js API Metrics

Install prom-client:
```bash
cd server && npm install prom-client
```

Add to server:
```javascript
const client = require('prom-client');
const collectDefaultMetrics = client.collectDefaultMetrics;
collectDefaultMetrics();

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});
```

## Production Deployment

For production, consider:
- Persistent storage for Prometheus data
- HA setup with multiple Prometheus instances
- Remote write to long-term storage (Thanos, Cortex)
- Secure Grafana with proper authentication
