#!/usr/bin/env python3
# =============================================================================
# TEST APPLICATION - LOG GENERATOR
# =============================================================================
# Aplicação Flask que gera logs abundantes para demonstração do Loki
# Aula 04 - PosTech DevOps e Arquitetura Cloud - Monitoramento OpenSource
# =============================================================================

import time
import random
import logging
import threading
from datetime import datetime
from flask import Flask, request, jsonify
import os

# OpenTelemetry - tracing distribuído enviado ao Jaeger Agent
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource, SERVICE_NAME
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor

# Configurar logging
log_formatter = logging.Formatter(
    '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

# Logger para arquivo
file_handler = logging.FileHandler('/app/logs/test-app.log')
file_handler.setFormatter(log_formatter)
file_handler.setLevel(logging.INFO)

# Logger para console
console_handler = logging.StreamHandler()
console_handler.setFormatter(log_formatter)
console_handler.setLevel(logging.INFO)

# Configurar logger principal
logger = logging.getLogger('test-app')
logger.setLevel(logging.INFO)
logger.addHandler(file_handler)
logger.addHandler(console_handler)

# Configurar tracing - spans enviados via UDP (thrift compact) ao Jaeger Agent
tracer_provider = TracerProvider(
    resource=Resource.create({SERVICE_NAME: os.getenv('OTEL_SERVICE_NAME', 'test-app')})
)
tracer_provider.add_span_processor(BatchSpanProcessor(JaegerExporter(
    agent_host_name=os.getenv('JAEGER_AGENT_HOST', 'jaeger-agent'),
    agent_port=int(os.getenv('JAEGER_AGENT_PORT', '6831')),
)))
trace.set_tracer_provider(tracer_provider)
tracer = trace.get_tracer('test-app')

# Criar aplicação Flask
app = Flask(__name__)

# Gera um span para cada requisição HTTP (exceto health check, chamado a cada 30s)
FlaskInstrumentor().instrument_app(app, excluded_urls='health')

# Contador global para estatísticas
stats = {
    'requests': 0,
    'logs_generated': 0,
    'errors': 0,
    'warnings': 0,
    'start_time': datetime.now()
}

def background_activity():
    """Gera atividade em background para simular aplicação real"""
    activities = [
        "Processing user authentication",
        "Database query executed successfully",
        "Cache hit for user profile data",
        "API call to payment service",
        "File upload processing completed",
        "Email notification sent",
        "Background cleanup job started",
        "Session cleanup completed",
        "Data backup process initiated",
        "Configuration reload triggered"
    ]
    
    while True:
        try:
            # Escolher atividade e nível aleatoriamente
            activity = random.choice(activities)
            
            # 70% info, 20% warning, 10% error
            rand = random.random()
            if rand < 0.7:
                logger.info(f"Background: {activity}")
                stats['logs_generated'] += 1
            elif rand < 0.9:
                logger.warning(f"Background: {activity} - Slow response time detected")
                stats['warnings'] += 1
                stats['logs_generated'] += 1
            else:
                logger.error(f"Background: {activity} - Operation failed with timeout")
                stats['errors'] += 1
                stats['logs_generated'] += 1
            
            # Pausa aleatória entre 1-5 segundos
            time.sleep(random.uniform(1.0, 5.0))
            
        except Exception as e:
            logger.error(f"Background activity error: {str(e)}")
            time.sleep(5)

@app.route('/')
def home():
    """Página inicial da aplicação"""
    stats['requests'] += 1
    client_ip = request.environ.get('HTTP_X_REAL_IP', request.remote_addr)
    
    logger.info(f"Home page accessed from {client_ip}")
    
    uptime = datetime.now() - stats['start_time']
    
    return jsonify({
        "message": "Test Application for Log Generation - Aula 04",
        "timestamp": datetime.now().isoformat(),
        "status": "running",
        "uptime_seconds": int(uptime.total_seconds()),
        "stats": {
            "total_requests": stats['requests'],
            "logs_generated": stats['logs_generated'],
            "errors": stats['errors'],
            "warnings": stats['warnings']
        },
        "endpoints": {
            "/": "Home page with stats",
            "/generate/<count>": "Generate specific number of logs",
            "/health": "Health check endpoint",
            "/stress": "Generate continuous logs for 30 seconds",
            "/error": "Force an error for testing"
        }
    })

@app.route('/generate/<int:count>')
def generate_logs(count):
    """Gera quantidade específica de logs"""
    stats['requests'] += 1
    client_ip = request.environ.get('HTTP_X_REAL_IP', request.remote_addr)
    
    if count > 1000:
        logger.warning(f"Large log generation requested: {count} entries from {client_ip}")
        count = 1000  # Limitar para evitar sobrecarga
    
    logger.info(f"Log generation started: {count} entries requested from {client_ip}")
    
    log_types = ["info", "warning", "error"]
    messages = [
        "User login successful",
        "Data processing completed",
        "Cache invalidation triggered",
        "API response received",
        "File operation completed",
        "Database transaction committed",
        "Queue message processed",
        "Scheduled task executed"
    ]
    
    # Span filho para visualizar no Jaeger o tempo gasto na geração dos logs
    with tracer.start_as_current_span("generate-log-entries") as span:
        span.set_attribute("logs.count", count)

        for i in range(count):
            log_type = random.choices(log_types, weights=[70, 20, 10])[0]
            message = random.choice(messages)

            if log_type == "error":
                logger.error(f"Generated error {i+1}/{count}: {message} failed - Connection timeout")
                stats['errors'] += 1
            elif log_type == "warning":
                logger.warning(f"Generated warning {i+1}/{count}: {message} - Performance degraded")
                stats['warnings'] += 1
            else:
                logger.info(f"Generated info {i+1}/{count}: {message} - Operation successful")

            stats['logs_generated'] += 1

            # Pequena pausa para não sobrecarregar
            if i % 50 == 0:
                time.sleep(0.1)

    logger.info(f"Log generation completed: {count} entries generated")
    
    return jsonify({
        "message": f"Generated {count} log entries successfully",
        "timestamp": datetime.now().isoformat(),
        "breakdown": {
            "info": int(count * 0.7),
            "warning": int(count * 0.2),
            "error": int(count * 0.1)
        }
    })

@app.route('/stress')
def stress_test():
    """Gera logs continuamente por 30 segundos"""
    stats['requests'] += 1
    client_ip = request.environ.get('HTTP_X_REAL_IP', request.remote_addr)
    
    logger.info(f"Stress test started from {client_ip}")
    
    def stress_worker():
        end_time = time.time() + 30  # 30 segundos
        count = 0
        
        while time.time() < end_time:
            logger.info(f"Stress test log entry {count} - High frequency logging")
            count += 1
            stats['logs_generated'] += 1
            time.sleep(0.2)  # 5 logs por segundo
        
        logger.info(f"Stress test completed - Generated {count} logs in 30 seconds")
    
    # Executar em thread separada para não bloquear resposta
    thread = threading.Thread(target=stress_worker, daemon=True)
    thread.start()
    
    return jsonify({
        "message": "Stress test started - will generate logs for 30 seconds",
        "timestamp": datetime.now().isoformat(),
        "frequency": "5 logs per second"
    })

@app.route('/error')
def force_error():
    """Força um erro para teste"""
    stats['requests'] += 1
    client_ip = request.environ.get('HTTP_X_REAL_IP', request.remote_addr)
    
    logger.error(f"Forced error triggered from {client_ip}")
    stats['errors'] += 1
    
    # Simular diferentes tipos de erro
    error_types = [
        "Database connection failed",
        "External API timeout",
        "File not found",
        "Permission denied",
        "Memory allocation failed"
    ]
    
    error_msg = random.choice(error_types)
    logger.error(f"Simulated error: {error_msg}")
    
    return jsonify({
        "error": error_msg,
        "timestamp": datetime.now().isoformat(),
        "status": "error_simulated"
    }), 500

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "uptime_seconds": int((datetime.now() - stats['start_time']).total_seconds())
    })

if __name__ == '__main__':
    # Iniciar atividade em background
    logger.info("Starting test application...")
    logger.info("Initializing background activity generator...")
    
    bg_thread = threading.Thread(target=background_activity, daemon=True)
    bg_thread.start()
    
    logger.info("Test application ready - listening on port 5000")
    
    # Executar aplicação
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)