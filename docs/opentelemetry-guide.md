# Guia Completo de OpenTelemetry

OpenTelemetry (OTel) é um framework de observabilidade open-source que fornece APIs, SDKs e ferramentas para coletar, processar e exportar telemetria (métricas, logs e traces) de aplicações.

## O que é OpenTelemetry?

OpenTelemetry é o resultado da fusão de dois projetos: **OpenTracing** (traces) e **OpenCensus** (métricas). É mantido pela Cloud Native Computing Foundation (CNCF) e é o segundo projeto mais ativo da CNCF, atrás apenas do Kubernetes.

### Objetivos

- **Telemetria unificada**: Um único padrão para métricas, logs e traces
- **Vendor-neutral**: Não depende de fornecedores específicos
- **Instrumentação consistente**: Mesma API para diferentes linguagens
- **Extensível**: Suporta múltiplos backends e exporters

## Conceitos Fundamentais

### 1. Sinais de Telemetria (Signals)

OpenTelemetry trabalha com três tipos de sinais:

#### Traces (Rastreamento)
- **O que é**: Representa o caminho de uma requisição através de sistemas distribuídos
- **Componentes**: Spans (unidades de trabalho) organizados em uma árvore
- **Uso**: Debugging, análise de latência, identificação de gargalos

```
Trace: Requisição GET /api/users
├── Span: frontend-service (100ms)
│   ├── Span: HTTP GET backend (80ms)
│   │   ├── Span: Query PostgreSQL (50ms)
│   │   └── Span: Redis GET (10ms)
│   └── Span: Render response (20ms)
```

#### Metrics (Métricas)
- **O que é**: Medições numéricas agregadas ao longo do tempo
- **Tipos**: Counter, Gauge, Histogram, Summary
- **Uso**: Monitoramento, alertas, dashboards

```
http_requests_total{service="backend", status="200"} 1523
http_request_duration_seconds{service="backend", quantile="0.95"} 0.234
```

#### Logs
- **O que é**: Registros textuais de eventos com timestamp
- **Formato**: Estruturado (JSON) ou não estruturado (texto)
- **Uso**: Debugging, auditoria, análise de eventos

```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "level": "INFO",
  "service": "backend-service",
  "message": "User created successfully",
  "user_id": 123
}
```

### 2. Componentes do OpenTelemetry

```
┌─────────────────────────────────────────────────────────────┐
│                      Aplicação                              │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              OpenTelemetry API                       │  │
│  │  (Interface para instrumentação)                     │  │
│  └────────────────────────┬─────────────────────────────┘  │
│                           │                                 │
│  ┌────────────────────────▼─────────────────────────────┐  │
│  │              OpenTelemetry SDK                       │  │
│  │  (Implementação, processamento, exportação)          │  │
│  └────────────────────────┬─────────────────────────────┘  │
│                           │                                 │
│  ┌────────────────────────▼─────────────────────────────┐  │
│  │              Exporters                               │  │
│  │  (OTLP, Prometheus, Jaeger, etc.)                    │  │
│  └────────────────────────┬─────────────────────────────┘  │
└───────────────────────────┼─────────────────────────────────┘
                            │
                            ▼
              ┌─────────────────────────┐
              │  OpenTelemetry Collector│
              │  ou Backend direto      │
              └─────────────────────────┘
```

#### API
- Interface estável para instrumentação
- Não muda entre versões
- Usada por bibliotecas e frameworks

#### SDK
- Implementação da API
- Configurável e extensível
- Processa e exporta telemetria

#### Exporters
- Enviam telemetria para backends
- Suportam múltiplos protocolos
- Exemplos: OTLP, Prometheus, Jaeger, Zipkin

#### Collector (Opcional)
- Pipeline de processamento de telemetria
- Recebe, processa e exporta dados
- Vendor-neutral e extensível

### 3. Instrumentação

#### Instrumentação Automática
- **O que é**: Bibliotecas que instrumentam código automaticamente
- **Vantagens**: Rápido, sem modificar código
- **Desvantagens**: Menos controle, overhead

**Exemplo Python**:
```bash
opentelemetry-instrument python app.py
```

**Exemplo Node.js**:
```javascript
require('./tracing');  // Configura auto-instrumentação
const app = require('./app');
```

#### Instrumentação Manual
- **O que é**: Adicionar código de instrumentação manualmente
- **Vantagens**: Controle total, spans customizados
- **Desvantagens**: Mais trabalho, manutenção

**Exemplo Python**:
```python
from opentelemetry import trace

tracer = trace.get_tracer(__name__)

with tracer.start_as_current_span("process_order"):
    # Seu código aqui
    span = trace.get_current_span()
    span.set_attribute("order.id", order_id)
```

**Exemplo Node.js**:
```javascript
const { trace } = require('@opentelemetry/api');

const tracer = trace.getTracer('my-service');

tracer.startActiveSpan('process-order', (span) => {
  // Seu código aqui
  span.setAttribute('order.id', orderId);
  span.end();
});
```

## Protocolo OTLP

**OTLP** (OpenTelemetry Protocol) é o protocolo nativo do OpenTelemetry.

### Características

- **Binário eficiente**: Usa Protocol Buffers (protobuf)
- **Múltiplos transportes**: HTTP, gRPC
- **Todos os sinais**: Métricas, logs e traces
- **Vendor-neutral**: Padrão da indústria

### Endpoints

```
# gRPC
OTEL_EXPORTER_OTLP_ENDPOINT=http://collector:4317

# HTTP
OTEL_EXPORTER_OTLP_ENDPOINT=http://collector:4318
```

### Formato

```protobuf
message ExportTraceServiceRequest {
  repeated ResourceSpans resource_spans = 1;
}

message ResourceSpans {
  Resource resource = 1;
  repeated ScopeSpans scope_spans = 2;
}
```

## Context Propagation

**Context Propagation** permite correlacionar telemetria entre serviços.

### Como Funciona

```
Frontend                    Backend
   │                           │
   ├─ Span A (trace_id: 123)   │
   │  └─ HTTP Request ─────────►│
   │     Headers:               │
   │     traceparent: 00-123... │
   │                            │
   │                            ├─ Span B (trace_id: 123)
   │                            │  parent: Span A
   │                            │
   │◄─────── Response ──────────┤
   │                            │
```

### Headers

**W3C Trace Context** (padrão):
```
traceparent: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01
             │  │                                │                │
             │  └─ Trace ID                     └─ Span ID       └─ Flags
             └─ Version
```

## Semantic Conventions

**Semantic Conventions** são padrões para nomear atributos e métricas.

### Exemplos

#### HTTP
```
http.method = "GET"
http.url = "https://api.example.com/users"
http.status_code = 200
http.route = "/users"
```

#### Database
```
db.system = "postgresql"
db.name = "appdb"
db.statement = "SELECT * FROM users"
db.operation = "SELECT"
```

#### Service
```
service.name = "backend-service"
service.version = "1.0.0"
service.namespace = "production"
```

## Sampling

**Sampling** reduz o volume de traces coletados.

### Tipos

#### Head Sampling (no SDK)
- Decisão tomada **antes** de criar o trace
- Baseado em probabilidade ou taxa
- Mais eficiente, menos flexível

```python
from opentelemetry.sdk.trace.sampling import TraceIdRatioBased

# Coletar 10% dos traces
sampler = TraceIdRatioBased(0.1)
```

#### Tail Sampling (no Collector)
- Decisão tomada **depois** de ver o trace completo
- Baseado em regras (erro, latência, etc.)
- Mais flexível, mais overhead

```yaml
processors:
  tail_sampling:
    policies:
      - name: errors
        type: status_code
        status_code: {status_codes: [ERROR]}
      - name: slow
        type: latency
        latency: {threshold_ms: 1000}
```

## Arquiteturas Comuns

### 1. Direto para Backend

```
App + SDK ──OTLP──► Prometheus
                  ► Loki
                  ► Jaeger
```

**Vantagens**: Simples, menos componentes
**Desvantagens**: Acoplamento, sem processamento

### 2. Via Collector (Cenário 1)

```
App + SDK ──OTLP──► Collector ──► Prometheus
                                ► Loki
                                ► Jaeger
```

**Vantagens**: Processamento centralizado, desacoplamento
**Desvantagens**: Ponto único de falha, latência de rede

### 3. Via Agente Local (Cenário 2)

```
App + SDK ──OTLP──► Alloy (local) ──► Prometheus
                                    ► Loki
                                    ► Jaeger
```

**Vantagens**: Buffer local, resiliência, processamento local
**Desvantagens**: Mais componentes, mais recursos

## Melhores Práticas

### 1. Instrumentação

- ✅ Use instrumentação automática quando possível
- ✅ Adicione spans customizados para lógica de negócio
- ✅ Use semantic conventions
- ✅ Adicione atributos relevantes aos spans
- ❌ Não crie spans demais (overhead)
- ❌ Não adicione dados sensíveis (PII)

### 2. Naming

```python
# ✅ Bom
span_name = "GET /api/users"
span_name = "query_users_table"

# ❌ Ruim
span_name = "GET /api/users/123"  # ID específico
span_name = "function_1"          # Não descritivo
```

### 3. Atributos

```python
# ✅ Bom
span.set_attribute("http.method", "GET")
span.set_attribute("user.id", user_id)

# ❌ Ruim
span.set_attribute("user.email", email)  # PII
span.set_attribute("password", pwd)      # Sensível
```

### 4. Sampling

- ✅ Use sampling em produção (reduz custos)
- ✅ Sempre colete traces com erro
- ✅ Colete traces lentos (tail sampling)
- ❌ Não use sampling em desenvolvimento

### 5. Performance

- ✅ Use batch export (não síncrono)
- ✅ Configure timeouts adequados
- ✅ Monitore overhead do SDK
- ❌ Não bloqueie a aplicação esperando export

## Configuração via Variáveis de Ambiente

```bash
# Serviço
OTEL_SERVICE_NAME=backend-service
OTEL_SERVICE_VERSION=1.0.0

# Endpoint
OTEL_EXPORTER_OTLP_ENDPOINT=http://collector:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf

# Exporters
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_LOGS_EXPORTER=otlp

# Sampling
OTEL_TRACES_SAMPLER=traceidratio
OTEL_TRACES_SAMPLER_ARG=0.1  # 10%

# Resource attributes
OTEL_RESOURCE_ATTRIBUTES=deployment.environment=production,service.namespace=api
```

## Troubleshooting

### Telemetria não aparece

1. Verificar se SDK está inicializado
2. Verificar variáveis de ambiente
3. Verificar conectividade com backend
4. Verificar logs do SDK (debug mode)

```bash
# Python
OTEL_LOG_LEVEL=debug python app.py

# Node.js
OTEL_LOG_LEVEL=debug node app.js
```

### Performance degradada

1. Verificar sampling (pode estar coletando demais)
2. Verificar batch size (pode estar muito pequeno)
3. Verificar timeout de export
4. Monitorar CPU/memória do SDK

### Traces incompletos

1. Verificar context propagation
2. Verificar se todos os serviços usam mesmo trace_id
3. Verificar headers HTTP (traceparent)
4. Verificar sampling (pode estar descartando spans)

## Recursos Adicionais

- [OpenTelemetry Official Docs](https://opentelemetry.io/docs/)
- [OTLP Specification](https://github.com/open-telemetry/opentelemetry-proto)
- [Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/)
- [W3C Trace Context](https://www.w3.org/TR/trace-context/)
- [Guia do OTel Collector](./otel-collector-guide.md)
- [Guia de Instrumentação](./instrumentation-otel.md)
