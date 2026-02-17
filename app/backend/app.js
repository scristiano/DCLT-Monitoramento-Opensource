const { logger } = require('./tracing');
const { SeverityNumber } = require('@opentelemetry/api-logs');

const express = require('express');
const { Pool } = require('pg');
const redis = require('redis');

const app = express();
const PORT = process.env.PORT || 5000;

app.use(express.json());

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

// Database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://appuser:apppass@postgres:5432/appdb',
});

// Redis connection
const redisClient = redis.createClient({
  url: process.env.REDIS_URL || 'redis://redis:6379',
});

redisClient.connect().catch(console.error);

// Helper function to add random delay
const randomDelay = (min, max) => {
  return new Promise(resolve => setTimeout(resolve, Math.random() * (max - min) + min));
};

app.get('/health', (req, res) => {
  emitLog(SeverityNumber.INFO, 'Health check requested');
  res.json({ status: 'healthy', service: 'backend-service' });
});

app.get('/api/users', async (req, res) => {
  emitLog(SeverityNumber.INFO, 'Fetching users from database');
  try {
    await randomDelay(10, 100);
    
    // Check cache first
    const cached = await redisClient.get('users');
    if (cached) {
      emitLog(SeverityNumber.INFO, 'Users found in cache');
      return res.json({ source: 'cache', users: JSON.parse(cached) });
    }
    
    // Query database
    const result = await pool.query('SELECT id, name, email FROM users LIMIT 10');
    const users = result.rows;
    
    // Cache for 60 seconds
    await redisClient.setEx('users', 60, JSON.stringify(users));
    
    emitLog(SeverityNumber.INFO, `Fetched ${users.length} users from database`, { count: users.length });
    res.json({ source: 'database', users });
  } catch (error) {
    emitLog(SeverityNumber.ERROR, 'Error fetching users', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/orders', async (req, res) => {
  emitLog(SeverityNumber.INFO, 'Fetching orders from database');
  try {
    await randomDelay(20, 150);
    
    const result = await pool.query(`
      SELECT o.id, o.user_id, o.total_amount, o.status, u.name 
      FROM orders o 
      JOIN users u ON o.user_id = u.id 
      LIMIT 10
    `);
    
    const orders = result.rows.map(row => ({
      id: row.id,
      user_id: row.user_id,
      total_amount: parseFloat(row.total_amount),
      status: row.status,
      user_name: row.name,
    }));
    
    emitLog(SeverityNumber.INFO, `Fetched ${orders.length} orders from database`, { count: orders.length });
    res.json({ orders });
  } catch (error) {
    emitLog(SeverityNumber.ERROR, 'Error fetching orders', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/products', async (req, res) => {
  emitLog(SeverityNumber.INFO, 'Fetching products from database');
  try {
    await randomDelay(10, 80);
    
    // Check cache first
    const cached = await redisClient.get('products');
    if (cached) {
      emitLog(SeverityNumber.INFO, 'Products found in cache');
      return res.json({ source: 'cache', products: JSON.parse(cached) });
    }
    
    // Query database
    const result = await pool.query('SELECT id, name, price, stock FROM products LIMIT 20');
    const products = result.rows.map(row => ({
      id: row.id,
      name: row.name,
      price: parseFloat(row.price),
      stock: row.stock,
    }));
    
    // Cache for 120 seconds
    await redisClient.setEx('products', 120, JSON.stringify(products));
    
    emitLog(SeverityNumber.INFO, `Fetched ${products.length} products from database`, { count: products.length });
    res.json({ source: 'database', products });
  } catch (error) {
    emitLog(SeverityNumber.ERROR, 'Error fetching products', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/orders', async (req, res) => {
  emitLog(SeverityNumber.INFO, 'Creating new order');
  try {
    const { user_id, total_amount } = req.body;
    
    if (!user_id || !total_amount) {
      emitLog(SeverityNumber.WARN, 'Missing required fields');
      return res.status(400).json({ error: 'Missing required fields' });
    }
    
    await randomDelay(50, 200);
    
    const result = await pool.query(
      'INSERT INTO orders (user_id, total_amount, status) VALUES ($1, $2, $3) RETURNING id',
      [user_id, total_amount, 'pending']
    );
    
    const order_id = result.rows[0].id;
    
    // Invalidate cache
    await redisClient.del('orders');
    
    emitLog(SeverityNumber.INFO, `Order created with ID: ${order_id}`, { order_id });
    res.status(201).json({ order_id, status: 'created' });
  } catch (error) {
    emitLog(SeverityNumber.ERROR, 'Error creating order', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

app.listen(PORT, () => {
  emitLog(SeverityNumber.INFO, `Backend service listening on port ${PORT}`, {
    port: PORT,
    database_url: process.env.DATABASE_URL,
    redis_url: process.env.REDIS_URL,
    otlp_endpoint: process.env.OTEL_EXPORTER_OTLP_ENDPOINT
  });
});
