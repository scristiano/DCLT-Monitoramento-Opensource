#!/bin/bash

# =============================================================================
# EC2 USER DATA SCRIPT - DISTRIBUTED APPLICATIONS SETUP
# =============================================================================
# Script de configuração automática para instância de aplicações distribuídas (Instância 2)
# Aula 05 - PosTech DevOps e Arquitetura Cloud - Monitoramento OpenSource
# 
# Este script instala e configura automaticamente:
# - Docker e Docker Compose
# - Clona repositório com aplicações distribuídas instrumentadas
# - Inicia stack de aplicações via Docker Compose
# =============================================================================

# -----------------------------------------------------------------------------
# CONFIGURAÇÕES DE AMBIENTE
# -----------------------------------------------------------------------------
# Define variáveis de ambiente essenciais para execução como root
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# -----------------------------------------------------------------------------
# CONFIGURAÇÃO DE LOGS
# -----------------------------------------------------------------------------
# Redireciona toda saída (stdout e stderr) para arquivo de log
# Permite acompanhar a execução via: sudo tail -f /var/log/user-data.log
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== Iniciando configuração das aplicações distribuídas em $(date) ==="

# -----------------------------------------------------------------------------
# FUNÇÃO DE VERIFICAÇÃO DE STATUS
# -----------------------------------------------------------------------------
# Função utilitária para verificar se comandos foram executados com sucesso
# Parâmetro: $1 = Descrição da operação para log
check_status() {
    if [ $? -eq 0 ]; then
        echo "✅ $1 - Sucesso"
    else
        echo "❌ $1 - Falhou"
        exit 1                              # Para execução em caso de erro
    fi
}

# =============================================================================
# FASE 1: ATUALIZAÇÃO DO SISTEMA
# =============================================================================

echo "📦 Atualizando sistema..."
apt-get update -y                           # Atualiza lista de pacotes disponíveis
check_status "Atualização do sistema"

# =============================================================================
# FASE 2: INSTALAÇÃO DE PACOTES BÁSICOS
# =============================================================================

echo "📦 Instalando pacotes básicos..."
apt-get install -y curl wget htop docker.io git # Instala ferramentas essenciais
# curl/wget: Clientes HTTP para downloads
# htop: Monitor de processos interativo
# docker.io: Para containers
# git: Para clonar repositório
check_status "Instalação de pacotes básicos"

# =============================================================================
# FASE 3: CONFIGURAÇÃO DO DOCKER
# =============================================================================

echo "🐳 Configurando Docker..."
systemctl start docker                      # Inicia serviço do Docker
systemctl enable docker                     # Habilita Docker para iniciar com o sistema
usermod -a -G docker ubuntu                 # Adiciona usuário ubuntu ao grupo docker
check_status "Configuração do Docker"

# =============================================================================
# FASE 4: INSTALAÇÃO DO DOCKER COMPOSE
# =============================================================================

echo "🐳 Instalando Docker Compose..."
# Download da versão específica para arquitetura AMD64 (t3.small)
curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose       # Torna executável
check_status "Instalação do Docker Compose"

# =============================================================================
# FASE 5: CLONAGEM DO REPOSITÓRIO
# =============================================================================

echo "📥 Clonando repositório..."
cd /home/ubuntu
git clone -b aula-05 https://github.com/Ed-Carlos-Marinho/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource.git repo
cd repo/distributed-app
chown -R ubuntu:ubuntu /home/ubuntu/repo
check_status "Clonagem do repositório"

# =============================================================================
# FASE 6: CONFIGURAÇÃO E INICIALIZAÇÃO DA STACK
# =============================================================================

echo "🚀 Iniciando stack de aplicações distribuídas..."
# Iniciar stack usando docker-compose
sudo -u ubuntu docker-compose -f docker-compose-app.yml up -d
check_status "Inicialização da stack de aplicações distribuídas"

# =============================================================================
# FASE 7: CONFIGURAÇÃO DO FIREWALL
# =============================================================================

echo "🔥 Configurando firewall..."
ufw --force enable                          # Habilita firewall (força sem prompt)
ufw allow ssh                               # Permite SSH (porta 22)
ufw allow http                              # Permite HTTP (porta 80) - para frontend
ufw allow 5000                              # Permite Backend API
ufw allow 15672                             # Permite RabbitMQ Management UI
check_status "Configuração do firewall"

# =============================================================================
# FASE 8: VERIFICAÇÃO FINAL
# =============================================================================

echo "🔍 Verificando status dos serviços..."
# Verifica se serviços estão ativos e reporta status
systemctl is-active docker && echo "✅ Docker está rodando"
sudo -u ubuntu docker-compose -f /home/ubuntu/repo/distributed-app/docker-compose-app.yml ps

# =============================================================================
# FINALIZAÇÃO E INFORMAÇÕES DE ACESSO
# =============================================================================

echo "=== ✅ Configuração das aplicações distribuídas concluída em $(date) ==="
echo ""
echo "🚀 Serviços instalados e configurados:"
echo "   - Frontend: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "   - Backend API: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):5000"
echo "   - RabbitMQ Management: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):15672 (guest/guest)"
echo "   - Jaeger Agent Metrics: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):5778/metrics"
echo ""
echo "⚠️  PRÓXIMOS PASSOS MANUAIS:"
echo "   1. Obter IP privado da instância de tracing (Instância 1)"
echo "   2. Editar: /home/ubuntu/repo/distributed-app/docker-compose-app.yml"
echo "   3. Substituir JAEGER_COLLECTOR_IP pelo IP real da Instância 1"
echo "   4. Executar: cd /home/ubuntu/repo/distributed-app && docker-compose -f docker-compose-app.yml restart jaeger-agent"
echo "   5. Testar aplicações: curl http://localhost/api/users"
echo "   6. Verificar traces no Jaeger UI"
echo ""
echo "🔧 Comandos úteis:"
echo "   - Testar frontend: curl http://localhost/"
echo "   - Listar usuários: curl http://localhost/api/users"
echo "   - Listar produtos: curl http://localhost/api/products"
echo "   - Criar pedido: curl -X POST http://localhost/api/orders -H 'Content-Type: application/json' -d '{\"user_id\":1,\"total_amount\":99.99}'"
echo "   - Ver logs da stack: cd /home/ubuntu/repo/distributed-app && docker-compose -f docker-compose-app.yml logs -f"
echo "   - Status da stack: cd /home/ubuntu/repo/distributed-app && docker-compose -f docker-compose-app.yml ps"
echo "   - Verificar Jaeger Agent: curl http://localhost:5778/metrics"
echo "   - Logs de instalação: sudo tail -f /var/log/user-data.log"

# =============================================================================
# INFORMAÇÕES IMPORTANTES PARA MANUTENÇÃO:
# =============================================================================
# 
# LOGS E TROUBLESHOOTING:
# - Log de execução: /var/log/user-data.log
# - Logs da stack: docker-compose -f docker-compose-app.yml logs
# - Logs específicos: docker-compose -f docker-compose-app.yml logs [service]
#
# ARQUIVOS DE CONFIGURAÇÃO:
# - Docker Compose: /home/ubuntu/repo/distributed-app/docker-compose-app.yml
# - Jaeger Agent config: /home/ubuntu/repo/distributed-app/jaeger-agent-config.yml
# - Frontend: /home/ubuntu/repo/distributed-app/frontend/
# - Backend: /home/ubuntu/repo/distributed-app/backend/
#
# PORTAS UTILIZADAS:
# - 22: SSH
# - 80: HTTP (Frontend)
# - 5000: Backend API
# - 5432: PostgreSQL
# - 6379: Redis
# - 5672: RabbitMQ AMQP
# - 15672: RabbitMQ Management UI
# - 6831/6832: Jaeger Agent (UDP)
# - 5778: Jaeger Agent HTTP
#
# COMANDOS DE MANUTENÇÃO:
# - Reiniciar stack: docker-compose -f docker-compose-app.yml restart
# - Parar stack: docker-compose -f docker-compose-app.yml down
# - Iniciar stack: docker-compose -f docker-compose-app.yml up -d
# - Ver logs: docker-compose -f docker-compose-app.yml logs -f
# - Status: docker-compose -f docker-compose-app.yml ps
# - Rebuild serviços: docker-compose -f docker-compose-app.yml build
#
# CONFIGURAÇÃO FINAL NECESSÁRIA:
# 1. Substituir JAEGER_COLLECTOR_IP pelo IP real da instância 1 em docker-compose-app.yml
# 2. Verificar traces no Jaeger UI
# 3. Testar rastreamento de requisições entre serviços
#
# ENDPOINTS DAS APLICAÇÕES:
# - GET /: Página inicial do frontend
# - GET /health: Health check (frontend e backend)
# - GET /api/users: Lista usuários (com cache)
# - GET /api/products: Lista produtos (com cache)
# - GET /api/orders: Lista pedidos
# - POST /api/orders: Cria novo pedido (operação complexa)
# =============================================================================