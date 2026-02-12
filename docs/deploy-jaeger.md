# Deploy Jaeger - Distributed Tracing

Este guia demonstra como implementar o Jaeger no Kubernetes para distributed tracing.

## 📋 Pré-requisitos

- Cluster EKS configurado e rodando
- kubectl configurado
- Helm 3.x instalado
- Namespace `monitoring` já criado (aula anterior)

## 🏗️ Arquitetura do Jaeger

```
┌─────────────────────────┐
│  OpenTelemetry Collector│
│   (ou Aplicações)       │
└────────┬────────────────┘
         │ OTLP (4317/4318)
         ▼
┌─────────────────────────┐
│   Jaeger Collector      │
│                         │
│  • Recebe traces        │
│  • Valida dados         │
│  • Armazena no backend  │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│   Memory Storage        │
│   (In-Memory)           │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│   Jaeger Query (UI)     │
│                         │
│  • Interface web        │
│  • Busca traces         │
│  • Visualização         │
└─────────────────────────┘
```

## 📦 Componentes

### Jaeger Collector
- Recebe traces via OTLP (gRPC e HTTP)
- Suporta formatos Jaeger e Zipkin (legacy)
- Valida e processa spans
- Armazena no backend configurado

### Jaeger Query
- Interface web para visualização
- API para busca de traces
- Análise de dependências entre serviços
- Comparação de traces

### Storage
- **In-Memory**: Para ambiente de laboratório (configurado)
- **Elasticsearch**: Para produção (recomendado)
- **Cassandra**: Para alta escala

---

## 🚀 Instalação

### Passo 1: Adicionar Repositório Helm

```bash
# Adicionar repositório do Jaeger
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts

# Atualizar repositórios
helm repo update
```

### Passo 2: Instalar Jaeger

```bash
helm upgrade --install jaeger jaegertracing/jaeger \
  --namespace monitoring \
  --values helm-values/jaeger/values.yaml \
  --wait
```

**Saída esperada:**
```
Release "jaeger" does not exist. Installing it now.
NAME: jaeger
LAST DEPLOYED: Thu Feb 12 2026 00:15:00
NAMESPACE: monitoring
STATUS: deployed
REVISION: 1
```

### Passo 3: Verificar Instalação

```bash
# Verificar pods
kubectl get pods -n monitoring -l app.kubernetes.io/instance=jaeger

# Verificar services
kubectl get svc -n monitoring -l app.kubernetes.io/instance=jaeger

# Verificar logs do collector
kubectl logs -n monitoring -l app.kubernetes.io/component=collector --tail=50
```

**Saída esperada:**
```
NAME                      READY   STATUS    RESTARTS   AGE
jaeger-collector-xxx      1/1     Running   0          2m
jaeger-query-xxx          1/1     Running   0          2m

NAME                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
jaeger-collector          ClusterIP   10.100.x.x      <none>        4317/TCP,4318/TCP,14250/TCP,14268/TCP,9411/TCP
jaeger-query              ClusterIP   10.100.x.x      <none>        16686/TCP
```

---

## 🔍 Validação

### 1. Verificar Health do Collector

```bash
# Port-forward do collector
kubectl port-forward -n monitoring svc/jaeger-collector 14269:14269

# Em outro terminal, verificar health
curl http://localhost:14269/
```

**Resposta esperada:**
```json
{"status":"Server available"}
```

### 2. Testar Envio de Trace via OTLP

```bash
# Port-forward da porta OTLP HTTP
kubectl port-forward -n monitoring svc/jaeger-collector 4318:4318

# Enviar trace de teste
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "resource": {
        "attributes": [{
          "key": "service.name",
          "value": {"stringValue": "test-service"}
        }]
      },
      "scopeSpans": [{
        "spans": [{
          "traceId": "5b8aa5a2d2c872e8321cf37308d69df2",
          "spanId": "051581bf3cb55c13",
          "name": "test-operation",
          "kind": 1,
          "startTimeUnixNano": "1544712660000000000",
          "endTimeUnixNano": "1544712661000000000",
          "attributes": [{
            "key": "http.method",
            "value": {"stringValue": "GET"}
          }]
        }]
      }]
    }]
  }'
```

### 3. Acessar Jaeger UI

```bash
# Port-forward da UI
kubectl port-forward -n monitoring svc/jaeger-query 16686:16686

# Acessar no navegador:
# http://localhost:16686
```

**Na UI do Jaeger:**
1. No dropdown "Service", selecione `test-service`
2. Clique em "Find Traces"
3. Você deve ver o trace de teste com a operação `test-operation`

### 4. Verificar via Ingress (após aplicar)

```bash
# Aplicar Ingress
kubectl apply -f kubernetes/eks-lab-ingress.yaml

# Obter URL do ALB
kubectl get ingress -n monitoring eks-lab-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Acessar no navegador:
# https://jaeger.demo.lynxnetwork.com.br
```

---

## 📊 Endpoints do Jaeger

### Jaeger Collector

| Protocolo | Porta | Endpoint | Descrição |
|-----------|-------|----------|-----------|
| OTLP gRPC | 4317 | `jaeger-collector.monitoring.svc.cluster.local:4317` | Recebe traces via OTLP gRPC |
| OTLP HTTP | 4318 | `jaeger-collector.monitoring.svc.cluster.local:4318` | Recebe traces via OTLP HTTP |
| Jaeger gRPC | 14250 | `jaeger-collector.monitoring.svc.cluster.local:14250` | Formato Jaeger nativo (legacy) |
| Jaeger HTTP | 14268 | `jaeger-collector.monitoring.svc.cluster.local:14268` | Formato Jaeger Thrift (legacy) |
| Zipkin | 9411 | `jaeger-collector.monitoring.svc.cluster.local:9411` | Compatibilidade Zipkin |
| Health | 14269 | `jaeger-collector.monitoring.svc.cluster.local:14269` | Health check |

### Jaeger Query

| Porta | Endpoint | Descrição |
|-------|----------|-----------|
| 16686 | `jaeger-query.monitoring.svc.cluster.local:16686` | Interface web e API |
| 16687 | `jaeger-query.monitoring.svc.cluster.local:16687` | Health check |

---

## 🔧 Configuração de Aplicações

### Variáveis de Ambiente (OTLP)

```yaml
env:
  # Endpoint OTLP gRPC
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://jaeger-collector.monitoring.svc.cluster.local:4317"
  
  # Ou OTLP HTTP
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://jaeger-collector.monitoring.svc.cluster.local:4318"
  
  # Nome do serviço
  - name: OTEL_SERVICE_NAME
    value: "meu-servico"
```

### Exemplo SDK (Python)

```python
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

# Configurar exporter
otlp_exporter = OTLPSpanExporter(
    endpoint="jaeger-collector.monitoring.svc.cluster.local:4317",
    insecure=True
)

# Configurar provider
trace.set_tracer_provider(TracerProvider())
trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(otlp_exporter)
)

# Usar tracer
tracer = trace.get_tracer(__name__)
with tracer.start_as_current_span("operacao"):
    # Seu código aqui
    pass
```

---

## 🐛 Troubleshooting

### Problema: Traces não aparecem na UI

**Verificar:**
```bash
# 1. Collector está rodando?
kubectl get pods -n monitoring -l app.kubernetes.io/component=collector

# 2. Logs do collector
kubectl logs -n monitoring -l app.kubernetes.io/component=collector --tail=100

# 3. Query está rodando?
kubectl get pods -n monitoring -l app.kubernetes.io/component=query

# 4. Logs do query
kubectl logs -n monitoring -l app.kubernetes.io/component=query --tail=100
```

### Problema: Erro "connection refused"

**Causa:** Aplicação não consegue conectar ao collector

**Solução:**
```bash
# Verificar se o service existe
kubectl get svc -n monitoring jaeger-collector

# Verificar DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup jaeger-collector.monitoring.svc.cluster.local

# Verificar conectividade
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://jaeger-collector.monitoring.svc.cluster.local:4318/v1/traces
```

### Problema: Memory storage cheio

**Sintoma:** Traces antigos desaparecem

**Explicação:** Storage in-memory tem limite de 100.000 traces (configurado)

**Solução para produção:**
```bash
# Migrar para Elasticsearch
# Editar helm-values/jaeger/values.yaml:
storage:
  type: elasticsearch
  elasticsearch:
    host: elasticsearch.monitoring.svc.cluster.local
    port: 9200
```

---

## 📈 Monitoramento

### Métricas do Jaeger (Prometheus)

O Jaeger expõe métricas no formato Prometheus. Verifique se o ServiceMonitor está configurado:

```bash
kubectl get servicemonitor -n monitoring -l app.kubernetes.io/instance=jaeger
```

**Métricas importantes:**

```promql
# Taxa de spans recebidos
rate(jaeger_collector_spans_received_total[5m])

# Taxa de spans salvos com sucesso
rate(jaeger_collector_spans_saved_total[5m])

# Taxa de spans rejeitados
rate(jaeger_collector_spans_rejected_total[5m])

# Latência de queries (p95)
histogram_quantile(0.95, rate(jaeger_query_latency_bucket[5m]))

# Traces em memória
jaeger_collector_in_queue_latency_count
```

### Dashboard Grafana

Importar dashboard oficial do Jaeger:
- Dashboard ID: `10001` (Jaeger Overview)

---

## 🔄 Atualização

```bash
# Atualizar para nova versão
helm upgrade jaeger jaegertracing/jaeger \
  --namespace monitoring \
  --values helm-values/jaeger/values.yaml \
  --reuse-values

# Verificar versão instalada
helm list -n monitoring
```

---

## 🗑️ Desinstalação

```bash
# Remover Jaeger
helm uninstall jaeger -n monitoring

# Verificar remoção
kubectl get all -n monitoring -l app.kubernetes.io/instance=jaeger
```

---

## 📚 Referências

- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [Jaeger Architecture](https://www.jaegertracing.io/docs/latest/architecture/)
- [OTLP Specification](https://opentelemetry.io/docs/specs/otlp/)
- [Jaeger Helm Chart](https://github.com/jaegertracing/helm-charts/tree/main/charts/jaeger)

---

## ✅ Checklist de Implementação

- [ ] Repositório Helm do Jaeger adicionado
- [ ] Jaeger instalado no namespace `monitoring`
- [ ] Pods `jaeger-collector` e `jaeger-query` rodando
- [ ] Services criados e acessíveis
- [ ] Trace de teste enviado com sucesso
- [ ] UI acessível via port-forward
- [ ] ServiceMonitor configurado para Prometheus
- [ ] Ingress aplicado (opcional)

---

**Próximo Passo:** Deploy do OpenTelemetry Collector centralizado
