# Guia dos Scripts EC2 User Data

Este guia explica os scripts de user data usados para configurar automaticamente as instâncias EC2.

## O que é User Data?

**User Data** é um script que executa automaticamente quando uma instância EC2 é iniciada pela primeira vez. É usado para:

- Instalar software
- Configurar serviços
- Clonar repositórios
- Iniciar aplicações

## Localização dos Scripts

```
ec2-userdata/
├── instancia-1.sh    # Script para Instância 1 (Observabilidade)
└── instancia-2.sh    # Script para Instância 2 (Aplicações)
```

## Instância 1 - Stack de Observabilidade

### Script: `instancia-1.sh`

```bash
#!/bin/bash

# Atualizar sistema
apt-get update
apt-get upgrade -y

# Instalar Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Instalar Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Clonar repositório
cd /home/ubuntu
git clone <REPO_URL>
cd <REPO_NAME>
git checkout aula-06

# Iniciar stack de observabilidade
cd instancia-1-observability
docker-compose up -d

# Verificar status
docker-compose ps
```

### O que o script faz?

1. **Atualiza o sistema**: `apt-get update && upgrade`
2. **Instala Docker**: Via script oficial
3. **Instala Docker Compose**: Última versão
4. **Clona repositório**: Branch aula-06
5. **Inicia stack**: Grafana, Prometheus, Loki, Jaeger, OTel Collector

### Tempo de execução

- **Total**: ~5-7 minutos
- **Docker install**: ~2 minutos
- **Git clone**: ~30 segundos
- **Docker compose up**: ~3 minutos

### Verificar execução

```bash
# SSH na instância
ssh -i sua-chave.pem ubuntu@PUBLIC_IP

# Ver logs do user data
sudo tail -f /var/log/cloud-init-output.log

# Ver status do cloud-init
sudo cloud-init status

# Verificar Docker
docker ps

# Verificar serviços
curl http://localhost:3000/api/health  # Grafana
curl http://localhost:9090/-/healthy   # Prometheus
```

## Instância 2 - Aplicações

### Script: `instancia-2.sh`

```bash
#!/bin/bash

# IMPORTANTE: Substituir pelo IP PRIVADO da Instância 1
export OBSERVABILITY_IP="10.0.1.100"

# Atualizar sistema
apt-get update
apt-get upgrade -y

# Instalar Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Instalar Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Clonar repositório
cd /home/ubuntu
git clone <REPO_URL>
cd <REPO_NAME>
git checkout aula-06

# ESCOLHER UM CENÁRIO:

# Cenário 1: Via OpenTelemetry Collector
cd cenario-1-via-collector
sed -i "s/OBSERVABILITY_IP/${OBSERVABILITY_IP}/g" docker-compose.yml
docker-compose up -d

# OU

# Cenário 2: Via Grafana Alloy
cd cenario-2-via-alloy
sed -i "s/OBSERVABILITY_IP/${OBSERVABILITY_IP}/g" alloy-config.alloy
docker-compose up -d

# Verificar status
docker-compose ps
```

### O que o script faz?

1. **Define IP da Instância 1**: Variável `OBSERVABILITY_IP`
2. **Atualiza o sistema**: `apt-get update && upgrade`
3. **Instala Docker**: Via script oficial
4. **Instala Docker Compose**: Última versão
5. **Clona repositório**: Branch aula-06
6. **Escolhe cenário**: Cenário 1 ou 2
7. **Configura IP**: Substitui `OBSERVABILITY_IP` nos arquivos
8. **Inicia aplicações**: Frontend, Backend, PostgreSQL, Redis (+ Alloy no Cenário 2)

### ⚠️ IMPORTANTE: Configurar IP

**ANTES de usar o script**, você DEVE:

1. Criar a Instância 1
2. Anotar o **IP PRIVADO** da Instância 1
3. Substituir no script:

```bash
# Substituir esta linha:
export OBSERVABILITY_IP="10.0.1.100"

# Pelo IP real da sua Instância 1:
export OBSERVABILITY_IP="SEU_IP_PRIVADO_AQUI"
```

### Escolher Cenário

No script, **comente** o cenário que NÃO quer usar:

**Para usar Cenário 1**:
```bash
# Cenário 1: Via OpenTelemetry Collector
cd cenario-1-via-collector
sed -i "s/OBSERVABILITY_IP/${OBSERVABILITY_IP}/g" docker-compose.yml
docker-compose up -d

# Cenário 2: Via Grafana Alloy (COMENTADO)
# cd cenario-2-via-alloy
# sed -i "s/OBSERVABILITY_IP/${OBSERVABILITY_IP}/g" alloy-config.alloy
# docker-compose up -d
```

**Para usar Cenário 2**:
```bash
# Cenário 1: Via OpenTelemetry Collector (COMENTADO)
# cd cenario-1-via-collector
# sed -i "s/OBSERVABILITY_IP/${OBSERVABILITY_IP}/g" docker-compose.yml
# docker-compose up -d

# Cenário 2: Via Grafana Alloy
cd cenario-2-via-alloy
sed -i "s/OBSERVABILITY_IP/${OBSERVABILITY_IP}/g" alloy-config.alloy
docker-compose up -d
```

### Tempo de execução

- **Total**: ~5-7 minutos
- **Docker install**: ~2 minutos
- **Git clone**: ~30 segundos
- **Docker compose up**: ~3 minutos

### Verificar execução

```bash
# SSH na instância
ssh -i sua-chave.pem ubuntu@PUBLIC_IP

# Ver logs do user data
sudo tail -f /var/log/cloud-init-output.log

# Ver status do cloud-init
sudo cloud-init status

# Verificar Docker
docker ps

# Testar aplicações
curl http://localhost:3001/health  # Frontend
curl http://localhost:5000/health  # Backend
curl http://localhost:3001/api/users
```

## Como Usar User Data na AWS Console

### Passo 1: Criar Instância EC2

1. Acesse **EC2 Console**
2. Clique em **Launch Instance**
3. Configure:
   - AMI: Ubuntu Server 22.04 LTS
   - Instance Type: t3.medium (Inst. 1) ou t3.small (Inst. 2)
   - Key Pair: Selecione ou crie
   - Network: Configure VPC e Subnet
   - Security Group: Configure portas

### Passo 2: Adicionar User Data

1. Na seção **Advanced Details**
2. Role até **User data**
3. Cole o conteúdo do script:
   - Para Instância 1: Copie `instancia-1.sh`
   - Para Instância 2: Copie `instancia-2.sh` (APÓS configurar IP)

### Passo 3: Launch

1. Clique em **Launch instance**
2. Aguarde instância ficar **Running**
3. Aguarde ~5-7 minutos para script executar

## Troubleshooting

### Script não executou

```bash
# Ver logs
sudo cat /var/log/cloud-init-output.log

# Ver erros
sudo cat /var/log/cloud-init.log | grep -i error

# Ver status
sudo cloud-init status --long
```

### Docker não instalou

```bash
# Verificar se Docker está instalado
docker --version

# Se não estiver, instalar manualmente
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

# Logout e login novamente
exit
ssh -i sua-chave.pem ubuntu@PUBLIC_IP
```

### Git clone falhou

```bash
# Verificar conectividade
ping -c 3 github.com

# Clonar manualmente
cd /home/ubuntu
git clone <REPO_URL>
cd <REPO_NAME>
git checkout aula-06
```

### Docker Compose não iniciou

```bash
# Verificar logs
cd /home/ubuntu/<REPO_NAME>/instancia-1-observability
docker-compose logs

# Reiniciar
docker-compose down
docker-compose up -d
```

### IP da Instância 1 errado

```bash
# Instância 2 - Cenário 1
cd /home/ubuntu/<REPO_NAME>/cenario-1-via-collector
export OBSERVABILITY_IP="IP_CORRETO"
sed -i "s/OBSERVABILITY_IP/${OBSERVABILITY_IP}/g" docker-compose.yml
docker-compose restart

# Instância 2 - Cenário 2
cd /home/ubuntu/<REPO_NAME>/cenario-2-via-alloy
export OBSERVABILITY_IP="IP_CORRETO"
sed -i "s/OBSERVABILITY_IP/${OBSERVABILITY_IP}/g" alloy-config.alloy
docker-compose restart alloy
```

## Customização dos Scripts

### Adicionar comandos

```bash
#!/bin/bash

# ... código existente ...

# Adicionar seus comandos aqui
echo "Instalando ferramentas adicionais..."
apt-get install -y htop vim curl

# Configurar timezone
timedatectl set-timezone America/Sao_Paulo

# Criar usuário adicional
useradd -m -s /bin/bash devops
usermod -aG docker devops
```

### Usar variáveis de ambiente

```bash
#!/bin/bash

# Definir variáveis
export REPO_URL="https://github.com/seu-usuario/seu-repo.git"
export BRANCH="aula-06"
export OBSERVABILITY_IP="10.0.1.100"

# Usar variáveis
git clone $REPO_URL
cd <REPO_NAME>
git checkout $BRANCH
```

### Adicionar notificações

```bash
#!/bin/bash

# ... código existente ...

# Notificar conclusão (exemplo com SNS)
aws sns publish \
  --topic-arn arn:aws:sns:us-east-1:123456789:my-topic \
  --message "Instância configurada com sucesso!"

# Ou via webhook
curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
  -H 'Content-Type: application/json' \
  -d '{"text":"Instância configurada!"}'
```

## Melhores Práticas

### 1. Sempre teste localmente primeiro

```bash
# Testar script localmente
bash instancia-1.sh

# Verificar erros
echo $?
```

### 2. Use logs

```bash
#!/bin/bash

# Redirecionar output para arquivo
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Iniciando configuração..."
# ... resto do script ...
echo "Configuração concluída!"
```

### 3. Trate erros

```bash
#!/bin/bash

set -e  # Parar em caso de erro
set -x  # Mostrar comandos executados

# Função de erro
error_exit() {
  echo "ERRO: $1" >&2
  exit 1
}

# Usar função
apt-get update || error_exit "Falha ao atualizar sistema"
```

### 4. Valide pré-requisitos

```bash
#!/bin/bash

# Verificar se é Ubuntu
if [ ! -f /etc/lsb-release ]; then
  echo "Este script é para Ubuntu!"
  exit 1
fi

# Verificar conectividade
ping -c 1 github.com || {
  echo "Sem conectividade com internet!"
  exit 1
}
```

### 5. Use idempotência

```bash
#!/bin/bash

# Verificar se Docker já está instalado
if ! command -v docker &> /dev/null; then
  echo "Instalando Docker..."
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
else
  echo "Docker já instalado"
fi
```

## Alternativas ao User Data

### 1. AMI Customizada

Criar AMI com tudo pré-instalado:

```bash
# 1. Configurar instância manualmente
# 2. Criar AMI: EC2 → Actions → Image → Create Image
# 3. Usar AMI customizada em novas instâncias
```

**Vantagens**: Mais rápido, consistente
**Desvantagens**: Menos flexível, precisa manter AMI

### 2. Configuration Management

Usar Ansible, Chef, Puppet:

```yaml
# ansible-playbook.yml
- hosts: all
  tasks:
    - name: Install Docker
      shell: curl -fsSL https://get.docker.com | sh
    
    - name: Clone repo
      git:
        repo: https://github.com/user/repo.git
        dest: /home/ubuntu/repo
```

**Vantagens**: Mais poderoso, reutilizável
**Desvantagens**: Mais complexo, curva de aprendizado

### 3. Terraform

```hcl
resource "aws_instance" "observability" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.medium"
  
  user_data = file("instancia-1.sh")
  
  provisioner "remote-exec" {
    inline = [
      "sudo docker-compose up -d"
    ]
  }
}
```

**Vantagens**: Infraestrutura como código
**Desvantagens**: Requer Terraform

## Recursos Adicionais

- [AWS User Data Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html)
- [Cloud-Init Documentation](https://cloudinit.readthedocs.io/)
- [Docker Installation](https://docs.docker.com/engine/install/ubuntu/)
- [Guia de Setup EC2](./setup-ec2-instances.md)
