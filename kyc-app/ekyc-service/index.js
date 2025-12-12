const express = require('express');
const { Pool } = require('pg');
const mongoose = require('mongoose');
const { createClient } = require('redis');
const cors = require('cors');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3001;

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

const EkycSchema = new mongoose.Schema({
    aadhaar: String,
    name: String,
    dob: String,
    address: String,
    timestamp: { type: Date, default: Date.now }
});
const EkycModel = mongoose.model('EkycData', EkycSchema);

// Redis Connection (Cache)
const redisClient = createClient({
    url: process.env.REDIS_URL
});
redisClient.on('error', err => console.error('Redis Client Error', err));
redisClient.connect().then(() => console.log('Connected to Redis'));

// Routes
app.get('/health', (req, res) => {
    res.json({ status: 'UP', service: 'ekyc-service' });
});

app.post('/api/ekyc/verify', async (req, res) => {
    const { aadhaar, name } = req.body;

    try {
        // 1. Check Cache
        const cachedStatus = await redisClient.get(`ekyc:${aadhaar}`);
        if (cachedStatus) {
            return res.json({ status: 'VERIFIED', source: 'cache', data: JSON.parse(cachedStatus) });
        }

        // 2. Store Details in MongoDB
        const newRecord = new EkycModel({ aadhaar, name });
        await newRecord.save();

        // 3. Update Status in Postgres
        // Ensure table exists (simple migration for demo)
        await pgPool.query(`CREATE TABLE IF NOT EXISTS kyc_status (
      id SERIAL PRIMARY KEY,
      aadhaar VARCHAR(20) UNIQUE,
      status VARCHAR(20),
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )`);

        await pgPool.query(
            `INSERT INTO kyc_status (aadhaar, status) VALUES ($1, $2) 
       ON CONFLICT (aadhaar) DO UPDATE SET status = $2, updated_at = CURRENT_TIMESTAMP`,
            [aadhaar, 'VERIFIED']
        );

        // 4. Update Cache
        await redisClient.set(`ekyc:${aadhaar}`, JSON.stringify({ name, status: 'VERIFIED' }), {
            EX: 3600 // 1 hour
        });

        res.json({ status: 'VERIFIED', message: 'eKYC completed successfully' });

    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

app.listen(PORT, () => {
    console.log(`eKYC Service running on port ${PORT}`);
});
