import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Counter } from 'k6/metrics';

/*
 * Soak Test (Endurance Test)
 * Purpose: Test system stability over extended period
 * Duration: ~1 hour (adjust for longer tests)
 * VUs: Constant 50
 */

const errorRate = new Rate('errors');
const requests = new Counter('total_requests');

export const options = {
  stages: [
    { duration: '5m', target: 50 },   // Ramp up
    { duration: '50m', target: 50 },  // Sustained load
    { duration: '5m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<1500', 'p(99)<3000'],
    http_req_failed: ['rate<0.02'],
    errors: ['rate<0.05'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost';
const API_URL = __ENV.API_URL || 'http://localhost:3001';

export default function () {
  requests.add(1);

  // Simulate realistic user behavior
  const actions = [
    () => http.get(BASE_URL),
    () => http.get(`${API_URL}/api/contacts`),
    () => http.get(`${API_URL}/health`),
  ];

  // Random action
  const action = actions[Math.floor(Math.random() * actions.length)];
  const res = action();

  const success = check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 2s': (r) => r.timings.duration < 2000,
  });

  if (!success) {
    errorRate.add(1);
  }

  // Random think time (1-5 seconds)
  sleep(1 + Math.random() * 4);
}

export function handleSummary(data) {
  const duration = data.state?.testRunDurationMs || 0;
  const hours = Math.floor(duration / 3600000);
  const minutes = Math.floor((duration % 3600000) / 60000);

  console.log('\n========== SOAK TEST RESULTS ==========');
  console.log(`Test duration: ${hours}h ${minutes}m`);
  console.log(`Total requests: ${data.metrics.total_requests?.values?.count || 0}`);
  console.log(`Error rate: ${((data.metrics.errors?.values?.rate || 0) * 100).toFixed(2)}%`);
  console.log(`Avg response time: ${(data.metrics.http_req_duration?.values?.avg || 0).toFixed(2)}ms`);
  console.log(`Memory leaks: Check Grafana for memory trend`);
  console.log('========================================\n');

  return {
    '/results/soak-test-summary.json': JSON.stringify(data, null, 2),
  };
}
