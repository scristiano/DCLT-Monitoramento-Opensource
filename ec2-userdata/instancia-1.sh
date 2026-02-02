#!/bin/bash

# =============================================================================
# EC2 USER DATA SCRIPT - OBSERVABILITY STACK INSTANCE
# =============================================================================
# Aula 06 - PosTech DevOps - Monitoramento OpenSource
# Stack: Grafana + Prometheus + Loki + Jaeger + OpenTelemetry Collector
# =============================================================================

# Configurações de ambiente
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Logs de execução
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== Iniciando configuração da demo em $(date) ==="

# Função de verificação
check_status() {
    if [ $? -eq 0 ]; then
        echo "✅ $1 - Sucesso"
    else
        echo "❌ $1 - Falhou"
        exit 1
    fi
}

# Atualização do sistema
echo "📦 Atualizando sistema..."
apt-get update -y
check_status "Atualização do sistema"

# Instalação de pacotes básicos
echo "📦 Instalando pacotes básicos..."
apt-get install -y git curl htop docker.io
check_status "Instalação de pacotes básicos"

# Configuração do Docker
echo "🐳 Configurando Docker..."
systemctl start docker
systemctl enable docker
usermod -a -G docker ubuntu
check_status "Configuração do Docker"

# Instalação do Docker Compose
echo "🐳 Instalando Docker Compose..."
curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-aarch64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
check_status "Instalação do Docker Compose"

# Instalação do Code-server
echo "💻 Instalando code-server..."
curl -fsSL https://code-server.dev/install.sh | sh
check_status "Instalação do code-server"

sleep 3
if [ ! -f /usr/bin/code-server ]; then
    echo "❌ Code-server não foi instalado corretamente"
    exit 1
fi

# Criação de usuário para code-server
echo "👤 Criando usuário dedicado para code-server..."
useradd -m -s /bin/bash -c "Code Server User" codeserver
usermod -a -G docker codeserver
check_status "Criação do usuário codeserver"

# Configuração do code-server
echo "⚙️ Configurando code-server..."
mkdir -p /home/codeserver/.config/code-server

cat > /home/codeserver/.config/code-server/config.yaml << 'EOF'
bind-addr: 0.0.0.0:8080
auth: password
password: demo123
cert: false
EOF

chown -R codeserver:codeserver /home/codeserver/.config
check_status "Configuração do code-server"

# Criação do serviço systemd
echo "🔧 Criando serviço systemd..."
cat > /etc/systemd/system/code-server.service << 'EOF'
[Unit]
Description=Code Server - VS Code in Browser
After=network.target

[Service]
Type=simple
User=codeserver
Group=codeserver
WorkingDirectory=/home/codeserver
Environment=HOME=/home/codeserver
Environment=XDG_CONFIG_HOME=/home/codeserver/.config
Environment=XDG_DATA_HOME=/home/codeserver/.local/share
ExecStart=/usr/bin/code-server --config /home/codeserver/.config/code-server/config.yaml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Inicialização do code-server
echo "🚀 Iniciando code-server..."
systemctl daemon-reload
systemctl enable code-server
systemctl start code-server
check_status "Inicialização do code-server"

# Configuração do firewall
echo "🔥 Configurando firewall..."
ufw --force enable
ufw allow ssh
ufw allow 3000                              # Grafana
ufw allow 9090                              # Prometheus
ufw allow 3100                              # Loki
ufw allow 16686                             # Jaeger UI
ufw allow 4317                              # OTLP gRPC
ufw allow 4318                              # OTLP HTTP
ufw allow 4319                              # OTel Collector HTTP
ufw allow 8080                              # Code-server
check_status "Configuração do firewall"

# Verificação final
echo "🔍 Verificando status dos serviços..."
systemctl is-active docker && echo "✅ Docker está rodando"
systemctl is-active code-server && echo "✅ Code-server está rodando"

# Finalização
echo "=== ✅ Configuração concluída com sucesso em $(date) ==="
echo ""
echo "🎯 AULA 06 - STACK DE OBSERVABILIDADE COM OPENTELEMETRY PREPARADA"
echo "=================================================================="
echo "🌐 Code-server disponível em: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "🔑 Senha: demo123"
echo ""
echo "📊 PRÓXIMOS PASSOS PARA AULA 06:"
echo "1. Clonar repositório: git clone -b aula-06 https://github.com/Ed-Carlos-Marinho/PosTech-DevOps-e-Arquitetura-Cloud---Monitoramento-OpenSource.git"
echo "2. Executar stack de observabilidade: cd instancia-1-observability && docker-compose up -d"
echo "3. Acessar interfaces:"
echo "   - Grafana: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000 (admin/admin123)"
echo "   - Prometheus: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9090"
echo "   - Loki: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3100"
echo "   - Jaeger UI: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):16686"
echo ""
echo "📝 IP PRIVADO DESTA INSTÂNCIA (use na Instância 2):"
echo "   $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
echo ""
echo "🐳 Docker e Docker Compose instalados e configurados"
echo "🔧 Sistema pronto para OpenTelemetry e telemetria unificada"

# =============================================================================
# INFORMAÇÕES IMPORTANTES:
# 
# STACK DE OBSERVABILIDADE: 
# - Grafana (3000): Visualização unificada
# - Prometheus (9090): Métricas
# - Loki (3100): Logs
# - Jaeger (16686): Traces distribuídos
# - OpenTelemetry Collector (4319): Pipeline central
# 
# CODE-SERVER: http://IP:8080 (senha: demo123)
# 
# DATA SOURCES NO GRAFANA (pré-configurados):
# - Prometheus: http://prometheus:9090
# - Loki: http://loki:3100
# - Jaeger: http://jaeger:16686
#
# COMANDOS ÚTEIS:
# - Logs: sudo tail -f /var/log/user-data.log
# - Status: systemctl status code-server
# - Docker: cd instancia-1-observability && docker-compose ps
# - Restart: systemctl restart code-server
# - Ver logs da stack: docker-compose logs -f
# =============================================================================
