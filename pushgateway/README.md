# Pushgateway + Batch Job Scheduler

Stack completa para monitoramento de jobs batch usando Pushgateway e Prometheus.

## Arquitetura

```
┌─────────────────┐      ┌──────────────────┐      ┌─────────────────┐
│   Scheduler     │─────▶│   Batch Job      │─────▶│  Pushgateway    │
│  (Cron 1min)    │      │  (Processa +     │      │  (Porta 9091)   │
│                 │      │   Envia Métricas)│      │                 │
└─────────────────┘      └──────────────────┘      └────────┬────────┘
                                                             │
                                                             │ scrape
                                                             ▼
                                                    ┌─────────────────┐
                                                    │   Prometheus    │
                                                    │  (Instância 1)  │
                                                    └─────────────────┘
```

## Setup da Instância EC2 para Pushgateway

### Passo 1: Criar Security Group para Pushgateway

**Via Console AWS:**

1. **EC2 Dashboard** → **Security Groups** → **Create security group**

2. **Configurações:**
   - Name: `pushgateway-sg`
   - Description: `Security group para Pushgateway`
   - VPC: Mesma VPC das outras instâncias

3. **Regras de entrada (Inbound rules):**
   - SSH (22) - Source: Seu IP
   - Custom TCP (8080) - Source: 0.0.0.0/0 (code-server)
   - Custom TCP (9091) - Source: Security Group do Prometheus Server (Pushgateway)
   - Custom TCP (9090) - Source: 0.0.0.0/0 (Prometheus web - opcional para testes)

4. **Create security group**

**Via AWS CLI:**
```bash
# Criar Security Group
aws ec2 create-security-group \
  --group-name pushgateway-sg \
  --description "Security group para Pushgateway" \
  --vpc-id vpc-xxxxxxxxx

# Adicionar regras de entrada
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxxxxx \
  --protocol tcp \
  --port 22 \
  --cidr SEU_IP/32

aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxxxxx \
  --protocol tcp \
  --port 8080 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxxxxx \
  --protocol tcp \
  --port 9091 \
  --source-group sg-prometheus-server

aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxxxxx \
  --protocol tcp \
  --port 9090 \
  --cidr 0.0.0.0/0
```

### Passo 2: Criar Instância EC2 para Pushgateway

**Via Console AWS:**

1. **EC2 Dashboard** → **Launch Instance**

2. **Configurações básicas:**
   - Name: `pushgateway-server`
   - AMI: Ubuntu Server 24.04 LTS
   - Instance type: t4g.small (ARM64)
   - Key pair: Selecione sua chave

3. **Network settings:**
   - VPC: Mesma VPC do Prometheus Server
   - Subnet: Pública
   - Auto-assign public IP: Enable
   - Security group: `pushgateway-sg`

4. **Advanced details:**
   - IAM instance profile: `PosTech-DevOps-Monitoramento-Profile`
   - User data: Cole o conteúdo do arquivo `scripts/ec2-userdata-pushgateway.sh`

5. **Launch instance**

**Via AWS CLI:**
```bash
aws ec2 run-instances \
  --image-id ami-0c7217cdde317cfec \
  --instance-type t4g.small \
  --key-name sua-chave \
  --security-group-ids sg-xxxxxxxxx \
  --subnet-id subnet-xxxxxxxxx \
  --associate-public-ip-address \
  --iam-instance-profile Name=PosTech-DevOps-Monitoramento-Profile \
  --user-data file://scripts/ec2-userdata-pushgateway.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=pushgateway-server}]'
```

### Passo 3: Verificar Instância Pushgateway

**Aguardar inicialização (5-10 minutos)**

**Conectar na instância:**
```bash
# Via SSH
ssh -i sua-chave.pem ubuntu@IP_PUSHGATEWAY

# OU via SSM (recomendado)
aws ssm start-session --target i-xxxxxxxxx
```

**Verificar serviços:**
```bash
# Verificar user data
sudo tail -f /var/log/user-data.log

# Verificar code-server
sudo systemctl status code-server

# Verificar Docker
docker --version
docker-compose --version
```

**Acessar interfaces:**
- **Code-server**: `http://IP_PUSHGATEWAY:8080` (senha: demo123)
- **Pushgateway**: Após executar `docker-compose up -d` → `http://IP_PUSHGATEWAY:9091`
- **Prometheus**: `http://IP_PUSHGATEWAY:9090` (opcional para testes locais)

### Passo 4: Clonar repositório e iniciar serviços

```bash
# Navegar para o diretório home do usuário ubuntu
cd /home/ubuntu

# Clonar o repositório na branch aula-02 com nome simplificado
git clone -b aula-02 https://github.com/Ed-Carlos-Marinho/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource.git PosTech

# Acessar o diretório do pushgateway
cd PosTech/pushgateway

# Iniciar serviços
docker-compose up -d
```

## Componentes

### 1. Pushgateway
- Recebe métricas de jobs batch/efêmeros
- Expõe métricas para o Prometheus
- Porta: 9091

### 2. Scheduler (Cron)
- Executa o batch job a cada 1 minuto
- Baseado em Alpine Linux com cron

### 3. Batch Job
- Aplicação Python que simula processamento
- Duração: 3-10 segundos (aleatório)
- Usa `prometheus_client` para criar e enviar métricas
- Envia métricas ao Pushgateway após execução

## Framework de Métricas

A aplicação usa o **Prometheus Python Client** (`prometheus_client`), que simplifica:

- Criação de métricas (Gauge, Counter, Histogram, Summary)
- Formatação automática no formato Prometheus
- Envio para Pushgateway com `push_to_gateway()`
- Gerenciamento de labels e grouping keys

### Vantagens do prometheus_client:
- ✅ Sintaxe simples e intuitiva
- ✅ Validação automática de métricas
- ✅ Suporte a todos os tipos de métricas Prometheus
- ✅ Biblioteca oficial e bem mantida
- ✅ Elimina necessidade de formatar strings manualmente

## Métricas Geradas

O batch job envia as seguintes métricas:

- `batch_job_duration_seconds`: Duração da execução em segundos
- `batch_job_records_processed`: Número de registros processados
- `batch_job_status`: Status da execução (1=sucesso, 0=falha)
- `batch_job_last_success_timestamp`: Timestamp da última execução bem-sucedida

## Como usar

### 1. Build da aplicação batch
```bash
cd pushgateway
docker-compose build batch-job
```

### 2. Iniciar serviços
```bash
docker-compose up -d pushgateway scheduler
```

### 3. Verificar status
```bash
# Ver logs do scheduler
docker-compose logs -f scheduler

# Ver logs do batch job (quando executar)
docker logs batch-job-run

# Verificar containers
docker-compose ps
```

### 4. Acessar Pushgateway
```bash
# Interface web
http://SEU_IP:9091

# Métricas (endpoint para Prometheus)
http://SEU_IP:9091/metrics
```

### 5. Testar manualmente o batch job
```bash
# Executar uma vez manualmente
docker-compose run --rm batch-job
```

## Configuração no Prometheus

Adicione no arquivo `prometheus.yml` da instância 1:

```yaml
scrape_configs:
  - job_name: 'pushgateway'
    honor_labels: true
    static_configs:
      - targets: ['IP_PUSHGATEWAY:9091']
```

Depois reinicie o Prometheus:
```bash
docker-compose restart prometheus
```

## Verificação

### Ver métricas no Pushgateway
```bash
curl http://localhost:9091/metrics | grep batch_job
```

### Exemplo de saída esperada
```
batch_job_duration_seconds{instance="batch-job-instance",job="batch_processing_job"} 5.23
batch_job_records_processed{instance="batch-job-instance",job="batch_processing_job"} 456
batch_job_status{instance="batch-job-instance",job="batch_processing_job"} 1
batch_job_last_success_timestamp{instance="batch-job-instance",job="batch_processing_job"} 1708724567000
```

## Queries úteis no Prometheus

```promql
# Duração média das últimas 10 execuções
avg_over_time(batch_job_duration_seconds[10m])

# Taxa de sucesso (últimas 10 execuções)
avg_over_time(batch_job_status[10m]) * 100

# Total de registros processados na última hora
sum_over_time(batch_job_records_processed[1h])

# Tempo desde a última execução bem-sucedida
time() - batch_job_last_success_timestamp / 1000
```

## Troubleshooting

### Scheduler não executa o job
```bash
# Verificar logs do scheduler
docker-compose logs scheduler

# Verificar se o cron está configurado
docker-compose exec scheduler cat /etc/crontabs/root

# Verificar se Docker CLI está instalado
docker-compose exec scheduler docker --version
```

### Batch job não envia métricas
```bash
# Executar manualmente e ver logs
docker-compose run --rm batch-job

# Verificar conectividade com Pushgateway
docker-compose run --rm batch-job sh -c "ping -c 3 pushgateway"

# Verificar se Pushgateway está rodando
docker-compose ps pushgateway
```

### Pushgateway não aparece no Prometheus
- Verificar configuração do prometheus.yml
- Verificar conectividade de rede entre Prometheus e Pushgateway
- Verificar se porta 9091 está acessível
- Verificar targets no Prometheus: http://PROMETHEUS_IP:9090/targets

## Comandos úteis

```bash
# Parar todos os serviços
docker-compose down

# Parar e remover volumes
docker-compose down -v

# Rebuild da aplicação batch
docker-compose build --no-cache batch-job

# Ver logs em tempo real
docker-compose logs -f

# Limpar métricas antigas do Pushgateway
curl -X DELETE http://localhost:9091/metrics/job/batch_processing_job
```

## Personalização

### Alterar intervalo de execução

Edite o arquivo `docker-compose.yml` e modifique a linha do cron:

```yaml
# A cada 5 minutos
echo '*/5 * * * * docker run ...' > /etc/crontabs/root

# A cada hora
echo '0 * * * * docker run ...' > /etc/crontabs/root

# A cada 30 segundos (não recomendado para cron, use outro scheduler)
```

### Alterar duração do processamento

Edite `batch-job/batch_job.py`:

```python
# Linha 30
processing_time = random.uniform(3, 10)  # Altere os valores min/max
```

### Adicionar mais métricas

Edite `batch-job/batch_job.py` usando o `prometheus_client`:

```python
from prometheus_client import Counter, Histogram

# Criar novas métricas
error_counter = Counter(
    'batch_job_errors_total',
    'Total de erros no batch job',
    registry=registry
)

processing_histogram = Histogram(
    'batch_job_processing_duration_seconds',
    'Histograma de duração do processamento',
    registry=registry
)

# Usar as métricas
error_counter.inc()  # Incrementa contador
with processing_histogram.time():  # Mede tempo automaticamente
    # seu código aqui
    pass
```

### Exemplo com prometheus_client

```python
from prometheus_client import CollectorRegistry, Gauge, Counter, push_to_gateway

# Criar registry
registry = CollectorRegistry()

# Criar métricas
gauge = Gauge('my_gauge', 'Descrição', registry=registry)
counter = Counter('my_counter', 'Descrição', registry=registry)

# Definir valores
gauge.set(42)
counter.inc(5)

# Enviar para Pushgateway
push_to_gateway('pushgateway:9091', job='my_job', registry=registry)
```

## Security Groups / Firewall

Portas necessárias:
- **9091**: Pushgateway (entrada para Prometheus fazer scrape)
- Comunicação interna entre containers (rede Docker)

## Notas importantes

1. O Pushgateway mantém as métricas em memória até serem coletadas pelo Prometheus
2. Use `honor_labels: true` no Prometheus para preservar os labels originais
3. O scheduler usa o socket do Docker para executar containers
4. Métricas antigas não são automaticamente removidas do Pushgateway
