# Instância 1 - Stack de Observabilidade

Esta instância contém a **stack completa de observabilidade** que serve **ambos os cenários** (Cenário 1 e Cenário 2).

## Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│              INSTÂNCIA 1 - Observabilidade                  │
│                  ★ ÚNICA PARA AMBOS ★                       │
│                                                             │
│  ┌──────────┐  ┌────────────┐  ┌──────┐  ┌────────┐       │
│  │ Grafana  │  │ Prometheus │  │ Loki │  │ Jaeger │       │
│  │  :3000   │  │   :9090    │  │:3100 │  │ :16686 │       │
│  └────┬─────┘  └─────┬──────┘  └───┬──┘  └────┬───┘       │
│       │              │              │          │           │
│       └──────────────┴──────────────┴──────────┘           │
│                      │                                     │
│               ┌──────▼──────┐                              │
│               │   OTel      │                              │
│               │ Collector   │                              │
│               │   :4319     │                              │
│               └─────────────┘                              │
└─────────────────────────────────────────────────────────────┘
                      ▲
                      │
        ┌─────────────┴─────────────┐
        │                           │
   Cenário 1                   Cenário 2
   (Collector)                 (Alloy)
```

## Componentes

### 🎨 Grafana (porta 3000)
- **Função**: Visualização unificada de métricas, logs e traces
- **Acesso**: http://IP_INSTANCIA_1:3000
- **Credenciais**: admin / admin123
- **Data Sources**: Prometheus, Loki, Jaeger, Alertmanager (provisionados automaticamente)

### 📊 Prometheus (porta 9090)
- **Função**: Armazenamento e consulta de métricas
- **Acesso**: http://IP_INSTANCIA_1:9090
- **Recebe de**: OTel Collector (Cenário 1) e Alloy (Cenário 2)
- **Features**: Remote Write habilitado, Exemplar storage

### 📝 Loki (porta 3100)
- **Função**: Armazenamento e consulta de logs
- **Acesso**: http://IP_INSTANCIA_1:3100
- **Recebe de**: OTel Collector (Cenário 1) e Alloy (Cenário 2)
- **Formato**: LogQL para queries

### 🔍 Jaeger (porta 16686)
- **Função**: Armazenamento e visualização de traces
- **Acesso**: http://IP_INSTANCIA_1:16686
- **Recebe de**: OTel Collector (Cenário 1) e Alloy (Cenário 2)
- **Protocolo**: OTLP (portas 4317/4318)

### 🔄 OpenTelemetry Collector (porta 4319)
- **Função**: Pipeline central de processamento (usado no Cenário 1)
- **Acesso**: http://IP_INSTANCIA_1:4319 (OTLP HTTP)
- **Processa**: Métricas, logs e traces
- **Exporta para**: Prometheus, Loki, Jaeger

### 🚨 Alertmanager (porta 9093)
- **Função**: Gerenciamento e roteamento de alertas
- **Acesso**: http://IP_INSTANCIA_1:9093
- **Recebe de**: Prometheus
- **Notificações**: Email, Slack, PagerDuty, Webhook (configurável)

## Setup

### Pré-requisitos

- Docker e Docker Compose instalados
- Portas disponíveis: 3000, 3100, 4317, 4318, 4319, 9090, 16686
- Mínimo 4GB RAM disponível
- Security Group configurado (ver abaixo)

### Configuração do Security Group (AWS)

Libere as seguintes portas **INBOUND**:

```
Porta 3000  - TCP - 0.0.0.0/0  - Grafana UI
Porta 9090  - TCP - 0.0.0.0/0  - Prometheus UI
Porta 3100  - TCP - VPC CIDR   - Loki (interno)
Porta 16686 - TCP - 0.0.0.0/0  - Jaeger UI
Porta 4317  - TCP - VPC CIDR   - OTLP gRPC (interno)
Porta 4318  - TCP - VPC CIDR   - OTLP HTTP (interno)
Porta 4319  - TCP - VPC CIDR   - OTel Collector (interno)
```

### Passo 1: Clonar repositório

```bash
git clone <repo-url>
cd <repo-name>
git checkout aula-06
cd instancia-1-observability
```

### Passo 2: Iniciar stack

```bash
# Iniciar todos os serviços
docker-compose up -d

# Verificar status
docker-compose ps

# Ver logs
docker-compose logs -f
```

### Passo 3: Verificar serviços

```bash
# Grafana
curl http://localhost:3000/api/health

# Prometheus
curl http://localhost:9090/-/healthy

# Loki
curl http://localhost:3100/ready

# Jaeger
curl http://localhost:16686/

# OTel Collector
curl http://localhost:8888/metrics
```

### Passo 4: Acessar interfaces

1. **Grafana**: http://IP_INSTANCIA_1:3000
   - Usuário: `admin`
   - Senha: `admin123`

2. **Prometheus**: http://IP_INSTANCIA_1:9090
   - Verificar targets: Status → Targets

3. **Jaeger**: http://IP_INSTANCIA_1:16686
   - Verificar serviços disponíveis

## Configuração dos Data Sources no Grafana

Os data sources são **automaticamente provisionados** via `grafana-datasources.yml` quando o Grafana inicia:

### ✅ Datasources Automáticos

1. **Prometheus** (padrão)
   - URL: http://prometheus:9090
   - Métricas das aplicações e do OTel Collector
   - Correlação com Jaeger via exemplars

2. **Loki**
   - URL: http://loki:3100
   - Logs das aplicações
   - Extração automática de trace_id para navegação

3. **Jaeger**
   - URL: http://jaeger:16686
   - Traces distribuídos
   - Correlação com Loki (traces → logs)
   - Correlação com Prometheus (traces → métricas)

4. **Alertmanager**
   - URL: http://alertmanager:9093
   - Gerenciamento de alertas do Prometheus

## 📊 Dashboards Disponíveis

Os seguintes dashboards estão disponíveis para importação manual:

### Como Importar Dashboards

1. Acesse Grafana: http://IP_INSTANCIA_1:3000
2. Menu → Dashboards → New → Import
3. Clique em "Upload JSON file"
4. Selecione um dos arquivos JSON da pasta `dashboards/`
5. Selecione o datasource "Prometheus" quando solicitado
6. Clique em "Import"

### Dashboards Disponíveis

#### 1. Three Pillars Correlation ⭐ RECOMENDADO
- **Arquivo**: `dashboards/overview/three-pillars-correlation.json`
- **Localização sugerida**: Home (raiz)
- **Destaque**: Dashboard que integra Prometheus + Jaeger + Loki
- **Conteúdo**:
  - 📊 **Métricas** (Prometheus):
    - Request Rate por serviço
    - P95 Latency com exemplars (clique para ver traces)
    - Status Code Distribution
  - 🔍 **Traces** (Jaeger):
    - Recent Traces (clique para ver logs relacionados)
    - Navegação para métricas relacionadas
  - 📝 **Logs** (Loki):
    - Application Logs (com trace_id para correlação)
    - Error Logs filtrados
  - 🔗 **Guias de Correlação**:
    - Como navegar entre métricas → traces → logs
    - Fluxos de investigação (alta latência, erros, debugging)
- **Variável**: Filtro por serviço (padrão: frontend-service)

#### 2. Observability Overview
- **Arquivo**: `dashboards/overview/observability-overview.json`
- **Localização sugerida**: Home (raiz)
- **Conteúdo**:
  - Total Request Rate
  - Error Rate (5xx)
  - P95 Latency
  - OTel Collector Status
  - Request Rate by Service
  - Latency by Service (P50, P95, P99)
  - HTTP Status Codes Distribution
  - Top 10 Endpoints by Request Rate

#### 3. Application Monitoring
- **Arquivo**: `dashboards/applications/application-monitoring.json`
- **Localização sugerida**: Pasta "Applications"
- **Conteúdo**:
  - Request Rate (filtrado por serviço)
  - Latency (P50, P95, P99)
  - Error Rate (4xx e 5xx)
  - Requests by Status Code
  - Top 10 Endpoints by Request Rate
  - Top 10 Slowest Endpoints (P95)
- **Variável**: Filtro por serviço (padrão: frontend-service)

#### 4. OpenTelemetry Collector
- **Arquivo**: `dashboards/infrastructure/otel-collector.json`
- **Localização sugerida**: Pasta "Infrastructure"
- **Conteúdo**:
  - Collector Status
  - Spans Received/sec
  - Metrics Received/sec
  - Failed Exports/sec
  - Spans Flow (Received vs Sent)
  - Metrics Flow (Received vs Sent)
  - Exporter Queue Size
  - Errors and Failures

### 🔗 Correlação Automática

Os datasources estão configurados para navegação fluida:

- **Métricas → Traces**: Clique em exemplars no Prometheus para ver traces relacionados
- **Traces → Logs**: Clique em spans no Jaeger para ver logs relacionados
- **Traces → Métricas**: Veja métricas relacionadas a um trace específico
- **Logs → Traces**: Clique em trace_id nos logs para ver o trace completo

### Verificar Datasources

Para verificar se foram criados corretamente:
1. Acesse Grafana: http://IP_INSTANCIA_1:3000
2. Menu → Connections → Data sources
3. Todos devem aparecer com status "Working" ✅

### Recriar Datasources

Se precisar recriar os datasources:

```bash
# Remover volume do Grafana
docker compose down
docker volume rm instancia-1-observability_grafana-data

# Reiniciar (datasources serão recriados automaticamente)
docker compose up -d

# Reimportar dashboards manualmente via UI
```

## Queries de Exemplo

### Prometheus (Métricas)

```promql
# Total de requisições HTTP
sum(rate(http_server_request_duration_count[5m])) by (service_name)

# Latência P95
histogram_quantile(0.95, rate(http_server_request_duration_bucket[5m]))

# Taxa de erro
sum(rate(http_server_request_duration_count{http_status_code=~"5.."}[5m])) / sum(rate(http_server_request_duration_count[5m]))
```

### Loki (Logs)

```logql
# Logs do backend
{service_name="backend-service"}

# Logs com erro
{service_name="backend-service"} |= "error"

# Taxa de logs por minuto
rate({service_name="backend-service"}[1m])
```

### Jaeger (Traces)

1. Selecione o serviço: `frontend-service` ou `backend-service`
2. Clique em "Find Traces"
3. Explore os traces e spans

## Arquivos de Configuração

### docker-compose.yml
Define todos os serviços da stack de observabilidade.

### otel-collector-config.yml
Configuração do OpenTelemetry Collector:
- **Receivers**: OTLP (HTTP/gRPC)
- **Processors**: Batch, Resource Detection
- **Exporters**: Prometheus, Loki, Jaeger

### prometheus.yml
Configuração do Prometheus:
- Remote Write habilitado
- Exemplar storage habilitado
- Scrape do OTel Collector

### loki-config.yml
Configuração do Loki:
- Schema config
- Storage config
- Limits config

### grafana-datasources.yml
Provisionamento automático dos data sources:
- Prometheus (com correlação para Jaeger via exemplars)
- Loki (com extração de trace_id)
- Jaeger (com correlação para Loki e Prometheus)
- Alertmanager

### dashboards/
Diretório com dashboards JSON para importação manual:
- **overview/** - Dashboards de visão geral (Three Pillars Correlation, Observability Overview)
- **applications/** - Dashboard de monitoramento de aplicações
- **infrastructure/** - Dashboard de monitoramento do OTel Collector

### alertmanager.yml
Configuração do Alertmanager:
- Roteamento de alertas por severidade
- Agrupamento e inibição de alertas
- Templates para notificações (Email, Slack, PagerDuty)

## Troubleshooting

### Serviço não inicia

```bash
# Ver logs do serviço
docker-compose logs <service-name>

# Exemplo: ver logs do Grafana
docker-compose logs grafana

# Reiniciar serviço específico
docker-compose restart <service-name>
```

### Porta já em uso

```bash
# Verificar portas em uso
sudo netstat -tulpn | grep -E '3000|9090|3100|16686|4317|4318|4319'

# Parar serviço que está usando a porta
sudo kill -9 <PID>
```

### Sem dados no Grafana

1. Verifique se os cenários estão enviando telemetria
2. Verifique logs do OTel Collector: `docker-compose logs otel-collector`
3. Verifique se os data sources estão configurados corretamente
4. Teste os endpoints dos backends diretamente

### OTel Collector não recebe dados

```bash
# Ver métricas do Collector
curl http://localhost:8888/metrics | grep otelcol_receiver

# Ver logs
docker-compose logs otel-collector

# Verificar conectividade da Instância 2
# Na Instância 2, teste:
curl http://IP_INSTANCIA_1:4319
```

## Comandos Úteis

```bash
# Parar todos os serviços
docker-compose down

# Parar e remover volumes (CUIDADO: perde dados)
docker-compose down -v

# Reiniciar stack
docker-compose restart

# Ver uso de recursos
docker stats

# Limpar logs
docker-compose logs --tail=0 -f

# Backup de dados
docker run --rm -v instancia-1-observability_grafana-data:/data -v $(pwd):/backup alpine tar czf /backup/grafana-backup.tar.gz /data
```

## Monitoramento da Stack

### Métricas do OTel Collector

```bash
# Endpoint de métricas
curl http://localhost:8888/metrics

# Métricas importantes:
# - otelcol_receiver_accepted_spans
# - otelcol_receiver_accepted_metric_points
# - otelcol_receiver_accepted_log_records
# - otelcol_exporter_sent_spans
# - otelcol_exporter_sent_metric_points
# - otelcol_exporter_sent_log_records
```

### Health Checks

```bash
# Script de health check
#!/bin/bash
echo "Checking Grafana..."
curl -s http://localhost:3000/api/health | jq .

echo "Checking Prometheus..."
curl -s http://localhost:9090/-/healthy

echo "Checking Loki..."
curl -s http://localhost:3100/ready

echo "Checking Jaeger..."
curl -s http://localhost:16686/ > /dev/null && echo "OK"

echo "Checking OTel Collector..."
curl -s http://localhost:13133/ | jq .
```

## Próximos Passos

Após configurar a Instância 1, escolha um cenário para a Instância 2:

- **[Cenário 1 - Via OTel Collector](../scenario-1-via-collector/README.md)**: Mais simples, ideal para começar
- **[Cenário 2 - Via Alloy](../scenario-2-via-alloy/README.md)**: Mais robusto, ideal para produção

## Recursos Adicionais

- [Guia de OpenTelemetry](../docs/opentelemetry-guide.md)
- [Guia do OTel Collector](../docs/otel-collector-guide.md)
- [Comparação de Cenários](../docs/comparison-scenarios.md)
