# Queries do Prometheus para Monitoramento do OpenTelemetry Collector

Guia completo de queries PromQL para verificar o funcionamento da coleta de telemetria usando o OpenTelemetry Collector.

## 📊 Índice

1. [Métricas do OTel Collector](#métricas-do-otel-collector)
2. [Métricas das Aplicações](#métricas-das-aplicações)
3. [Análise de Performance](#análise-de-performance)
4. [Troubleshooting](#troubleshooting)
5. [Alertas Recomendados](#alertas-recomendados)

---

## 🔍 Métricas do OTel Collector

### Verificar se o Collector está recebendo dados

#### Traces recebidos
```promql
# Total de spans recebidos pelo Collector
sum(rate(otelcol_receiver_accepted_spans[5m]))

# Spans recebidos por receiver (OTLP gRPC vs HTTP)
sum(rate(otelcol_receiver_accepted_spans[5m])) by (receiver)

# Spans recebidos por transporte
sum(rate(otelcol_receiver_accepted_spans[5m])) by (transport)
```

#### Métricas recebidas
```promql
# Total de métricas recebidas pelo Collector
sum(rate(otelcol_receiver_accepted_metric_points[5m]))

# Métricas recebidas por receiver
sum(rate(otelcol_receiver_accepted_metric_points[5m])) by (receiver)
```

#### Logs recebidos
```promql
# Total de logs recebidos pelo Collector
sum(rate(otelcol_receiver_accepted_log_records[5m]))

# Logs recebidos por receiver
sum(rate(otelcol_receiver_accepted_log_records[5m])) by (receiver)
```

### Verificar se o Collector está exportando dados

#### Traces exportados
```promql
# Total de spans exportados pelo Collector
sum(rate(otelcol_exporter_sent_spans[5m]))

# Spans exportados por exporter (Jaeger)
sum(rate(otelcol_exporter_sent_spans[5m])) by (exporter)

# Taxa de sucesso de exportação de spans
sum(rate(otelcol_exporter_sent_spans[5m])) 
/ 
sum(rate(otelcol_receiver_accepted_spans[5m]))
```

#### Métricas exportadas
```promql
# Total de métricas exportadas pelo Collector
sum(rate(otelcol_exporter_sent_metric_points[5m]))

# Métricas exportadas por exporter (Prometheus)
sum(rate(otelcol_exporter_sent_metric_points[5m])) by (exporter)

# Taxa de sucesso de exportação de métricas
sum(rate(otelcol_exporter_sent_metric_points[5m])) 
/ 
sum(rate(otelcol_receiver_accepted_metric_points[5m]))
```

### Verificar erros no Collector

#### Erros de recebimento
```promql
# Spans rejeitados
sum(rate(otelcol_receiver_refused_spans[5m]))

# Métricas rejeitadas
sum(rate(otelcol_receiver_refused_metric_points[5m]))

# Logs rejeitados
sum(rate(otelcol_receiver_refused_log_records[5m]))
```

#### Erros de exportação
```promql
# Falhas ao enviar spans
sum(rate(otelcol_exporter_send_failed_spans[5m]))

# Falhas ao enviar métricas
sum(rate(otelcol_exporter_send_failed_metric_points[5m]))

# Falhas ao enviar logs
sum(rate(otelcol_exporter_send_failed_log_records[5m]))
```

### Verificar fila e processamento

#### Tamanho da fila
```promql
# Tamanho atual da fila de exportação
otelcol_exporter_queue_size

# Tamanho da fila por exporter
otelcol_exporter_queue_size by (exporter)

# Capacidade da fila
otelcol_exporter_queue_capacity
```

#### Processamento em batch
```promql
# Tamanho médio dos batches enviados
rate(otelcol_processor_batch_batch_send_size_sum[5m]) 
/ 
rate(otelcol_processor_batch_batch_send_size_count[5m])

# Timeout de batches (batches enviados por timeout)
rate(otelcol_processor_batch_timeout_trigger_send[5m])

# Batches enviados por tamanho
rate(otelcol_processor_batch_batch_size_trigger_send[5m])
```

---

## 📱 Métricas das Aplicações

### HTTP Requests - Frontend e Backend

> **Nota:** As métricas HTTP do OpenTelemetry Node.js usam o nome `http_server_duration_milliseconds` (não `http_server_request_duration`). Os labels disponíveis são: `job`, `service_name`, `http_route`, `http_method`, `http_status_code`, `net_host_name`, `net_host_port`.

#### Taxa de requisições
```promql
# Total de requisições por segundo
sum(rate(http_server_duration_milliseconds_count[5m]))

# Requisições por serviço (usando label service_name)
sum(rate(http_server_duration_milliseconds_count[5m])) by (service_name)

# Requisições por job (nome do serviço no Prometheus)
sum(rate(http_server_duration_milliseconds_count[5m])) by (job)

# Requisições por endpoint
sum(rate(http_server_duration_milliseconds_count[5m])) by (http_route)

# Requisições por método HTTP
sum(rate(http_server_duration_milliseconds_count[5m])) by (http_method)

# Requisições por serviço e rota
sum(rate(http_server_duration_milliseconds_count[5m])) by (service_name, http_route)
```

#### Latência (P50, P95, P99)
```promql
# Latência P50 (mediana) - em milissegundos
histogram_quantile(0.50, 
  sum(rate(http_server_duration_milliseconds_bucket[5m])) by (le, service_name)
)

# Latência P95 - em milissegundos
histogram_quantile(0.95, 
  sum(rate(http_server_duration_milliseconds_bucket[5m])) by (le, service_name)
)

# Latência P99 - em milissegundos
histogram_quantile(0.99, 
  sum(rate(http_server_duration_milliseconds_bucket[5m])) by (le, service_name)
)

# Latência média - em milissegundos
rate(http_server_duration_milliseconds_sum[5m]) 
/ 
rate(http_server_duration_milliseconds_count[5m])

# Latência P95 por endpoint
histogram_quantile(0.95, 
  sum(rate(http_server_duration_milliseconds_bucket[5m])) by (le, http_route)
)

# Latência P99 por serviço e método HTTP
histogram_quantile(0.99, 
  sum(rate(http_server_duration_milliseconds_bucket[5m])) by (le, service_name, http_method)
)
```

#### Taxa de erro
```promql
# Taxa de erro geral (status 5xx)
sum(rate(http_server_duration_milliseconds_count{http_status_code=~"5.."}[5m])) 
/ 
sum(rate(http_server_duration_milliseconds_count[5m]))

# Taxa de erro por serviço
sum(rate(http_server_duration_milliseconds_count{http_status_code=~"5.."}[5m])) by (service_name)
/ 
sum(rate(http_server_duration_milliseconds_count[5m])) by (service_name)

# Contagem de erros 4xx por serviço
sum(rate(http_server_duration_milliseconds_count{http_status_code=~"4.."}[5m])) by (service_name)

# Contagem de erros 5xx por serviço
sum(rate(http_server_duration_milliseconds_count{http_status_code=~"5.."}[5m])) by (service_name)

# Taxa de erro por endpoint
sum(rate(http_server_duration_milliseconds_count{http_status_code=~"5.."}[5m])) by (http_route)
/ 
sum(rate(http_server_duration_milliseconds_count[5m])) by (http_route)
```

#### Distribuição de status codes
```promql
# Requisições por status code
sum(rate(http_server_duration_milliseconds_count[5m])) by (http_status_code)

# Porcentagem de cada status code
sum(rate(http_server_duration_milliseconds_count[5m])) by (http_status_code)
/ 
sum(rate(http_server_duration_milliseconds_count[5m]))
* 100

# Status codes por serviço
sum(rate(http_server_duration_milliseconds_count[5m])) by (service_name, http_status_code)
```

### Métricas de Negócio

#### Endpoints específicos
```promql
# Requisições para /api/users
sum(rate(http_server_duration_milliseconds_count{http_route="/api/users"}[5m]))

# Latência P95 do endpoint /api/orders (em milissegundos)
histogram_quantile(0.95, 
  sum(rate(http_server_duration_milliseconds_bucket{http_route="/api/orders"}[5m])) by (le)
)

# Taxa de erro do endpoint /api/products
sum(rate(http_server_duration_milliseconds_count{http_route="/api/products",http_status_code=~"5.."}[5m]))
/ 
sum(rate(http_server_duration_milliseconds_count{http_route="/api/products"}[5m]))

# Top 5 endpoints mais requisitados
topk(5, sum(rate(http_server_duration_milliseconds_count[5m])) by (http_route))

# Top 5 endpoints mais lentos (P95)
topk(5, 
  histogram_quantile(0.95, 
    sum(rate(http_server_duration_milliseconds_bucket[5m])) by (le, http_route)
  )
)
```

---

## ⚡ Análise de Performance

### Throughput

```promql
# Requisições por minuto
sum(rate(http_server_duration_milliseconds_count[1m])) * 60

# Throughput por serviço
sum(rate(http_server_duration_milliseconds_count[1m])) by (service_name) * 60

# Throughput total do sistema
sum(rate(http_server_duration_milliseconds_count[5m])) * 60

# Requisições por segundo (RPS) por serviço
sum(rate(http_server_duration_milliseconds_count[1m])) by (service_name)
```

### Comparação Frontend vs Backend

```promql
# Latência P95 - Frontend vs Backend (em milissegundos)
histogram_quantile(0.95, 
  sum(rate(http_server_duration_milliseconds_bucket[5m])) by (le, service_name)
)

# Taxa de requisições - Frontend vs Backend
sum(rate(http_server_duration_milliseconds_count[5m])) by (service_name)

# Taxa de erro - Frontend vs Backend
sum(rate(http_server_duration_milliseconds_count{http_status_code=~"5.."}[5m])) by (service_name)
/ 
sum(rate(http_server_duration_milliseconds_count[5m])) by (service_name)

# Latência média - Frontend vs Backend
rate(http_server_duration_milliseconds_sum[5m]) by (service_name)
/ 
rate(http_server_duration_milliseconds_count[5m]) by (service_name)
```

### Análise de Tendências

```promql
# Crescimento de requisições (última hora vs hora anterior)
sum(rate(http_server_duration_milliseconds_count[1h] offset 1h))
/ 
sum(rate(http_server_duration_milliseconds_count[1h]))

# Latência média nas últimas 24 horas
avg_over_time(
  (rate(http_server_duration_milliseconds_sum[5m]) 
  / 
  rate(http_server_duration_milliseconds_count[5m]))[24h:]
)

# Comparar requisições de hoje vs ontem (mesmo horário)
sum(rate(http_server_duration_milliseconds_count[1h]))
/
sum(rate(http_server_duration_milliseconds_count[1h] offset 24h))
```

---

## 🔧 Troubleshooting

### Verificar se aplicações estão enviando telemetria

```promql
# Verificar se há métricas do frontend
count(http_server_duration_milliseconds_count{service_name="frontend-service"})

# Verificar se há métricas do backend
count(http_server_duration_milliseconds_count{service_name="backend-service"})

# Verificar por job name
count(http_server_duration_milliseconds_count{job="frontend-service"})
count(http_server_duration_milliseconds_count{job="backend-service"})

# Última vez que recebemos dados (em segundos atrás)
time() - timestamp(http_server_duration_milliseconds_count)

# Listar todos os serviços ativos
count(http_server_duration_milliseconds_count) by (service_name)

# Verificar se serviços estão enviando dados nos últimos 5 minutos
sum(rate(http_server_duration_milliseconds_count[5m])) by (service_name) > 0
```

### Identificar gargalos no Collector

```promql
# Uso de memória do Collector (se disponível)
process_resident_memory_bytes{job="otel-collector"}

# CPU do Collector (se disponível)
rate(process_cpu_seconds_total{job="otel-collector"}[5m])

# Fila de exportação cheia (alerta se > 80%)
(otelcol_exporter_queue_size / otelcol_exporter_queue_capacity) * 100 > 80
```

### Verificar perda de dados

```promql
# Taxa de perda de spans
(sum(rate(otelcol_receiver_accepted_spans[5m])) 
- 
sum(rate(otelcol_exporter_sent_spans[5m])))
/ 
sum(rate(otelcol_receiver_accepted_spans[5m]))
* 100

# Taxa de perda de métricas
(sum(rate(otelcol_receiver_accepted_metric_points[5m])) 
- 
sum(rate(otelcol_exporter_sent_metric_points[5m])))
/ 
sum(rate(otelcol_receiver_accepted_metric_points[5m]))
* 100
```

### Latência do pipeline

```promql
# Tempo de processamento no Collector (se disponível)
rate(otelcol_processor_batch_batch_send_size_sum[5m]) 
/ 
rate(otelcol_processor_batch_batch_send_size_count[5m])
```

---

## 🚨 Alertas Recomendados

### Alertas Críticos

#### Collector não está recebendo dados
```promql
# Alerta se não receber spans por 5 minutos
sum(rate(otelcol_receiver_accepted_spans[5m])) == 0

# Alerta se não receber métricas por 5 minutos
sum(rate(otelcol_receiver_accepted_metric_points[5m])) == 0
```

#### Alta taxa de erro nas aplicações
```promql
# Alerta se taxa de erro > 5%
(sum(rate(http_server_duration_milliseconds_count{http_status_code=~"5.."}[5m])) 
/ 
sum(rate(http_server_duration_milliseconds_count[5m]))) 
* 100 > 5

# Alerta por serviço
(sum(rate(http_server_duration_milliseconds_count{http_status_code=~"5.."}[5m])) by (service_name)
/ 
sum(rate(http_server_duration_milliseconds_count[5m])) by (service_name)) 
* 100 > 5
```

#### Latência alta
```promql
# Alerta se P95 > 1000ms (1 segundo)
histogram_quantile(0.95, 
  sum(rate(http_server_duration_milliseconds_bucket[5m])) by (le)
) > 1000

# Alerta se P99 > 2000ms (2 segundos)
histogram_quantile(0.99, 
  sum(rate(http_server_duration_milliseconds_bucket[5m])) by (le, service_name)
) > 2000

# Alerta se latência média > 500ms
(rate(http_server_duration_milliseconds_sum[5m]) 
/ 
rate(http_server_duration_milliseconds_count[5m])) > 500
```

### Alertas de Aviso

#### Fila do Collector crescendo
```promql
# Alerta se fila > 80% da capacidade
(otelcol_exporter_queue_size / otelcol_exporter_queue_capacity) * 100 > 80
```

#### Falhas de exportação
```promql
# Alerta se houver falhas de exportação
sum(rate(otelcol_exporter_send_failed_spans[5m])) > 0
sum(rate(otelcol_exporter_send_failed_metric_points[5m])) > 0
```

#### Perda de dados
```promql
# Alerta se perda de dados > 1%
(sum(rate(otelcol_receiver_accepted_spans[5m])) 
- 
sum(rate(otelcol_exporter_sent_spans[5m])))
/ 
sum(rate(otelcol_receiver_accepted_spans[5m]))
* 100 > 1
```

---

## 📈 Dashboards Recomendados

### Dashboard 1: Visão Geral do Collector

**Painéis:**
1. Taxa de spans recebidos vs enviados
2. Taxa de métricas recebidas vs enviadas
3. Taxa de logs recebidos
4. Tamanho da fila de exportação
5. Taxa de erro de exportação

### Dashboard 2: Performance das Aplicações

**Painéis:**
1. Requisições por segundo (por serviço)
2. Latência P50, P95, P99
3. Taxa de erro (4xx e 5xx)
4. Distribuição de status codes
5. Top 10 endpoints mais lentos

### Dashboard 3: Análise de Negócio

**Painéis:**
1. Requisições por endpoint
2. Latência por endpoint
3. Taxa de erro por endpoint
4. Throughput total
5. Comparação Frontend vs Backend

---

## 🔍 Queries Úteis para Exploração

### Descobrir métricas disponíveis

```promql
# Listar todas as métricas do OTel Collector
{__name__=~"otelcol_.*"}

# Listar todas as métricas HTTP
{__name__=~"http_.*"}

# Listar métricas por serviço
{service_name="backend-service"}

# Listar métricas por job
{job="frontend-service"}

# Ver todas as métricas de duração HTTP
{__name__=~"http_server_duration.*"}

# Listar todos os labels disponíveis para uma métrica
http_server_duration_milliseconds_count
```

### Análise de cardinalidade

```promql
# Contar séries temporais por métrica
count({__name__=~"http_server_duration.*"}) by (__name__)

# Contar séries por serviço
count({service_name!=""}) by (service_name)

# Contar endpoints únicos
count(http_server_duration_milliseconds_count) by (http_route)

# Contar métodos HTTP únicos
count(http_server_duration_milliseconds_count) by (http_method)

# Contar status codes únicos
count(http_server_duration_milliseconds_count) by (http_status_code)

# Total de séries temporais HTTP
count(http_server_duration_milliseconds_count)
```

---

## 📚 Recursos Adicionais

### Documentação
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [PromQL Functions](https://prometheus.io/docs/prometheus/latest/querying/functions/)
- [OTel Collector Metrics](https://opentelemetry.io/docs/collector/internal-telemetry/)

### Exemplos de Uso

#### Verificação Rápida de Saúde
```bash
# Via curl no Prometheus
curl -G 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=sum(rate(otelcol_receiver_accepted_spans[5m]))'

# Verificar se aplicações estão enviando dados
curl -G 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=sum(rate(http_server_duration_milliseconds_count[5m])) by (service_name)'

# Verificar latência P95
curl -G 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=histogram_quantile(0.95, sum(rate(http_server_duration_milliseconds_bucket[5m])) by (le, service_name))'
```

#### Exportar Métricas
```bash
# Exportar todas as métricas do Collector
curl http://localhost:8888/metrics

# Filtrar métricas específicas
curl http://localhost:8888/metrics | grep otelcol_receiver
```

---

## ✅ Checklist de Verificação

Use estas queries para verificar se tudo está funcionando:

- [ ] Collector está recebendo spans: `sum(rate(otelcol_receiver_accepted_spans[5m])) > 0`
- [ ] Collector está recebendo métricas: `sum(rate(otelcol_receiver_accepted_metric_points[5m])) > 0`
- [ ] Collector está exportando spans: `sum(rate(otelcol_exporter_sent_spans[5m])) > 0`
- [ ] Collector está exportando métricas: `sum(rate(otelcol_exporter_sent_metric_points[5m])) > 0`
- [ ] Frontend está enviando métricas: `count(http_server_duration_milliseconds_count{service_name="frontend-service"}) > 0`
- [ ] Backend está enviando métricas: `count(http_server_duration_milliseconds_count{service_name="backend-service"}) > 0`
- [ ] Não há erros de exportação: `sum(rate(otelcol_exporter_send_failed_spans[5m])) == 0`
- [ ] Fila não está cheia: `(otelcol_exporter_queue_size / otelcol_exporter_queue_capacity) * 100 < 80`
- [ ] Taxa de erro das apps < 5%: `(sum(rate(http_server_duration_milliseconds_count{http_status_code=~"5.."}[5m])) / sum(rate(http_server_duration_milliseconds_count[5m]))) * 100 < 5`
- [ ] Latência P95 < 1000ms: `histogram_quantile(0.95, sum(rate(http_server_duration_milliseconds_bucket[5m])) by (le)) < 1000`

---

**Última atualização:** Aula 06 - PosTech DevOps e Arquitetura Cloud
