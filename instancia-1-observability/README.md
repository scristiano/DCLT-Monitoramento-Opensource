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
- **Data Sources**: Prometheus, Loki, Jaeger (pré-configurados)

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

Os data sources são **automaticamente provisionados** via `grafana-datasources.yml`:

- ✅ **Prometheus**: http://prometheus:9090
- ✅ **Loki**: http://loki:3100
- ✅ **Jaeger**: http://jaeger:16686

Para verificar:
1. Acesse Grafana
2. Menu → Connections → Data sources
3. Teste cada data source

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
Provisionamento automático dos data sources.

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
