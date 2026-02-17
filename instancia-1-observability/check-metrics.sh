#!/bin/bash

# Script para verificar métricas disponíveis no Prometheus
# Execute: bash check-metrics.sh

echo "========================================="
echo "Verificando métricas do Prometheus"
echo "========================================="
echo ""

PROMETHEUS_URL="http://localhost:9090"

echo "1. Verificando se há métricas HTTP disponíveis:"
echo "-------------------------------------------"
curl -s "${PROMETHEUS_URL}/api/v1/label/__name__/values" | jq -r '.data[]' | grep -i http | head -20
echo ""

echo "2. Verificando labels disponíveis para http_server_duration_milliseconds_count:"
echo "-------------------------------------------"
curl -s "${PROMETHEUS_URL}/api/v1/series?match[]=http_server_duration_milliseconds_count" | jq -r '.data[0]' 2>/dev/null
echo ""

echo "3. Verificando se há dados recentes (últimos 5 minutos):"
echo "-------------------------------------------"
QUERY="sum(rate(http_server_duration_milliseconds_count[5m]))"
curl -s -G "${PROMETHEUS_URL}/api/v1/query" --data-urlencode "query=${QUERY}" | jq -r '.data.result'
echo ""

echo "4. Verificando dados por service_name:"
echo "-------------------------------------------"
QUERY="sum(rate(http_server_duration_milliseconds_count[5m])) by (service_name)"
curl -s -G "${PROMETHEUS_URL}/api/v1/query" --data-urlencode "query=${QUERY}" | jq -r '.data.result'
echo ""

echo "5. Verificando dados por job:"
echo "-------------------------------------------"
QUERY="sum(rate(http_server_duration_milliseconds_count[5m])) by (job)"
curl -s -G "${PROMETHEUS_URL}/api/v1/query" --data-urlencode "query=${QUERY}" | jq -r '.data.result'
echo ""

echo "6. Verificando métricas do OTel Collector:"
echo "-------------------------------------------"
QUERY="sum(rate(otelcol_receiver_accepted_spans[5m]))"
curl -s -G "${PROMETHEUS_URL}/api/v1/query" --data-urlencode "query=${QUERY}" | jq -r '.data.result'
echo ""

echo "========================================="
echo "Verificação concluída!"
echo "========================================="
