const express = require('express');
const { Pool } = require('pg');
const mongoose = require('mongoose');
const { createClient } = require('redis');
const cors = require('cors');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3002;

// Postgres Connection (Status)
const pgPool = new Pool({
    host: process.env.PG_HOST,
    user: process.env.PG_USER,
    password: process.env.PG_PASSWORD,
    database: process.env.PG_DATABASE,
    port: process.env.PG_PORT || 5432,
});

// MongoDB Connection (Details)
mongoose.connect(process.env.MONGO_URI, {
    useNewUrlParser: true,
    useUnifiedTopology: true,
}).then(() => console.log('Connected to MongoDB'))
    .catch(err => console.error('MongoDB connection error:', err));

const VkycSchema = new mongoose.Schema({
    sessionId: String,
    agentId: String,
    customerName: String,
    recordingUrl: String,
    timestamp: { type: Date, default: Date.now }
});
const VkycModel = mongoose.model('VkycData', VkycSchema);

// Redis Connection (Cache/Session)
const redisClient = createClient({
    url: process.env.REDIS_URL
});
redisClient.on('error', err => console.error('Redis Client Error', err));
redisClient.connect().then(() => console.log('Connected to Redis'));

// Routes
app.get('/health', (req, res) => {
    res.json({ status: 'UP', service: 'vkyc-service' });
});

app.post('/api/vkyc/initiate', async (req, res) => {
    const { customerName } = req.body;
    const sessionId = `vkyc-${Date.now()}`;

    try {
        // 1. Create Session in Redis
        await redisClient.set(`vkyc:session:${sessionId}`, JSON.stringify({ customerName, status: 'INITIATED' }), {
            EX: 1800 // 30 mins
        });

        res.json({ sessionId, message: 'vKYC Session Initiated' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

app.post('/api/vkyc/complete', async (req, res) => {
    const { sessionId, agentId, recordingUrl } = req.body;

    try {
        // 1. Retrieve Session
        const sessionData = await redisClient.get(`vkyc:session:${sessionId}`);
        if (!sessionData) {
            return res.status(404).json({ error: 'Session not found or expired' });
        }
        const { customerName } = JSON.parse(sessionData);

        // 2. Store Details in MongoDB
        const newRecord = new VkycModel({ sessionId, agentId, customerName, recordingUrl });
        await newRecord.save();

        // 3. Update Status in Postgres
        await pgPool.query(`CREATE TABLE IF NOT EXISTS kyc_status (
      id SERIAL PRIMARY KEY,
      aadhaar VARCHAR(20) UNIQUE,
      status VARCHAR(20),
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )`);

        // Assuming sessionId maps to a user, but for demo we just insert a record
        // In real app, we would link this to the user's ID

        // 4. Update Cache
        await redisClient.del(`vkyc:session:${sessionId}`);

        res.json({ status: 'COMPLETED', message: 'vKYC completed successfully' });

    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

app.listen(PORT, () => {
    console.log(`vKYC Service running on port ${PORT}`);
});
