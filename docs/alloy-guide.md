# Guia do Grafana Alloy

Grafana Alloy é um agente de telemetria open-source, vendor-neutral, que coleta, processa e encaminha dados de observabilidade (métricas, logs e traces).

## O que é Grafana Alloy?

Alloy é a evolução do **Grafana Agent**, redesenhado para ser mais flexível e poderoso. É parte do ecossistema Grafana, mas funciona com qualquer backend de observabilidade.

### Características Principais

- **Vendor-neutral**: Funciona com qualquer backend (não apenas Grafana Cloud)
- **OpenTelemetry nativo**: Suporte completo para OTLP
- **Configuração declarativa**: Linguagem River (inspirada em HCL/Terraform)
- **Componentes modulares**: Pipeline flexível e extensível
- **Leve e eficiente**: Baixo overhead de CPU e memória
- **Modo agente**: Roda localmente nas aplicações

## Alloy vs OpenTelemetry Collector

| Aspecto | Alloy | OTel Collector |
|---------|-------|----------------|
| **Origem** | Grafana Labs | CNCF / OpenTelemetry |
| **Linguagem config** | River | YAML |
| **Foco** | Stack Grafana + OTel | OpenTelemetry puro |
| **Componentes** | Grafana + OTel | Apenas OTel |
| **Prometheus** | Suporte nativo | Via exporter |
| **Loki** | Suporte nativo | Via exporter |
| **Complexidade** | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Ideal para** | Stack Grafana | Qualquer backend |

**Quando usar Alloy**:
- Você usa Grafana, Prometheus, Loki
- Quer configuração mais simples
- Precisa de features específicas do Grafana

**Quando usar OTel Collector**:
- Quer máxima portabilidade
- Usa backends não-Grafana
- Precisa de componentes específicos do OTel

## Arquitetura do Alloy

```
┌─────────────────────────────────────────────────────────────┐
│                      Grafana Alloy                          │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                   Receivers                          │  │
│  │  (OTLP, Prometheus, Loki, Jaeger, etc.)             │  │
│  └────────────────────┬─────────────────────────────────┘  │
│                       │                                     │
│  ┌────────────────────▼─────────────────────────────────┐  │
│  │                   Processors                         │  │
│  │  (Batch, Filter, Transform, Attributes, etc.)       │  │
│  └────────────────────┬─────────────────────────────────┘  │
│                       │                                     │
│  ┌────────────────────▼─────────────────────────────────┐  │
│  │                   Exporters                          │  │
│  │  (Prometheus, Loki, Jaeger, OTLP, etc.)             │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Linguagem River

River é a linguagem de configuração do Alloy, inspirada em HCL (Terraform) e Starlark.

### Sintaxe Básica

```river
// Comentário de linha

/* Comentário
   de bloco */

// Bloco de componente
component_type "label" {
  argument = "value"
  
  nested_block {
    key = "value"
  }
}
```

### Tipos de Dados

```river
// String
name = "backend-service"

// Number
port = 4318
timeout = 5.5

// Boolean
enabled = true

// Array
ports = [4317, 4318]

// Object
config = {
  host = "localhost"
  port = 9090
}
```

### Referências

```river
// Definir componente
otelcol.receiver.otlp "default" {
  http {
    endpoint = "0.0.0.0:4318"
  }
  
  output {
    metrics = [otelcol.processor.batch.default.input]
  }
}

// Referenciar output de outro componente
otelcol.processor.batch "default" {
  output {
    metrics = [otelcol.exporter.prometheus.default.input]
  }
}
```

## Componentes do Alloy

### 1. Receivers (Recebedores)

#### OTLP Receiver

```river
otelcol.receiver.otlp "default" {
  // HTTP endpoint
  http {
    endpoint = "0.0.0.0:4318"
  }
  
  // gRPC endpoint
  grpc {
    endpoint = "0.0.0.0:4317"
  }
  
  // Output para próximo componente
  output {
    metrics = [otelcol.processor.batch.default.input]
    logs    = [otelcol.processor.batch.default.input]
    traces  = [otelcol.processor.batch.default.input]
  }
}
```

#### Prometheus Receiver

```river
prometheus.scrape "default" {
  targets = [
    {"__address__" = "localhost:8080"},
    {"__address__" = "localhost:9090"},
  ]
  
  forward_to = [prometheus.remote_write.default.receiver]
}
```

### 2. Processors (Processadores)

#### Batch Processor

```river
otelcol.processor.batch "default" {
  // Timeout para enviar batch
  timeout = "5s"
  
  // Tamanho do batch
  send_batch_size = 100
  
  // Tamanho máximo do batch
  send_batch_max_size = 1000
  
  output {
    metrics = [otelcol.processor.attributes.default.input]
    logs    = [otelcol.processor.attributes.default.input]
    traces  = [otelcol.processor.attributes.default.input]
  }
}
```

#### Attributes Processor

```river
otelcol.processor.attributes "default" {
  // Inserir atributo
  action {
    key    = "environment"
    value  = "production"
    action = "insert"
  }
  
  // Atualizar atributo
  action {
    key    = "service.version"
    value  = "2.0.0"
    action = "update"
  }
  
  // Deletar atributo
  action {
    key    = "internal.field"
    action = "delete"
  }
  
  output {
    metrics = [otelcol.exporter.prometheus.default.input]
    logs    = [otelcol.exporter.loki.default.input]
    traces  = [otelcol.exporter.otlp.default.input]
  }
}
```

#### Filter Processor

```river
otelcol.processor.filter "drop_health_checks" {
  // Filtrar traces
  traces {
    span = [
      "attributes[\"http.route\"] == \"/health\"",
    ]
  }
  
  // Filtrar métricas
  metrics {
    metric = [
      "name == \"health_check_duration\"",
    ]
  }
  
  output {
    metrics = [otelcol.exporter.prometheus.default.input]
    traces  = [otelcol.exporter.otlp.default.input]
  }
}
```

#### Transform Processor

```river
otelcol.processor.transform "rename_attributes" {
  error_mode = "ignore"
  
  trace_statements {
    context = "span"
    statements = [
      "set(attributes[\"http.method\"], attributes[\"method\"])",
      "delete_key(attributes, \"method\")",
    ]
  }
  
  output {
    traces = [otelcol.exporter.otlp.default.input]
  }
}
```

### 3. Exporters (Exportadores)

#### Prometheus Exporter (Remote Write)

```river
otelcol.exporter.prometheus "default" {
  forward_to = [prometheus.remote_write.default.receiver]
}

prometheus.remote_write "default" {
  endpoint {
    url = "http://prometheus:9090/api/v1/write"
    
    // Configuração de fila
    queue_config {
      capacity             = 10000
      max_shards           = 10
      min_shards           = 1
      max_samples_per_send = 5000
      batch_send_deadline  = "5s"
    }
    
    // Retry
    retry_on_http_429 = true
    
    // Timeout
    timeout = "30s"
  }
}
```

#### Loki Exporter

```river
otelcol.exporter.loki "default" {
  forward_to = [loki.write.default.receiver]
}

loki.write "default" {
  endpoint {
    url = "http://loki:3100/loki/api/v1/push"
    
    // Configuração de fila
    queue_config {
      capacity             = 10000
      max_shards           = 10
      min_shards           = 1
      max_samples_per_send = 5000
      batch_send_deadline  = "5s"
    }
    
    // Headers customizados
    headers = {
      "X-Scope-OrgID" = "tenant1",
    }
  }
}
```

#### OTLP Exporter (Jaeger)

```river
otelcol.exporter.otlp "jaeger" {
  client {
    endpoint = "jaeger:4318"
    
    // TLS
    tls {
      insecure = true
    }
    
    // Timeout
    timeout = "30s"
    
    // Retry
    retry_on_failure {
      enabled         = true
      initial_interval = "5s"
      max_interval    = "30s"
      max_elapsed_time = "5m"
    }
    
    // Headers
    headers = {
      "api-key" = "secret",
    }
  }
}
```

## Pipeline Completo (Exemplo)

```river
// ============================================================================
// RECEIVERS
// ============================================================================

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

// ============================================================================
// PROCESSORS
// ============================================================================

otelcol.processor.batch "default" {
  timeout          = "5s"
  send_batch_size  = 100
  
  output {
    metrics = [otelcol.processor.attributes.default.input]
    logs    = [otelcol.processor.attributes.default.input]
    traces  = [otelcol.processor.attributes.default.input]
  }
}

otelcol.processor.attributes "default" {
  action {
    key    = "deployment.environment"
    value  = "production"
    action = "insert"
  }
  
  action {
    key    = "telemetry.agent"
    value  = "alloy"
    action = "insert"
  }
  
  output {
    metrics = [otelcol.exporter.prometheus.default.input]
    logs    = [otelcol.exporter.loki.default.input]
    traces  = [otelcol.exporter.otlp.jaeger.input]
  }
}

// ============================================================================
// EXPORTERS
// ============================================================================

otelcol.exporter.prometheus "default" {
  forward_to = [prometheus.remote_write.default.receiver]
}

prometheus.remote_write "default" {
  endpoint {
    url = "http://prometheus:9090/api/v1/write"
  }
}

otelcol.exporter.loki "default" {
  forward_to = [loki.write.default.receiver]
}

loki.write "default" {
  endpoint {
    url = "http://loki:3100/loki/api/v1/push"
  }
}

otelcol.exporter.otlp "jaeger" {
  client {
    endpoint = "jaeger:4318"
    tls {
      insecure = true
    }
  }
}

// ============================================================================
// LOGGING
// ============================================================================

logging {
  level  = "info"
  format = "logfmt"
}
```

## Modos de Operação

### 1. Modo Agente (Recomendado)

```
App ──OTLP──► Alloy (local) ──► Backends
```

- Alloy roda **localmente** com a aplicação
- Buffer local para resiliência
- Processamento local

### 2. Modo Gateway

```
Apps ──OTLP──► Alloy (centralizado) ──► Backends
```

- Alloy roda **centralizado**
- Processamento centralizado
- Similar ao OTel Collector

### 3. Modo Híbrido

```
Apps ──OTLP──► Alloy (local) ──OTLP──► Alloy (gateway) ──► Backends
```

- Dois níveis de processamento
- Máxima flexibilidade

## Configuração e Deployment

### Docker

```yaml
services:
  alloy:
    image: grafana/alloy:latest
    ports:
      - "4318:4318"
      - "4317:4317"
      - "12345:12345"
    command:
      - run
      - --server.http.listen-addr=0.0.0.0:12345
      - --storage.path=/var/lib/alloy/data
      - /etc/alloy/config.alloy
    volumes:
      - ./alloy-config.alloy:/etc/alloy/config.alloy
      - alloy-data:/var/lib/alloy
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: alloy
spec:
  selector:
    matchLabels:
      app: alloy
  template:
    metadata:
      labels:
        app: alloy
    spec:
      containers:
      - name: alloy
        image: grafana/alloy:latest
        args:
          - run
          - --server.http.listen-addr=0.0.0.0:12345
          - --storage.path=/var/lib/alloy/data
          - /etc/alloy/config.alloy
        ports:
          - containerPort: 4318
            name: otlp-http
          - containerPort: 4317
            name: otlp-grpc
          - containerPort: 12345
            name: http
        volumeMounts:
          - name: config
            mountPath: /etc/alloy
      volumes:
        - name: config
          configMap:
            name: alloy-config
```

## Monitoramento do Alloy

### Métricas Internas

```bash
# Endpoint de métricas
curl http://localhost:12345/metrics

# Métricas importantes:
# - alloy_otelcol_receiver_accepted_spans
# - alloy_otelcol_receiver_refused_spans
# - alloy_otelcol_processor_batch_batch_send_size
# - alloy_otelcol_exporter_sent_spans
# - alloy_otelcol_exporter_send_failed_spans
# - alloy_otelcol_exporter_queue_size
```

### Health Check

```bash
# Health endpoint
curl http://localhost:12345/-/healthy

# Ready endpoint
curl http://localhost:12345/-/ready
```

### API de Configuração

```bash
# Ver configuração carregada
curl http://localhost:12345/api/v0/web/config

# Ver componentes ativos
curl http://localhost:12345/api/v0/web/components

# Ver métricas de componentes
curl http://localhost:12345/api/v0/web/components/otelcol.receiver.otlp.default/metrics
```

## Debugging

### Logs

```river
logging {
  level  = "debug"  // debug, info, warn, error
  format = "logfmt" // logfmt, json
}
```

### Debug Exporter

```river
otelcol.exporter.debug "default" {
  verbosity           = "detailed"
  sampling_initial    = 5
  sampling_thereafter = 200
}

otelcol.processor.batch "default" {
  output {
    metrics = [otelcol.exporter.debug.default.input]
    logs    = [otelcol.exporter.debug.default.input]
    traces  = [otelcol.exporter.debug.default.input]
  }
}
```

## Melhores Práticas

### 1. Configuração

- ✅ Use batch processor (reduz overhead)
- ✅ Configure timeouts adequados
- ✅ Use queue_config para resiliência
- ✅ Adicione retry_on_failure
- ❌ Não use processadores desnecessários

### 2. Performance

- ✅ Ajuste send_batch_size baseado no volume
- ✅ Configure max_shards para paralelismo
- ✅ Use filter processor para reduzir volume
- ❌ Não processe tudo se não precisa

### 3. Resiliência

- ✅ Configure queue_config com capacity adequado
- ✅ Use retry_on_failure
- ✅ Configure timeout apropriado
- ✅ Monitore queue_size

### 4. Segurança

- ✅ Use TLS quando possível
- ✅ Configure autenticação (headers, tokens)
- ✅ Não exponha portas desnecessárias
- ❌ Não use insecure=true em produção

## Troubleshooting

### Alloy não inicia

```bash
# Verificar logs
docker logs alloy

# Testar sintaxe
alloy fmt config.alloy

# Validar configuração
alloy run --config.file=config.alloy --dry-run
```

### Telemetria não chega

```bash
# Verificar se está recebendo
curl http://localhost:12345/metrics | grep receiver_accepted

# Verificar se está enviando
curl http://localhost:12345/metrics | grep exporter_sent

# Verificar fila
curl http://localhost:12345/metrics | grep queue_size
```

### Performance degradada

```bash
# Verificar CPU/memória
docker stats alloy

# Verificar métricas
curl http://localhost:12345/metrics | grep -E "queue_size|batch_size"

# Ajustar batch_size e max_shards
```

## Recursos Adicionais

- [Alloy Documentation](https://grafana.com/docs/alloy/)
- [River Language Reference](https://grafana.com/docs/alloy/latest/concepts/configuration-syntax/)
- [Component Reference](https://grafana.com/docs/alloy/latest/reference/components/)
- [Migration from Grafana Agent](https://grafana.com/docs/alloy/latest/tasks/migrate/)
- [Guia de OpenTelemetry](./opentelemetry-guide.md)
- [Comparação de Cenários](./comparison-scenarios.md)
