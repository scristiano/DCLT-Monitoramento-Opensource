# Setup de Instâncias EC2 para Zabbix

Guia para criar duas instâncias EC2: uma para o Zabbix Server e outra para instalar o Zabbix Agent.

## Arquitetura

- **Instância 1**: Zabbix Server (t4g.small - ARM64 com user data)
- **Instância 2**: Host monitorado (t3.small - AMD64 para Zabbix Agent)

## Pré-requisitos

- Conta AWS ativa
- Key Pair criado
- VPC e Subnet configuradas

**Importante sobre as arquiteturas:**
- **t4g.small** (ARM64): Para Zabbix Server com Docker
- **t3.small** (AMD64): Para Zabbix Agent com binários estáticos

- **Instância 1**: Zabbix Server (com user data)
- **Instância 2**: Host monitorado (Zabbix Agent)

## Pré-requisitos

- Conta AWS ativa
- Key Pair criado
- VPC e Subnet configuradas

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

### Security Group para Zabbix Server
```bash
# Nome: zabbix-server-sg
# Descrição: Security group para Zabbix Server
```

**Regras de entrada:**
- SSH (22) - Source: Seu IP
- Custom TCP (3000) - Source: 0.0.0.0/0 (code-server)
- HTTP (80) - Source: 0.0.0.0/0 (Zabbix web)
- Custom TCP (10051) - Source: VPC CIDR (Zabbix server)

### Security Group para Zabbix Agent
```bash
# Nome: zabbix-agent-sg
# Descrição: Security group para hosts monitorados
```

**Regras de entrada:**
- SSH (22) - Source: Seu IP
- Custom TCP (10050) - Source: Security Group do Zabbix Server ou IP do Zabbix Server

## Passo 3: Criar Instância do Zabbix Server

### Via Console AWS

1. **EC2 Dashboard** → **Launch Instance**

2. **Configurações básicas:**
   - Name: `zabbix-server`
   - AMI: Ubuntu Server 24.04 LTS
   - Instance type: t4g.small
   - Key pair: Selecione sua chave

3. **Network settings:**
   - VPC: Default ou sua VPC
   - Subnet: Pública
   - Auto-assign public IP: Enable
   - Security group: `zabbix-server-sg`

4. **Advanced details:**
   - IAM instance profile: `PosTech-DevOps-Monitoramento-Profile`
   - User data: Cole o conteúdo do `ec2-userdata-demo.sh`

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
  --user-data file://ec2-userdata-demo.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=zabbix-server}]'
```

## Passo 4: Criar Instância para Zabbix Agent

### Via Console AWS

1. **EC2 Dashboard** → **Launch Instance**

2. **Configurações básicas:**
   - Name: `zabbix-agent-host`
   - AMI: Ubuntu Server 24.04 LTS
   - Instance type: t3.small
   - Key pair: Selecione sua chave

3. **Network settings:**
   - VPC: Mesma do Zabbix Server
   - Subnet: Mesma ou diferente (mesma AZ recomendada)
   - Auto-assign public IP: Enable
   - Security group: `zabbix-agent-sg`

4. **Advanced details:**
   - IAM instance profile: `PosTech-DevOps-Monitoramento-Profile`

5. **Launch instance** (sem user data)

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
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=zabbix-agent-host}]'
```

## Passo 5: Clonar repositório com os arquivos

Após criar as duas instâncias, clone o repositório para ter acesso aos arquivos necessários:

```bash
git clone -b aula-01 https://github.com/Ed-Carlos-Marinho/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource.git PosTech
cd PosTech
```

Os arquivos estarão disponíveis:
- `docker-compose.yml` - Para subir o Zabbix Server
- `ec2-userdata-demo.sh` - Script usado no user data
- `setup-ec2-instances.md` - Este guia
- `zabbix-compose.md` - Documentação do Docker Compose

## Passo 6: Verificar Zabbix Server

### Aguardar inicialização (5-10 minutos)

### Verificar serviços
```bash
# Conectar via SSH
ssh -i sua-chave.pem ubuntu@IP_ZABBIX_SERVER

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
- **Code-server**: `http://IP_ZABBIX_SERVER:3000` (senha: demo123)
- **Zabbix**: Após executar `docker-compose up -d` → `http://IP_ZABBIX_SERVER` (Admin/zabbix)

## Passo 7: Instalar Zabbix Agent na segunda instância

### Conectar na instância agent
```bash
# Via SSH
ssh -i sua-chave.pem ubuntu@IP_AGENT_HOST

# OU via SSM (recomendado)
aws ssm start-session --target i-0987654321fedcba0
```

### Instalar Zabbix Agent
```bash
# Baixar binário estático do Zabbix Agent 7.4.6 (AMD64)
wget https://cdn.zabbix.com/zabbix/binaries/stable/7.4/7.4.6/zabbix_agent-7.4.6-linux-3.0-amd64-static.tar.gz

# Extrair arquivos
tar -xzf zabbix_agent-7.4.6-linux-3.0-amd64-static.tar.gz

# Criar usuário zabbix
sudo useradd --system --shell /bin/false zabbix

# Criar diretórios necessários
sudo mkdir -p /usr/local/sbin
sudo mkdir -p /etc/zabbix
sudo mkdir -p /var/log/zabbix
sudo mkdir -p /run/zabbix

# Copiar binários
sudo cp sbin/zabbix_agentd /usr/local/sbin/
sudo cp bin/zabbix_get /usr/local/bin/
sudo cp bin/zabbix_sender /usr/local/bin/

# Definir permissões
sudo chown root:root /usr/local/sbin/zabbix_agentd
sudo chmod 755 /usr/local/sbin/zabbix_agentd
sudo chown zabbix:zabbix /var/log/zabbix
sudo chown zabbix:zabbix /run/zabbix

# Criar arquivo de configuração
sudo tee /etc/zabbix/zabbix_agentd.conf > /dev/null << 'EOF'
PidFile=/run/zabbix/zabbix_agentd.pid
LogFile=/var/log/zabbix/zabbix_agentd.log
LogFileSize=0
Server=IP_PRIVADO_ZABBIX_SERVER
ServerActive=IP_PRIVADO_ZABBIX_SERVER
Hostname=zabbix-agent-host
EOF

# Verificar instalação
/usr/local/sbin/zabbix_agentd --version
```

### Configuração do Agent
```bash
# Editar configuração (substituir IP_PRIVADO_ZABBIX_SERVER pelo IP real)
sudo sed -i 's/IP_PRIVADO_ZABBIX_SERVER/SEU_IP_ZABBIX_SERVER_AQUI/' /etc/zabbix/zabbix_agentd.conf

# Criar serviço systemd
sudo tee /etc/systemd/system/zabbix-agent.service > /dev/null << 'EOF'
[Unit]
Description=Zabbix Agent
After=syslog.target
After=network.target

[Service]
Environment="CONFFILE=/etc/zabbix/zabbix_agentd.conf"
Type=forking
Restart=on-failure
PIDFile=/run/zabbix/zabbix_agentd.pid
KillMode=control-group
ExecStart=/usr/local/sbin/zabbix_agentd -c $CONFFILE
ExecStop=/bin/kill -SIGTERM $MAINPID
RestartSec=10s
User=zabbix
Group=zabbix

[Install]
WantedBy=multi-user.target
EOF
```

### Iniciar serviço
```bash
# Recarregar systemd e iniciar serviço
sudo systemctl daemon-reload
sudo systemctl enable zabbix-agent
sudo systemctl start zabbix-agent
sudo systemctl status zabbix-agent

# Verificar se está rodando
ps aux | grep zabbix_agentd
```

## Passo 8: Configurar monitoramento no Zabbix

1. **Acessar Zabbix Web**: `http://IP_ZABBIX_SERVER`
2. **Login**: Admin / zabbix
3. **Configuration** → **Hosts** → **Create host**
4. **Configurar host:**
   - Host name: `zabbix-agent-host`
   - Visible name: `Agent Host`
   - Groups: `Linux servers`
   - Interfaces: Agent - IP_PRIVADO_AGENT_HOST:10050
5. **Templates**: Link `Linux by Zabbix agent`
6. **Add**

## Verificação final

### No Zabbix Server
- Hosts devem aparecer como "Available" em alguns minutos
- Métricas começam a ser coletadas automaticamente

### Comandos úteis
```bash
# Testar conectividade do server para agent
telnet IP_AGENT_HOST 10050

# Ver logs do Zabbix Agent
sudo tail -f /var/log/zabbix/zabbix_agentd.log

# Testar configuração do agent
sudo -u zabbix /usr/local/sbin/zabbix_agentd -t system.cpu.load[all,avg1] -c /etc/zabbix/zabbix_agentd.conf

# Verificar versão
/usr/local/sbin/zabbix_agentd --version

# Verificar se está rodando
ps aux | grep zabbix_agentd
```

## Troubleshooting

### Zabbix Agent não inicia
```bash
# Verificar logs
sudo journalctl -u zabbix-agent -f

# Verificar status
sudo systemctl status zabbix-agent

# Testar configuração manualmente
sudo -u zabbix /usr/local/sbin/zabbix_agentd -t system.cpu.load[all,avg1] -c /etc/zabbix/zabbix_agentd.conf

# Verificar se o binário está no local correto
ls -la /usr/local/sbin/zabbix_agentd

# Verificar permissões
ls -la /var/log/zabbix/
ls -la /var/run/zabbix/

# Verificar arquitetura do binário (deve ser AMD64)
file /usr/local/sbin/zabbix_agentd
```

### Agent não conecta
- Verificar Security Groups (porta 10050)
- Confirmar IPs privados na configuração
- Verificar logs: `/var/log/zabbix/zabbix_agentd.log`
- Testar conectividade: `telnet IP_ZABBIX_SERVER 10051`

### Zabbix Server não inicia
- Verificar logs: `docker-compose logs zabbix-server`
- Verificar recursos da instância
- Aguardar inicialização completa do MySQL