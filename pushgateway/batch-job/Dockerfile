# =============================================================================
# DOCKERFILE - BATCH JOB APPLICATION
# =============================================================================
# Aplicação batch que simula processamento e envia métricas para Pushgateway
# =============================================================================

FROM python:3.11-alpine

# Metadados
LABEL maintainer="PosTech DevOps"
LABEL description="Batch job que envia métricas para Pushgateway"

# Diretório de trabalho
WORKDIR /app

# Instalar dependências
RUN pip install --no-cache-dir prometheus_client

# Copiar script da aplicação
COPY batch_job.py .

# Tornar executável
RUN chmod +x batch_job.py

# Comando padrão
CMD ["python", "batch_job.py"]
