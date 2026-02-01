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
  const span = trace.getActiveSpan();
  
  try {
    span?.addEvent('Calling backend API', { endpoint });
    
    const response = await axios.get(`${BACKEND_URL}${endpoint}`, {
      timeout: 5000,
    });
    
    span?.setAttributes({
      'http.backend.status_code': response.status,
      'http.backend.endpoint': endpoint,
    });
    
    return response.data;
  } catch (error) {
    span?.recordException(error);
    span?.setStatus({ code: 2, message: error.message });
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
  return tracer.startActiveSpan('get-users', async (span) => {
    try {
      span.setAttributes({
        'http.method': 'GET',
        'http.route': '/api/users',
      });
      
      const data = await callBackend('/api/users');
      
      span.addEvent('Users fetched successfully', {
        'users.count': data.users?.length || 0,
        'data.source': data.source || 'unknown',
      });
      
      res.json(data);
    } catch (error) {
      span.recordException(error);
      span.setStatus({ code: 2, message: error.message });
      res.status(500).json({ error: error.message });
    } finally {
      span.end();
    }
  });
});

app.get('/api/orders', async (req, res) => {
  return tracer.startActiveSpan('get-orders', async (span) => {
    try {
      span.setAttributes({
        'http.method': 'GET',
        'http.route': '/api/orders',
      });
      
      const data = await callBackend('/api/orders');
      
      span.addEvent('Orders fetched successfully', {
        'orders.count': data.orders?.length || 0,
      });
      
      res.json(data);
    } catch (error) {
      span.recordException(error);
      span.setStatus({ code: 2, message: error.message });
      res.status(500).json({ error: error.message });
    } finally {
      span.end();
    }
  });
});

app.get('/api/products', async (req, res) => {
  return tracer.startActiveSpan('get-products', async (span) => {
    try {
      span.setAttributes({
        'http.method': 'GET',
        'http.route': '/api/products',
      });
      
      const data = await callBackend('/api/products');
      
      span.addEvent('Products fetched successfully', {
        'products.count': data.products?.length || 0,
        'data.source': data.source || 'unknown',
      });
      
      res.json(data);
    } catch (error) {
      span.recordException(error);
      span.setStatus({ code: 2, message: error.message });
      res.status(500).json({ error: error.message });
    } finally {
      span.end();
    }
  });
});

app.post('/api/orders', async (req, res) => {
  return tracer.startActiveSpan('create-order', async (span) => {
    try {
      span.setAttributes({
        'http.method': 'POST',
        'http.route': '/api/orders',
      });
      
      const response = await axios.post(`${BACKEND_URL}/api/orders`, req.body, {
        timeout: 5000,
      });
      
      span.addEvent('Order created successfully', {
        'order.id': response.data.order_id,
      });
      
      res.status(201).json(response.data);
    } catch (error) {
      span.recordException(error);
      span.setStatus({ code: 2, message: error.message });
      res.status(500).json({ error: error.message });
    } finally {
      span.end();
    }
  });
});

app.listen(PORT, () => {
  console.log(`Frontend service listening on port ${PORT}`);
  console.log(`Backend URL: ${BACKEND_URL}`);
  console.log(`OTLP Endpoint: ${process.env.OTEL_EXPORTER_OTLP_ENDPOINT}`);
});
