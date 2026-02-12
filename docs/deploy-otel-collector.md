# Deploy OpenTelemetry Collector - Centralizado

Este guia demonstra como implementar um OpenTelemetry Collector centralizado no Kubernetes para receber, processar e rotear telemetria de todas as aplicações.

## 📋 Pré-requisitos

- Cluster EKS configurado e rodando
- kubectl configurado
- Helm 3.x instalado
- Namespace `monitoring` já criado (aula anterior)
- Jaeger instalado (aula anterior)

## 🏗️ Arquitetura

```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Aplicação 1  │  │ Aplicação 2  │  │ Aplicação N  │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │
       │ OTLP            │ OTLP            │ OTLP
       │ (4317/4318)     │ (4317/4318)     │ (4317/4318)
       └─────────────────┴─────────────────┘
                         │
                         ▼
       ┌─────────────────────────────────────┐
       │  OpenTelemetry Collector            │
       │         (Centralizado)              │
       │                                     │
       │  ┌──────────────────────────────┐   │
       │  │ Receivers                    │   │
       │  │ • OTLP (gRPC/HTTP)          │   │
       │  │ • Jaeger (legacy)           │   │
       │  │ • Zipkin                    │   │
       │  └──────────────────────────────┘   │
       │                                     │
       │  ┌──────────────────────────────┐   │
       │  │ Processors                   │   │
       │  │ • Batch                     │   │
       │  │ • Memory Limiter            │   │
       │  │ • Resource                  │   │
       │  │ • Attributes                │   │
       │  └──────────────────────────────┘   │
       │                                     │
       │  ┌──────────────────────────────┐   │
       │  │ Exporters                    │   │
       │  │ • Jaeger (traces)           │   │
       │  │ • Prometheus (metrics)      │   │
       │  │ • Loki (logs)               │   │
       │  └──────────────────────────────┘   │
       └─────────┬───────────┬───────────┬───┘
                 │           │           │
                 ▼           ▼           ▼
         ┌──────────┐ ┌──────────┐ ┌──────────┐
         │  Jaeger  │ │Prometheus│ │   Loki   │
         └──────────┘ └──────────┘ └──────────┘
```

## 📦 Componentes

### Receivers
- **OTLP**: Protocolo padrão OpenTelemetry (gRPC e HTTP)
- **Jaeger**: Compatibilidade com formato Jaeger (legacy)
- **Zipkin**: Compatibilidade com formato Zipkin
- **Prometheus**: Scrape de métricas próprias

### Processors
- **Batch**: Agrupa telemetria para envio eficiente
- **Memory Limiter**: Previne OOM (Out of Memory)
- **Resource**: Adiciona atributos de recurso (cluster, environment)
- **Attributes**: Manipula atributos de spans

### Exporters
- **OTLP/Jaeger**: Envia traces para Jaeger
- **Prometheus**: Expõe métricas para scraping
- **Loki**: Envia logs para Loki
- **Debug**: Logging para troubleshooting

---

## 🚀 Instalação

### Passo 1: Adicionar Repositório Helm

```bash
# Adicionar repositório do OpenTelemetry
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts

# Atualizar repositórios
helm repo update
```

### Passo 2: Instalar OpenTelemetry Collector

```bash
helm upgrade --install otel-collector open-telemetry/opentelemetry-collector \
  --namespace monitoring \
  --values helm-values/opentelemetry-collector/values.yaml \
  --wait
```

**Saída esperada:**
```
Release "otel-collector" does not exist. Installing it now.
NAME: otel-collector
LAST DEPLOYED: Thu Feb 12 2026 00:20:00
NAMESPACE: monitoring
STATUS: deployed
REVISION: 1
```

### Passo 3: Verificar Instalação

```bash
# Verificar pods (deve ter 2 réplicas)
kubectl get pods -n monitoring -l app.kubernetes.io/instance=otel-collector

# Verificar service
kubectl get svc -n monitoring -l app.kubernetes.io/instance=otel-collector

# Verificar HPA (Horizontal Pod Autoscaler)
kubectl get hpa -n monitoring

# Verificar logs
kubectl logs -n monitoring -l app.kubernetes.io/instance=otel-collector --tail=50
```

**Saída esperada:**
```
NAME                      READY   STATUS    RESTARTS   AGE
otel-collector-xxx        1/1     Running   0          2m
otel-collector-yyy        1/1     Running   0          2m

NAME                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
otel-collector            ClusterIP   10.100.x.x      <none>        4317/TCP,4318/TCP,8888/TCP,...

NAME                      REFERENCE                   TARGETS         MINPODS   MAXPODS
otel-collector            Deployment/otel-collector   cpu: 15%/80%    2         10
```

---

## 🔍 Validação

### 1. Verificar Health do Collector

```bash
# Port-forward do health check
kubectl port-forward -n monitoring svc/otel-collector 13133:13133

# Verificar health
curl http://localhost:13133/
```

**Resposta esperada:**
```json
{"status":"Server available","upSince":"2026-02-12T00:20:00Z","uptime":"5m"}
```

### 2. Verificar Conectividade com Jaeger

```bash
# Verificar logs do collector
kubectl logs -n monitoring -l app.kubernetes.io/instance=otel-collector | grep -i jaeger

# Procurar por:
# - "Everything is ready. Begin running and processing data"
# - Sem erros de conexão
```

### 3. Testar Envio de Trace

```bash
# Port-forward da porta OTLP HTTP
kubectl port-forward -n monitoring svc/otel-collector 4318:4318

# Enviar trace de teste
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "resource": {
        "attributes": [{
          "key": "service.name",
          "value": {"stringValue": "otel-test-service"}
        }]
      },
      "scopeSpans": [{
        "spans": [{
          "traceId": "7b8aa5a2d2c872e8321cf37308d69df3",
          "spanId": "151581bf3cb55c14",
          "name": "otel-test-operation",
          "kind": 1,
          "startTimeUnixNano": "1544712660000000000",
          "endTimeUnixNano": "1544712661000000000",
          "attributes": [{
            "key": "http.method",
            "value": {"stringValue": "POST"}
          }, {
            "key": "http.status_code",
            "value": {"intValue": "200"}
          }]
        }]
      }]
    }]
  }'
```

### 4. Verificar Trace no Jaeger

```bash
# Acessar Jaeger UI
kubectl port-forward -n monitoring svc/jaeger-query 16686:16686

# Abrir no navegador: http://localhost:16686
# Selecionar serviço: otel-test-service
# Clicar em "Find Traces"
# Verificar se o trace aparece
```

### 5. Verificar Métricas

```bash
# Port-forward das métricas
kubectl port-forward -n monitoring svc/otel-collector 8888:8888

# Ver métricas
curl http://localhost:8888/metrics

# Métricas específicas
curl http://localhost:8888/metrics | grep otelcol_receiver_accepted_spans
curl http://localhost:8888/metrics | grep otelcol_exporter_sent_spans
```

---

## 📊 Endpoints do OpenTelemetry Collector

### Receivers (Entrada de Telemetria)

| Protocolo | Porta | Endpoint | Descrição |
|-----------|-------|----------|-----------|
| OTLP gRPC | 4317 | `otel-collector.monitoring.svc.cluster.local:4317` | Recebe telemetria via OTLP gRPC |
| OTLP HTTP | 4318 | `otel-collector.monitoring.svc.cluster.local:4318` | Recebe telemetria via OTLP HTTP |
| Jaeger gRPC | 14250 | `otel-collector.monitoring.svc.cluster.local:14250` | Formato Jaeger (legacy) |
| Jaeger HTTP | 14268 | `otel-collector.monitoring.svc.cluster.local:14268` | Formato Jaeger Thrift (legacy) |
| Zipkin | 9411 | `otel-collector.monitoring.svc.cluster.local:9411` | Formato Zipkin |

### Observabilidade do Collector

| Porta | Endpoint | Descrição |
|-------|----------|-----------|
| 8888 | `otel-collector.monitoring.svc.cluster.local:8888/metrics` | Métricas Prometheus |
| 13133 | `otel-collector.monitoring.svc.cluster.local:13133` | Health check |
| 55679 | `otel-collector.monitoring.svc.cluster.local:55679/debug/...` | zPages (debug) |
| 1777 | `otel-collector.monitoring.svc.cluster.local:1777/debug/pprof` | pprof (profiling) |

---

## 🔧 Configuração de Aplicações

### Variáveis de Ambiente

```yaml
env:
  # Endpoint OTLP gRPC (recomendado)
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://otel-collector.monitoring.svc.cluster.local:4317"
  
  # Ou OTLP HTTP
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://otel-collector.monitoring.svc.cluster.local:4318"
  
  # Nome do serviço
  - name: OTEL_SERVICE_NAME
    value: "meu-servico"
  
  # Resource attributes
  - name: OTEL_RESOURCE_ATTRIBUTES
    value: "environment=lab,version=1.0.0"
```

### Exemplo SDK (Node.js)

```javascript
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');
const { OTLPMetricExporter } = require('@opentelemetry/exporter-metrics-otlp-grpc');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'meu-servico',
    [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
    'environment': 'lab',
  }),
  traceExporter: new OTLPTraceExporter({
    url: 'http://otel-collector.monitoring.svc.cluster.local:4317',
  }),
  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter({
      url: 'http://otel-collector.monitoring.svc.cluster.local:4317',
    }),
  }),
});

sdk.start();
```

### Exemplo SDK (Java)

```java
import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.sdk.OpenTelemetrySdk;
import io.opentelemetry.sdk.trace.SdkTracerProvider;
import io.opentelemetry.sdk.trace.export.BatchSpanProcessor;
import io.opentelemetry.exporter.otlp.trace.OtlpGrpcSpanExporter;

OtlpGrpcSpanExporter spanExporter = OtlpGrpcSpanExporter.builder()
    .setEndpoint("http://otel-collector.monitoring.svc.cluster.local:4317")
    .build();

SdkTracerProvider tracerProvider = SdkTracerProvider.builder()
    .addSpanProcessor(BatchSpanProcessor.builder(spanExporter).build())
    .build();

OpenTelemetry openTelemetry = OpenTelemetrySdk.builder()
    .setTracerProvider(tracerProvider)
    .build();
```

---

## 🐛 Troubleshooting

### Problema: Traces não chegam ao Jaeger

**Verificar pipeline:**
```bash
# 1. Collector está recebendo traces?
kubectl logs -n monitoring -l app.kubernetes.io/instance=otel-collector | grep "Traces received"

# 2. Verificar métricas de receiver
kubectl port-forward -n monitoring svc/otel-collector 8888:8888
curl http://localhost:8888/metrics | grep otelcol_receiver_accepted_spans

# 3. Verificar métricas de exporter
curl http://localhost:8888/metrics | grep otelcol_exporter_sent_spans

# 4. Verificar erros
kubectl logs -n monitoring -l app.kubernetes.io/instance=otel-collector | grep -i error
```

### Problema: OOMKilled (Out of Memory)

**Sintoma:** Pods reiniciando com status OOMKilled

**Solução:**
```bash
# Verificar uso de memória
kubectl top pods -n monitoring -l app.kubernetes.io/instance=otel-collector

# Aumentar memory limit
kubectl edit deployment -n monitoring otel-collector

# Ou ajustar no values.yaml:
resources:
  limits:
    memory: 4Gi  # Aumentar
  requests:
    memory: 1Gi  # Aumentar
```

### Problema: Alta latência no processamento

**Verificar:**
```bash
# Métricas de batch processor
curl http://localhost:8888/metrics | grep otelcol_processor_batch

# Ajustar configuração no values.yaml:
processors:
  batch:
    timeout: 5s        # Reduzir para processar mais rápido
    send_batch_size: 512  # Reduzir batch size
```

### Problema: Conexão recusada com Jaeger

**Verificar:**
```bash
# Jaeger está rodando?
kubectl get pods -n monitoring -l app.kubernetes.io/instance=jaeger

# Testar conectividade
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n monitoring -- \
  curl -v http://jaeger-collector.monitoring.svc.cluster.local:4317

# Verificar DNS
kubectl run -it --rm debug --image=busybox --restart=Never -n monitoring -- \
  nslookup jaeger-collector.monitoring.svc.cluster.local
```

---

## 📈 Monitoramento

### Métricas do Collector

O Collector expõe métricas próprias que devem ser monitoradas:

```promql
# Spans recebidos por segundo
rate(otelcol_receiver_accepted_spans[5m])

# Spans enviados por segundo
rate(otelcol_exporter_sent_spans[5m])

# Spans dropados (problema!)
rate(otelcol_processor_dropped_spans[5m])

# Taxa de erro no export
rate(otelcol_exporter_send_failed_spans[5m])

# Uso de memória
otelcol_process_memory_rss

# CPU usage
rate(otelcol_process_cpu_seconds[5m])

# Queue size (backpressure)
otelcol_exporter_queue_size
```

### Alertas Recomendados

```yaml
# Exemplo de alertas Prometheus
groups:
  - name: otel-collector
    rules:
      - alert: OtelCollectorHighDropRate
        expr: rate(otelcol_processor_dropped_spans[5m]) > 10
        annotations:
          summary: "OTel Collector dropping spans"
      
      - alert: OtelCollectorExportFailing
        expr: rate(otelcol_exporter_send_failed_spans[5m]) > 0
        annotations:
          summary: "OTel Collector failing to export"
      
      - alert: OtelCollectorHighMemory
        expr: otelcol_process_memory_rss > 1.5e9  # 1.5GB
        annotations:
          summary: "OTel Collector high memory usage"
```

### Dashboard Grafana

Importar dashboard oficial do OpenTelemetry Collector:
- Dashboard ID: `15983` (OpenTelemetry Collector)

---

## 🔄 Atualização

```bash
# Atualizar para nova versão
helm upgrade otel-collector open-telemetry/opentelemetry-collector \
  --namespace monitoring \
  --values helm-values/opentelemetry-collector/values.yaml \
  --reuse-values

# Verificar rollout
kubectl rollout status deployment/otel-collector -n monitoring

# Verificar versão
helm list -n monitoring
```

---

## 📊 Scaling

### Horizontal Pod Autoscaler (HPA)

O HPA já está configurado no values.yaml:

```bash
# Verificar HPA
kubectl get hpa -n monitoring otel-collector

# Descrever HPA
kubectl describe hpa -n monitoring otel-collector

# Ajustar manualmente (se necessário)
kubectl scale deployment otel-collector -n monitoring --replicas=5
```

### Ajustar limites de autoscaling

Editar `helm-values/opentelemetry-collector/values.yaml`:

```yaml
autoscaling:
  enabled: true
  minReplicas: 3      # Aumentar mínimo
  maxReplicas: 20     # Aumentar máximo
  targetCPUUtilizationPercentage: 70  # Mais agressivo
```

---

## 🗑️ Desinstalação

```bash
# Remover OpenTelemetry Collector
helm uninstall otel-collector -n monitoring

# Verificar remoção
kubectl get all -n monitoring -l app.kubernetes.io/instance=otel-collector
```

---

## 📚 Referências

- [OpenTelemetry Collector Documentation](https://opentelemetry.io/docs/collector/)
- [Collector Configuration](https://opentelemetry.io/docs/collector/configuration/)
- [Collector Helm Chart](https://github.com/open-telemetry/opentelemetry-helm-charts/tree/main/charts/opentelemetry-collector)
- [OTLP Specification](https://opentelemetry.io/docs/specs/otlp/)

---

## ✅ Checklist de Implementação

- [ ] Repositório Helm do OpenTelemetry adicionado
- [ ] OTel Collector instalado no namespace `monitoring`
- [ ] Pods rodando (mínimo 2 réplicas)
- [ ] Services criados e acessíveis
- [ ] HPA configurado e funcionando
- [ ] Conectividade com Jaeger validada
- [ ] Trace de teste enviado e visualizado no Jaeger
- [ ] Métricas do Collector acessíveis
- [ ] ServiceMonitor configurado para Prometheus
- [ ] Aplicações configuradas para enviar telemetria

---

**Próximo Passo:** Configurar aplicações para enviar telemetria ao Collector
