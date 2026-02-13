import http from 'k6/http';
import { check, sleep } from 'k6';

/*
 * Spike Test
 * Purpose: Test system behavior under sudden traffic spikes
 * Duration: ~8 minutes
 * VUs: Sudden spike to 300
 */

export const options = {
  stages: [
    { duration: '1m', target: 10 },    // Baseline
    { duration: '30s', target: 300 },  // Spike!
    { duration: '1m', target: 300 },   // Stay at spike
    { duration: '30s', target: 10 },   // Scale down
    { duration: '2m', target: 10 },    // Recovery period
    { duration: '1m', target: 0 },     // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<5000'],
    http_req_failed: ['rate<0.25'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost';
const API_URL = __ENV.API_URL || 'http://localhost:3001';

export default function () {
  const responses = http.batch([
    ['GET', BASE_URL, null, { tags: { name: 'frontend' } }],
    ['GET', `${API_URL}/api/contacts`, null, { tags: { name: 'api-contacts' } }],
    ['GET', `${API_URL}/health`, null, { tags: { name: 'api-health' } }],
  ]);

  responses.forEach((res, i) => {
    check(res, {
      'status is not 5xx': (r) => r.status < 500,
    });
  });

  sleep(0.3);
}

export function handleSummary(data) {
  console.log('\n========== SPIKE TEST RESULTS ==========');
  console.log(`Peak VUs: ${data.metrics.vus_max?.values?.value || 0}`);
  console.log(`Total requests: ${data.metrics.http_reqs?.values?.count || 0}`);
  console.log(`Failed requests: ${data.metrics.http_req_failed?.values?.passes || 0}`);
  console.log(`Avg response time: ${(data.metrics.http_req_duration?.values?.avg || 0).toFixed(2)}ms`);
  console.log(`P95 response time: ${(data.metrics.http_req_duration?.values?.['p(95)'] || 0).toFixed(2)}ms`);
  console.log('=========================================\n');

  return {
    '/results/spike-test-summary.json': JSON.stringify(data, null, 2),
  };
}
