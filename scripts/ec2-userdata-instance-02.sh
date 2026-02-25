#!/bin/bash

# =============================================================================
# EC2 USER DATA SCRIPT - INSTÂNCIA 2 (DOCKER ONLY)
# =============================================================================
# Script para configuração básica da Instância 2 - Aula 02 Prometheus
# Instala apenas Docker para posterior instalação manual dos exporters
# =============================================================================

export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

exec > >(tee /var/log/user-data.log) 2>&1
echo "=== Iniciando configuração da Instância 2 - Docker em $(date) ==="

# Função para verificar se comando foi executado com sucesso
check_status() {
    if [ $? -eq 0 ]; then
        echo "✅ $1 - Sucesso"
    else
        echo "❌ $1 - Falhou"
        exit 1
    fi
}

# Atualizar sistema
echo "📦 Atualizando sistema..."
apt-get update -y
check_status "Atualização do sistema"

# Instalar Docker
echo "🐳 Instalando Docker..."
apt-get install -y docker.io
check_status "Instalação do Docker"

# Configurar Docker
echo "🐳 Configurando Docker..."
systemctl start docker
systemctl enable docker
usermod -a -G docker ubuntu
check_status "Configuração do Docker"

# Verificar se Docker está funcionando
docker --version
check_status "Verificação do Docker"

# Instalar Docker Compose
echo "🐙 Instalando Docker Compose..."
DOCKER_COMPOSE_VERSION="v2.24.5"
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
check_status "Download do Docker Compose"

chmod +x /usr/local/bin/docker-compose
check_status "Permissões do Docker Compose"

# Criar link simbólico para compatibilidade
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Verificar instalação do Docker Compose
docker-compose --version
check_status "Verificação do Docker Compose"

# Finalizar
echo "=== ✅ Configuração da Instância 2 concluída com sucesso em $(date) ==="
echo ""
echo "🐳 DOCKER INSTALADO:"
echo "   • Docker version: $(docker --version)"
echo "   • Docker Compose version: $(docker-compose --version)"
echo "   • Status: $(systemctl is-active docker)"
echo ""
echo "🔧 PRÓXIMOS PASSOS:"
echo "   1. Clonar o repositório: git clone <URL_DO_REPO>"
echo "   2. Entrar no diretório: cd <nome-do-repo>"
echo "   3. Trocar para a branch correta: git checkout <branch>"
echo "   4. Subir cAdvisor e apps de teste: docker-compose -f docker-compose-cadvisor-test.yml up -d"
echo "   5. Instalar Node Exporter manualmente (porta 9100)"
echo "   6. Seguir o guia: docs/exporters-installation.md"
echo "   7. Configurar Security Groups para portas 9100 e 8080"