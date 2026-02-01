# Aula 06 - PosTech DevOps e Arquitetura Cloud

Este repositório contém os materiais da **Aula 06** do módulo **Monitoramento OpenSource** da PosTech DevOps e Arquitetura Cloud.

## Visão Geral

```
┌─────────────────────────────────────────────────────────────────────┐
│                    INSTÂNCIA 1 (Observabilidade)                    │
│                         ★ ÚNICA PARA AMBOS ★                        │
│                                                                     │
│  ┌──────────┐  ┌────────────┐  ┌──────┐  ┌────────┐  ┌──────────┐ │
│  │ Grafana  │  │ Prometheus │  │ Loki │  │ Jaeger │  │OTel Coll.│ │
│  │  :3000   │  │   :9090    │  │:3100 │  │ :16686 │  │  :4319   │ │
│  └────┬─────┘  └─────┬──────┘  └───┬──┘  └────┬───┘  └────┬─────┘ │
│       └──────────────┼──────────────┼──────────┼───────────┘       │
└───────────────────────┼──────────────┼──────────┼───────────────────┘
                        │              │          │
        ┌───────────────┴──────────────┴──────────┴───────────┐
        │                                                      │
        ▼                                                      ▼
┌─────────────────────────────────┐    ┌─────────────────────────────────┐
│  CENÁRIO 1 (Instância 2)        │    │  CENÁRIO 2 (Instância 2)        │
│  Via OpenTelemetry Collector    │    │  Via Grafana Alloy              │
│                                 │    │                                 │
│  ┌──────────┐  ┌──────────┐    │    │  ┌──────────┐  ┌──────────┐    │
│  │ Frontend │  │ Backend  │    │    │  │ Frontend │  │ Backend  │    │
│  │ + OTel   │  │ + OTel   │    │    │  │ + OTel   │  │ + OTel   │    │
│  └────┬─────┘  └────┬─────┘    │    │  └────┬─────┘  └────┬─────┘    │
│       │             │           │    │       │             │           │
│       │ OTLP        │ OTLP      │    │       │ OTLP        │ OTLP      │
│       │ (direto)    │ (direto)  │    │       │ (local)     │ (local)   │
│       └─────────────┴───────────┼──┐ │       └─────────────┴───────┐   │
│                                 │  │ │                             │   │
│                                 │  │ │                      ┌──────▼───┴┐
│                                 │  │ │                      │   Alloy   │
│                                 │  │ │                      │  (Agent)  │
│                                 │  │ │                      └──────┬────┘
└─────────────────────────────────┘  │ └─────────────────────────────┼────┘
                                     │                               │
                                     └───────────────────────────────┘
```

## Conteúdo da Branch aula-06

Esta aula apresenta **2 cenários** de implementação de telemetria unificada com OpenTelemetry.

### 🏢 Instância 1 - Stack de Observabilidade (Única para ambos cenários)

Stack completa de observabilidade que recebe telemetria dos 2 cenários:
- **Grafana**: Visualização unificada de métricas, logs e traces
- **Prometheus**: Armazenamento de métricas
- **Loki**: Armazenamento de logs
- **Jaeger**: Armazenamento de traces
- **OpenTelemetry Collector**: Pipeline central de processamento

### 💻 Instância 2 - Aplicações (2 Cenários Diferentes)

Mesmas aplicações instrumentadas com OpenTelemetry, mas com diferentes formas de envio:

#### 📦 Cenário 1: Via OpenTelemetry Collector
**Arquitetura:** `Apps (OTel SDK) → OTel Collector → Backends`

- Aplicações enviam telemetria diretamente para o OTel Collector (Instância 1)
- Collector processa e distribui para Prometheus, Loki e Jaeger
- Configuração mais tradicional e robusta
- Ideal para: processamento centralizado, múltiplos backends, governança

#### 🚀 Cenário 2: Via Grafana Alloy
**Arquitetura:** `Apps (OTel SDK) → Alloy (local) → Backends`

- Aplicações enviam telemetria para Alloy local (Instância 2)
- Alloy processa localmente e envia diretamente para Prometheus, Loki e Jaeger (Instância 1)
- Configuração mais moderna e otimizada
- Ideal para: processamento local, otimização de rede, stack Grafana

### 🔧 Aplicações (Comuns aos 2 Cenários)

- **Frontend Service**: Node.js + Express com OTel SDK
- **Backend API Service**: Python Flask com OTel SDK
- **PostgreSQL**: Banco de dados
- **Redis**: Cache

## Estrutura do Projeto

```
├── README.md                              # Documentação principal
│
├── instancia-1-observability/             # 🏢 INSTÂNCIA 1 (única)
│   ├── README.md                          # Guia de setup da Instância 1
│   ├── docker-compose.yml                 # Stack completa de observabilidade
│   ├── otel-collector-config.yml          # Configuração do OTel Collector
│   ├── prometheus.yml                     # Configuração do Prometheus
│   ├── loki-config.yml                    # Configuração do Loki
│   └── grafana-datasources.yml            # Data sources do Grafana
│
├── scenario-1-via-collector/              # 📦 CENÁRIO 1 (Instância 2)
│   ├── README.md                          # Guia do cenário 1
│   ├── docker-compose.yml                 # Apps enviando para Collector
│   ├── frontend/                          # Frontend com OTel SDK
│   ├── backend/                           # Backend com OTel SDK
│   └── database/                          # Scripts do banco
│
├── scenario-2-via-alloy/                  # 🚀 CENÁRIO 2 (Instância 2)
│   ├── README.md                          # Guia do cenário 2
│   ├── docker-compose.yml                 # Apps + Alloy
│   ├── alloy-config.alloy                 # Configuração do Alloy
│   ├── frontend/                          # Frontend com OTel SDK
│   ├── backend/                           # Backend com OTel SDK
│   └── database/                          # Scripts do banco
│
├── ec2-userdata/                          # Scripts de userdata
│   ├── instancia-1.sh                     # Script para Instância 1
│   └── instancia-2.sh                     # Script para Instância 2
│
└── docs/                                  # Documentação adicional
    ├── setup-ec2-instances.md             # Setup das instâncias EC2
    ├── opentelemetry-guide.md             # Guia completo de OpenTelemetry
    ├── alloy-guide.md                     # Guia do Grafana Alloy
    ├── otel-collector-guide.md            # Guia do OTel Collector
    ├── instrumentation-otel.md            # Guia de instrumentação
    ├── ec2-userdata.md                    # Guia dos scripts userdata
    └── comparison-scenarios.md            # Comparação entre cenários
```

## Como usar

### 🏢 Passo 1: Configurar Instância 1 (Observabilidade)

Esta instância é **única** e serve ambos os cenários.

```bash
# Na Instância 1 (EC2)
cd instancia-1-observability

# Iniciar stack de observabilidade
docker-compose up -d

# Verificar serviços
docker-compose ps

# Acessar interfaces
# - Grafana: http://IP_INSTANCIA_1:3000 (admin/admin123)
# - Prometheus: http://IP_INSTANCIA_1:9090
# - Loki: http://IP_INSTANCIA_1:3100
# - Jaeger UI: http://IP_INSTANCIA_1:16686
# - OTel Collector: http://IP_INSTANCIA_1:4319 (OTLP HTTP)
```

[Ver guia completo da Instância 1](instancia-1-observability/README.md)

---

### 💻 Passo 2: Escolher e configurar cenário na Instância 2

Escolha **UM** dos cenários abaixo para a Instância 2:

#### 📦 **Cenário 1: Via OpenTelemetry Collector**

Aplicações enviam telemetria diretamente para o OTel Collector.

```bash
# Na Instância 2 (EC2)
cd scenario-1-via-collector

# Configurar IP da Instância 1
export OBSERVABILITY_IP="IP_PRIVADO_INSTANCIA_1"
sed -i "s/OBSERVABILITY_IP/${OBSERVABILITY_IP}/g" docker-compose.yml

# Iniciar aplicações
docker-compose up -d

# Testar
curl http://localhost:3001/api/users
```

[Ver guia completo do Cenário 1](scenario-1-via-collector/README.md)

#### 🚀 **Cenário 2: Via Grafana Alloy**

Aplicações enviam telemetria para Alloy local, que processa e envia para backends.

```bash
# Na Instância 2 (EC2)
cd scenario-2-via-alloy

# Configurar IP da Instância 1
export OBSERVABILITY_IP="IP_PRIVADO_INSTANCIA_1"
sed -i "s/OBSERVABILITY_IP/${OBSERVABILITY_IP}/g" alloy-config.alloy

# Iniciar aplicações + Alloy
docker-compose up -d

# Testar
curl http://localhost:3001/api/users
```

[Ver guia completo do Cenário 2](scenario-2-via-alloy/README.md)

---

### 📊 Passo 3: Visualizar no Grafana

Acesse o Grafana na Instância 1:
- URL: `http://IP_INSTANCIA_1:3000`
- Usuário: `admin`
- Senha: `admin123`

**Explorar telemetria:**
- **Métricas**: Explore → Prometheus → `http_requests_total`
- **Logs**: Explore → Loki → `{service_name="backend-service"}`
- **Traces**: Explore → Jaeger → Service: `frontend-service`

---

### 🔄 Comparação Rápida dos Cenários

| Aspecto | Cenário 1 (Collector) | Cenário 2 (Alloy) |
|---------|----------------------|-------------------|
| **Arquitetura** | App → Collector (remoto) | App → Alloy (local) → Backends |
| **Componentes na Inst. 2** | 4 (apps + DBs) | 5 (apps + DBs + Alloy) |
| **Latência** | Rede direta | Buffer local |
| **Processamento** | Centralizado | Local + Remoto |
| **Resiliência** | Depende do Collector | Buffer local |
| **Complexidade** | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Ideal para** | Simplicidade, poucos serviços | Produção, muitos serviços |

[Ver comparação detalhada](docs/comparison-scenarios.md)

## Arquivos de Documentação

### 🎯 Por Onde Começar?

**Iniciante - Nunca usei OpenTelemetry:**
1. [Guia de OpenTelemetry](docs/opentelemetry-guide.md) - Conceitos fundamentais
2. [Setup da Instância 1](instancia-1-observability/README.md) - Configurar observabilidade
3. [Cenário 1](scenario-1-via-collector/README.md) - Começar pelo mais simples

**Intermediário - Já conheço OTel:**
1. [Setup da Instância 1](instancia-1-observability/README.md)
2. [Comparação de Cenários](docs/comparison-scenarios.md) - Escolher cenário
3. [Cenário 2](scenario-2-via-alloy/README.md) - Implementar com Alloy

**Avançado - Quero entender tudo:**
1. [Guia de OpenTelemetry](docs/opentelemetry-guide.md)
2. [Guia do OTel Collector](docs/otel-collector-guide.md)
3. [Guia do Grafana Alloy](docs/alloy-guide.md)
4. [Comparação Detalhada](docs/comparison-scenarios.md)

---

### 📚 Guias Principais
- [Setup de Instâncias EC2](docs/setup-ec2-instances.md) - Passo a passo completo
- [Guia de OpenTelemetry](docs/opentelemetry-guide.md) - Guia completo do ecossistema OTel
- [Comparação de Cenários](docs/comparison-scenarios.md) - Qual cenário escolher?

### 🔧 Telemetria Unificada
- [Guia do OTel Collector](docs/otel-collector-guide.md) - Pipeline central de processamento
- [Guia do Grafana Alloy](docs/alloy-guide.md) - Agente de coleta e roteamento
- [Guia de Instrumentação OTel](docs/instrumentation-otel.md) - Instrumentação de aplicações

### 🏢 Setup por Instância
- [Instância 1 - Observabilidade](instancia-1-observability/README.md) - Stack única
- [Cenário 1 - Via Collector](scenario-1-via-collector/README.md) - Instância 2
- [Cenário 2 - Via Alloy](scenario-2-via-alloy/README.md) - Instância 2

## Objetivo da Aula

Explorar o ecossistema OpenTelemetry (OTel) e comparar duas abordagens de coleta de telemetria: via OpenTelemetry Collector (pipeline central) e via Grafana Alloy (agente local), demonstrando como instrumentar aplicações e coletar métricas, logs e traces em um pipeline observável unificado.

## Teoria Abordada

- **Conceito de telemetria unificada**: Integração de métricas, logs e traces em um único pipeline
- **Componentes do OpenTelemetry**: SDKs, Collector, exporters e suas funções
- **Pipeline de dados observáveis**: Coleta, processamento e exportação de sinais
- **OpenTelemetry Collector**: Pipeline central para processamento de sinais
- **Grafana Alloy**: Agente de coleta e roteamento de telemetria
- **Comparação de arquiteturas**: Centralizada vs distribuída
- **Instrumentação automática vs manual**: Estratégias de instrumentação com OTel SDKs
- **Exporters e backends**: Integração com Prometheus, Loki e Jaeger
- **Context propagation**: Correlação entre métricas, logs e traces
- **Sampling e otimização**: Estratégias para reduzir overhead de telemetria
- **Resiliência e buffer**: Garantia de entrega de telemetria

## Diferenças entre os Cenários

### Cenário 1: Via OpenTelemetry Collector
- Apps enviam telemetria **diretamente** para OTel Collector (Instância 1)
- Processamento **centralizado**
- **Mais simples**: menos componentes
- Ideal para: desenvolvimento, poucos serviços, simplicidade

### Cenário 2: Via Grafana Alloy
- Apps enviam telemetria para **Alloy local** (Instância 2)
- Alloy processa e envia para backends (Instância 1)
- Processamento **local + remoto**
- **Mais robusto**: buffer local, otimização de rede
- Ideal para: produção, muitos serviços, alta disponibilidade

[Ver comparação detalhada](docs/comparison-scenarios.md)
