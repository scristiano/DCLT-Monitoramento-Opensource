# Guia do OpenTelemetry Collector

O OpenTelemetry Collector é um componente vendor-neutral que recebe, processa e exporta dados de telemetria (métricas, logs e traces).

## O que é o OTel Collector?

O Collector é um **proxy de telemetria** que fica entre suas aplicações e os backends de observabilidade. Ele desacopla a instrumentação da exportação, permitindo flexibilidade e controle sobre o pipeline de telemetria.

### Por que usar o Collector?

#### Sem Collector
```
App 1 ──► Prometheus
       ──► Loki
       ──► Jaeger

App 2 ──► Prometheus
       ──► Loki
       ──► Jaeger
```

**Problemas**:
- Cada app precisa conhecer todos os backends
- Mudança de backend = mudança em todas as apps
- Sem processamento centralizado
- Sem buffer/retry centralizado

#### Com Collector
```
App 1 ──┐
        ├──► Collector ──► Prometheus
App 2 ──┘              ──► Loki
                       ──► Jaeger
```

**Benefícios**:
- Apps só conhecem o Collector
- Mudança de backend = mudança só no Collector
- Processamento centralizado
- Buffer/retry centralizado
- Governança de dados

## Arquitetura do Collector

```
┌─────────────────────────────────────────────────────────────┐
│              OpenTelemetry Collector                        │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                   Receivers                          │  │
│  │  (OTLP, Jaeger, Zipkin, Prometheus, etc.)           │  │
│  └────────────────────┬─────────────────────────────────┘  │
│                       │                                     │
│  ┌────────────────────▼─────────────────────────────────┐  │
│  │                   Processors                         │  │
│  │  (Batch, Filter, Transform, Sampling, etc.)         │  │
│  └────────────────────┬─────────────────────────────────┘  │
│                       │                                     │
│  ┌────────────────────▼─────────────────────────────────┐  │
│  │                   Exporters                          │  │
│  │  (OTLP, Prometheus, Loki, Jaeger, etc.)             │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                   Extensions                         │  │
│  │  (Health Check, pprof, zpages, etc.)                │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Componentes

#### 1. Receivers (Recebedores)
- Recebem telemetria de aplicações
- Suportam múltiplos protocolos
- Exemplos: OTLP, Jaeger, Zipkin, Prometheus

#### 2. Processors (Processadores)
- Transformam, filtram e enriquecem telemetria
- Executam em ordem (pipeline)
- Exemplos: Batch, Filter, Attributes, Sampling

#### 3. Exporters (Exportadores)
- Enviam telemetria para backends
- Suportam múltiplos destinos
- Exemplos: OTLP, Prometheus, Jaeger, Loki

#### 4. Extensions (Extensões)
- Funcionalidades auxiliares
- Não processam telemetria
- Exemplos: Health Check, pprof, zpages

## Configuração YAML

### Estrutura Básica

```yaml
receivers:
  # Configuração de receivers

processors:
  # Configuração de processors

exporters:
  # Configuração de exporters

extensions:
  # Configuração de extensions

service:
  extensions: [health_check, pprof]
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [jaeger]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [prometheus]
    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [loki]
```

## Receivers

### OTLP Receiver

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
        cors:
          allowed_origins:
            - http://*
            - https://*
```

### Prometheus Receiver

```yaml
receivers:
  prometheus:
    config:
      scrape_configs:
        - job_name: 'otel-collector'
          scrape_interval: 10s
          static_configs:
            - targets: ['localhost:8888']
```

### Jaeger Receiver

```yaml
receivers:
  jaeger:
    protocols:
      grpc:
        endpoint: 0.0.0.0:14250
      thrift_http:
        endpoint: 0.0.0.0:14268
```

## Processors

### Batch Processor

```yaml
processors:
  batch:
    # Timeout para enviar batch
    timeout: 10s
    
    # Tamanho do batch
    send_batch_size: 1024
    
    # Tamanho máximo do batch
    send_batch_max_size: 2048
```

**Por que usar**:
- Reduz número de requisições
- Melhora throughput
- Reduz overhead de rede

### Attributes Processor

```yaml
processors:
  attributes:
    actions:
      # Inserir atributo
      - key: environment
        value: production
        action: insert
      
      # Atualizar atributo
      - key: service.version
        value: 2.0.0
        action: update
      
      # Deletar atributo
      - key: internal.field
        action: delete
      
      # Extrair de outro atributo
      - key: http.method
        from_attribute: method
        action: extract
```

### Filter Processor

```yaml
processors:
  filter:
    # Filtrar traces
    traces:
      span:
        # Remover health checks
        - 'attributes["http.route"] == "/health"'
        - 'attributes["http.route"] == "/metrics"'
    
    # Filtrar métricas
    metrics:
      metric:
        # Remover métricas específicas
        - 'name == "health_check_duration"'
```

### Resource Processor

```yaml
processors:
  resource:
    attributes:
      # Adicionar atributos de resource
      - key: deployment.environment
        value: production
        action: insert
      
      - key: service.namespace
        value: api
        action: insert
      
      - key: cloud.provider
        value: aws
        action: insert
```

### Resource Detection Processor

```yaml
processors:
  resourcedetection:
    detectors: [env, system, docker, ec2]
    timeout: 5s
    override: false
```

**Detecta automaticamente**:
- Variáveis de ambiente
- Informações do sistema (hostname, OS)
- Container ID (Docker)
- Metadados EC2 (região, AZ, instance ID)

### Tail Sampling Processor

```yaml
processors:
  tail_sampling:
    decision_wait: 10s
    num_traces: 100
    expected_new_traces_per_sec: 10
    policies:
      # Sempre coletar traces com erro
      - name: errors
        type: status_code
        status_code:
          status_codes: [ERROR]
      
      # Coletar traces lentos
      - name: slow
        type: latency
        latency:
          threshold_ms: 1000
      
      # Coletar 10% dos demais
      - name: probabilistic
        type: probabilistic
        probabilistic:
          sampling_percentage: 10
```

### Memory Limiter Processor

```yaml
processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 512
    spike_limit_mib: 128
```

**Protege contra**:
- Out of memory
- Sobrecarga do Collector

## Exporters

### OTLP Exporter

```yaml
exporters:
  otlp:
    endpoint: jaeger:4317
    tls:
      insecure: true
    retry_on_failure:
      enabled: true
      initial_interval: 5s
      max_interval: 30s
      max_elapsed_time: 300s
```

### Prometheus Exporter (Remote Write)

```yaml
exporters:
  prometheusremotewrite:
    endpoint: http://prometheus:9090/api/v1/write
    tls:
      insecure: true
    retry_on_failure:
      enabled: true
    queue:
      enabled: true
      num_consumers: 10
      queue_size: 1000
```

### Loki Exporter

```yaml
exporters:
  loki:
    endpoint: http://loki:3100/loki/api/v1/push
    tls:
      insecure: true
    retry_on_failure:
      enabled: true
```

### Logging Exporter (Debug)

```yaml
exporters:
  logging:
    verbosity: detailed
    sampling_initial: 5
    sampling_thereafter: 200
```

## Extensions

### Health Check

```yaml
extensions:
  health_check:
    endpoint: 0.0.0.0:13133
    path: /health
```

### pprof (Profiling)

```yaml
extensions:
  pprof:
    endpoint: 0.0.0.0:1777
```

### zpages (Debug)

```yaml
extensions:
  zpages:
    endpoint: 0.0.0.0:55679
```

## Service (Pipelines)

```yaml
service:
  # Extensions ativas
  extensions: [health_check, pprof, zpages]
  
  # Pipelines
  pipelines:
    # Pipeline de traces
    traces:
      receivers: [otlp, jaeger]
      processors: [memory_limiter, batch, resourcedetection, attributes]
      exporters: [otlp, logging]
    
    # Pipeline de métricas
    metrics:
      receivers: [otlp, prometheus]
      processors: [memory_limiter, batch, resourcedetection]
      exporters: [prometheusremotewrite, logging]
    
    # Pipeline de logs
    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch, resourcedetection, attributes]
      exporters: [loki, logging]
  
  # Telemetria do próprio Collector
  telemetry:
    logs:
      level: info
    metrics:
      level: detailed
      address: 0.0.0.0:8888
```

## Configuração Completa (Exemplo)

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 512
  
  batch:
    timeout: 10s
    send_batch_size: 1024
  
  resourcedetection:
    detectors: [env, system, docker]
    timeout: 5s
  
  attributes:
    actions:
      - key: deployment.environment
        value: production
        action: insert

exporters:
  otlp:
    endpoint: jaeger:4317
    tls:
      insecure: true
  
  prometheusremotewrite:
    endpoint: http://prometheus:9090/api/v1/write
  
  loki:
    endpoint: http://loki:3100/loki/api/v1/push
  
  logging:
    verbosity: normal

extensions:
  health_check:
    endpoint: 0.0.0.0:13133
  
  pprof:
    endpoint: 0.0.0.0:1777

service:
  extensions: [health_check, pprof]
  
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch, resourcedetection, attributes]
      exporters: [otlp]
    
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch, resourcedetection]
      exporters: [prometheusremotewrite]
    
    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch, resourcedetection, attributes]
      exporters: [loki]
  
  telemetry:
    logs:
      level: info
    metrics:
      address: 0.0.0.0:8888
```

## Modos de Deployment

### 1. Agent Mode (Sidecar)

```
App ──► Collector (local) ──► Collector (gateway) ──► Backends
```

- Collector roda junto com a aplicação
- Baixa latência
- Buffer local

### 2. Gateway Mode (Centralizado)

```
App 1 ──┐
App 2 ──┼──► Collector (gateway) ──► Backends
App 3 ──┘
```

- Collector centralizado
- Processamento centralizado
- Escalável horizontalmente

### 3. Hybrid Mode

```
Apps ──► Collector (agent) ──► Collector (gateway) ──► Backends
```

- Dois níveis de processamento
- Máxima flexibilidade

## Monitoramento do Collector

### Métricas Internas

```bash
# Endpoint de métricas
curl http://localhost:8888/metrics

# Métricas importantes:
# - otelcol_receiver_accepted_spans
# - otelcol_receiver_refused_spans
# - otelcol_processor_batch_batch_send_size
# - otelcol_exporter_sent_spans
# - otelcol_exporter_send_failed_spans
# - otelcol_exporter_queue_size
```

### Health Check

```bash
curl http://localhost:13133/health
```

### zpages (Debug)

```bash
# Ver pipelines
http://localhost:55679/debug/pipelinez

# Ver traces
http://localhost:55679/debug/tracez

# Ver service
http://localhost:55679/debug/servicez
```

## Melhores Práticas

### 1. Sempre use Memory Limiter

```yaml
processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 512
```

**Por que**: Protege contra OOM

### 2. Sempre use Batch Processor

```yaml
processors:
  batch:
    timeout: 10s
    send_batch_size: 1024
```

**Por que**: Reduz overhead de rede

### 3. Configure Retry

```yaml
exporters:
  otlp:
    retry_on_failure:
      enabled: true
      initial_interval: 5s
      max_interval: 30s
```

**Por que**: Resiliência contra falhas temporárias

### 4. Use Resource Detection

```yaml
processors:
  resourcedetection:
    detectors: [env, system, docker, ec2]
```

**Por que**: Enriquece telemetria automaticamente

### 5. Monitore o Collector

```yaml
service:
  telemetry:
    metrics:
      address: 0.0.0.0:8888
```

**Por que**: Visibilidade do próprio Collector

## Troubleshooting

### Collector não inicia

```bash
# Verificar logs
docker logs otel-collector

# Validar configuração
otelcol validate --config=config.yaml
```

### Telemetria não chega

```bash
# Verificar métricas do receiver
curl http://localhost:8888/metrics | grep receiver_accepted

# Verificar métricas do exporter
curl http://localhost:8888/metrics | grep exporter_sent

# Verificar logs
docker logs otel-collector | grep error
```

### Performance degradada

```bash
# Verificar uso de recursos
docker stats otel-collector

# Verificar queue size
curl http://localhost:8888/metrics | grep queue_size

# Ajustar batch_size e memory_limiter
```

### Perda de dados

```bash
# Verificar refused/dropped
curl http://localhost:8888/metrics | grep -E "refused|dropped"

# Aumentar memory_limiter
# Aumentar queue_size
# Adicionar mais replicas
```

## Recursos Adicionais

- [OTel Collector Documentation](https://opentelemetry.io/docs/collector/)
- [Collector Configuration](https://opentelemetry.io/docs/collector/configuration/)
- [Collector Components](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main)
- [Guia de OpenTelemetry](./opentelemetry-guide.md)
- [Comparação com Alloy](./alloy-guide.md)
