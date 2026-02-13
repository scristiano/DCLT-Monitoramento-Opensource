# Deploy da Stack de Tracing - Passo a Passo

Guia completo para implementar distributed tracing no Kubernetes usando Jaeger e OpenTelemetry Collector.

## Índice

- [Arquitetura da Stack](#arquitetura-da-stack)
- [Passo 1: Instalar Jaeger](#passo-1-instalar-jaeger)
- [Passo 2: Instalar OpenTelemetry Collector](#passo-2-instalar-opentelemetry-collector)
- [Passo 3: Verificar Integração](#passo-3-verificar-integração)
- [Acessar as Interfaces](#acessar-as-interfaces)
- [Testar a Stack de Tracing](#testar-a-stack-de-tracing)

## Arquitetura da Stack

```
┌─────────────────────────────────────────────────────────────────┐
│                    EKS CLUSTER (AUTO MODE)                      │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   MONITORING    │  │       APP       │  │   AWS MANAGED   │ │
│  │   NAMESPACE     │  │   NAMESPACE     │  │   SERVICES      │ │
│  │                 │  │                 │  │                 │ │
│  │ • Jaeger        │  │ • OpenTelemetry │  │ • ALB           │ │
│  │ • OTel          │  │   Demo          │  │   Controller    │ │
│  │   Collector     │  │ • Microservices │  │ • EBS CSI       │ │
│  │ • Prometheus    │  │                 │  │ • Auto Scaling  │ │
│  │ • Grafana       │  │                 │  │                 │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              APPLICATION LOAD BALANCER (ALB)            │   │
│  │  • HTTPS (443) com certificado ACM                      │   │
│  │  • HTTP (80) com redirect para HTTPS                    │   │
│  │  • Roteamento: jaeger.demo.lynxnetwork.com.br          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  Fluxo de Dados │
                    │                 │
                    │ App → OTel      │
                    │ Collector →     │
                    │ Jaeger          │
                    └─────────────────┘
```

## Passo 1: Instalar Jaeger

Jaeger é a plataforma de distributed tracing que armazena e visualiza traces.

```bash
# Adicionar repositório Helm
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update

# Instalar Jaeger
helm upgrade --install jaeger jaegertracing/jaeger \
  --namespace monitoring \
  --values helm-values/jaeger/values.yaml

# Aplicar ServiceMonitor para Prometheus
kubectl apply -f kubernetes/jaeger-servicemonitor.yaml

# Verificar instalação
kubectl get pods -n monitoring -l app.kubernetes.io/instance=jaeger

# Verificar ServiceMonitor
kubectl get servicemonitor -n monitoring jaeger
```

**Componentes instalados:**
- **Jaeger Collector**: Recebe traces via OTLP
- **Jaeger Query**: Interface web para visualização
- **Memory Storage**: Armazenamento in-memory (para lab)

**Configurações importantes:**
- Recebe traces via OTLP (porta 4317 gRPC, 4318 HTTP)
- Storage in-memory com limite de 100.000 traces
- Métricas Prometheus expostas na porta 8888
- Ingress configurado para acesso via ALB

**Nota sobre ServiceMonitor:** O chart do Jaeger não cria ServiceMonitor automaticamente. Por isso, aplicamos o arquivo `kubernetes/jaeger-servicemonitor.yaml` manualmente para que o Prometheus colete as métricas do Jaeger.

## Passo 2: Instalar OpenTelemetry Collector

O OpenTelemetry Collector centraliza a coleta de telemetria de todas as aplicações.

```bash
# Adicionar repositório Helm
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# Instalar OpenTelemetry Collector
helm upgrade --install otel-collector open-telemetry/opentelemetry-collector \
  --namespace monitoring \
  --values helm-values/opentelemetry-collector/values.yaml

# Verificar instalação
kubectl get pods -n monitoring -l app.kubernetes.io/instance=otel-collector
```

**Componentes instalados:**
- **Receivers**: OTLP (gRPC/HTTP), Jaeger, Zipkin
- **Processors**: Batch, Memory Limiter, Resource
- **Exporters**: Jaeger (traces), Prometheus (metrics)

**Configurações importantes:**
- 2 réplicas para alta disponibilidade
- HPA configurado (min: 2, max: 10)
- Envia traces para Jaeger
- Expõe métricas para Prometheus

## Passo 3: Verificar Integração

### 3.1 Verificar Todos os Pods

```bash
# Pods do Jaeger
kubectl get pods -n monitoring -l app.kubernetes.io/instance=jaeger

# Pods do OTel Collector
kubectl get pods -n monitoring -l app.kubernetes.io/instance=otel-collector

# Pods do OpenTelemetry Demo
kubectl get pods -n app
```

### 3.2 Verificar Services

```bash
# Services de tracing
kubectl get svc -n monitoring | grep -E "jaeger|otel"

# Services do demo
kubectl get svc -n app
```

### 3.3 Verificar ServiceMonitors

```bash
# ServiceMonitors configurados
kubectl get servicemonitor -n monitoring
kubectl get servicemonitor -n app
```

### 3.4 Verificar Ingress

```bash
# Verificar Ingress do Jaeger
kubectl get ingress -n monitoring eks-lab-ingress

# Obter URL do ALB
kubectl get ingress -n monitoring eks-lab-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Acessar as Interfaces

### 1. Jaeger UI (HTTPS com ACM)

```bash
# URL via Ingress (após configurar DNS)
# https://jaeger.demo.lynxnetwork.com.br

# Ou via port-forward para teste local
kubectl port-forward -n monitoring svc/jaeger-query 16686:16686

# Acessar: http://localhost:16686
```

**Na UI do Jaeger:**
- Selecione um serviço no dropdown (ex: `frontend`, `checkoutservice`)
- Clique em "Find Traces"
- Explore os traces gerados pelo OpenTelemetry Demo

### 2. OpenTelemetry Demo (HTTPS com ACM)

```bash
# URL via Ingress (após configurar DNS)
# https://astronomy-shop.demo.lynxnetwork.com.br

# Ou via port-forward
kubectl port-forward -n app svc/opentelemetry-demo-frontendproxy 8080:8080

# Acessar: http://localhost:8080
```

**Gerar traces:**
- Navegue pela loja (Astronomy Shop)
- Adicione produtos ao carrinho
- Finalize uma compra
- Cada ação gera traces que aparecem no Jaeger

### 3. Grafana (Visualizar Traces)

```bash
# Acessar Grafana
# https://grafana.demo.lynxnetwork.com.br

# Ou via port-forward
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

**No Grafana:**
1. Ir em "Explore"
2. Selecionar datasource "Jaeger"
3. Buscar traces por serviço ou TraceID
4. Visualizar correlação entre traces, logs (Loki) e métricas (Prometheus)

## Testar a Stack de Tracing

### 1. Enviar Trace de Teste

```bash
# Port-forward do OTel Collector
kubectl port-forward -n monitoring svc/otel-collector 4318:4318

# Enviar trace via OTLP HTTP
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

### 2. Verificar Trace no Jaeger

```bash
# Acessar Jaeger UI
kubectl port-forward -n monitoring svc/jaeger-query 16686:16686

# Abrir: http://localhost:16686
# Selecionar serviço: test-service
# Clicar em "Find Traces"
# Verificar se o trace aparece
```

### 3. Verificar Métricas do OTel Collector

```bash
# Port-forward das métricas
kubectl port-forward -n monitoring svc/otel-collector 8888:8888

# Ver métricas
curl http://localhost:8888/metrics | grep otelcol_receiver_accepted_spans
curl http://localhost:8888/metrics | grep otelcol_exporter_sent_spans
```

### 4. Verificar Métricas no Prometheus

```bash
# Acessar Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Abrir: http://localhost:9090
# Executar query: rate(otelcol_receiver_accepted_spans[5m])
```

## Endpoints Importantes

### Jaeger

| Componente | Porta | Endpoint | Descrição |
|------------|-------|----------|-----------|
| Collector OTLP gRPC | 4317 | `jaeger.monitoring.svc.cluster.local:4317` | Recebe traces via OTLP gRPC |
| Collector OTLP HTTP | 4318 | `jaeger.monitoring.svc.cluster.local:4318` | Recebe traces via OTLP HTTP |
| Query UI | 16686 | `jaeger.monitoring.svc.cluster.local:16686` | Interface web |

### OpenTelemetry Collector

| Componente | Porta | Endpoint | Descrição |
|------------|-------|----------|-----------|
| OTLP gRPC | 4317 | `otel-collector.monitoring.svc.cluster.local:4317` | Recebe telemetria via OTLP gRPC |
| OTLP HTTP | 4318 | `otel-collector.monitoring.svc.cluster.local:4318` | Recebe telemetria via OTLP HTTP |
| Metrics | 8888 | `otel-collector.monitoring.svc.cluster.local:8888/metrics` | Métricas Prometheus |
| Health | 13133 | `otel-collector.monitoring.svc.cluster.local:13133` | Health check |

## Configuração de Aplicações

Para enviar traces ao OpenTelemetry Collector, configure suas aplicações com:

```yaml
env:
  # Endpoint OTLP gRPC (recomendado)
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://otel-collector.monitoring.svc.cluster.local:4317"
  
  # Nome do serviço
  - name: OTEL_SERVICE_NAME
    value: "meu-servico"
  
  # Resource attributes
  - name: OTEL_RESOURCE_ATTRIBUTES
    value: "environment=lab,version=1.0.0"
```

## Troubleshooting

### Traces não aparecem no Jaeger

```bash
# 1. Verificar se OTel Collector está recebendo
kubectl logs -n monitoring -l app.kubernetes.io/instance=otel-collector | grep "Traces received"

# 2. Verificar se Jaeger está rodando
kubectl get pods -n monitoring -l app.kubernetes.io/instance=jaeger

# 3. Verificar conectividade
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n monitoring -- \
  curl -v http://jaeger.monitoring.svc.cluster.local:4318
```

### OpenTelemetry Demo não gera traces

```bash
# Verificar logs do frontend
kubectl logs -n app -l app.kubernetes.io/component=frontend

# Verificar se o collector do demo está enviando para o Jaeger
kubectl logs -n app -l app.kubernetes.io/component=otelcol
```

## Referências

- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
- [OpenTelemetry Demo](https://opentelemetry.io/docs/demo/)
- [OTLP Specification](https://opentelemetry.io/docs/specs/otlp/)

## Checklist de Implementação

- [ ] Jaeger instalado no namespace `monitoring`
- [ ] OpenTelemetry Collector instalado no namespace `monitoring`
- [ ] ServiceMonitor do OpenTelemetry Demo habilitado
- [ ] Pods rodando sem erros
- [ ] Trace de teste enviado e visualizado no Jaeger
- [ ] OpenTelemetry Demo gerando traces
- [ ] Jaeger UI acessível
- [ ] Integração com Grafana funcionando
- [ ] Métricas do OTel Collector no Prometheus

---

**Próximo Passo:** Explorar traces no Grafana e criar dashboards customizados
