import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate } from 'k6/metrics';

// Custom Metrics
const errorRate = new Rate('errors');

// Options & Scenarios
export const options = {
    discardResponseBodies: false,
    scenarios: {
        // 1. Smoke Test: Minimal load to verify system functions
        smoke: {
            executor: 'constant-vus',
            vus: 1,
            duration: '30s',
            tags: { test_type: 'smoke' },
        },
        // 2. Load Test: Standard day-to-day traffic
        load: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: [
                { duration: '2m', target: 50 },  // Ramp up
                { duration: '5m', target: 50 },  // Stay at 50 users
                { duration: '1m', target: 0 },   // Ramp down
            ],
            gracefulStop: '30s',
            startTime: '30s', // runs after smoke
            tags: { test_type: 'load' },
        },
        // 3. Stress Test: Push system to limits
        stress: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: [
                { duration: '1m', target: 100 },
                { duration: '2m', target: 200 }, // Heavy load
                { duration: '1m', target: 0 },
            ],
            startTime: '8m30s', // runs after load
            tags: { test_type: 'stress' },
        },
    },
    thresholds: {
        // Global Thresholds
        http_req_duration: ['p(95)<500'], // 95% of requests must be faster than 500ms
        'http_req_duration{test_type:smoke}': ['p(99)<200'], // Smoke test must be very fast
        'errors': ['rate<0.01'], // Error rate must be < 1%
    },
};

// Simulated Data
const PAYLOAD = JSON.stringify({
    aadhaar: '123456789012',
    name: 'Performance Tester'
});

const HEADERS = {
    'Content-Type': 'application/json',
};

export default function () {
    group('API Health Check', () => {
        const res = http.get('http://ekyc-service:3001/health');
        check(res, {
            'status is 200': (r) => r.status === 200,
        }) || errorRate.add(1);
    });

    group('eKYC Verification Flow', () => {
        // Simulate real user think time
        sleep(1);

        const res = http.post('http://ekyc-service:3001/api/ekyc/verify', PAYLOAD, { headers: HEADERS });

        const success = check(res, {
            'status is 200': (r) => r.status === 200,
            'response has verified status': (r) => r.json('status') === 'VERIFIED',
        });

        if (!success) {
            errorRate.add(1);
        }
    });
}
