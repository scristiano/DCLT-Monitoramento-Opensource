require('./tracing');

const express = require('express');
const axios = require('axios');
const { trace } = require('@opentelemetry/api');

const app = express();
const PORT = process.env.PORT || 3000;
const BACKEND_URL = process.env.BACKEND_URL || 'http://backend:5000';

app.use(express.json());

const tracer = trace.getTracer('frontend-service', '1.0.0');

async function callBackend(endpoint) {
  try {
    const response = await axios.get(`${BACKEND_URL}${endpoint}`, {
      timeout: 5000,
    });
    
    return response.data;
  } catch (error) {
    throw error;
  }
}

app.get('/', (req, res) => {
  res.json({
    service: 'frontend-service',
    version: '1.0.0',
    endpoints: [
      '/api/users',
      '/api/orders',
      '/api/products',
      '/health'
    ]
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'frontend-service' });
});

app.get('/api/users', async (req, res) => {
  try {
    const data = await callBackend('/api/users');
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/orders', async (req, res) => {
  try {
    const data = await callBackend('/api/orders');
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/products', async (req, res) => {
  try {
    const data = await callBackend('/api/products');
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/orders', async (req, res) => {
  try {
    const response = await axios.post(`${BACKEND_URL}/api/orders`, req.body, {
      timeout: 5000,
    });
    
    res.status(201).json(response.data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`Frontend service listening on port ${PORT}`);
  console.log(`Backend URL: ${BACKEND_URL}`);
  console.log(`OTLP Endpoint: ${process.env.OTEL_EXPORTER_OTLP_ENDPOINT}`);
});
