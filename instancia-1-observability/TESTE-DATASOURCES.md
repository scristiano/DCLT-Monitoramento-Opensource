# Guia de Teste - Datasources Automáticos do Grafana

Este guia mostra como verificar se os datasources foram criados automaticamente.

## 🚀 Passo 1: Iniciar Stack

```bash
cd instancia-1-observability

# Parar e remover volumes antigos (se existirem)
docker compose down -v

# Iniciar stack
docker compose up -d

# Aguardar serviços iniciarem (30 segundos)
sleep 30

# Verificar status
docker compose ps
```

## ✅ Passo 2: Verificar Datasources

### Via Interface Web

1. Acesse o Grafana: http://IP_INSTANCIA_1 (porta 80)
2. Login:
   - Usuário: `admin`
   - Senha: `admin123`
3. Menu lateral → **Connections** → **Data sources**
4. Você deve ver 4 datasources:
   - ✅ Prometheus (default)
   - ✅ Loki
   - ✅ Jaeger
   - ✅ Alertmanager

### Via API

```bash
# Listar todos os datasources
curl -u admin:admin123 http://localhost/api/datasources | jq .

# Verificar Prometheus
curl -u admin:admin123 http://localhost/api/datasources/name/Prometheus | jq .

# Verificar Loki
curl -u admin:admin123 http://localhost/api/datasources/name/Loki | jq .

# Verificar Jaeger
curl -u admin:admin123 http://localhost/api/datasources/name/Jaeger | jq .

# Verificar Alertmanager
curl -u admin:admin123 http://localhost/api/datasources/name/Alertmanager | jq .
```

## 🔍 Passo 3: Testar Datasources

### Testar Prometheus

1. No Grafana, vá em **Explore**
2. Selecione datasource: **Prometheus**
3. Execute query:
```promql
up
```
4. Deve mostrar os targets do Prometheus

### Testar Loki

1. No Grafana, vá em **Explore**
2. Selecione datasource: **Loki**
3. Execute query:
```logql
{job="varlogs"}
```
4. Deve mostrar logs (pode estar vazio se não houver aplicações enviando logs ainda)

### Testar Jaeger

1. No Grafana, vá em **Explore**
2. Selecione datasource: **Jaeger**
3. Clique em **Search**
4. Deve mostrar interface de busca de traces (pode estar vazio se não houver aplicações enviando traces ainda)

### Testar Alertmanager

1. No Grafana, vá em **Alerting** → **Alertmanager**
2. Deve mostrar o Alertmanager conectado

## 🔗 Passo 4: Verificar Correlação

### Prometheus → Jaeger (via Exemplars)

Após ter traces sendo gerados:

1. No Grafana, vá em **Explore**
2. Selecione datasource: **Prometheus**
3. Execute query:
```promql
rate(http_server_duration_milliseconds_count[5m])
```
4. Clique em um ponto no gráfico
5. Deve aparecer opção "View trace" para ver o trace relacionado

### Jaeger → Loki (via Trace ID)

Após ter traces e logs:

1. No Grafana, vá em **Explore**
2. Selecione datasource: **Jaeger**
3. Busque um trace
4. Clique em um span
5. Deve aparecer botão "Logs for this span"

### Jaeger → Prometheus (via Tags)

1. No Grafana, vá em **Explore**
2. Selecione datasource: **Jaeger**
3. Busque um trace
4. Clique em "Trace to metrics"
5. Deve mostrar métricas relacionadas ao trace

## 🐛 Troubleshooting

### Datasources não aparecem

```bash
# Verificar logs do Grafana
docker compose logs grafana | grep -i datasource

# Verificar se arquivo foi montado
docker exec grafana ls -la /etc/grafana/provisioning/datasources/

# Deve mostrar: datasources.yml
```

### Datasource com erro "Bad Gateway"

```bash
# Verificar conectividade entre containers
docker exec grafana ping -c 3 prometheus
docker exec grafana ping -c 3 loki
docker exec grafana ping -c 3 jaeger
docker exec grafana ping -c 3 alertmanager

# Verificar se serviços estão rodando
docker compose ps
```

### Datasource com erro "Timeout"

```bash
# Verificar se serviços estão respondendo
curl http://localhost:9090/-/healthy  # Prometheus
curl http://localhost:3100/ready      # Loki
curl http://localhost:16686/          # Jaeger
curl http://localhost:9093/-/healthy  # Alertmanager
```

### Recriar datasources do zero

```bash
# Parar stack
docker compose down

# Remover APENAS volume do Grafana
docker volume rm instancia-1-observability_grafana-data

# Reiniciar
docker compose up -d

# Aguardar 30 segundos
sleep 30

# Verificar datasources
curl -u admin:admin123 http://localhost/api/datasources | jq .
```

## 📊 Passo 5: Criar Dashboard de Teste

1. No Grafana, clique em **+** → **Create Dashboard**
2. Adicione um painel com query do Prometheus:
```promql
rate(http_server_duration_milliseconds_count[5m])
```
3. Adicione um painel com query do Loki:
```logql
{service_name="backend-service"}
```
4. Salve o dashboard

## ✅ Checklist de Verificação

- [ ] Grafana acessível em http://IP_INSTANCIA_1
- [ ] Login funciona (admin/admin123)
- [ ] 4 datasources aparecem em Connections → Data sources
- [ ] Prometheus datasource com status "Working"
- [ ] Loki datasource com status "Working"
- [ ] Jaeger datasource com status "Working"
- [ ] Alertmanager datasource com status "Working"
- [ ] Query no Prometheus retorna dados
- [ ] Interface do Jaeger carrega no Explore
- [ ] Interface do Loki carrega no Explore

## 🎯 Próximos Passos

Após verificar que os datasources estão funcionando:

1. Configure a Instância 2 com as aplicações (Cenário 1 ou 2)
2. Verifique se métricas, logs e traces aparecem no Grafana
3. Teste a correlação entre os três pilares da observabilidade
4. Configure alertas no Alertmanager (edite `alertmanager.yml`)

## 📚 Referências

- [Grafana Provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/)
- [Prometheus Data Source](https://grafana.com/docs/grafana/latest/datasources/prometheus/)
- [Loki Data Source](https://grafana.com/docs/grafana/latest/datasources/loki/)
- [Jaeger Data Source](https://grafana.com/docs/grafana/latest/datasources/jaeger/)
