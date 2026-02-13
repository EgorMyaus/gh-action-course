import http from 'k6/http';
import { check, sleep } from 'k6';

/*
 * Smoke Test
 * Purpose: Verify the system works under minimal load
 * Duration: ~1 minute
 * VUs: 1
 */

export const options = {
  vus: 1,
  duration: '1m',
  thresholds: {
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.01'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost';
const API_URL = __ENV.API_URL || 'http://localhost:3001';

export default function () {
  // Test frontend
  const frontendRes = http.get(BASE_URL);
  check(frontendRes, {
    'frontend status is 200': (r) => r.status === 200,
    'frontend loads in < 500ms': (r) => r.timings.duration < 500,
  });

  sleep(1);

  // Test API health
  const healthRes = http.get(`${API_URL}/health`);
  check(healthRes, {
    'health check status is 200': (r) => r.status === 200,
    'health check response is healthy': (r) => {
      const body = JSON.parse(r.body);
      return body.status === 'healthy';
    },
  });

  sleep(1);

  // Test API contacts endpoint
  const contactsRes = http.get(`${API_URL}/api/contacts`);
  check(contactsRes, {
    'contacts status is 200': (r) => r.status === 200,
    'contacts returns array': (r) => {
      const body = JSON.parse(r.body);
      return Array.isArray(body);
    },
  });

  sleep(1);
}
