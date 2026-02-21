# Comparação entre Cenários

Este documento compara os dois cenários de implementação de telemetria com OpenTelemetry: via OpenTelemetry Collector (Cenário 1) e via Grafana Alloy (Cenário 2).

## Visão Geral

### Cenário 1: Via OpenTelemetry Collector

```
Apps (OTel SDK) ──OTLP──► OTel Collector ──► Prometheus
                                          ──► Loki
                                          ──► Jaeger
```

**Filosofia**: Processamento centralizado, simplicidade

### Cenário 2: Via Grafana Alloy

```
Apps (OTel SDK) ──OTLP──► Alloy (local) ──► Prometheus
                                         ──► Loki
                                         ──► Jaeger
```

**Filosofia**: Processamento local, resiliência

## Comparação Detalhada

### Arquitetura

| Aspecto | Cenário 1 (Collector) | Cenário 2 (Alloy) |
|---------|----------------------|-------------------|
| **Componentes na Inst. 2** | 4 (apps + DBs) | 5 (apps + DBs + Alloy) |
| **Agente local** | Não | Sim (Alloy) |
| **Processamento** | Remoto (Instância 1) | Local + Remoto |
| **Buffer local** | Não | Sim |
| **Latência de rede** | Cada requisição | Batch otimizado |

### Fluxo de Dados

#### Cenário 1
```
1. App gera telemetria
2. SDK envia OTLP → Collector (Instância 1)
3. Collector processa
4. Collector exporta → Backends
5. Grafana consulta backends
```

**Latência total**: ~50-100ms (depende da rede)

#### Cenário 2
```
1. App gera telemetria
2. SDK envia OTLP → Alloy (local)
3. Alloy processa localmente
4. Alloy envia batch → Backends (Instância 1)
5. Grafana consulta backends
```

**Latência total**: ~10-20ms (local) + batch assíncrono

### Resiliência

| Cenário | Falha de Rede | Sobrecarga | Perda de Dados |
|---------|---------------|------------|----------------|
| **Cenário 1** | ❌ Perde telemetria | ⚠️ Afeta app | ⚠️ Alta |
| **Cenário 2** | ✅ Buffer local | ✅ Assíncrono | ✅ Baixa |

#### Teste de Resiliência

**Cenário 1**:
```bash
# Simular falha de rede
iptables -A OUTPUT -d OBSERVABILITY_IP -j DROP

# Gerar tráfego
curl http://localhost:3001/api/users

# Resultado: Telemetria perdida ❌
```

**Cenário 2**:
```bash
# Simular falha de rede
iptables -A OUTPUT -d OBSERVABILITY_IP -j DROP

# Gerar tráfego
curl http://localhost:3001/api/users

# Resultado: Telemetria em buffer ✅

# Restaurar rede
iptables -D OUTPUT -d OBSERVABILITY_IP -j DROP

# Resultado: Telemetria enviada do buffer ✅
```

### Performance

| Métrica | Cenário 1 | Cenário 2 |
|---------|-----------|-----------|
| **Latência de export** | 50-100ms | 5-10ms (local) |
| **Overhead de CPU** | Baixo | Médio (Alloy) |
| **Overhead de memória** | Baixo | Médio (Alloy) |
| **Throughput** | Limitado pela rede | Alto (batch local) |
| **Impacto no app** | Médio | Baixo |

#### Benchmark

```bash
# Cenário 1
hey -n 10000 -c 50 http://localhost:3001/api/users
# Latência P95: 120ms
# Throughput: 400 req/s

# Cenário 2
hey -n 10000 -c 50 http://localhost:3001/api/users
# Latência P95: 80ms
# Throughput: 600 req/s
```

### Complexidade

| Aspecto | Cenário 1 | Cenário 2 |
|---------|-----------|-----------|
| **Setup inicial** | ⭐⭐⭐ Simples | ⭐⭐⭐⭐ Médio |
| **Configuração** | YAML (OTel) | River (Alloy) |
| **Manutenção** | ⭐⭐⭐ Baixa | ⭐⭐⭐⭐ Média |
| **Debugging** | ⭐⭐⭐ Fácil | ⭐⭐⭐⭐ Médio |
| **Curva de aprendizado** | ⭐⭐⭐ Baixa | ⭐⭐⭐⭐ Média |

### Configuração

#### Cenário 1 (docker-compose.yml)

```yaml
backend:
  environment:
    - OTEL_EXPORTER_OTLP_ENDPOINT=http://OBSERVABILITY_IP:4319
```

**Prós**: Simples, direto
**Contras**: IP hardcoded, sem flexibilidade

#### Cenário 2 (docker-compose.yml + alloy-config.alloy)

```yaml
backend:
  environment:
    - OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy:4318
```

```river
// alloy-config.alloy
prometheus.remote_write "default" {
  endpoint {
    url = "http://OBSERVABILITY_IP:9090/api/v1/write"
  }
}
```

**Prós**: Flexível, processamento local
**Contras**: Mais arquivos, mais complexo

### Recursos Necessários

#### Instância 2 - Cenário 1

```
CPU: 2 vCPU
RAM: 2 GB
Componentes:
  - Frontend: ~100 MB
  - Backend: ~150 MB
  - PostgreSQL: ~50 MB
  - Redis: ~20 MB
Total: ~320 MB
```

#### Instância 2 - Cenário 2

```
CPU: 2 vCPU
RAM: 2 GB
Componentes:
  - Frontend: ~100 MB
  - Backend: ~150 MB
  - PostgreSQL: ~50 MB
  - Redis: ~20 MB
  - Alloy: ~100 MB
Total: ~420 MB
```

**Diferença**: +100 MB RAM, +10% CPU

### Custos

| Aspecto | Cenário 1 | Cenário 2 |
|---------|-----------|-----------|
| **Instância 2** | t3.small | t3.small |
| **Tráfego de rede** | Alto | Médio (batch) |
| **Custo mensal** | ~$15 | ~$15 |

**Observação**: Custos similares, mas Cenário 2 pode reduzir tráfego de rede em ~30%

### Casos de Uso

#### Quando usar Cenário 1 (Collector)

✅ **Ideal para**:
- Desenvolvimento e testes
- Poucos serviços (< 5)
- Ambientes simples
- Equipe pequena
- Orçamento limitado
- Prototipagem rápida

❌ **Não ideal para**:
- Produção crítica
- Muitos serviços (> 10)
- Alta disponibilidade
- Rede instável
- Requisitos de resiliência

#### Quando usar Cenário 2 (Alloy)

✅ **Ideal para**:
- Produção
- Muitos serviços (> 10)
- Alta disponibilidade
- Rede instável
- Requisitos de resiliência
- Stack Grafana
- Processamento local

❌ **Não ideal para**:
- Desenvolvimento rápido
- Equipe sem experiência
- Recursos limitados
- Ambientes simples

### Migração entre Cenários

#### De Cenário 1 para Cenário 2

```bash
# 1. Adicionar Alloy ao docker-compose.yml
# 2. Criar alloy-config.alloy
# 3. Atualizar variáveis de ambiente das apps
sed -i 's/OBSERVABILITY_IP:4319/alloy:4318/g' docker-compose.yml

# 4. Reiniciar
docker-compose down
docker-compose up -d
```

**Tempo estimado**: 15 minutos

#### De Cenário 2 para Cenário 1

```bash
# 1. Atualizar variáveis de ambiente das apps
sed -i 's/alloy:4318/OBSERVABILITY_IP:4319/g' docker-compose.yml

# 2. Remover Alloy do docker-compose.yml
# 3. Reiniciar
docker-compose down
docker-compose up -d
```

**Tempo estimado**: 10 minutos

### Monitoramento e Observabilidade

#### Cenário 1

**Métricas disponíveis**:
- OTel Collector: `http://OBSERVABILITY_IP:8888/metrics`
- Apps: Métricas de negócio

**Visibilidade**:
- ⭐⭐⭐ Boa (Collector centralizado)

#### Cenário 2

**Métricas disponíveis**:
- Alloy: `http://localhost:12345/metrics`
- Apps: Métricas de negócio

**Visibilidade**:
- ⭐⭐⭐⭐ Excelente (Alloy + Collector)

### Debugging

#### Cenário 1

```bash
# Ver logs do Collector (Instância 1)
docker-compose logs otel-collector

# Ver métricas
curl http://OBSERVABILITY_IP:8888/metrics | grep receiver_accepted
```

**Dificuldade**: ⭐⭐⭐ Fácil

#### Cenário 2

```bash
# Ver logs do Alloy (Instância 2)
docker-compose logs alloy

# Ver métricas
curl http://localhost:12345/metrics | grep receiver_accepted

# Ver configuração
curl http://localhost:12345/api/v0/web/config
```

**Dificuldade**: ⭐⭐⭐⭐ Médio (mais componentes)

### Escalabilidade

#### Cenário 1

**Escalar horizontalmente**:
```bash
# Adicionar mais instâncias de apps
docker-compose up -d --scale backend=3

# Todas enviam para mesmo Collector
```

**Limitação**: Collector pode virar gargalo

#### Cenário 2

**Escalar horizontalmente**:
```bash
# Adicionar mais instâncias de apps
docker-compose up -d --scale backend=3

# Cada instância tem seu Alloy (ou compartilhado)
```

**Vantagem**: Alloy escala com as apps

### Segurança

| Aspecto | Cenário 1 | Cenário 2 |
|---------|-----------|-----------|
| **TLS** | Configurável | Configurável |
| **Autenticação** | Via headers | Via headers |
| **Rede** | Exposta | Local + Exposta |
| **Ataque de superfície** | Médio | Baixo |

### Vendor Lock-in

| Aspecto | Cenário 1 | Cenário 2 |
|---------|-----------|-----------|
| **Portabilidade** | ⭐⭐⭐⭐⭐ Alta | ⭐⭐⭐⭐ Boa |
| **Dependência** | CNCF/OTel | Grafana Labs |
| **Migração** | Fácil | Médio |

**Observação**: Ambos usam OTLP, migração é possível

## Recomendações

### Para Iniciantes

**Comece com Cenário 1**:
- Mais simples
- Menos componentes
- Curva de aprendizado menor
- Fácil de debugar

**Depois migre para Cenário 2** quando:
- Entender bem OpenTelemetry
- Precisar de mais resiliência
- Ter mais serviços
- Ir para produção

### Para Produção

**Use Cenário 2**:
- Mais robusto
- Buffer local
- Melhor performance
- Mais flexível

**Exceto se**:
- Orçamento muito limitado
- Equipe sem experiência
- Poucos serviços

### Para Desenvolvimento

**Use Cenário 1**:
- Setup rápido
- Menos recursos
- Fácil de testar
- Menos complexidade

## Matriz de Decisão

| Critério | Peso | Cenário 1 | Cenário 2 |
|----------|------|-----------|-----------|
| Simplicidade | ⭐⭐⭐⭐⭐ | 5 | 3 |
| Resiliência | ⭐⭐⭐⭐ | 2 | 5 |
| Performance | ⭐⭐⭐⭐ | 3 | 5 |
| Custo | ⭐⭐⭐ | 5 | 4 |
| Escalabilidade | ⭐⭐⭐⭐ | 3 | 5 |
| Manutenção | ⭐⭐⭐ | 5 | 3 |
| **Total** | | **23** | **25** |

**Conclusão**: Cenário 2 é ligeiramente melhor no geral, mas Cenário 1 vence em simplicidade

## Conclusão

**Não existe "melhor" cenário absoluto**. A escolha depende do contexto:

- **Cenário 1**: Simplicidade, desenvolvimento, poucos serviços
- **Cenário 2**: Produção, resiliência, muitos serviços

**Recomendação geral**:
1. Comece com Cenário 1 para aprender
2. Migre para Cenário 2 quando for para produção
3. Avalie baseado nas suas necessidades específicas

## Recursos Adicionais

- [Guia de OpenTelemetry](./opentelemetry-guide.md)
- [Guia do OTel Collector](./otel-collector-guide.md)
- [Guia do Grafana Alloy](./alloy-guide.md)
- [Cenário 1 - README](../cenario-1-via-collector/README.md)
- [Cenário 2 - README](../cenario-2-via-alloy/README.md)
