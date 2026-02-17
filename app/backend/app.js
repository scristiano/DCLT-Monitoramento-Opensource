require('./tracing');

const express = require('express');
const { Pool } = require('pg');
const redis = require('redis');

const app = express();
const PORT = process.env.PORT || 5000;

app.use(express.json());

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
  console.log('Health check requested');
  res.json({ status: 'healthy', service: 'backend-service' });
});

app.get('/api/users', async (req, res) => {
  console.log('Fetching users from database');
  try {
    await randomDelay(10, 100);
    
    // Check cache first
    const cached = await redisClient.get('users');
    if (cached) {
      console.log('Users found in cache');
      return res.json({ source: 'cache', users: JSON.parse(cached) });
    }
    
    // Query database
    const result = await pool.query('SELECT id, name, email FROM users LIMIT 10');
    const users = result.rows;
    
    // Cache for 60 seconds
    await redisClient.setEx('users', 60, JSON.stringify(users));
    
    console.log(`Fetched ${users.length} users from database`);
    res.json({ source: 'database', users });
  } catch (error) {
    console.error('Error fetching users:', error);
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/orders', async (req, res) => {
  console.log('Fetching orders from database');
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
    
    console.log(`Fetched ${orders.length} orders from database`);
    res.json({ orders });
  } catch (error) {
    console.error('Error fetching orders:', error);
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/products', async (req, res) => {
  console.log('Fetching products from database');
  try {
    await randomDelay(10, 80);
    
    // Check cache first
    const cached = await redisClient.get('products');
    if (cached) {
      console.log('Products found in cache');
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
    
    console.log(`Fetched ${products.length} products from database`);
    res.json({ source: 'database', products });
  } catch (error) {
    console.error('Error fetching products:', error);
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/orders', async (req, res) => {
  console.log('Creating new order');
  try {
    const { user_id, total_amount } = req.body;
    
    if (!user_id || !total_amount) {
      console.log('Missing required fields');
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
    
    console.log(`Order created with ID: ${order_id}`);
    res.status(201).json({ order_id, status: 'created' });
  } catch (error) {
    console.error('Error creating order:', error);
    res.status(500).json({ error: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`Backend service listening on port ${PORT}`);
  console.log(`Database URL: ${process.env.DATABASE_URL}`);
  console.log(`Redis URL: ${process.env.REDIS_URL}`);
  console.log(`OTLP Endpoint: ${process.env.OTEL_EXPORTER_OTLP_ENDPOINT}`);
});
