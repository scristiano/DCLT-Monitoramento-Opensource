#!/usr/bin/env python3
# =============================================================================
# BATCH JOB APPLICATION
# =============================================================================
# Simula uma aplicação batch que:
# 1. Processa dados (simulado com sleep)
# 2. Gera métricas de execução
# 3. Envia métricas para o Pushgateway usando prometheus_client
# =============================================================================

import os
import time
import random
from datetime import datetime
from prometheus_client import CollectorRegistry, Gauge, push_to_gateway

# Configurações
PUSHGATEWAY_URL = os.getenv('PUSHGATEWAY_URL', 'pushgateway:9091')
JOB_NAME = os.getenv('JOB_NAME', 'batch_processing_job')
INSTANCE_NAME = os.getenv('INSTANCE_NAME', 'batch-job-instance')

def simulate_batch_processing():
    """
    Simula processamento batch com duração variável
    Retorna: (duration, records_processed, status)
    """
    print(f"[{datetime.now()}] Iniciando processamento batch...")
    
    start_time = time.time()
    
    # Simula processamento (3 a 10 segundos)
    processing_time = random.uniform(3, 10)
    time.sleep(processing_time)
    
    # Simula número de registros processados
    records_processed = random.randint(100, 1000)
    
    # Simula sucesso/falha (95% de sucesso)
    status = 1 if random.random() > 0.05 else 0
    
    duration = time.time() - start_time
    
    print(f"[{datetime.now()}] Processamento concluído:")
    print(f"  - Duração: {duration:.2f}s")
    print(f"  - Registros processados: {records_processed}")
    print(f"  - Status: {'SUCESSO' if status == 1 else 'FALHA'}")
    
    return duration, records_processed, status

def send_metrics_to_pushgateway(duration, records_processed, status):
    """
    Envia métricas para o Pushgateway usando prometheus_client
    """
    try:
        print(f"[{datetime.now()}] Enviando métricas para {PUSHGATEWAY_URL}...")
        
        # Criar registry para as métricas
        registry = CollectorRegistry()
        
        # Definir métricas
        duration_metric = Gauge(
            'batch_job_duration_seconds',
            'Duração da execução do batch job em segundos',
            registry=registry
        )
        
        records_metric = Gauge(
            'batch_job_records_processed',
            'Número de registros processados',
            registry=registry
        )
        
        status_metric = Gauge(
            'batch_job_status',
            'Status da execução (1=sucesso, 0=falha)',
            registry=registry
        )
        
        timestamp_metric = Gauge(
            'batch_job_last_success_timestamp',
            'Timestamp da última execução bem-sucedida',
            registry=registry
        )
        
        # Definir valores das métricas
        duration_metric.set(duration)
        records_metric.set(records_processed)
        status_metric.set(status)
        timestamp_metric.set(int(time.time()) if status == 1 else 0)
        
        # Enviar para o Pushgateway
        push_to_gateway(
            PUSHGATEWAY_URL,
            job=JOB_NAME,
            registry=registry,
            grouping_key={'instance': INSTANCE_NAME}
        )
        
        print(f"[{datetime.now()}] ✅ Métricas enviadas com sucesso!")
        
    except Exception as e:
        print(f"[{datetime.now()}] ❌ Erro ao enviar métricas: {e}")
        raise

def main():
    """
    Função principal do batch job
    """
    print("=" * 80)
    print(f"BATCH JOB - {JOB_NAME}")
    print(f"Iniciado em: {datetime.now()}")
    print("=" * 80)
    
    try:
        # Executa processamento batch
        duration, records_processed, status = simulate_batch_processing()
        
        # Envia métricas para Pushgateway
        send_metrics_to_pushgateway(duration, records_processed, status)
        
        print("=" * 80)
        print(f"BATCH JOB FINALIZADO - {datetime.now()}")
        print("=" * 80)
        
        # Retorna código de saída baseado no status
        exit(0 if status == 1 else 1)
        
    except Exception as e:
        print(f"[{datetime.now()}] ❌ ERRO CRÍTICO: {e}")
        exit(1)

if __name__ == "__main__":
    main()
