# Cenário 2 - Via Grafana Alloy

Este cenário demonstra a arquitetura **moderna** onde as aplicações enviam telemetria para um **agente Alloy local**, que processa e encaminha para os backends na Instância 1.

## Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                    INSTÂNCIA 1                              │
│              (Stack de Observabilidade)                     │
│                                                             │
│  ┌──────────┐  ┌────────────┐  ┌──────┐  ┌────────┐       │
│  │ Grafana  │  │ Prometheus │  │ Loki │  │ Jaeger │       │
│  └────▲─────┘  └─────▲──────┘  └───▲──┘  └────▲───┘       │
│       │              │              │          │           │
│       └──────────────┴──────────────┴──────────┘           │
└───────────────────────────────────────────────┬────────────┘
                                                │
                                                │ Remote Write
                                                │ Push / OTLP
┌───────────────────────────────────────────────┼────────────┐
│                    INSTÂNCIA 2                │            │
│                  (Aplicações)                 │            │
│                                               │            │
│  ┌──────────────┐         ┌──────────────┐   │            │
│  │   Frontend   │         │   Backend    │   │            │
│  │  + OTel SDK  │────────►│  + OTel SDK  │   │            │
│  │   Node.js    │  HTTP   │   Python     │   │            │
│  └──────┬───────┘         └──────┬───────┘   │            │
│         │                        │            │            │
│         │ OTLP                   │ OTLP       │            │
│         │ (local)                │ (local)    │            │
│         └────────────┬───────────┘            │            │
│                      │                        │            │
│               ┌──────▼──────┐                 │            │
│               │    Alloy    │─────────────────┘            │
│               │   (Agent)   │  Processa e                  │
│               │   :4318     │  encaminha                   │
│               └─────────────┘                              │
│                      │                                     │
│               ┌──────▼───────┐                             │
│               │  PostgreSQL  │                             │
│               │    Redis     │                             │
│               └──────────────┘                             │
└─────────────────────────────────────────────────────────────┘
```

## Características

### ✅ Vantagens
- **Buffer local**: Telemetria armazenada localmente antes de enviar
- **Resiliência**: Continua funcionando mesmo com falha de rede
- **Processamento local**: Filtragem e transformação antes de enviar
- **Otimização de rede**: Batch e compressão de dados
- **Ideal para**: Produção, muitos serviços, alta disponibilidade

### ⚠️ Desvantagens
- **Mais componentes**: Alloy adiciona complexidade
- **Mais recursos**: CPU e memória para o Alloy
- **Configuração**: Arquivo de configuração Alloy (River format)
- **Overhead**: Processamento adicional no agente

## Componentes

### Instância 2 (Este Cenário)

#### Grafana Alloy
- **Portas**: 4318 (OTLP HTTP), 4317 (OTLP gRPC), 12345 (UI)
- **Função**: Agente de coleta e roteamento
- **Recebe de**: Frontend e Backend (local)
- **Envia para**: Prometheus, Loki, Jaeger (Instância 1)
- **Configuração**: `alloy-config.alloy` (River format)

#### Frontend Service (Node.js + Express)
- **Porta**: 3001
- **Instrumentação**: OpenTelemetry SDK para Node.js
- **Envia para**: Alloy local (localhost:4318)
- **Telemetria**: Traces, métricas HTTP, logs

#### Backend Service (Python + Flask)
- **Porta**: 5000
- **Instrumentação**: OpenTelemetry SDK para Python
- **Envia para**: Alloy local (localhost:4318)
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
   - Portas 9090, 3100, 4318 liberadas da Instância 2 → Instância 1

### Passo 1: Clonar repositório

```bash
git clone <repo-url>
cd <repo-name>
git checkout aula-06
cd scenario-2-via-alloy
```

### Passo 2: Configurar IP da Instância 1

```bash
# Substituir OBSERVABILITY_IP pelo IP privado da Instância 1
export OBSERVABILITY_IP="10.0.1.100"  # Exemplo

# Atualizar alloy-config.alloy
sed -i "s/OBSERVABILITY_IP/${OBSERVABILITY_IP}/g" alloy-config.alloy

# Verificar
grep OBSERVABILITY_IP alloy-config.alloy
```

### Passo 3: Iniciar aplicações + Alloy

```bash
# Build e start
docker-compose up -d --build

# Verificar status
docker-compose ps

# Ver logs
docker-compose logs -f
```

### Passo 4: Verificar Alloy

```bash
# Health check do Alloy
curl http://localhost:12345/-/healthy

# Ver configuração carregada
curl http://localhost:12345/api/v0/web/config

# Ver componentes ativos
curl http://localhost:12345/api/v0/web/components
```

### Passo 5: Testar aplicações

```bash
# Health check
curl http://localhost:3001/health
curl http://localhost:5000/health

# Testar endpoints
curl http://localhost:3001/api/users
curl http://localhost:3001/api/orders
curl http://localhost:3001/api/products
```

### Passo 6: Verificar telemetria no Grafana

1. Acesse Grafana: http://IP_INSTANCIA_1:3000
2. Login: admin / admin123
3. Explore → Prometheus → Query: `http_server_request_duration_count`
4. Explore → Loki → Query: `{service_name="backend-service"}`
5. Explore → Jaeger → Service: `frontend-service`

## Configuração do Alloy

O arquivo `alloy-config.alloy` usa o formato **River** (linguagem de configuração do Alloy):

### Estrutura

```
┌─────────────┐
│  Receivers  │  ← Recebe OTLP das apps
└──────┬──────┘
       │
┌──────▼──────┐
│ Processors  │  ← Processa (batch, attributes)
└──────┬──────┘
       │
┌──────▼──────┐
│  Exporters  │  → Envia para backends
└─────────────┘
```

### Receivers

```alloy
otelcol.receiver.otlp "default" {
  http {
    endpoint = "0.0.0.0:4318"
  }
  grpc {
    endpoint = "0.0.0.0:4317"
  }
  output {
    metrics = [otelcol.processor.batch.default.input]
    logs    = [otelcol.processor.batch.default.input]
    traces  = [otelcol.processor.batch.default.input]
  }
}
```

### Processors

```alloy
// Batch - agrupa telemetria para eficiência
otelcol.processor.batch "default" {
  timeout          = "5s"
  send_batch_size  = 100
  output { ... }
}

// Attributes - adiciona atributos comuns
otelcol.processor.attributes "default" {
  action {
    key    = "deployment.environment"
    value  = "production"
    action = "insert"
  }
  output { ... }
}
```

### Exporters

```alloy
// Prometheus - Remote Write
prometheus.remote_write "default" {
  endpoint {
    url = "http://OBSERVABILITY_IP:9090/api/v1/write"
  }
}

// Loki - Push API
loki.write "default" {
  endpoint {
    url = "http://OBSERVABILITY_IP:3100/loki/api/v1/push"
  }
}

// Jaeger - OTLP
otelcol.exporter.otlp "jaeger" {
  client {
    endpoint = "OBSERVABILITY_IP:4318"
  }
}
```

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

### Alloy UI (porta 12345)

```bash
# Health check
GET http://localhost:12345/-/healthy

# Configuração
GET http://localhost:12345/api/v0/web/config

# Componentes
GET http://localhost:12345/api/v0/web/components

# Métricas do Alloy
GET http://localhost:12345/metrics
```

## Variáveis de Ambiente

### Frontend

```bash
OTEL_SERVICE_NAME=frontend-service
OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
BACKEND_URL=http://backend:5000
```

### Backend

```bash
OTEL_SERVICE_NAME=backend-service
OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_LOGS_EXPORTER=otlp
OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED=true
DATABASE_URL=postgresql://appuser:apppass@postgres:5432/appdb
REDIS_URL=redis://redis:6379
```

## Monitoramento do Alloy

### Métricas do Alloy

```bash
# Endpoint de métricas
curl http://localhost:12345/metrics

# Métricas importantes:
# - alloy_otelcol_receiver_accepted_spans
# - alloy_otelcol_receiver_accepted_metric_points
# - alloy_otelcol_receiver_accepted_log_records
# - alloy_otelcol_exporter_sent_spans
# - alloy_otelcol_exporter_sent_metric_points
# - alloy_otelcol_exporter_queue_size
```

### Logs do Alloy

```bash
# Ver logs
docker-compose logs alloy

# Logs em tempo real
docker-compose logs -f alloy

# Filtrar por nível
docker-compose logs alloy | grep "level=error"
```

## Visualização no Grafana

### Métricas (Prometheus)

```promql
# Requisições por segundo
rate(http_server_request_duration_count{service_name="frontend-service"}[1m])

# Latência P95
histogram_quantile(0.95, 
  rate(http_server_request_duration_bucket{service_name="backend-service"}[5m])
)

# Taxa de erro
sum(rate(http_server_request_duration_count{http_status_code=~"5.."}[5m])) 
/ 
sum(rate(http_server_request_duration_count[5m]))

# Verificar atributo do Alloy
http_server_request_duration_count{telemetry_agent="alloy"}
```

### Logs (Loki)

```logql
# Logs do backend
{service_name="backend-service"}

# Logs com atributo do Alloy
{telemetry_agent="alloy"}

# Logs com erro
{service_name="backend-service"} |= "error"

# Taxa de logs
rate({service_name="backend-service"}[1m])
```

### Traces (Jaeger)

1. Service: `frontend-service`
2. Operation: `GET /api/users`
3. Verificar tags: `deployment.environment=production`, `telemetry.agent=alloy`

## Troubleshooting

### Alloy não inicia

```bash
# Ver logs
docker-compose logs alloy

# Verificar configuração
docker-compose exec alloy cat /etc/alloy/config.alloy

# Testar sintaxe (localmente)
alloy fmt alloy-config.alloy
```

### Aplicações não enviam para Alloy

```bash
# Verificar se Alloy está escutando
docker-compose exec alloy netstat -tulpn | grep 4318

# Testar conectividade
docker-compose exec backend curl http://alloy:4318

# Ver logs das apps
docker-compose logs backend
docker-compose logs frontend
```

### Alloy não envia para backends

```bash
# Verificar logs do Alloy
docker-compose logs alloy | grep "error"

# Verificar métricas do Alloy
curl http://localhost:12345/metrics | grep exporter_sent

# Testar conectividade com backends (Instância 1)
docker-compose exec alloy curl http://OBSERVABILITY_IP:9090/-/healthy
docker-compose exec alloy curl http://OBSERVABILITY_IP:3100/ready
docker-compose exec alloy curl http://OBSERVABILITY_IP:4318
```

### Erro de configuração do Alloy

```bash
# Validar sintaxe
alloy fmt alloy-config.alloy

# Ver erros de configuração
docker-compose logs alloy | grep "config"

# Recarregar configuração
docker-compose restart alloy
```

## Comandos Úteis

```bash
# Parar aplicações
docker-compose down

# Rebuild
docker-compose up -d --build

# Ver logs em tempo real
docker-compose logs -f

# Ver logs do Alloy
docker-compose logs -f alloy

# Reiniciar Alloy
docker-compose restart alloy

# Executar comando no Alloy
docker-compose exec alloy sh

# Ver uso de recursos
docker stats

# Limpar tudo (CUIDADO: perde dados)
docker-compose down -v
```

## Testes de Resiliência

### Teste 1: Falha de rede

```bash
# Simular falha de rede (bloquear Instância 1)
# No Security Group, remover temporariamente as regras

# Gerar tráfego
curl http://localhost:3001/api/users

# Verificar buffer do Alloy
curl http://localhost:12345/metrics | grep queue_size

# Restaurar rede
# Adicionar regras novamente no Security Group

# Verificar se telemetria foi enviada
# Checar Grafana
```

### Teste 2: Sobrecarga

```bash
# Gerar carga alta
hey -n 10000 -c 50 http://localhost:3001/api/users

# Monitorar Alloy
docker stats alloy

# Verificar métricas
curl http://localhost:12345/metrics | grep dropped
```

## Comparação com Cenário 1

| Aspecto | Cenário 1 (Collector) | Cenário 2 (Este) |
|---------|----------------------|------------------|
| **Componentes** | 4 (apps + DBs) | 5 (apps + DBs + Alloy) |
| **Latência** | Rede direta | Buffer local |
| **Resiliência** | Baixa | Alta |
| **Complexidade** | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Processamento** | Remoto | Local + Remoto |
| **Buffer** | Não | Sim |
| **Ideal para** | Dev, poucos serviços | Prod, muitos serviços |

[Ver comparação detalhada](../docs/comparison-scenarios.md)

## Próximos Passos

- Comparar com [Cenário 1 - Via Collector](../scenario-1-via-collector/README.md)
- Ler [Guia do Grafana Alloy](../docs/alloy-guide.md)
- Customizar processamento no Alloy
- Configurar alertas baseados em métricas do Alloy

## Recursos Adicionais

- [Guia de OpenTelemetry](../docs/opentelemetry-guide.md)
- [Guia do Grafana Alloy](../docs/alloy-guide.md)
- [Comparação de Cenários](../docs/comparison-scenarios.md)
- [Alloy Documentation](https://grafana.com/docs/alloy/)
- [River Language](https://grafana.com/docs/alloy/latest/concepts/configuration-syntax/)
