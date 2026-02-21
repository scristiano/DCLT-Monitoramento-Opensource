# Setup de Instâncias EC2 para OpenTelemetry e Alloy - Aula 06

Guia para criar duas instâncias EC2: uma para o stack completo de observabilidade (Grafana + Prometheus + Loki + Jaeger + OTel Collector) e outra para aplicações instrumentadas com OpenTelemetry em dois cenários diferentes.

## Arquitetura da Aula 06

- **Instância 1**: Stack de Observabilidade Completa (t4g.medium - ARM64)
  - Grafana (visualização unificada de métricas, logs e traces)
  - Prometheus (coleta e armazenamento de métricas)
  - Loki (armazenamento centralizado de logs)
  - Jaeger (tracing distribuído completo)
  - OpenTelemetry Collector (pipeline central de processamento)

- **Instância 2**: Aplicações Instrumentadas com OpenTelemetry (t3.small - AMD64)
  - **Cenário 1 (Via OTel Collector)**: Apps enviam telemetria direto para Collector
    - Frontend Service (Node.js/Express com OTel SDK)
    - Backend API Service (Python/Flask com OTel SDK)
    - PostgreSQL Database
    - Redis Cache
  
  - **Cenário 2 (Via Grafana Alloy)**: Apps enviam telemetria para Alloy local
    - Frontend Service (Node.js/Express com OTel SDK)
    - Backend API Service (Python/Flask com OTel SDK)
    - PostgreSQL Database
    - Redis Cache
    - Grafana Alloy (agente local de telemetria)

## Pré-requisitos

- Conta AWS ativa
- Key Pair criado
- VPC e Subnet configuradas

**Importante sobre as arquiteturas:**
- **t4g.medium** (ARM64): Para stack de observabilidade completa (4GB RAM recomendado)
- **t3.small** (AMD64): Para aplicações instrumentadas (2GB RAM suficiente)

**Novidades da Aula 06:**
- **OpenTelemetry nativo**: Instrumentação com OTel SDK em Python e Node.js
- **Dois cenários**: Comparação entre OTel Collector e Grafana Alloy
- **Telemetria unificada**: Métricas, logs e traces em um único pipeline
- **OTLP Protocol**: Protocolo padrão do OpenTelemetry
- **Context Propagation**: Correlação automática entre sinais

## Passo 1: Criar IAM Role para SSM

### Via Console AWS

1. **IAM Dashboard** → **Roles** → **Create role**

2. **Trusted entity type:**
   - AWS service
   - Use case: EC2

3. **Add permissions:**
   - Buscar e selecionar: `AmazonSSMManagedInstanceCore`

4. **Role details:**
   - Role name: `PosTech-DevOps-Monitoramento-Role`
   - Description: `Role para acesso SSM às instâncias EC2 - PosTech DevOps`

5. **Create role**

### Via AWS CLI
```bash
# Criar policy de confiança
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Criar role
aws iam create-role \
  --role-name PosTech-DevOps-Monitoramento-Role \
  --assume-role-policy-document file://trust-policy.json

# Anexar policy do SSM
aws iam attach-role-policy \
  --role-name PosTech-DevOps-Monitoramento-Role \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

# Criar instance profile
aws iam create-instance-profile --instance-profile-name PosTech-DevOps-Monitoramento-Profile

# Adicionar role ao instance profile
aws iam add-role-to-instance-profile \
  --instance-profile-name PosTech-DevOps-Monitoramento-Profile \
  --role-name PosTech-DevOps-Monitoramento-Role
```

## Passo 2: Criar Security Groups

### Security Group para Stack de Observabilidade
```bash
# Nome: observability-stack-sg
# Descrição: Security group para stack completo de observabilidade (Grafana + Prometheus + Loki + Jaeger + OTel Collector)
```

**Regras de entrada:**
- SSH (22) - Source: Seu IP
- Custom TCP (80) - Source: 0.0.0.0/0 (Grafana web)
- Custom TCP (9090) - Source: 0.0.0.0/0 (Prometheus web)
- Custom TCP (16686) - Source: 0.0.0.0/0 (Jaeger UI)
- Custom TCP (3100) - Source: VPC CIDR (Loki API)
- Custom TCP (4317) - Source: VPC CIDR (Jaeger OTLP gRPC)
- Custom TCP (4318) - Source: VPC CIDR (Jaeger OTLP HTTP)
- Custom TCP (4319) - Source: VPC CIDR (OTel Collector OTLP HTTP)
- Custom TCP (4320) - Source: VPC CIDR (OTel Collector OTLP gRPC)

### Security Group para Aplicações Instrumentadas
```bash
# Nome: instrumented-apps-sg
# Descrição: Security group para instância com aplicações instrumentadas com OpenTelemetry
```

**Regras de entrada:**
- SSH (22) - Source: Seu IP
- Custom TCP (3001) - Source: 0.0.0.0/0 (Frontend web)
- Custom TCP (5000) - Source: 0.0.0.0/0 (Backend API)
- Custom TCP (12345) - Source: 0.0.0.0/0 (Alloy UI - apenas Cenário 2)

## Passo 3: Criar Instância da Stack de Observabilidade

### Via Console AWS

1. **EC2 Dashboard** → **Launch Instance**

2. **Configurações básicas:**
   - Name: `observability-stack`
   - AMI: Ubuntu Server 22.04 LTS
   - Instance type: t4g.medium
   - Key pair: Selecione sua chave

3. **Network settings:**
   - VPC: Default ou sua VPC
   - Subnet: Pública
   - Auto-assign public IP: Enable
   - Security group: `observability-stack-sg`

4. **Configure storage:**
   - 30 GB gp3

5. **Advanced details:**
   - IAM instance profile: `PosTech-DevOps-Monitoramento-Profile`
   - User data: Cole o conteúdo do `ec2-userdata/instancia-1.sh`

6. **Launch instance**

### Via AWS CLI
```bash
aws ec2 run-instances \
  --image-id ami-0c7217cdde317cfec \
  --instance-type t4g.medium \
  --key-name sua-chave \
  --security-group-ids sg-xxxxxxxxx \
  --subnet-id subnet-xxxxxxxxx \
  --associate-public-ip-address \
  --iam-instance-profile Name=PosTech-DevOps-Monitoramento-Profile \
  --user-data file://ec2-userdata/instancia-1.sh \
  --block-device-mappings 'DeviceName=/dev/sda1,Ebs={VolumeSize=30,VolumeType=gp3}' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=observability-stack-aula06}]'
```

## Passo 4: Criar Instância para Aplicações Instrumentadas

### Via Console AWS

1. **EC2 Dashboard** → **Launch Instance**

2. **Configurações básicas:**
   - Name: `instrumented-apps`
   - AMI: Ubuntu Server 22.04 LTS
   - Instance type: t3.small
   - Key pair: Selecione sua chave

3. **Network settings:**
   - VPC: Mesma da instância de observabilidade
   - Subnet: Mesma ou diferente (mesma AZ recomendada)
   - Auto-assign public IP: Enable
   - Security group: `instrumented-apps-sg`

4. **Configure storage:**
   - 20 GB gp3

5. **Advanced details:**
   - IAM instance profile: `PosTech-DevOps-Monitoramento-Profile`
   - User data: Cole o conteúdo do `ec2-userdata/instancia-2.sh`
   - **IMPORTANTE**: Edite o user data e substitua `OBSERVABILITY_IP` pelo IP privado da Instância 1

6. **Launch instance**

### Via AWS CLI
```bash
# IMPORTANTE: Substituir OBSERVABILITY_IP no arquivo antes de executar
aws ec2 run-instances \
  --image-id ami-0c7217cdde317cfec \
  --instance-type t3.small \
  --key-name sua-chave \
  --security-group-ids sg-yyyyyyyyy \
  --subnet-id subnet-xxxxxxxxx \
  --associate-public-ip-address \
  --iam-instance-profile Name=PosTech-DevOps-Monitoramento-Profile \
  --user-data file://ec2-userdata/instancia-2.sh \
  --block-device-mappings 'DeviceName=/dev/sda1,Ebs={VolumeSize=20,VolumeType=gp3}' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=instrumented-apps}]'
```

## Passo 5: Clonar repositório com os arquivos

Após criar as duas instâncias, clone o repositório para ter acesso aos arquivos necessários:

```bash
git clone -b aula-06 https://github.com/Ed-Carlos-Marinho/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource.git PosTech
cd PosTech
```

Os arquivos estarão disponíveis:
- `instancia-1-observability/` - Stack completa de observabilidade
- `cenario-1-via-collector/` - Cenário 1: Apps → OTel Collector
- `cenario-2-via-alloy/` - Cenário 2: Apps → Alloy → Backends
- `ec2-userdata/instancia-1.sh` - Script para instância de observabilidade
- `ec2-userdata/instancia-2.sh` - Script para instância de aplicações
- `docs/` - Documentação completa (7 guias)

## Passo 6: Verificar Stack de Observabilidade Completa

### Aguardar inicialização (5-10 minutos)

### Verificar serviços
```bash
# Conectar via SSH
ssh -i sua-chave.pem ubuntu@IP_OBSERVABILITY_SERVER

# OU conectar via SSM (sem necessidade de SSH)
aws ssm start-session --target i-1234567890abcdef0

# Verificar user data
sudo tail -f /var/log/cloud-init-output.log

# Verificar Docker
docker --version
docker-compose --version

# Verificar stack de observabilidade
cd /home/ubuntu/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource/instancia-1-observability
docker-compose ps
```

### Acessar interfaces
- **Grafana**: `http://IP_OBSERVABILITY_SERVER` (admin/admin123)
- **Prometheus**: `http://IP_OBSERVABILITY_SERVER:9090`
- **Jaeger UI**: `http://IP_OBSERVABILITY_SERVER:16686`
- **Loki**: `http://IP_OBSERVABILITY_SERVER:3100` (API - sem interface web)

## Passo 7: Verificar Aplicações Instrumentadas

### Conectar na instância de aplicações
```bash
# Via SSH
ssh -i sua-chave.pem ubuntu@IP_INSTRUMENTED_APPS_SERVER

# OU via SSM (recomendado)
aws ssm start-session --target i-0987654321fedcba0
```

### Verificar serviços instalados automaticamente
```bash
# Verificar user data
sudo tail -f /var/log/cloud-init-output.log

# Navegar para diretório do cenário escolhido
cd /home/ubuntu/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource

# Cenário 1
cd cenario-1-via-collector
docker-compose ps

# OU Cenário 2
cd cenario-2-via-alloy
docker-compose ps

# Testar frontend
curl http://localhost:3001/health

# Testar backend API
curl http://localhost:5000/health
curl http://localhost:5000/api/users
```

### Configurar IP da instância de observabilidade (se não foi feito no user data)
```bash
# Obter IP privado da instância de observabilidade
# Exemplo: 10.0.1.100

# Cenário 1: Configurar IP no docker-compose
cd cenario-1-via-collector
export OBSERVABILITY_IP="10.0.1.100"
sed -i "s/OBSERVABILITY_IP/${OBSERVABILITY_IP}/g" docker-compose.yml
docker-compose down
docker-compose up -d

# Cenário 2: Configurar IP no Alloy config
cd cenario-2-via-alloy
export OBSERVABILITY_IP="10.0.1.100"
sed -i "s/OBSERVABILITY_IP/${OBSERVABILITY_IP}/g" alloy-config.alloy
docker-compose down
docker-compose up -d
```

## Passo 8: Configurar Data Sources no Grafana

### Verificar targets no Prometheus
1. **Acessar Prometheus Web**: `http://IP_OBSERVABILITY_SERVER:9090`
2. **Status** → **Targets**
3. **Verificar** se OTel Collector está "UP"

### Configurar Data Sources no Grafana
1. **Acessar Grafana**: `http://IP_OBSERVABILITY_SERVER` (admin/admin123)
2. **Configuration** → **Data Sources** → **Add data source**

#### Configurar Prometheus
- **URL**: `http://prometheus:9090`
- **Access**: Server (default)
- **Save & Test**

#### Configurar Loki
- **URL**: `http://loki:3100`
- **Access**: Server (default)
- **Save & Test**

#### Configurar Jaeger
- **URL**: `http://jaeger:16686`
- **Access**: Server (default)
- **Save & Test**

### Testar consultas básicas

#### PromQL (Prometheus)
- `up` - Status de todos os targets
- `http_server_request_duration_count` - Requisições HTTP
- `http_server_request_duration_bucket` - Latência HTTP
- `otelcol_receiver_accepted_spans` - Spans recebidos pelo Collector

#### LogQL (Loki)
- `{service_name="frontend-service"}` - Logs do frontend
- `{service_name="backend-service"}` - Logs do backend
- `{level="error"}` - Todos os logs de erro
- `{service_name="backend-service"} |= "trace_id"` - Logs com trace_id

#### Traces no Jaeger
- **Service**: `frontend-service`
- **Operation**: `GET /api/users`
- **Tags**: `http.status_code=200`

## Passo 9: Testar Telemetria Unificada

### Gerar telemetria nas aplicações
```bash
# Conectar na instância de aplicações
ssh -i sua-chave.pem ubuntu@IP_INSTRUMENTED_APPS_SERVER

# Gerar requisições
curl http://localhost:3001/api/users
curl http://localhost:3001/api/products
curl http://localhost:3001/api/orders

# Criar pedido (trace complexo)
curl -X POST http://localhost:3001/api/orders \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "total_amount": 99.99}'

# Script para gerar telemetria contínua
for i in {1..20}; do
  curl -s http://localhost:3001/api/users > /dev/null
  curl -s http://localhost:3001/api/products > /dev/null
  sleep 2
done
```

### Verificar traces no Jaeger UI
1. **Acessar Jaeger UI**: `http://IP_OBSERVABILITY_SERVER:16686`
2. **Service**: Selecionar `frontend-service` ou `backend-service`
3. **Find Traces**: Buscar traces recentes
4. **Analisar**: Spans, duração, tags e eventos

### Correlacionar traces com logs no Grafana
1. **Acessar Grafana**: `http://IP_OBSERVABILITY_SERVER`
2. **Explore** → **Loki**
3. **Consulta**: `{service_name="backend-service"} |= "trace_id"`
4. **Copiar trace_id** de um log
5. **Jaeger** → **Buscar pelo trace_id específico**

### Visualizar métricas no Prometheus
1. **Acessar Grafana**: `http://IP_OBSERVABILITY_SERVER`
2. **Explore** → **Prometheus**
3. **Consultas**:
   - `rate(http_server_duration_milliseconds_count[1m])` - Requisições por segundo
   - `histogram_quantile(0.95, rate(http_server_duration_milliseconds_bucket[5m]))` - Latência P95

## Passo 10: Comparar Cenários

### Cenário 1: Via OpenTelemetry Collector
```bash
# Verificar logs do Collector (Instância 1)
ssh -i sua-chave.pem ubuntu@IP_OBSERVABILITY_SERVER
cd instancia-1-observability
docker-compose logs otel-collector

# Verificar métricas do Collector
curl http://localhost:8888/metrics | grep otelcol_receiver_accepted
```

### Cenário 2: Via Grafana Alloy
```bash
# Verificar logs do Alloy (Instância 2)
ssh -i sua-chave.pem ubuntu@IP_INSTRUMENTED_APPS_SERVER
cd scenario-2-via-alloy
docker-compose logs alloy

# Verificar métricas do Alloy
curl http://localhost:12345/metrics | grep alloy_otelcol_receiver_accepted

# Acessar Alloy UI
# http://IP_INSTRUMENTED_APPS_SERVER:12345
```

## Passo 11: Endpoints e Interfaces Disponíveis

### Instância de Observabilidade (IP_OBSERVABILITY_SERVER)
- **Grafana**: `http://IP` (admin/admin123)
- **Prometheus**: `http://IP:9090`
- **Jaeger UI**: `http://IP:16686`
- **Loki API**: `http://IP:3100` (sem interface web)
- **OTel Collector Metrics**: `http://IP:8888/metrics`
- **OTel Collector Health**: `http://IP:13133/health`

### Instância de Aplicações (IP_INSTRUMENTED_APPS_SERVER)
- **Frontend Web**: `http://IP:3001/`
- **Backend API**: `http://IP:5000/`
- **Alloy UI** (Cenário 2): `http://IP:12345`
- **Alloy Metrics** (Cenário 2): `http://IP:12345/metrics`

### Endpoints da API Backend
```bash
# Health checks
GET /health

# Recursos principais
GET /api/users          # Lista usuários (com cache Redis)
GET /api/products       # Lista produtos (com cache Redis)
GET /api/orders         # Lista pedidos

# Operações (geram traces interessantes)
POST /api/orders        # Criar pedido (envolve DB, cache)
```

## Verificação Final

### Na Stack de Observabilidade
- OTel Collector deve aparecer como "UP" no Prometheus
- Logs começam a ser coletados pelo Loki automaticamente
- Traces aparecem no Jaeger UI após requisições
- Data Sources configurados no Grafana funcionando

### Nas Aplicações Instrumentadas
- Todos os serviços rodando (frontend, backend, database, cache)
- Aplicações respondendo às requisições HTTP
- Telemetria sendo enviada (verificar logs)

**Cenário 1 específico:**
- Apps enviando para OTel Collector (Instância 1)

**Cenário 2 específico:**
- Alloy rodando localmente
- Apps enviando para Alloy local
- Alloy encaminhando para backends (Instância 1)

### Comandos úteis para verificação
```bash
# Verificar stack de observabilidade
cd instancia-1-observability
docker-compose ps
docker-compose logs otel-collector

# Verificar aplicações - Cenário 1
cd cenario-1-via-collector
docker-compose ps
docker-compose logs frontend
docker-compose logs backend

# Verificar aplicações - Cenário 2
cd cenario-2-via-alloy
docker-compose ps
docker-compose logs alloy
docker-compose logs frontend
docker-compose logs backend

# Testar conectividade entre instâncias
# Da instância de aplicações para observabilidade
telnet IP_OBSERVABILITY_SERVER 4319  # OTel Collector (Cenário 1)
telnet IP_OBSERVABILITY_SERVER 9090  # Prometheus (Cenário 2)
telnet IP_OBSERVABILITY_SERVER 3100  # Loki (Cenário 2)
telnet IP_OBSERVABILITY_SERVER 4318  # Jaeger (Cenário 2)

# Verificar se OTel Collector está recebendo telemetria
curl http://IP_OBSERVABILITY_SERVER:8888/metrics | grep otelcol_receiver_accepted

# Verificar se Alloy está recebendo telemetria (Cenário 2)
curl http://localhost:12345/metrics | grep alloy_otelcol_receiver_accepted
```

## Troubleshooting

### Aplicações não iniciam
```bash
# Ver logs detalhados
docker-compose logs frontend
docker-compose logs backend

# Verificar conectividade com dependências
docker-compose exec backend ping postgres
docker-compose exec backend ping redis
docker-compose exec frontend ping backend
```

### Telemetria não aparece no Grafana

**Cenário 1:**
```bash
# Verificar se apps estão enviando para Collector
docker-compose logs backend | grep -i "otlp\|exporter"

# Verificar logs do Collector (Instância 1)
ssh IP_OBSERVABILITY_SERVER
cd instancia-1-observability
docker-compose logs otel-collector | grep -i "error\|refused"

# Testar conectividade
docker-compose exec backend curl http://OBSERVABILITY_IP:4319
```

**Cenário 2:**
```bash
# Verificar se apps estão enviando para Alloy
docker-compose logs backend | grep -i "otlp\|exporter"

# Verificar logs do Alloy
docker-compose logs alloy | grep -i "error\|refused"

# Verificar se Alloy está enviando para backends
curl http://localhost:12345/metrics | grep alloy_otelcol_exporter_sent
```

### Traces não aparecem no Jaeger
```bash
# Verificar variáveis de ambiente das aplicações
docker-compose exec frontend env | grep OTEL
docker-compose exec backend env | grep OTEL

# Verificar logs de instrumentação
docker-compose logs frontend | grep -i "tracer\|span\|trace"
docker-compose logs backend | grep -i "tracer\|span\|trace"

# Verificar métricas do Jaeger
curl http://IP_OBSERVABILITY_SERVER:14269/metrics | grep jaeger_collector_spans_received
```

### Logs não aparecem no Loki
```bash
# Verificar se aplicações estão gerando logs
docker-compose logs backend | head -20

# Verificar se OTel Collector está enviando logs para Loki
cd instancia-1-observability
docker-compose logs otel-collector | grep -i "loki"

# Testar Loki diretamente
curl http://IP_OBSERVABILITY_SERVER:3100/ready
```

### Performance e recursos
```bash
# Monitorar uso de recursos
docker stats

# Verificar latência das aplicações
time curl http://localhost:3001/api/users

# Verificar cache hits
docker-compose logs backend | grep "cache"
```

### Data Sources não conectam no Grafana
```bash
# Verificar conectividade interna do Docker
cd instancia-1-observability
docker-compose exec grafana ping prometheus
docker-compose exec grafana ping loki
docker-compose exec grafana ping jaeger

# Verificar logs dos serviços
docker-compose logs prometheus
docker-compose logs loki
docker-compose logs jaeger
```

## Recursos Adicionais

- [Guia de OpenTelemetry](./opentelemetry-guide.md)
- [Guia do OTel Collector](./otel-collector-guide.md)
- [Guia do Grafana Alloy](./alloy-guide.md)
- [Guia de Instrumentação](./instrumentation-otel.md)
- [Comparação de Cenários](./comparison-scenarios.md)
- [Guia de User Data](./ec2-userdata.md)
