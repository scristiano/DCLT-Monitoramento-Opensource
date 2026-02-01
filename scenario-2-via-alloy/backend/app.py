from flask import Flask, jsonify, request
import psycopg2
import redis
import os
import logging
import time
import random

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://appuser:apppass@postgres:5432/appdb')
REDIS_URL = os.getenv('REDIS_URL', 'redis://redis:6379')

def get_db_connection():
    return psycopg2.connect(DATABASE_URL)

def get_redis_connection():
    return redis.from_url(REDIS_URL, decode_responses=True)

@app.route('/health', methods=['GET'])
def health():
    logger.info("Health check requested")
    return jsonify({"status": "healthy", "service": "backend-service"}), 200

@app.route('/api/users', methods=['GET'])
def get_users():
    logger.info("Fetching users from database")
    try:
        time.sleep(random.uniform(0.01, 0.1))
        redis_client = get_redis_connection()
        cached_users = redis_client.get('users')
        
        if cached_users:
            logger.info("Users found in cache")
            return jsonify({"source": "cache", "users": eval(cached_users)}), 200
        
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT id, name, email FROM users LIMIT 10")
        users = [{"id": row[0], "name": row[1], "email": row[2]} for row in cursor.fetchall()]
        cursor.close()
        conn.close()
        
        redis_client.setex('users', 60, str(users))
        logger.info(f"Fetched {len(users)} users from database")
        return jsonify({"source": "database", "users": users}), 200
    except Exception as e:
        logger.error(f"Error fetching users: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/orders', methods=['GET'])
def get_orders():
    logger.info("Fetching orders from database")
    try:
        time.sleep(random.uniform(0.02, 0.15))
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT o.id, o.user_id, o.total_amount, o.status, u.name 
            FROM orders o 
            JOIN users u ON o.user_id = u.id 
            LIMIT 10
        """)
        orders = [{"id": row[0], "user_id": row[1], "total_amount": float(row[2]), "status": row[3], "user_name": row[4]} for row in cursor.fetchall()]
        cursor.close()
        conn.close()
        logger.info(f"Fetched {len(orders)} orders from database")
        return jsonify({"orders": orders}), 200
    except Exception as e:
        logger.error(f"Error fetching orders: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/products', methods=['GET'])
def get_products():
    logger.info("Fetching products from database")
    try:
        time.sleep(random.uniform(0.01, 0.08))
        redis_client = get_redis_connection()
        cached_products = redis_client.get('products')
        
        if cached_products:
            logger.info("Products found in cache")
            return jsonify({"source": "cache", "products": eval(cached_products)}), 200
        
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT id, name, price, stock FROM products LIMIT 20")
        products = [{"id": row[0], "name": row[1], "price": float(row[2]), "stock": row[3]} for row in cursor.fetchall()]
        cursor.close()
        conn.close()
        
        redis_client.setex('products', 120, str(products))
        logger.info(f"Fetched {len(products)} products from database")
        return jsonify({"source": "database", "products": products}), 200
    except Exception as e:
        logger.error(f"Error fetching products: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/orders', methods=['POST'])
def create_order():
    logger.info("Creating new order")
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        total_amount = data.get('total_amount')
        
        if not user_id or not total_amount:
            logger.warning("Missing required fields")
            return jsonify({"error": "Missing required fields"}), 400
        
        time.sleep(random.uniform(0.05, 0.2))
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("INSERT INTO orders (user_id, total_amount, status) VALUES (%s, %s, %s) RETURNING id", (user_id, total_amount, 'pending'))
        order_id = cursor.fetchone()[0]
        conn.commit()
        cursor.close()
        conn.close()
        
        redis_client = get_redis_connection()
        redis_client.delete('orders')
        logger.info(f"Order created with ID: {order_id}")
        return jsonify({"order_id": order_id, "status": "created"}), 201
    except Exception as e:
        logger.error(f"Error creating order: {str(e)}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    logger.info("Starting backend service...")
    app.run(host='0.0.0.0', port=5000, debug=False)
