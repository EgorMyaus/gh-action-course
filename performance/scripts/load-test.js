import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend } from 'k6/metrics';

/*
 * Load Test
 * Purpose: Test system behavior under expected load
 * Duration: ~10 minutes
 * VUs: Ramp up to 50
 */

const errorRate = new Rate('errors');
const contactsLatency = new Trend('contacts_latency');

export const options = {
  stages: [
    { duration: '2m', target: 10 },   // Ramp up to 10 users
    { duration: '5m', target: 50 },   // Stay at 50 users
    { duration: '2m', target: 50 },   // Continue at 50
    { duration: '1m', target: 0 },    // Ramp down to 0
  ],
  thresholds: {
    http_req_duration: ['p(95)<1000', 'p(99)<2000'],
    http_req_failed: ['rate<0.05'],
    errors: ['rate<0.1'],
    contacts_latency: ['p(95)<800'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost';
const API_URL = __ENV.API_URL || 'http://localhost:3001';

export default function () {
  group('Frontend', function () {
    const res = http.get(BASE_URL);
    check(res, {
      'frontend status is 200': (r) => r.status === 200,
    }) || errorRate.add(1);
    sleep(1);
  });

  group('API - Get Contacts', function () {
    const start = Date.now();
    const res = http.get(`${API_URL}/api/contacts`);
    contactsLatency.add(Date.now() - start);
    
    check(res, {
      'contacts status is 200': (r) => r.status === 200,
      'contacts has data': (r) => {
        try {
          const body = JSON.parse(r.body);
          return Array.isArray(body) && body.length > 0;
        } catch {
          return false;
        }
      },
    }) || errorRate.add(1);
    sleep(1);
  });

  group('API - CRUD Operations', function () {
    // Create contact
    const createPayload = JSON.stringify({
      name: `Load Test User ${Date.now()}`,
      gender: 'Other',
      phone: '555-0100',
      street: '123 Test St',
      city: 'Test City',
    });

    const createRes = http.post(`${API_URL}/api/contacts`, createPayload, {
      headers: { 'Content-Type': 'application/json' },
    });
    
    check(createRes, {
      'create status is 201': (r) => r.status === 201,
    }) || errorRate.add(1);
    
    sleep(0.5);
  });

  sleep(Math.random() * 2);
}

export function handleSummary(data) {
  return {
    '/results/load-test-summary.json': JSON.stringify(data, null, 2),
    stdout: textSummary(data, { indent: ' ', enableColors: true }),
  };
}

function textSummary(data, options) {
  const metrics = data.metrics;
  let summary = '\n========== LOAD TEST SUMMARY ==========\n\n';
  
  summary += `Total Requests: ${metrics.http_reqs?.values?.count || 0}\n`;
  summary += `Failed Requests: ${metrics.http_req_failed?.values?.passes || 0}\n`;
  summary += `Avg Response Time: ${(metrics.http_req_duration?.values?.avg || 0).toFixed(2)}ms\n`;
  summary += `P95 Response Time: ${(metrics.http_req_duration?.values?.['p(95)'] || 0).toFixed(2)}ms\n`;
  summary += `P99 Response Time: ${(metrics.http_req_duration?.values?.['p(99)'] || 0).toFixed(2)}ms\n`;
  
  summary += '\n========================================\n';
  return summary;
}
