# Setup de Instâncias EC2

Guia completo para configurar as instâncias EC2 para os cenários de OpenTelemetry e Alloy.

## Visão Geral

Este setup utiliza **2 instâncias EC2**:

- **Instância 1**: Stack de observabilidade (Grafana, Prometheus, Loki, Jaeger, OTel Collector)
- **Instância 2**: Aplicações (Frontend, Backend, PostgreSQL, Redis) + Alloy (apenas Cenário 2)

## Arquitetura de Rede

```
┌─────────────────────────────────────────────────────────────┐
│                         VPC                                 │
│                    10.0.0.0/16                              │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Subnet Pública                          │  │
│  │              10.0.1.0/24                             │  │
│  │                                                      │  │
│  │  ┌─────────────────┐      ┌─────────────────┐      │  │
│  │  │  Instância 1    │      │  Instância 2    │      │  │
│  │  │  Observability  │◄─────┤  Applications   │      │  │
│  │  │  10.0.1.100     │      │  10.0.1.200     │      │  │
│  │  └─────────────────┘      └─────────────────┘      │  │
│  │                                                      │  │
│  └──────────────────────────────────────────────────────┘  │
│                           │                                 │
└───────────────────────────┼─────────────────────────────────┘
                            │
                    ┌───────▼────────┐
                    │ Internet       │
                    │ Gateway        │
                    └────────────────┘
```

## Pré-requisitos

- Conta AWS ativa
- AWS CLI configurado (opcional)
- Conhecimento básico de EC2 e VPC
- Par de chaves SSH criado

## Passo 1: Criar VPC e Subnet

### Opção A: Usar VPC Default

Se você já tem uma VPC default, pode usá-la diretamente.

### Opção B: Criar Nova VPC

1. Acesse **VPC Console**
2. Clique em **Create VPC**
3. Configurações:
   - **Name**: `aula-06-vpc`
   - **IPv4 CIDR**: `10.0.0.0/16`
   - **IPv6 CIDR**: Sem IPv6
   - **Tenancy**: Default

4. Criar **Subnet**:
   - **Name**: `aula-06-subnet-public`
   - **VPC**: `aula-06-vpc`
   - **Availability Zone**: Qualquer
   - **IPv4 CIDR**: `10.0.1.0/24`

5. Criar **Internet Gateway**:
   - **Name**: `aula-06-igw`
   - Attach à VPC `aula-06-vpc`

6. Configurar **Route Table**:
   - Adicionar rota: `0.0.0.0/0` → Internet Gateway

## Passo 2: Criar Security Groups

### Security Group da Instância 1 (Observabilidade)

**Nome**: `aula-06-sg-observability`

**Inbound Rules**:

| Tipo | Protocolo | Porta | Origem | Descrição |
|------|-----------|-------|--------|-----------|
| SSH | TCP | 22 | Seu IP | Acesso SSH |
| Custom TCP | TCP | 3000 | 0.0.0.0/0 | Grafana UI |
| Custom TCP | TCP | 9090 | 0.0.0.0/0 | Prometheus UI |
| Custom TCP | TCP | 16686 | 0.0.0.0/0 | Jaeger UI |
| Custom TCP | TCP | 3100 | 10.0.1.0/24 | Loki (interno) |
| Custom TCP | TCP | 4317 | 10.0.1.0/24 | OTLP gRPC (interno) |
| Custom TCP | TCP | 4318 | 10.0.1.0/24 | OTLP HTTP (interno) |
| Custom TCP | TCP | 4319 | 10.0.1.0/24 | OTel Collector (interno) |

**Outbound Rules**:
- All traffic → 0.0.0.0/0

### Security Group da Instância 2 (Aplicações)

**Nome**: `aula-06-sg-applications`

**Inbound Rules**:

| Tipo | Protocolo | Porta | Origem | Descrição |
|------|-----------|-------|--------|-----------|
| SSH | TCP | 22 | Seu IP | Acesso SSH |
| Custom TCP | TCP | 3001 | 0.0.0.0/0 | Frontend |
| Custom TCP | TCP | 5000 | 0.0.0.0/0 | Backend |
| Custom TCP | TCP | 12345 | 0.0.0.0/0 | Alloy UI (Cenário 2) |

**Outbound Rules**:
- All traffic → 0.0.0.0/0

## Passo 3: Criar Instância 1 (Observabilidade)

### Configurações

1. **AMI**: Ubuntu Server 22.04 LTS
2. **Instance Type**: `t3.medium` (2 vCPU, 4 GB RAM)
   - Mínimo recomendado para a stack completa
3. **Key Pair**: Selecione ou crie um par de chaves
4. **Network Settings**:
   - **VPC**: `aula-06-vpc`
   - **Subnet**: `aula-06-subnet-public`
   - **Auto-assign Public IP**: Enable
   - **Security Group**: `aula-06-sg-observability`
5. **Storage**: 30 GB gp3
6. **Advanced Details**:
   - **User Data**: Copiar conteúdo de `ec2-userdata/instancia-1.sh`

### User Data Script

```bash
#!/bin/bash
# Ver arquivo completo em: ec2-userdata/instancia-1.sh

# Instala Docker e Docker Compose
# Clona repositório
# Inicia stack de observabilidade
```

### Após Criação

1. Aguardar instância ficar **Running**
2. Anotar **Public IP** e **Private IP**
3. Aguardar ~5 minutos para user data executar
4. Verificar logs: `sudo tail -f /var/log/cloud-init-output.log`

### Testar Acesso

```bash
# SSH
ssh -i sua-chave.pem ubuntu@PUBLIC_IP_INSTANCIA_1

# Verificar Docker
docker ps

# Verificar serviços
curl http://localhost:3000/api/health  # Grafana
curl http://localhost:9090/-/healthy   # Prometheus
curl http://localhost:3100/ready       # Loki
curl http://localhost:16686/           # Jaeger
```

### Acessar Interfaces

- **Grafana**: http://PUBLIC_IP_INSTANCIA_1:3000 (admin/admin123)
- **Prometheus**: http://PUBLIC_IP_INSTANCIA_1:9090
- **Jaeger**: http://PUBLIC_IP_INSTANCIA_1:16686

## Passo 4: Criar Instância 2 (Aplicações)

### Configurações

1. **AMI**: Ubuntu Server 22.04 LTS
2. **Instance Type**: `t3.small` (2 vCPU, 2 GB RAM)
   - Suficiente para as aplicações
3. **Key Pair**: Mesmo da Instância 1
4. **Network Settings**:
   - **VPC**: `aula-06-vpc`
   - **Subnet**: `aula-06-subnet-public`
   - **Auto-assign Public IP**: Enable
   - **Security Group**: `aula-06-sg-applications`
5. **Storage**: 20 GB gp3
6. **Advanced Details**:
   - **User Data**: Copiar conteúdo de `ec2-userdata/instancia-2.sh`
   - **IMPORTANTE**: Substituir `OBSERVABILITY_IP` pelo IP privado da Instância 1

### User Data Script

```bash
#!/bin/bash
# Ver arquivo completo em: ec2-userdata/instancia-2.sh

# IMPORTANTE: Substituir OBSERVABILITY_IP antes de usar
export OBSERVABILITY_IP="10.0.1.100"  # IP PRIVADO da Instância 1

# Instala Docker e Docker Compose
# Clona repositório
# Configura IP da Instância 1
# Inicia aplicações (escolher cenário)
```

### Escolher Cenário

No user data, escolha **UM** dos cenários:

**Cenário 1 (Via Collector)**:
```bash
cd scenario-1-via-collector
sed -i "s/OBSERVABILITY_IP/${OBSERVABILITY_IP}/g" docker-compose.yml
docker-compose up -d
```

**Cenário 2 (Via Alloy)**:
```bash
cd scenario-2-via-alloy
sed -i "s/OBSERVABILITY_IP/${OBSERVABILITY_IP}/g" alloy-config.alloy
docker-compose up -d
```

### Após Criação

1. Aguardar instância ficar **Running**
2. Anotar **Public IP**
3. Aguardar ~5 minutos para user data executar
4. Verificar logs: `sudo tail -f /var/log/cloud-init-output.log`

### Testar Acesso

```bash
# SSH
ssh -i sua-chave.pem ubuntu@PUBLIC_IP_INSTANCIA_2

# Verificar Docker
docker ps

# Testar aplicações
curl http://localhost:3001/health  # Frontend
curl http://localhost:5000/health  # Backend

# Testar endpoints
curl http://localhost:3001/api/users
```

### Acessar Aplicações

- **Frontend**: http://PUBLIC_IP_INSTANCIA_2:3001
- **Backend**: http://PUBLIC_IP_INSTANCIA_2:5000
- **Alloy UI** (Cenário 2): http://PUBLIC_IP_INSTANCIA_2:12345

## Passo 5: Verificar Conectividade

### Da Instância 2 para Instância 1

```bash
# SSH na Instância 2
ssh -i sua-chave.pem ubuntu@PUBLIC_IP_INSTANCIA_2

# Testar conectividade
ping -c 3 PRIVATE_IP_INSTANCIA_1

# Testar portas
curl http://PRIVATE_IP_INSTANCIA_1:9090/-/healthy   # Prometheus
curl http://PRIVATE_IP_INSTANCIA_1:3100/ready       # Loki
curl http://PRIVATE_IP_INSTANCIA_1:4318             # OTLP HTTP
curl http://PRIVATE_IP_INSTANCIA_1:4319             # OTel Collector
```

### Verificar Telemetria no Grafana

1. Acesse Grafana: http://PUBLIC_IP_INSTANCIA_1:3000
2. Login: admin / admin123
3. Explore → Prometheus → Query: `http_server_request_duration_count`
4. Explore → Loki → Query: `{service_name="backend-service"}`
5. Explore → Jaeger → Service: `frontend-service`

## Troubleshooting

### Instância não inicia

```bash
# Ver logs do user data
sudo tail -f /var/log/cloud-init-output.log

# Ver status do cloud-init
sudo cloud-init status
```

### Docker não instalou

```bash
# Verificar se Docker está instalado
docker --version

# Instalar manualmente
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu
```

### Aplicações não conectam

```bash
# Verificar Security Groups
# Porta 4319 (Cenário 1) ou 9090/3100/4318 (Cenário 2) devem estar liberadas

# Testar conectividade
telnet PRIVATE_IP_INSTANCIA_1 4319

# Verificar logs
docker-compose logs
```

### Sem telemetria no Grafana

1. Verificar se aplicações estão rodando (Instância 2)
2. Verificar logs das aplicações
3. Verificar conectividade entre instâncias
4. Verificar logs do OTel Collector ou Alloy
5. Verificar data sources no Grafana

## Custos Estimados (us-east-1)

| Recurso | Tipo | Custo/hora | Custo/mês (730h) |
|---------|------|------------|------------------|
| Instância 1 | t3.medium | $0.0416 | ~$30 |
| Instância 2 | t3.small | $0.0208 | ~$15 |
| Storage (50 GB) | gp3 | - | ~$4 |
| **Total** | | | **~$49/mês** |

**Dica**: Use **t3.micro** (Free Tier) para testes rápidos.

## Limpeza de Recursos

### Parar Instâncias (preserva dados)

```bash
# Via Console
EC2 → Instances → Select → Instance State → Stop

# Via CLI
aws ec2 stop-instances --instance-ids i-xxx i-yyy
```

### Terminar Instâncias (remove tudo)

```bash
# Via Console
EC2 → Instances → Select → Instance State → Terminate

# Via CLI
aws ec2 terminate-instances --instance-ids i-xxx i-yyy
```

### Remover Security Groups e VPC

1. Terminar todas as instâncias
2. Deletar Security Groups
3. Deletar Subnet
4. Detach e deletar Internet Gateway
5. Deletar VPC

## Automação com Terraform (Opcional)

```hcl
# Exemplo básico
resource "aws_instance" "observability" {
  ami           = "ami-0c55b159cbfafe1f0"  # Ubuntu 22.04
  instance_type = "t3.medium"
  
  vpc_security_group_ids = [aws_security_group.observability.id]
  subnet_id              = aws_subnet.public.id
  
  user_data = file("ec2-userdata/instancia-1.sh")
  
  tags = {
    Name = "aula-06-observability"
  }
}
```

## Próximos Passos

- Configurar [Instância 1](../instancia-1-observability/README.md)
- Escolher cenário:
  - [Cenário 1 - Via Collector](../scenario-1-via-collector/README.md)
  - [Cenário 2 - Via Alloy](../scenario-2-via-alloy/README.md)
- Explorar [Guia de OpenTelemetry](./opentelemetry-guide.md)

## Recursos Adicionais

- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/)
- [Docker Installation](https://docs.docker.com/engine/install/ubuntu/)
- [Guia de User Data](./ec2-userdata.md)
