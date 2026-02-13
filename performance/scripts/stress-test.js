import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

/*
 * Stress Test
 * Purpose: Find the breaking point of the system
 * Duration: ~15 minutes
 * VUs: Ramp up to 200+
 */

const errorRate = new Rate('errors');

export const options = {
  stages: [
    { duration: '2m', target: 50 },    // Warm up
    { duration: '3m', target: 100 },   // Increase load
    { duration: '3m', target: 150 },   // Push further
    { duration: '3m', target: 200 },   // Stress point
    { duration: '2m', target: 250 },   // Breaking point?
    { duration: '2m', target: 0 },     // Recovery
  ],
  thresholds: {
    http_req_duration: ['p(95)<3000'],
    http_req_failed: ['rate<0.15'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost';
const API_URL = __ENV.API_URL || 'http://localhost:3001';

export default function () {
  // Frontend request
  const frontendRes = http.get(BASE_URL, { timeout: '10s' });
  check(frontendRes, {
    'frontend is available': (r) => r.status === 200 || r.status === 503,
  }) || errorRate.add(1);

  // API request
  const apiRes = http.get(`${API_URL}/api/contacts`, { timeout: '10s' });
  check(apiRes, {
    'API is available': (r) => r.status === 200 || r.status === 503,
  }) || errorRate.add(1);

  sleep(0.5);
}

export function handleSummary(data) {
  const passed = data.metrics.checks?.values?.passes || 0;
  const failed = data.metrics.checks?.values?.fails || 0;
  const total = passed + failed;
  
  console.log('\n========== STRESS TEST RESULTS ==========');
  console.log(`Max VUs reached: ${data.metrics.vus_max?.values?.value || 0}`);
  console.log(`Total checks: ${total} (${passed} passed, ${failed} failed)`);
  console.log(`Error rate: ${((failed / total) * 100).toFixed(2)}%`);
  console.log(`Avg response time: ${(data.metrics.http_req_duration?.values?.avg || 0).toFixed(2)}ms`);
  console.log(`Max response time: ${(data.metrics.http_req_duration?.values?.max || 0).toFixed(2)}ms`);
  console.log('==========================================\n');

  return {
    '/results/stress-test-summary.json': JSON.stringify(data, null, 2),
  };
}
