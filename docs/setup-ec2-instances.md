# Setup de Instâncias EC2 para Prometheus

Guia para criar duas instâncias EC2: uma para o Prometheus Server e outra para instalar os exporters.

## Arquitetura

- **Instância 1**: Prometheus Server (t4g.small - ARM64 com user data)
- **Instância 2**: Host monitorado (t3.small - AMD64 para exporters)

## Pré-requisitos

- Conta AWS ativa
- Key Pair criado
- VPC e Subnet configuradas

**Importante sobre as arquiteturas:**
- **t4g.small** (ARM64): Para Prometheus Server com Docker
- **t3.small** (AMD64): Para host monitorado com exporters

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

### Security Group para Prometheus Server
```bash
# Nome: prometheus-server-sg
# Descrição: Security group para Prometheus Server
```

**Regras de entrada:**
- SSH (22) - Source: Seu IP
- Custom TCP (8080) - Source: 0.0.0.0/0 (code-server)
- Custom TCP (9090) - Source: 0.0.0.0/0 (Prometheus web)
- Custom TCP (9093) - Source: 0.0.0.0/0 (Alertmanager web)

### Security Group para Exporters
```bash
# Nome: prometheus-exporters-sg
# Descrição: Security group para instâncias com exporters
```

**Regras de entrada:**
- SSH (22) - Source: Seu IP
- Custom TCP (9100) - Source: Security Group do Prometheus Server (Node Exporter)
- Custom TCP (8080) - Source: Security Group do Prometheus Server (cAdvisor)

## Passo 3: Criar Instância do Prometheus Server

### Via Console AWS

1. **EC2 Dashboard** → **Launch Instance**

2. **Configurações básicas:**
   - Name: `prometheus-server`
   - AMI: Ubuntu Server 24.04 LTS
   - Instance type: t4g.small
   - Key pair: Selecione sua chave

3. **Network settings:**
   - VPC: Default ou sua VPC
   - Subnet: Pública
   - Auto-assign public IP: Enable
   - Security group: `prometheus-server-sg`

4. **Advanced details:**
   - IAM instance profile: `PosTech-DevOps-Monitoramento-Profile`
   - User data: Cole o conteúdo do `ec2-userdata-instance-01.sh`

5. **Launch instance**

### Via AWS CLI
```bash
aws ec2 run-instances \
  --image-id ami-0c7217cdde317cfec \
  --instance-type t4g.small \
  --key-name sua-chave \
  --security-group-ids sg-xxxxxxxxx \
  --subnet-id subnet-xxxxxxxxx \
  --associate-public-ip-address \
  --iam-instance-profile Name=PosTech-DevOps-Monitoramento-Profile \
  --user-data file://ec2-userdata-instance-01.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=prometheus-server}]'
```

## Passo 4: Criar Instância para Exporters

### Via Console AWS

1. **EC2 Dashboard** → **Launch Instance**

2. **Configurações básicas:**
   - Name: `prometheus-exporters-host`
   - AMI: Ubuntu Server 24.04 LTS
   - Instance type: t3.small
   - Key pair: Selecione sua chave

3. **Network settings:**
   - VPC: Mesma do Prometheus Server
   - Subnet: Mesma ou diferente (mesma AZ recomendada)
   - Auto-assign public IP: Enable
   - Security group: `prometheus-exporters-sg`

4. **Advanced details:**
   - IAM instance profile: `PosTech-DevOps-Monitoramento-Profile`
   - User data: Cole o conteúdo do `ec2-userdata-instance-02.sh`

5. **Launch instance**

### Via AWS CLI
```bash
aws ec2 run-instances \
  --image-id ami-0c7217cdde317cfec \
  --instance-type t3.small \
  --key-name sua-chave \
  --security-group-ids sg-yyyyyyyyy \
  --subnet-id subnet-xxxxxxxxx \
  --associate-public-ip-address \
  --iam-instance-profile Name=PosTech-DevOps-Monitoramento-Profile \
  --user-data file://ec2-userdata-instance-02.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=prometheus-exporters-host}]'
```

## Passo 5: Clonar repositório com os arquivos

Após criar as duas instâncias, clone o repositório para ter acesso aos arquivos necessários:

```bash
# Navegar para o diretório home do usuário ubuntu
cd /home/ubuntu

# Clonar o repositório na branch aula-02 com nome simplificado
git clone -b aula-02 https://github.com/Ed-Carlos-Marinho/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource.git PosTech

# Acessar o diretório do projeto
cd PosTech
```

Os arquivos estarão disponíveis:
- `docker-compose.yml` - Para subir o Prometheus e Alertmanager
- `prometheus.yml` - Configuração do Prometheus
- `alertmanager.yml` - Configuração do Alertmanager
- `alert_rules.yml` - Regras de alerta
- `docs/exporters-installation.md` - Guia de instalação dos exporters

## Passo 6: Verificar Prometheus Server

### Aguardar inicialização (5-10 minutos)

### Verificar serviços
```bash
# Conectar via SSH
ssh -i sua-chave.pem ubuntu@IP_PROMETHEUS_SERVER

# OU conectar via SSM (sem necessidade de SSH)
aws ssm start-session --target i-1234567890abcdef0

# Verificar user data
sudo tail -f /var/log/user-data.log

# Verificar code-server
sudo systemctl status code-server

# Verificar Docker
docker --version
docker-compose --version
```

### Acessar interfaces
- **Code-server**: `http://IP_PROMETHEUS_SERVER:8080` (senha: demo123)
- **Prometheus**: Após executar `docker-compose up -d` → `http://IP_PROMETHEUS_SERVER:9090`
- **Alertmanager**: `http://IP_PROMETHEUS_SERVER:9093`

## Passo 7: Instalar Exporters na segunda instância

### Conectar na instância exporters
```bash
# Via SSH
ssh -i sua-chave.pem ubuntu@IP_EXPORTERS_HOST

# OU via SSM (recomendado)
aws ssm start-session --target i-0987654321fedcba0
```

### Instalar Node Exporter e cAdvisor
Siga o guia detalhado em `docs/exporters-installation.md` para:
- Instalar Node Exporter (porta 9100)
- Instalar cAdvisor (porta 8080)
- Configurar como serviços systemd
- Verificar funcionamento

## Passo 8: Configurar monitoramento no Prometheus

### Atualizar configuração
1. **Editar prometheus.yml** na instância do Prometheus Server
2. **Substituir IPs** pelos IPs privados reais das instâncias
3. **Recarregar configuração**: `docker-compose restart prometheus`

### Verificar targets
1. **Acessar Prometheus Web**: `http://IP_PROMETHEUS_SERVER:9090`
2. **Status** → **Targets**
3. **Verificar** se todos os exporters estão "UP"

### Testar consultas PromQL
- `up` - Status de todos os targets
- `node_cpu_seconds_total` - Métricas de CPU
- `container_memory_usage_bytes` - Métricas de containers
- `rate(node_cpu_seconds_total[5m])` - Taxa de uso de CPU

## Verificação final

### No Prometheus Server
- Targets devem aparecer como "UP" em alguns minutos
- Métricas começam a ser coletadas automaticamente
- Alertas configurados começam a funcionar

### Comandos úteis
```bash
# Testar conectividade do Prometheus para exporters
telnet IP_EXPORTERS_HOST 9100
telnet IP_EXPORTERS_HOST 8080

# Ver logs dos exporters
sudo journalctl -u node_exporter -f
sudo journalctl -u cadvisor -f

# Testar métricas localmente
curl http://localhost:9100/metrics
curl http://localhost:8080/metrics

# Verificar configuração do Prometheus
docker-compose exec prometheus promtool check config /etc/prometheus/prometheus.yml
```

## Troubleshooting

### Exporters não conectam
- Verificar Security Groups (portas 9100 e 8080)
- Confirmar IPs privados no prometheus.yml
- Verificar se serviços estão rodando: `systemctl status node_exporter cadvisor`

### Prometheus não coleta métricas
- Verificar logs: `docker-compose logs prometheus`
- Verificar targets em Status → Targets
- Testar conectividade de rede entre instâncias

### Alertmanager não funciona
- Verificar logs: `docker-compose logs alertmanager`
- Verificar configuração: `/etc/alertmanager/alertmanager.yml`
- Testar regras de alerta no Prometheus