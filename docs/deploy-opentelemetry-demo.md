# Deploy OpenTelemetry Demo - Aplicação de Teste

Guia para instalar a aplicação de demonstração OpenTelemetry, uma loja online com múltiplos microserviços que gera métricas, logs e traces automaticamente.

## Sobre o OpenTelemetry Demo

A aplicação **OpenTelemetry Demo** (Astronomy Shop) é uma aplicação de e-commerce completa com:

- **11+ microserviços** em diferentes linguagens (Go, Java, Python, Node.js, .NET, etc.)
- **Geração automática** de métricas, logs e traces
- **Load Generator** para simular tráfego realista
- **Feature Flags** para testar diferentes cenários
- **Integração nativa** com OpenTelemetry

### Arquitetura

```
┌─────────────────────────────────────────────────────────────────┐
│                    OPENTELEMETRY DEMO                           │
│                                                                 │
│  Frontend (Web Store)                                           │
│       ↓                                                         │
│  ┌──────────────────────────────────────────────────────┐      │
│  │  Microserviços:                                      │      │
│  │  • Ad Service (Java)                                 │      │
│  │  • Cart Service (C#)                                 │      │
│  │  • Checkout Service (Go)                             │      │
│  │  • Currency Service (C++)                            │      │
│  │  • Email Service (Ruby)                              │      │
│  │  • Payment Service (JavaScript)                      │      │
│  │  • Product Catalog (Go)                              │      │
│  │  • Recommendation (Python)                           │      │
│  │  • Shipping Service (Rust)                           │      │
│  │  • Quote Service (PHP)                               │      │
│  │  • Accounting Service (Go)                           │      │
│  │  • Fraud Detection (Kotlin)                          │      │
│  └──────────────────────────────────────────────────────┘      │
│       ↓                                                         │
│  OpenTelemetry Collector                                        │
│       ↓                                                         │
│  ┌──────────────┬──────────────┬──────────────┐               │
│  │  Prometheus  │     Loki     │    Jaeger    │               │
│  │  (Métricas)  │    (Logs)    │   (Traces)   │               │
│  └──────────────┴──────────────┴──────────────┘               │
└─────────────────────────────────────────────────────────────────┘
```

## Pré-requisitos

- Cluster EKS configurado e rodando
- Stack de observabilidade instalada (Prometheus, Grafana, Loki)
- Pelo menos 2GB de RAM disponível no cluster
- DNS configurado para `astronomy-shop.demo.lynxnetwork.com.br`

## Instalação

### 1. Adicionar Repositório Helm

```bash
# Adicionar repositório OpenTelemetry
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts

# Atualizar repositórios
helm repo update
```

### 2. Criar Namespace

```bash
# Criar namespace para aplicações
kubectl create namespace app

# Verificar namespace
kubectl get namespace app
```

### 3. Instalar OpenTelemetry Demo

```bash
# Instalar com valores customizados
helm upgrade --install otel-demo open-telemetry/opentelemetry-demo \
  --namespace app \
  --values helm-values/opentelemetry-demo/values.yaml \
  --wait \
  --timeout 10m

# Verificar instalação
kubectl get pods -n app
```

### 4. Aguardar Pods Ficarem Prontos

```bash
# Monitorar status dos pods
kubectl get pods -n app -w

# Verificar se todos estão Running (pode levar 3-5 minutos)
kubectl get pods -n app
```

### 5. Verificar Ingress

```bash
# Verificar se o Ingress foi criado
kubectl get ingress -n app

# O Ingress compartilha o mesmo ALB (eks-lab-alb) com Grafana e Prometheus
```

### 6. Configurar DNS

Adicionar registro DNS apontando para o ALB:

```bash
# Obter endereço do ALB
kubectl get ingress -n app

# Criar registro DNS
# astronomy-shop.demo.lynxnetwork.com.br → CNAME → eks-lab-alb-XXXXXXXXX.us-east-1.elb.amazonaws.com
```

## Acessar a Aplicação

Após a instalação e configuração do DNS:

### Web Store (Loja Online)
```
URL: https://astronomy-shop.demo.lynxnetwork.com.br
```

Navegue pela loja, adicione produtos ao carrinho, faça checkout para gerar telemetria.

### Load Generator UI
```
URL: https://astronomy-shop.demo.lynxnetwork.com.br/loadgen/
```

Interface para controlar o gerador de carga (tráfego sintético).

### Feature Flags UI
```
URL: https://astronomy-shop.demo.lynxnetwork.com.br/feature/
```

Interface para habilitar/desabilitar features e testar diferentes cenários.

## Visualizar Telemetria

### 1. Métricas no Prometheus

Acessar Prometheus: `https://prometheus.demo.lynxnetwork.com.br`

**Queries úteis:**

```promql
# Taxa de requisições por serviço
rate(http_server_duration_count[5m])

# Latência P95 por serviço
histogram_quantile(0.95, rate(http_server_duration_bucket[5m]))

# Erros HTTP
rate(http_server_duration_count{http_status_code=~"5.."}[5m])

# CPU por pod
rate(container_cpu_usage_seconds_total{namespace="app"}[5m])

# Memória por pod
container_memory_working_set_bytes{namespace="app"}
```

### 2. Logs no Grafana/Loki

Acessar Grafana: `https://grafana.demo.lynxnetwork.com.br`

**Ir em Explore → Loki:**

```logql
# Todos os logs da demo
{namespace="app"}

# Logs de um serviço específico
{namespace="app", service_name="checkoutservice"}

# Filtrar por nível de log
{namespace="app"} |= "error"

# Logs de checkout com erro
{namespace="app", service_name="checkoutservice"} |= "error"
```

### 3. Dashboards no Grafana

O Grafana já tem dashboards pré-configurados:

1. **Kubernetes / Compute Resources / Namespace (Pods)**
   - Selecionar namespace: `app`
   - Ver CPU, memória, rede por pod

2. **Kubernetes / Compute Resources / Pod**
   - Selecionar pod específico
   - Ver métricas detalhadas

3. **Criar Dashboard Customizado**
   - Adicionar painéis com queries do Prometheus
   - Adicionar logs do Loki
   - Correlacionar métricas e logs

## Testar Cenários

### 1. Gerar Tráfego

O Load Generator já está gerando tráfego automaticamente. Para aumentar:

```bash
# Escalar o load generator
kubectl scale deployment otel-demo-loadgenerator -n app --replicas=3

# Verificar
kubectl get pods -n app | grep loadgenerator
```

### 2. Simular Erros

Acessar Feature Flags UI e habilitar flags de erro:

```
URL: https://astronomy-shop.demo.lynxnetwork.com.br/feature/
```

Habilitar flags como:
- `cartServiceFailure` - Simula falha no carrinho
- `productCatalogFailure` - Simula falha no catálogo
- `recommendationServiceCacheFailure` - Simula falha no cache

### 3. Observar Impacto

Após habilitar erros:

1. **Prometheus**: Ver aumento de erros HTTP 5xx
2. **Loki**: Ver logs de erro nos serviços afetados
3. **Grafana**: Ver impacto em dashboards de latência e taxa de erro

## Troubleshooting

### Pods não iniciam

```bash
# Verificar eventos
kubectl get events -n app --sort-by='.lastTimestamp'

# Verificar recursos
kubectl describe pod <pod-name> -n app

# Verificar logs
kubectl logs -n app <pod-name>
```

### Ingress não funciona

```bash
# Verificar Ingress
kubectl describe ingress -n app

# Verificar ALB
kubectl get ingress -n app

# Verificar logs do ALB controller
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

### Métricas não aparecem no Prometheus

```bash
# Verificar ServiceMonitor
kubectl get servicemonitor -n app

# Verificar se Prometheus está scraping
# Acessar Prometheus → Status → Targets
# Procurar por "app"
```

### Logs não aparecem no Loki

```bash
# Verificar se Promtail está coletando
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail | grep "namespace=\"app\""

# Verificar configuração do Collector
kubectl logs -n app deployment/otel-demo-otelcol
```

## Desinstalar

```bash
# Desinstalar aplicação
helm uninstall otel-demo -n app

# Deletar namespace (opcional)
kubectl delete namespace app
```

## Recursos Estimados

| Componente | CPU Request | Memory Request |
|------------|-------------|----------------|
| Frontend | 50m | 100Mi |
| Load Generator | 100m | 128Mi |
| Microserviços (11x) | 50m × 11 | 100Mi × 11 |
| OTel Collector | 100m | 256Mi |
| **Total** | **~1.3 CPU** | **~1.8Gi** |

## Próximos Passos

Após instalar a demo:

1. **Explorar a aplicação** navegando pela loja
2. **Criar dashboards customizados** no Grafana
3. **Configurar alertas** no Prometheus/Alertmanager
4. **Testar diferentes cenários** com Feature Flags
5. **Analisar correlação** entre métricas, logs e traces

A aplicação OpenTelemetry Demo é perfeita para aprender e testar observabilidade em um ambiente realista com múltiplos microserviços!
