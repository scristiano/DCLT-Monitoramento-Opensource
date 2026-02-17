const { logger } = require('./tracing');
const { SeverityNumber } = require('@opentelemetry/api-logs');

const express = require('express');
const axios = require('axios');
const { trace } = require('@opentelemetry/api');

const app = express();
const PORT = process.env.PORT || 3000;
const BACKEND_URL = process.env.BACKEND_URL || 'http://backend:5000';

app.use(express.json());

const tracer = trace.getTracer('frontend-service', '1.0.0');

// Helper function to emit logs
function emitLog(severity, message, attributes = {}) {
  logger.emit({
    severityNumber: severity,
    severityText: getSeverityText(severity),
    body: message,
    attributes: attributes,
  });
  // Also log to console for debugging
  console.log(message);
}

function getSeverityText(severityNumber) {
  const severityMap = {
    [SeverityNumber.INFO]: 'INFO',
    [SeverityNumber.WARN]: 'WARN',
    [SeverityNumber.ERROR]: 'ERROR',
    [SeverityNumber.DEBUG]: 'DEBUG',
  };
  return severityMap[severityNumber] || 'INFO';
}

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
  emitLog(SeverityNumber.INFO, 'Frontend: Fetching users', { endpoint: '/api/users' });
  try {
    const data = await callBackend('/api/users');
    res.json(data);
  } catch (error) {
    emitLog(SeverityNumber.ERROR, 'Frontend: Error fetching users', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/orders', async (req, res) => {
  emitLog(SeverityNumber.INFO, 'Frontend: Fetching orders', { endpoint: '/api/orders' });
  try {
    const data = await callBackend('/api/orders');
    res.json(data);
  } catch (error) {
    emitLog(SeverityNumber.ERROR, 'Frontend: Error fetching orders', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/products', async (req, res) => {
  emitLog(SeverityNumber.INFO, 'Frontend: Fetching products', { endpoint: '/api/products' });
  try {
    const data = await callBackend('/api/products');
    res.json(data);
  } catch (error) {
    emitLog(SeverityNumber.ERROR, 'Frontend: Error fetching products', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/orders', async (req, res) => {
  emitLog(SeverityNumber.INFO, 'Frontend: Creating order', { body: req.body });
  try {
    const response = await axios.post(`${BACKEND_URL}/api/orders`, req.body, {
      timeout: 5000,
    });
    
    res.status(201).json(response.data);
  } catch (error) {
    emitLog(SeverityNumber.ERROR, 'Frontend: Error creating order', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

app.listen(PORT, () => {
  emitLog(SeverityNumber.INFO, `Frontend service listening on port ${PORT}`, {
    port: PORT,
    backend_url: BACKEND_URL,
    otlp_endpoint: process.env.OTEL_EXPORTER_OTLP_ENDPOINT
  });
});
