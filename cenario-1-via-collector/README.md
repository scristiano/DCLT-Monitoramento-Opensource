# Cenário 1 - Via OpenTelemetry Collector

Este cenário demonstra a arquitetura **tradicional** onde as aplicações enviam telemetria **diretamente** para o OpenTelemetry Collector na Instância 1.

> **📁 Nota sobre a estrutura**: As aplicações (backend, frontend, database) estão no diretório `../app/` e são compartilhadas entre os cenários 1 e 2. Isso evita duplicação de código e facilita a manutenção.

## Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                    INSTÂNCIA 1                              │
│              (Stack de Observabilidade)                     │
│                                                             │
│  ┌──────────┐  ┌────────────┐  ┌──────┐  ┌────────┐       │
│  │ Grafana  │  │ Prometheus │  │ Loki │  │ Jaeger │       │
│  └────┬─────┘  └─────┬──────┘  └───┬──┘  └────┬───┘       │
│       └──────────────┴──────────────┴──────────┘           │
│                      │                                     │
│               ┌──────▼──────┐                              │
│               │   OTel      │                              │
│               │ Collector   │ ◄─────────────────┐          │
│               │   :4319     │                   │          │
│               └─────────────┘                   │          │
└─────────────────────────────────────────────────┼──────────┘
                                                  │
                                                  │ OTLP
                                                  │ (direto)
┌─────────────────────────────────────────────────┼──────────┐
│                    INSTÂNCIA 2                  │          │
│                  (Aplicações)                   │          │
│                                                 │          │
│  ┌──────────────┐         ┌──────────────┐     │          │
│  │   Frontend   │         │   Backend    │     │          │
│  │  + OTel SDK  │────────►│  + OTel SDK  │─────┘          │
│  │   Node.js    │  HTTP   │   Python     │                │
│  └──────────────┘         └──────┬───────┘                │
│                                  │                         │
│                           ┌──────▼───────┐                 │
│                           │  PostgreSQL  │                 │
│                           │    Redis     │                 │
│                           └──────────────┘                 │
└─────────────────────────────────────────────────────────────┘
```

## Características

### ✅ Vantagens
- **Simplicidade**: Menos componentes na Instância 2
- **Configuração direta**: Apps apontam direto para o Collector
- **Menos overhead**: Sem agente intermediário
- **Ideal para**: Desenvolvimento, poucos serviços, ambientes simples

### ⚠️ Desvantagens
- **Dependência de rede**: Falha na rede = perda de telemetria
- **Sem buffer local**: Telemetria não é armazenada localmente
- **Latência de rede**: Cada requisição atravessa a rede
- **Menos flexível**: Processamento apenas no Collector remoto

## Componentes

### Instância 2 (Este Cenário)

#### Frontend Service (Node.js + Express)
- **Porta**: 3001
- **Instrumentação**: OpenTelemetry SDK para Node.js
- **Envia para**: OTel Collector (Instância 1:4319)
- **Telemetria**: Traces, métricas HTTP, logs

#### Backend Service (Python + Flask)
- **Porta**: 5000
- **Instrumentação**: OpenTelemetry SDK para Python
- **Envia para**: OTel Collector (Instância 1:4319)
- **Telemetria**: Traces, métricas HTTP, logs, queries SQL

#### PostgreSQL
- **Porta**: 5432 (interna)
- **Banco**: appdb
- **Dados**: Usuários, pedidos, produtos

#### Redis
- **Porta**: 6379 (interna)
- **Função**: Cache de dados

#### Traffic Generator
- **Função**: Gera tráfego automático para testes
- **Endpoints**: /api/users, /api/orders, /api/products

## Setup

### Pré-requisitos

1. **Instância 1 configurada e rodando**
   - Ver [guia da Instância 1](../instancia-1-observability/README.md)
   - Anotar o IP privado da Instância 1

2. **Docker e Docker Compose instalados**
   ```bash
   docker --version
   docker-compose --version
   ```

3. **Conectividade entre instâncias**
   - Security Groups configurados
   - Porta 4319 liberada da Instância 2 → Instância 1

### Passo 1: Clonar repositório

```bash
git clone -b aula-06 https://github.com/Ed-Carlos-Marinho/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource.git PosTech
cd PosTech
cd cenario-1-via-collector
```

### Passo 2: Configurar IP da Instância 1

```bash
# Substituir OBSERVABILITY_IP pelo IP privado da Instância 1
export OBSERVABILITY_IP="10.0.1.100"  # Exemplo

# Atualizar docker-compose.yml
sed -i "s/OBSERVABILITY_IP/${OBSERVABILITY_IP}/g" docker-compose.yml

# Verificar
grep OBSERVABILITY_IP docker-compose.yml
```

### Passo 3: Iniciar aplicações

```bash
# Build e start
docker-compose up -d --build

# Verificar status
docker-compose ps

# Ver logs
docker-compose logs -f
```

### Passo 4: Testar aplicações

```bash
# Health check
curl http://localhost:3001/health
curl http://localhost:5000/health

# Testar endpoints
curl http://localhost:3001/api/users
curl http://localhost:3001/api/orders
curl http://localhost:3001/api/products
```

### Passo 5: Verificar telemetria no Grafana

1. Acesse Grafana: http://IP_INSTANCIA_1
2. Login: admin / admin123
3. Explore → Prometheus → Query: `http_server_duration_milliseconds_count`
4. Explore → Loki → Query: `{service_name="backend-service"}`
5. Explore → Jaeger → Service: `frontend-service`

## Endpoints da Aplicação

### Frontend (porta 3001)

```bash
# Home
GET http://localhost:3001/

# Health check
GET http://localhost:3001/health

# Listar usuários
GET http://localhost:3001/api/users

# Listar pedidos
GET http://localhost:3001/api/orders

# Listar produtos
GET http://localhost:3001/api/products

# Criar pedido
POST http://localhost:3001/api/orders
Content-Type: application/json
{
  "user_id": 1,
  "total_amount": 99.99
}
```

### Backend (porta 5000)

```bash
# Health check
GET http://localhost:5000/health

# Listar usuários (com cache Redis)
GET http://localhost:5000/api/users

# Listar pedidos (com JOIN)
GET http://localhost:5000/api/orders

# Listar produtos (com cache Redis)
GET http://localhost:5000/api/products

# Criar pedido
POST http://localhost:5000/api/orders
Content-Type: application/json
{
  "user_id": 1,
  "total_amount": 99.99
}
```

## Variáveis de Ambiente

### Frontend

```bash
OTEL_SERVICE_NAME=frontend-service
OTEL_EXPORTER_OTLP_ENDPOINT=http://OBSERVABILITY_IP:4319
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
BACKEND_URL=http://backend:5000
```

### Backend

```bash
OTEL_SERVICE_NAME=backend-service
OTEL_EXPORTER_OTLP_ENDPOINT=http://OBSERVABILITY_IP:4319
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_LOGS_EXPORTER=otlp
OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED=true
DATABASE_URL=postgresql://appuser:apppass@postgres:5432/appdb
REDIS_URL=redis://redis:6379
```

## Instrumentação OpenTelemetry

### Frontend (Node.js)

O frontend usa **instrumentação automática** via `tracing.js`:

```javascript
// tracing.js
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { OTLPMetricExporter } = require('@opentelemetry/exporter-metrics-otlp-http');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter(),
  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter(),
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();
```

**Instrumentações automáticas**:
- HTTP/HTTPS (cliente e servidor)
- Express
- Axios
- DNS, Net, etc.

### Backend (Python)

O backend usa **instrumentação automática** via `opentelemetry-instrument`:

```dockerfile
# Dockerfile
CMD ["opentelemetry-instrument", "python", "app.py"]
```

**Instrumentações automáticas**:
- Flask
- psycopg2 (PostgreSQL)
- redis
- requests
- logging

## Visualização no Grafana

### Métricas (Prometheus)

```promql
# Requisições por segundo
rate(http_server_duration_milliseconds_count{service_name="frontend-service"}[1m])

# Latência P95
histogram_quantile(0.95, 
  rate(http_server_duration_milliseconds_bucket{service_name="backend-service"}[5m])
)

# Taxa de erro
sum(rate(http_server_duration_milliseconds_count{http_status_code=~"5.."}[5m])) 
/ 
sum(rate(http_server_duration_milliseconds_count[5m]))
```

### Logs (Loki)

```logql
# Logs do backend
{service_name="backend-service"}

# Logs com erro
{service_name="backend-service"} |= "error"

# Logs de queries SQL
{service_name="backend-service"} |= "SELECT"

# Taxa de logs
rate({service_name="backend-service"}[1m])
```

### Traces (Jaeger)

1. Service: `frontend-service`
2. Operation: `GET /api/users`
3. Visualizar:
   - Span do frontend
   - Span da chamada HTTP para backend
   - Span do backend
   - Span da query SQL
   - Span do Redis

## Troubleshooting

### Aplicações não enviam telemetria

```bash
# Verificar logs
docker-compose logs backend
docker-compose logs frontend

# Verificar variáveis de ambiente
docker-compose exec backend env | grep OTEL
docker-compose exec frontend env | grep OTEL

# Testar conectividade com Collector
docker-compose exec backend curl http://OBSERVABILITY_IP:4319
```

### Erro de conexão com Collector

```bash
# Verificar se Collector está rodando (Instância 1)
curl http://IP_INSTANCIA_1:4319

# Verificar Security Group
# Porta 4319 deve estar liberada da Instância 2 → Instância 1

# Verificar logs do Collector (Instância 1)
docker-compose logs otel-collector
```

### Banco de dados não conecta

```bash
# Verificar status do PostgreSQL
docker-compose exec postgres pg_isready -U appuser -d appdb

# Ver logs
docker-compose logs postgres

# Conectar manualmente
docker-compose exec postgres psql -U appuser -d appdb
```

### Redis não conecta

```bash
# Verificar status
docker-compose exec redis redis-cli ping

# Ver logs
docker-compose logs redis
```

## Comandos Úteis

```bash
# Parar aplicações
docker-compose down

# Rebuild
docker-compose up -d --build

# Ver logs em tempo real
docker-compose logs -f

# Ver logs de um serviço específico
docker-compose logs -f backend

# Reiniciar serviço
docker-compose restart backend

# Executar comando no container
docker-compose exec backend bash

# Ver uso de recursos
docker stats

# Limpar tudo (CUIDADO: perde dados)
docker-compose down -v
```

## Testes de Carga

```bash
# Instalar hey (load testing)
go install github.com/rakyll/hey@latest

# Teste de carga no frontend
hey -n 1000 -c 10 http://localhost:3001/api/users

# Teste de carga no backend
hey -n 1000 -c 10 http://localhost:5000/api/users

# Monitorar no Grafana durante o teste
```

## Comparação com Cenário 2

| Aspecto | Cenário 1 (Este) | Cenário 2 (Alloy) |
|---------|------------------|-------------------|
| **Componentes** | 4 (apps + DBs) | 5 (apps + DBs + Alloy) |
| **Latência** | Rede direta | Buffer local |
| **Resiliência** | Baixa | Alta |
| **Complexidade** | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Processamento** | Remoto | Local + Remoto |
| **Ideal para** | Dev, poucos serviços | Prod, muitos serviços |

[Ver comparação detalhada](../docs/comparison-scenarios.md)

## Próximos Passos

- Explorar [Cenário 2 - Via Alloy](../cenario-2-via-alloy/README.md)
- Ler [Guia de Instrumentação](../docs/instrumentation-otel.md)
- Criar dashboards customizados no Grafana
- Configurar alertas no Prometheus

## Recursos Adicionais

- [Guia de OpenTelemetry](../docs/opentelemetry-guide.md)
- [Guia do OTel Collector](../docs/otel-collector-guide.md)
- [Comparação de Cenários](../docs/comparison-scenarios.md)
- [OpenTelemetry Docs](https://opentelemetry.io/docs/)
