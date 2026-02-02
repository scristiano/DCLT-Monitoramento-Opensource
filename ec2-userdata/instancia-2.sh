#!/bin/bash

# =============================================================================
# EC2 USER DATA SCRIPT - INSTRUMENTED APPLICATIONS SETUP
# =============================================================================
# Script de configuração automática para instância de aplicações instrumentadas (Instância 2)
# Aula 06 - PosTech DevOps e Arquitetura Cloud - Monitoramento OpenSource
# 
# Este script instala e configura automaticamente:
# - Docker e Docker Compose
# - Clona repositório com aplicações instrumentadas com OpenTelemetry
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
echo "=== Iniciando configuração das aplicações instrumentadas em $(date) ==="

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
git clone -b aula-06 https://github.com/Ed-Carlos-Marinho/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource.git repo
cd repo
chown -R ubuntu:ubuntu /home/ubuntu/repo
check_status "Clonagem do repositório"

# =============================================================================
# FASE 6: CONFIGURAÇÃO E INICIALIZAÇÃO DA STACK
# =============================================================================

echo "🚀 Iniciando stack de aplicações instrumentadas..."
# IMPORTANTE: Escolher UM dos cenários abaixo antes de executar

# CENÁRIO 1: Via OpenTelemetry Collector (descomente as 3 linhas abaixo)
# cd scenario-1-via-collector
# sed -i "s/OBSERVABILITY_IP/IP_PRIVADO_INSTANCIA_1/g" docker-compose.yml
# sudo -u ubuntu docker-compose up -d

# CENÁRIO 2: Via Grafana Alloy (descomente as 3 linhas abaixo)
# cd scenario-2-via-alloy
# sed -i "s/OBSERVABILITY_IP/IP_PRIVADO_INSTANCIA_1/g" alloy-config.alloy
# sudo -u ubuntu docker-compose up -d

check_status "Inicialização da stack de aplicações instrumentadas"

# =============================================================================
# FASE 7: CONFIGURAÇÃO DO FIREWALL
# =============================================================================

echo "🔥 Configurando firewall..."
ufw --force enable                          # Habilita firewall (força sem prompt)
ufw allow ssh                               # Permite SSH (porta 22)
ufw allow 3001                              # Permite Frontend
ufw allow 5000                              # Permite Backend API
ufw allow 12345                             # Permite Alloy UI (Cenário 2)
check_status "Configuração do firewall"

# =============================================================================
# FASE 8: VERIFICAÇÃO FINAL
# =============================================================================

echo "🔍 Verificando status dos serviços..."
# Verifica se serviços estão ativos e reporta status
systemctl is-active docker && echo "✅ Docker está rodando"

# =============================================================================
# FINALIZAÇÃO E INFORMAÇÕES DE ACESSO
# =============================================================================

echo "=== ✅ Configuração das aplicações instrumentadas concluída em $(date) ==="
echo ""
echo "🚀 Serviços instalados e configurados:"
echo "   - Frontend: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3001"
echo "   - Backend API: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):5000"
echo "   - Alloy UI (Cenário 2): http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):12345"
echo ""
echo "⚠️  PRÓXIMOS PASSOS MANUAIS:"
echo "   1. Obter IP privado da instância de observabilidade (Instância 1)"
echo "   2. Escolher um cenário (1 ou 2) no script"
echo "   3. Editar o script e descomentar o cenário escolhido"
echo "   4. Substituir IP_PRIVADO_INSTANCIA_1 pelo IP real da Instância 1"
echo "   5. Executar o cenário escolhido manualmente"
echo "   6. Testar aplicações: curl http://localhost:3001/api/users"
echo "   7. Verificar telemetria no Grafana (Instância 1)"
echo ""
echo "🔧 Comandos úteis:"
echo "   - Testar frontend: curl http://localhost:3001/health"
echo "   - Testar backend: curl http://localhost:5000/health"
echo "   - Listar usuários: curl http://localhost:3001/api/users"
echo "   - Listar produtos: curl http://localhost:3001/api/products"
echo "   - Criar pedido: curl -X POST http://localhost:3001/api/orders -H 'Content-Type: application/json' -d '{\"user_id\":1,\"total_amount\":99.99}'"
echo "   - Ver logs da stack: cd ~/repo/[cenario] && docker-compose logs -f"
echo "   - Status da stack: docker-compose ps"
echo "   - Verificar Alloy (Cenário 2): curl http://localhost:12345/metrics"
echo "   - Logs de instalação: sudo tail -f /var/log/user-data.log"

# =============================================================================
# INFORMAÇÕES IMPORTANTES PARA MANUTENÇÃO:
# =============================================================================
# 
# LOGS E TROUBLESHOOTING:
# - Log de execução: /var/log/user-data.log
# - Logs da stack: docker-compose logs
# - Logs específicos: docker-compose logs [service]
#
# ARQUIVOS DE CONFIGURAÇÃO:
# - Cenário 1: ~/repo/scenario-1-via-collector/docker-compose.yml
# - Cenário 2: ~/repo/scenario-2-via-alloy/docker-compose.yml
# - Cenário 2: ~/repo/scenario-2-via-alloy/alloy-config.alloy
# - Frontend: ~/repo/[cenario]/frontend/
# - Backend: ~/repo/[cenario]/backend/
#
# PORTAS UTILIZADAS:
# - 22: SSH
# - 3001: Frontend
# - 5000: Backend API
# - 5432: PostgreSQL
# - 6379: Redis
# - 12345: Alloy UI (Cenário 2)
#
# COMANDOS DE MANUTENÇÃO:
# - Reiniciar stack: docker-compose restart
# - Parar stack: docker-compose down
# - Iniciar stack: docker-compose up -d
# - Ver logs: docker-compose logs -f
# - Status: docker-compose ps
# - Rebuild serviços: docker-compose build
#
# CENÁRIOS DISPONÍVEIS:
# 1. Via OpenTelemetry Collector: Apps → OTel Collector → Backends
# 2. Via Grafana Alloy: Apps → Alloy (local) → Backends
#
# CONFIGURAÇÃO FINAL NECESSÁRIA:
# 1. Escolher cenário (1 ou 2)
# 2. Substituir IP_PRIVADO_INSTANCIA_1 pelo IP real
# 3. Executar cenário escolhido
# 4. Verificar telemetria no Grafana (Instância 1)
#
# ENDPOINTS DAS APLICAÇÕES:
# - GET /health: Health check (frontend e backend)
# - GET /api/users: Lista usuários (com cache Redis)
# - GET /api/products: Lista produtos (com cache Redis)
# - GET /api/orders: Lista pedidos
# - POST /api/orders: Cria novo pedido (operação complexa com traces)
# =============================================================================
