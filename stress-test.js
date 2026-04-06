import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = 'https://nukaloot.com';

export const options = {
  stages: [
    { duration: '15s', target: 50 },   // warm up
    { duration: '15s', target: 100 },  // push to 100
    { duration: '30s', target: 100 },  // hold 100
    { duration: '15s', target: 200 },  // push to 200
    { duration: '30s', target: 200 },  // hold 200
    { duration: '15s', target: 300 },  // push to 300
    { duration: '30s', target: 300 },  // hold 300
    { duration: '10s', target: 0 },    // ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<5000'], // relaxed: 95% under 5s
    http_req_failed: ['rate<0.10'],    // relaxed: up to 10% errors
  },
};

const SEARCH_TERMS = ['elden ring', 'zelda', 'mario', 'god of war', 'fifa'];

export default function () {
  const query = SEARCH_TERMS[Math.floor(Math.random() * SEARCH_TERMS.length)];

  // Home page
  const home = http.get(`${BASE_URL}/`);
  check(home, { 'home 200': (r) => r.status === 200 });

  // Featured games
  const featured = http.get(`${BASE_URL}/api/games/featured`);
  check(featured, { 'featured 200': (r) => r.status === 200 });

  // Upcoming games
  const upcoming = http.get(`${BASE_URL}/api/games/upcoming`);
  check(upcoming, { 'upcoming 200': (r) => r.status === 200 });

  sleep(1);

  // Search page
  const search = http.get(`${BASE_URL}/search?q=${encodeURIComponent(query)}`);
  check(search, { 'search 200': (r) => r.status === 200 });

  // Search stream (SSE)
  const stream = http.get(`${BASE_URL}/api/search/stream?q=${encodeURIComponent(query)}&cc=co`, {
    timeout: '30s',
  });
  check(stream, { 'stream 200': (r) => r.status === 200 });

  sleep(1);
}
