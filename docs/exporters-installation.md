# Instalação Manual de Exporters

Guia para instalação manual do Node Exporter e cAdvisor nas instâncias Ubuntu para coleta de métricas pelo Prometheus.

## Node Exporter - Métricas do Sistema

### Instalação

```bash
# Conectar na instância via SSM ou SSH
aws ssm start-session --target i-xxxxxxxxx

# Criar usuário para o Node Exporter
sudo useradd --no-create-home --shell /bin/false node_exporter

# Baixar Node Exporter
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz

# Extrair e instalar
tar xvf node_exporter-1.8.2.linux-amd64.tar.gz
sudo cp node_exporter-1.8.2.linux-amd64/node_exporter /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Limpar arquivos temporários
rm -rf node_exporter-1.8.2.linux-amd64*
```

### Configurar como serviço

```bash
# Criar arquivo de serviço systemd
sudo tee /etc/systemd/system/node_exporter.service > /dev/null << 'EOF'
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter \
    --collector.systemd \
    --collector.processes \
    --web.listen-address=:9100

[Install]
WantedBy=multi-user.target
EOF

# Recarregar systemd e iniciar serviço
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
sudo systemctl status node_exporter
```

### Verificar funcionamento

```bash
# Testar métricas localmente
curl http://localhost:9100/metrics

# Verificar se está escutando na porta
sudo netstat -tlnp | grep :9100
```

## cAdvisor - Métricas de Containers

### Por que usar cAdvisor em container?

- **Acesso nativo ao Docker**: Acesso direto ao socket e APIs do Docker
- **Isolamento**: Não interfere no sistema host
- **Facilidade de gerenciamento**: Mais fácil de atualizar e configurar
- **Padrão da indústria**: Forma recomendada pela comunidade
- **Menos dependências**: Não precisa instalar binários no host
- **Descoberta automática**: Monitora todos os containers automaticamente

### Instalação via Docker Compose

Esta opção usa Docker Compose para gerenciar o cAdvisor e aplicações de teste.

#### Passo 1: Clonar o repositório

```bash
# Conectar na instância via SSM ou SSH
aws ssm start-session --target i-xxxxxxxxx

# Navegar para o diretório home do usuário ubuntu
cd /home/ubuntu

# Clonar o repositório na branch aula-02 com nome simplificado
git clone -b aula-02 https://github.com/Ed-Carlos-Marinho/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource.git PosTech

# Acessar o diretório do projeto
cd PosTech
```

#### Passo 2: Subir o cAdvisor e aplicações de teste

```bash
# Subir todos os containers (cAdvisor + apps de teste)
docker-compose -f docker-compose-cadvisor-test.yml up -d

# Verificar se os containers estão rodando
docker-compose -f docker-compose-cadvisor-test.yml ps

# Ver logs do cAdvisor
docker-compose -f docker-compose-cadvisor-test.yml logs -f cadvisor
```

#### Containers incluídos:

- **cAdvisor** (porta 8080) - Monitor de containers
- **NGINX** (porta 8081) - Web server de teste
- **Redis** (porta 6379) - Cache/Database de teste
- **Postgres** (porta 5432) - Database de teste
- **Stress Test** - Gera carga de CPU/memória para testes
- **Busybox** - Container leve para testes

#### Verificar funcionamento

```bash
# Verificar containers rodando
docker-compose -f docker-compose-cadvisor-test.yml ps

# Testar métricas do cAdvisor
curl http://localhost:8080/metrics

# Acessar interface web do cAdvisor
# http://IP_INSTANCIA:8080

# Testar aplicações
curl http://localhost:8081  # NGINX
```

#### Gerenciar containers

```bash
# Parar todos os containers
docker-compose -f docker-compose-cadvisor-test.yml stop

# Iniciar containers parados
docker-compose -f docker-compose-cadvisor-test.yml start

# Reiniciar containers
docker-compose -f docker-compose-cadvisor-test.yml restart

# Ver logs de um container específico
docker-compose -f docker-compose-cadvisor-test.yml logs -f nginx-app

# Parar e remover tudo (incluindo volumes)
docker-compose -f docker-compose-cadvisor-test.yml down -v
```

#### Testar alertas com Stress Test

O container `stress-test` gera carga de CPU e memória, perfeito para testar alertas:

```bash
# Parar o stress test
docker-compose -f docker-compose-cadvisor-test.yml stop stress-test

# Iniciar o stress test novamente
docker-compose -f docker-compose-cadvisor-test.yml start stress-test

# Ver uso de recursos do stress test
docker stats stress-test-app
```

## Configurar Security Groups

### Para Node Exporter (porta 9100)
```bash
# Via AWS CLI
aws ec2 authorize-security-group-ingress \
    --group-id sg-xxxxxxxxx \
    --protocol tcp \
    --port 9100 \
    --source-group sg-yyyyyyyyy
```

### Para cAdvisor (porta 8080)
```bash
# Via AWS CLI  
aws ec2 authorize-security-group-ingress \
    --group-id sg-xxxxxxxxx \
    --protocol tcp \
    --port 8080 \
    --source-group sg-yyyyyyyyy
```

**Ou via Console AWS:**
1. EC2 → Security Groups
2. Selecionar SG das instâncias com exporters
3. Inbound rules → Edit
4. Add rule:
   - Type: Custom TCP
   - Port: 9100 (Node Exporter) ou 8080 (cAdvisor)
   - Source: Security Group do Prometheus

## Atualizar configuração do Prometheus

Após instalar os exporters, editar o arquivo `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['10.0.1.100:9100', '10.0.1.101:9100']  # IPs privados das instâncias

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['10.0.1.100:8080', '10.0.1.101:8080']  # IPs privados das instâncias
```

Validar e recarregar configuração do Prometheus:
```bash
# Validar configuração
docker-compose exec prometheus promtool check config /etc/prometheus/prometheus.yml

# Recarregar via API (sem reiniciar)
curl -X POST http://localhost:9090/-/reload

# Ou reiniciar o container
docker-compose restart prometheus
```

## Verificação no Prometheus

1. Acessar Prometheus: `http://IP_PROMETHEUS:9090`
2. Status → Targets
3. Verificar se todos os exporters estão "UP"
4. Testar consultas PromQL:
   - `up` - Status de todos os targets
   - `node_cpu_seconds_total` - Métricas de CPU do Node Exporter
   - `container_memory_usage_bytes` - Métricas de containers do cAdvisor
   - `container_last_seen{name!=""}` - Listar todos os containers descobertos
   - `rate(container_cpu_usage_seconds_total{name!=""}[5m])` - CPU por container

## Queries PromQL para Containers

Com o cAdvisor rodando, você pode usar estas queries para monitorar containers:

```promql
# Listar todos os containers descobertos
container_last_seen{name!=""}

# CPU por container (em %)
rate(container_cpu_usage_seconds_total{name!=""}[5m]) * 100

# Memória usada por container
container_memory_usage_bytes{name!=""}

# Uso de memória vs limite (em %)
(container_memory_usage_bytes{name!=""} / container_spec_memory_limit_bytes{name!=""}) * 100

# Top 5 containers por uso de CPU
topk(5, rate(container_cpu_usage_seconds_total{name!=""}[5m]))

# Top 5 containers por uso de memória
topk(5, container_memory_usage_bytes{name!=""})

# Tráfego de rede por container
rate(container_network_receive_bytes_total{name!=""}[5m]) + rate(container_network_transmit_bytes_total{name!=""}[5m])

# Containers específicos (ex: nginx)
container_memory_usage_bytes{name="nginx-test-app"}
```

## Troubleshooting

### Node Exporter não inicia
```bash
# Ver logs
sudo journalctl -u node_exporter -f

# Verificar permissões
ls -la /usr/local/bin/node_exporter

# Testar manualmente
sudo -u node_exporter /usr/local/bin/node_exporter
```

### cAdvisor não inicia

```bash
# Ver logs do cAdvisor
docker-compose -f docker-compose-cadvisor-test.yml logs cadvisor

# Verificar status dos containers
docker-compose -f docker-compose-cadvisor-test.yml ps

# Reiniciar apenas o cAdvisor
docker-compose -f docker-compose-cadvisor-test.yml restart cadvisor

# Recriar o cAdvisor
docker-compose -f docker-compose-cadvisor-test.yml up -d --force-recreate cadvisor

# Verificar se Docker está rodando
sudo systemctl status docker
```

### Containers de teste não aparecem no cAdvisor

```bash
# Verificar se os containers estão rodando
docker ps

# Aguardar alguns segundos - cAdvisor descobre containers automaticamente
# Atualizar a página do cAdvisor: http://IP:8080

# Verificar métricas via curl
curl http://localhost:8080/metrics | grep container_last_seen

# Reiniciar o cAdvisor para forçar redescoberta
docker-compose -f docker-compose-cadvisor-test.yml restart cadvisor
```

### Erro de permissão no cAdvisor

```bash
# Verificar se o cAdvisor está rodando com privilégios
docker inspect cadvisor | grep -i privileged

# Se necessário, recriar com --privileged
docker-compose -f docker-compose-cadvisor-test.yml down
docker-compose -f docker-compose-cadvisor-test.yml up -d
```

### Prometheus não consegue coletar métricas
```bash
# Testar conectividade
telnet IP_TARGET 9100
telnet IP_TARGET 8080

# Verificar Security Groups
# Verificar IPs no prometheus.yml
# Verificar logs do Prometheus
docker-compose logs prometheus
```