const request = require('supertest');
const express = require('express');
const app = express();

app.get('/health', (req, res) => {
    res.json({ status: 'UP', service: 'vkyc-service' });
});

describe('vKYC Service Health Check', () => {
    it('should return status UP', async () => {
        const res = await request(app).get('/health');
        expect(res.statusCode).toEqual(200);
        expect(res.body).toHaveProperty('status', 'UP');
    });
});
