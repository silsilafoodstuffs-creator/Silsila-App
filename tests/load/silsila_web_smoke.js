import http from 'k6/http';
import { check, sleep } from 'k6';

const baseUrl = (__ENV.BASE_URL || 'https://silsilafoodstuffs-creator.github.io/Silsila-App').replace(/\/+$/, '');
const virtualUsers = Math.min(Math.max(Number(__ENV.VUS || 3), 1), 10);
const duration = __ENV.DURATION || '30s';

export const options = {
  vus: virtualUsers,
  duration,
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<2500'],
  },
};

export default function () {
  const page = http.get(baseUrl + '/', { tags: { endpoint: 'web-shell' } });
  check(page, {
    'web shell responds with HTTP 200': (response) => response.status === 200,
    'web shell returns HTML': (response) => (response.headers['Content-Type'] || '').includes('text/html'),
  });

  const bootstrap = http.get(baseUrl + '/flutter_bootstrap.js', {
    tags: { endpoint: 'flutter-bootstrap' },
  });
  check(bootstrap, {
    'Flutter bootstrap responds with HTTP 200': (response) => response.status === 200,
    'Flutter bootstrap is not empty': (response) => response.body.length > 0,
  });

  sleep(1);
}
