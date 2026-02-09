import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export const options = {
    scenarios: {
        load: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: [
                { duration: '1m', target: 20 },
                { duration: '3m', target: 20 },
                { duration: '1m', target: 0 },
            ],
        },
        spike: {
            executor: 'ramping-arrival-rate',
            startRate: 10,
            timeUnit: '1s',
            preAllocatedVUs: 50,
            maxVUs: 100,
            stages: [
                { duration: '10s', target: 10 },
                { duration: '20s', target: 100 }, // SPIKE!
                { duration: '10s', target: 10 },
            ],
            startTime: '5m',
        }
    },
    thresholds: {
        http_req_duration: ['p(95)<800'], // Video init might be slower
        errors: ['rate<0.05'],
    },
};

export default function () {
    const payload = JSON.stringify({ customerName: 'Load Test User' });
    const headers = { 'Content-Type': 'application/json' };

    group('vKYC Initiate', () => {
        const res = http.post('http://vkyc-service:3002/api/vkyc/initiate', payload, { headers: headers });

        check(res, {
            'status is 200': (r) => r.status === 200,
            'has session id': (r) => r.json('sessionId') !== undefined,
        }) || errorRate.add(1);
    });

    sleep(1);
}
