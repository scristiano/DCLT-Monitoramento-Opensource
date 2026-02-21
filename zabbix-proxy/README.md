# Setup de Instância EC2 para Zabbix Proxy

Guia para criar uma instância EC2 dedicada ao Zabbix Proxy para distribuir a carga de monitoramento.

## Arquitetura

- **Instância**: Zabbix Proxy (t4g.small - ARM64 com user data)
- **Função**: Coletar dados dos agentes e enviar para o Zabbix Server central

## Pré-requisitos

- Conta AWS ativa
- Key Pair criado
- VPC e Subnet configuradas
- Zabbix Server já configurado e rodando
- IAM Role `PosTech-DevOps-Monitoramento-Role` já criada

## Passo 1: Criar Security Group para Zabbix Proxy

### Via Console AWS

**Nome**: `zabbix-proxy-sg`  
**Descrição**: Security group para Zabbix Proxy

**Regras de entrada:**
- SSH (22) - Source: Seu IP
- Custom TCP (8080) - Source: 0.0.0.0/0 (code-server)
- Custom TCP (10051) - Source: 0.0.0.0/0 ou VPC CIDR (Zabbix Agents)

**Regras de saída:**
- All traffic - Destination: 0.0.0.0/0 (para conectar ao Zabbix Server)

### Via AWS CLI
```bash
# Criar security group
aws ec2 create-security-group \
  --group-name zabbix-proxy-sg \
  --description "Security group para Zabbix Proxy"

# Adicionar regras de entrada
aws ec2 authorize-security-group-ingress \
  --group-name zabbix-proxy-sg \
  --protocol tcp --port 22 --cidr SEU_IP/32

aws ec2 authorize-security-group-ingress \
  --group-name zabbix-proxy-sg \
  --protocol tcp --port 8080 --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-name zabbix-proxy-sg \
  --protocol tcp --port 10051 --cidr 0.0.0.0/0
```

## Passo 2: Criar Instância do Zabbix Proxy

### Via Console AWS

1. **EC2 Dashboard** → **Launch Instance**

2. **Configurações básicas:**
   - Name: `zabbix-proxy`
   - AMI: Ubuntu Server 24.04 LTS
   - Instance type: t4g.small (ARM64)
   - Key pair: Selecione sua chave

3. **Network settings:**
   - VPC: Default ou sua VPC
   - Subnet: Pública
   - Auto-assign public IP: Enable
   - Security group: `zabbix-proxy-sg`

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
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=zabbix-proxy}]'
```

## Passo 3: Verificar Zabbix Proxy

### Aguardar inicialização (5-10 minutos)

### Verificar serviços
```bash
# Conectar via SSH
ssh -i sua-chave.pem ubuntu@IP_ZABBIX_PROXY

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

### Acessar code-server
- **Code-server**: `http://IP_ZABBIX_PROXY:8080` (senha: demo123)

## Passo 4: Configurar Zabbix Proxy

### Clonar repositório
```bash
git clone -b aula-01 https://github.com/Ed-Carlos-Marinho/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource.git PosTech
cd PosTech/zabbix-proxy
```

### Editar docker-compose.yml
```bash
# Editar o arquivo e alterar ZBX_SERVER_HOST
nano docker-compose.yml

# Alterar a linha:
# ZBX_SERVER_HOST: zabbix-server
# Para:
# ZBX_SERVER_HOST: IP_PRIVADO_DO_SEU_ZABBIX_SERVER
```

### Iniciar Zabbix Proxy
```bash
docker-compose up -d

# Verificar logs
docker-compose logs -f zabbix-proxy
```

## Passo 5: Cadastrar Proxy no Zabbix Server

1. **Acessar Zabbix Server Web**: `http://IP_ZABBIX_SERVER`
2. **Login**: Admin / zabbix
3. **Administration** → **Proxies** → **Create proxy**
4. **Configurar proxy:**
   - Proxy name: `zabbix-proxy-01` (mesmo valor de ZBX_HOSTNAME no docker-compose.yml)
   - Proxy mode: `Active`
5. **Add**

## Passo 6: Configurar Hosts para usar o Proxy

1. **Configuration** → **Hosts** → Selecione um host ou crie novo
2. **Monitored by proxy**: Selecione `zabbix-proxy-01`
3. **Update**

## Verificação final

### No Zabbix Server
- **Administration** → **Proxies**
- Status do proxy deve aparecer como "Active"
- "Last seen" deve mostrar timestamp recente

### Logs do proxy
```bash
# Ver logs do proxy
docker-compose logs -f zabbix-proxy

# Verificar conectividade com o server
docker-compose exec zabbix-proxy ping IP_ZABBIX_SERVER
```

## Comandos úteis

```bash
# Parar proxy
docker-compose down

# Reiniciar proxy
docker-compose restart zabbix-proxy

# Ver status dos containers
docker-compose ps

# Ver logs específicos
docker-compose logs zabbix-proxy

# Remover tudo (CUIDADO: apaga dados)
docker-compose down -v
```

## Troubleshooting

### Proxy não conecta ao server
```bash
# Verificar configuração
docker-compose exec zabbix-proxy cat /etc/zabbix/zabbix_proxy.conf | grep Server

# Verificar conectividade
docker-compose exec zabbix-proxy ping IP_ZABBIX_SERVER
docker-compose exec zabbix-proxy telnet IP_ZABBIX_SERVER 10051

# Verificar logs
docker-compose logs zabbix-proxy | grep -i error
```

### Proxy não aparece como "Active" no server
- Verificar se o nome do proxy no docker-compose.yml (ZBX_HOSTNAME) é igual ao cadastrado no server
- Verificar se o modo está como "Active" no server
- Verificar firewall/security groups (porta 10051 do server deve estar acessível)
- Aguardar alguns minutos para sincronização

### Agentes não enviam dados para o proxy
- Verificar se agentes estão configurados com IP do proxy (não do server)
- Verificar porta 10051 do proxy acessível
- Verificar logs do agente: `/var/log/zabbix/zabbix_agentd.log`

## Arquitetura de Comunicação

```
Zabbix Agent → (10050) → Zabbix Proxy → (10051) → Zabbix Server
                          (porta 10051)
```

O proxy coleta dados dos agentes e envia para o servidor central, reduzindo a carga no servidor e permitindo monitoramento distribuído.

## Security Groups - Resumo

**Zabbix Proxy precisa:**
- Porta 10051 aberta para receber dados dos agentes (entrada)
- Conectividade com porta 10051 do Zabbix Server (saída)
- Porta 8080 para code-server (entrada - opcional)
- Porta 22 para SSH (entrada - opcional se usar SSM)

**Zabbix Agents precisam:**
- Conectividade com porta 10051 do Zabbix Proxy (saída)
