# Guia de Instrumentação OpenTelemetry

Este guia mostra como instrumentar aplicações com OpenTelemetry para coletar métricas, logs e traces.

## Conceitos de Instrumentação

### Instrumentação Automática vs Manual

#### Instrumentação Automática
- **O que é**: Bibliotecas que instrumentam código automaticamente
- **Como**: Interceptam chamadas de bibliotecas populares
- **Vantagens**: Rápido, sem modificar código, cobre casos comuns
- **Desvantagens**: Menos controle, pode ter overhead, limitado

#### Instrumentação Manual
- **O que é**: Adicionar código de instrumentação explicitamente
- **Como**: Usar APIs do OpenTelemetry diretamente
- **Vantagens**: Controle total, spans customizados, lógica de negócio
- **Desvantagens**: Mais trabalho, manutenção, pode esquecer pontos

**Recomendação**: Use automática como base + manual para lógica de negócio

## Instrumentação Python (Flask)

### Setup Inicial

```bash
# Instalar dependências
pip install opentelemetry-api \
            opentelemetry-sdk \
            opentelemetry-instrumentation-flask \
            opentelemetry-instrumentation-psycopg2 \
            opentelemetry-instrumentation-redis \
            opentelemetry-exporter-otlp
```

### Instrumentação Automática

```python
# app.py
from flask import Flask
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.psycopg2 import Psycopg2Instrumentor
from opentelemetry.instrumentation.redis import RedisInstrumentor

# Configurar provider
trace.set_tracer_provider(TracerProvider())
tracer_provider = trace.get_tracer_provider()

# Configurar exporter
otlp_exporter = OTLPSpanExporter(
    endpoint="http://collector:4318/v1/traces"
)
span_processor = BatchSpanProcessor(otlp_exporter)
tracer_provider.add_span_processor(span_processor)

# Criar app
app = Flask(__name__)

# Instrumentar automaticamente
FlaskInstrumentor().instrument_app(app)
Psycopg2Instrumentor().instrument()
RedisInstrumentor().instrument()

@app.route('/api/users')
def get_users():
    # Automaticamente instrumentado!
    return {"users": []}
```

### Instrumentação Manual (Spans Customizados)

```python
from opentelemetry import trace

tracer = trace.get_tracer(__name__)

@app.route('/api/orders')
def create_order():
    # Span customizado
    with tracer.start_as_current_span("create_order") as span:
        # Adicionar atributos
        span.set_attribute("order.user_id", user_id)
        span.set_attribute("order.amount", amount)
        
        # Lógica de negócio
        order = process_order(user_id, amount)
        
        # Adicionar evento
        span.add_event("Order created", {
            "order.id": order.id,
            "order.status": order.status
        })
        
        return {"order_id": order.id}

def process_order(user_id, amount):
    # Span aninhado
    with tracer.start_as_current_span("validate_order") as span:
        span.set_attribute("validation.user_id", user_id)
        # Validação...
    
    with tracer.start_as_current_span("save_order") as span:
        # Salvar no banco...
        pass
    
    return order
```

### Instrumentação via CLI (Mais Fácil)

```bash
# Instalar
pip install opentelemetry-distro opentelemetry-exporter-otlp

# Instalar instrumentações automaticamente
opentelemetry-bootstrap -a install

# Executar app com instrumentação
opentelemetry-instrument \
    --traces_exporter otlp \
    --metrics_exporter otlp \
    --logs_exporter otlp \
    --service_name backend-service \
    --exporter_otlp_endpoint http://collector:4318 \
    python app.py
```

### Dockerfile com Instrumentação

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Instalar dependências
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Instalar OpenTelemetry
RUN pip install opentelemetry-distro opentelemetry-exporter-otlp
RUN opentelemetry-bootstrap -a install

# Copiar código
COPY . .

# Executar com instrumentação
CMD ["opentelemetry-instrument", "python", "app.py"]
```

## Instrumentação Node.js (Express)

### Setup Inicial

```bash
# Instalar dependências
npm install @opentelemetry/sdk-node \
            @opentelemetry/auto-instrumentations-node \
            @opentelemetry/exporter-trace-otlp-http \
            @opentelemetry/exporter-metrics-otlp-http
```

### Instrumentação Automática

```javascript
// tracing.js
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { OTLPMetricExporter } = require('@opentelemetry/exporter-metrics-otlp-http');
const { PeriodicExportingMetricReader } = require('@opentelemetry/sdk-metrics');

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({
    url: 'http://collector:4318/v1/traces',
  }),
  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter({
      url: 'http://collector:4318/v1/metrics',
    }),
    exportIntervalMillis: 10000,
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();

// Graceful shutdown
process.on('SIGTERM', () => {
  sdk.shutdown()
    .then(() => console.log('Tracing terminated'))
    .catch((error) => console.log('Error terminating tracing', error))
    .finally(() => process.exit(0));
});
```

```javascript
// server.js
require('./tracing'); // IMPORTANTE: Importar ANTES do app

const express = require('express');
const app = express();

// Automaticamente instrumentado!
app.get('/api/users', (req, res) => {
  res.json({ users: [] });
});

app.listen(3000);
```

### Instrumentação Manual (Spans Customizados)

```javascript
const { trace } = require('@opentelemetry/api');

const tracer = trace.getTracer('my-service', '1.0.0');

app.get('/api/orders', async (req, res) => {
  // Span customizado
  return tracer.startActiveSpan('create-order', async (span) => {
    try {
      // Adicionar atributos
      span.setAttributes({
        'order.user_id': req.body.user_id,
        'order.amount': req.body.amount,
      });
      
      // Lógica de negócio
      const order = await processOrder(req.body);
      
      // Adicionar evento
      span.addEvent('Order created', {
        'order.id': order.id,
        'order.status': order.status,
      });
      
      res.json({ order_id: order.id });
    } catch (error) {
      // Registrar erro
      span.recordException(error);
      span.setStatus({ code: 2, message: error.message });
      res.status(500).json({ error: error.message });
    } finally {
      span.end();
    }
  });
});

async function processOrder(data) {
  // Span aninhado
  return tracer.startActiveSpan('validate-order', async (span) => {
    span.setAttribute('validation.user_id', data.user_id);
    // Validação...
    span.end();
    
    return tracer.startActiveSpan('save-order', async (span) => {
      // Salvar no banco...
      span.end();
      return { id: 123, status: 'created' };
    });
  });
}
```

### Dockerfile com Instrumentação

```dockerfile
FROM node:18-alpine

WORKDIR /app

# Instalar dependências
COPY package*.json ./
RUN npm ci --only=production

# Copiar código
COPY . .

# Executar com instrumentação
CMD ["node", "-r", "./tracing.js", "server.js"]
```

## Métricas Customizadas

### Python

```python
from opentelemetry import metrics
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter

# Configurar provider
metric_reader = PeriodicExportingMetricReader(
    OTLPMetricExporter(endpoint="http://collector:4318/v1/metrics")
)
meter_provider = MeterProvider(metric_readers=[metric_reader])
metrics.set_meter_provider(meter_provider)

# Criar meter
meter = metrics.get_meter(__name__)

# Counter
order_counter = meter.create_counter(
    "orders.created",
    description="Number of orders created",
    unit="1"
)

# Histogram
order_amount_histogram = meter.create_histogram(
    "orders.amount",
    description="Order amount distribution",
    unit="USD"
)

# Gauge (via callback)
def get_active_users():
    return len(active_users)

meter.create_observable_gauge(
    "users.active",
    callbacks=[lambda options: get_active_users()],
    description="Number of active users",
    unit="1"
)

# Usar métricas
@app.route('/api/orders', methods=['POST'])
def create_order():
    order = save_order(request.json)
    
    # Incrementar counter
    order_counter.add(1, {"status": "created"})
    
    # Registrar histogram
    order_amount_histogram.record(order.amount, {"currency": "USD"})
    
    return {"order_id": order.id}
```

### Node.js

```javascript
const { metrics } = require('@opentelemetry/api');

const meter = metrics.getMeter('my-service', '1.0.0');

// Counter
const orderCounter = meter.createCounter('orders.created', {
  description: 'Number of orders created',
  unit: '1',
});

// Histogram
const orderAmountHistogram = meter.createHistogram('orders.amount', {
  description: 'Order amount distribution',
  unit: 'USD',
});

// Gauge (via callback)
const activeUsersGauge = meter.createObservableGauge('users.active', {
  description: 'Number of active users',
  unit: '1',
});

activeUsersGauge.addCallback((result) => {
  result.observe(getActiveUsers());
});

// Usar métricas
app.post('/api/orders', async (req, res) => {
  const order = await saveOrder(req.body);
  
  // Incrementar counter
  orderCounter.add(1, { status: 'created' });
  
  // Registrar histogram
  orderAmountHistogram.record(order.amount, { currency: 'USD' });
  
  res.json({ order_id: order.id });
});
```

## Logs Estruturados

### Python

```python
import logging
from opentelemetry import trace
from opentelemetry.instrumentation.logging import LoggingInstrumentor

# Instrumentar logging
LoggingInstrumentor().instrument(set_logging_format=True)

# Configurar logger
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@app.route('/api/users')
def get_users():
    # Logs automaticamente incluem trace_id e span_id
    logger.info("Fetching users from database")
    
    try:
        users = db.query("SELECT * FROM users")
        logger.info(f"Fetched {len(users)} users")
        return {"users": users}
    except Exception as e:
        logger.error(f"Error fetching users: {str(e)}", exc_info=True)
        raise
```

### Node.js

```javascript
const { trace, context } = require('@opentelemetry/api');
const winston = require('winston');

// Configurar logger com trace context
const logger = winston.createLogger({
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json(),
    winston.format((info) => {
      const span = trace.getSpan(context.active());
      if (span) {
        const spanContext = span.spanContext();
        info.trace_id = spanContext.traceId;
        info.span_id = spanContext.spanId;
        info.trace_flags = spanContext.traceFlags;
      }
      return info;
    })()
  ),
  transports: [new winston.transports.Console()],
});

app.get('/api/users', async (req, res) => {
  // Logs incluem trace_id e span_id
  logger.info('Fetching users from database');
  
  try {
    const users = await db.query('SELECT * FROM users');
    logger.info(`Fetched ${users.length} users`);
    res.json({ users });
  } catch (error) {
    logger.error('Error fetching users', { error: error.message });
    throw error;
  }
});
```

## Context Propagation

### Propagação entre Serviços

```javascript
// Frontend (Node.js)
const axios = require('axios');
const { trace, context, propagation } = require('@opentelemetry/api');

app.get('/api/users', async (req, res) => {
  const span = trace.getActiveSpan();
  
  // Headers são automaticamente injetados pela instrumentação
  const response = await axios.get('http://backend:5000/api/users');
  
  res.json(response.data);
});
```

```python
# Backend (Python)
import requests
from opentelemetry import trace
from opentelemetry.propagate import inject

@app.route('/api/users')
def get_users():
    # Context é automaticamente extraído pela instrumentação
    span = trace.get_current_span()
    
    # Para chamadas manuais, injetar context
    headers = {}
    inject(headers)
    
    response = requests.get('http://another-service/api/data', headers=headers)
    
    return {"users": []}
```

## Melhores Práticas

### 1. Naming de Spans

```python
# ✅ Bom - Descritivo e consistente
with tracer.start_as_current_span("GET /api/users"):
with tracer.start_as_current_span("query_users_table"):
with tracer.start_as_current_span("validate_user_input"):

# ❌ Ruim - Não descritivo ou com dados variáveis
with tracer.start_as_current_span("function_1"):
with tracer.start_as_current_span(f"GET /api/users/{user_id}"):  # ID específico
```

### 2. Atributos

```python
# ✅ Bom - Semantic conventions
span.set_attribute("http.method", "GET")
span.set_attribute("http.status_code", 200)
span.set_attribute("db.system", "postgresql")
span.set_attribute("db.operation", "SELECT")

# ❌ Ruim - Dados sensíveis
span.set_attribute("user.email", "user@example.com")  # PII
span.set_attribute("user.password", "secret")  # Sensível
span.set_attribute("credit_card", "1234-5678")  # PII
```

### 3. Eventos

```python
# ✅ Bom - Eventos significativos
span.add_event("Order validated", {"order.id": order_id})
span.add_event("Payment processed", {"payment.amount": amount})
span.add_event("Email sent", {"email.type": "confirmation"})

# ❌ Ruim - Eventos demais
span.add_event("Variable x set to 5")
span.add_event("Loop iteration 1")
```

### 4. Exceções

```python
# ✅ Bom - Registrar exceções
try:
    result = risky_operation()
except Exception as e:
    span.record_exception(e)
    span.set_status(Status(StatusCode.ERROR, str(e)))
    raise

# ❌ Ruim - Ignorar exceções
try:
    result = risky_operation()
except:
    pass  # Span não sabe que houve erro
```

### 5. Performance

```python
# ✅ Bom - Batch export
BatchSpanProcessor(exporter)

# ❌ Ruim - Export síncrono
SimpleSpanProcessor(exporter)  # Bloqueia a aplicação
```

## Troubleshooting

### Telemetria não aparece

```python
# Habilitar debug
import logging
logging.basicConfig(level=logging.DEBUG)

# Verificar se SDK está inicializado
from opentelemetry import trace
print(trace.get_tracer_provider())

# Verificar exporters
print(tracer_provider._active_span_processor._span_processors)
```

### Performance degradada

```python
# Verificar sampling
from opentelemetry.sdk.trace.sampling import TraceIdRatioBased
sampler = TraceIdRatioBased(0.1)  # 10% dos traces

# Ajustar batch size
BatchSpanProcessor(
    exporter,
    max_queue_size=2048,
    max_export_batch_size=512,
    schedule_delay_millis=5000
)
```

## Recursos Adicionais

- [OpenTelemetry Python Docs](https://opentelemetry-python.readthedocs.io/)
- [OpenTelemetry JavaScript Docs](https://opentelemetry.io/docs/instrumentation/js/)
- [Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/)
- [Instrumentation Libraries](https://opentelemetry.io/ecosystem/registry/)
- [Guia de OpenTelemetry](./opentelemetry-guide.md)
