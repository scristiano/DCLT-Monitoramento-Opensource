# Aplicação Demo - Monitoramento OpenTelemetry

Este diretório contém a aplicação demo compartilhada entre os cenários de monitoramento.

## 📁 Estrutura

```
app/
├── backend/          # API Backend (Node.js + Express)
├── frontend/         # Frontend Service (Node.js + Express)
├── database/         # Scripts de inicialização do PostgreSQL
└── README.md         # Este arquivo
```

## 🎯 Propósito

Esta aplicação é usada por ambos os cenários:
- **Cenário 1**: Via OpenTelemetry Collector
- **Cenário 2**: Via Grafana Alloy

A separação permite:
- ✅ Código único e centralizado
- ✅ Facilita manutenção e atualizações
- ✅ Evita duplicação de código
- ✅ Mesma aplicação em diferentes arquiteturas de observabilidade

## 🏗️ Componentes

### Backend (Node.js)
- **Porta**: 5000
- **Tecnologias**: Express, OpenTelemetry SDK
- **Endpoints**:
  - `GET /api/users` - Lista usuários
  - `GET /api/orders` - Lista pedidos
  - `GET /api/products` - Lista produtos
- **Instrumentação**: Automática via OpenTelemetry
- **Dependências**: PostgreSQL, Redis

### Frontend (Node.js)
- **Porta**: 3000
- **Tecnologias**: Express, OpenTelemetry SDK
- **Função**: Proxy para o backend
- **Instrumentação**: Automática via OpenTelemetry
- **Dependências**: Backend service

### Database (PostgreSQL)
- **Porta**: 5432
- **Script**: `init.sql` - Cria tabelas e dados iniciais
- **Dados**: Usuários, pedidos e produtos de exemplo

## 🔧 Como Usar

Esta aplicação não é executada diretamente. Ela é referenciada pelos docker-compose dos cenários:

### Cenário 1 (via Collector)
```bash
cd cenario-1-via-collector
docker compose up -d
```

### Cenário 2 (via Alloy)
```bash
cd cenario-2-via-alloy
docker compose up -d
```

## 📊 Telemetria

A aplicação gera automaticamente:
- **Traces**: Spans de requisições HTTP, queries de banco, chamadas Redis
- **Métricas**: Request rate, latência, status codes
- **Logs**: Logs estruturados com trace_id para correlação

### Variáveis de Ambiente

Configuradas nos docker-compose de cada cenário:

```yaml
# Identificação do serviço
OTEL_SERVICE_NAME: backend-service | frontend-service

# Endpoint do coletor (varia por cenário)
OTEL_EXPORTER_OTLP_ENDPOINT: http://collector:4318 | http://alloy:4318

# Protocolo de exportação
OTEL_EXPORTER_OTLP_PROTOCOL: http/protobuf
```

## 🚀 Gerador de Tráfego

Ambos os cenários incluem um container `traffic-generator` que:
- Gera requisições automáticas a cada 5-10 segundos
- Testa todos os endpoints da aplicação
- Garante fluxo constante de telemetria

## 🔄 Atualizações

Para atualizar a aplicação:
1. Modifique os arquivos em `app/`
2. Reconstrua as imagens nos cenários:
   ```bash
   cd cenario-1-via-collector
   docker compose build
   docker compose up -d
   ```

As mudanças serão refletidas em ambos os cenários automaticamente.

## 📝 Notas

- A aplicação é idêntica em ambos os cenários
- A única diferença é o endpoint do coletor de telemetria
- Cenário 1 envia para OTel Collector (porta 4318)
- Cenário 2 envia para Grafana Alloy (porta 4318)
