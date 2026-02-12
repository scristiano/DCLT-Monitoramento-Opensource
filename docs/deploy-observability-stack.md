# Deploy da Stack de Observabilidade - Passo a Passo

Guia completo para implementar a stack de observabilidade no Kubernetes usando Helm com SSL/TLS automático via Let's Encrypt.

## Arquitetura da Stack

```
┌─────────────────────────────────────────────────────────────────┐
│                    EKS CLUSTER                                  │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   MONITORING    │  │   CERT-MANAGER  │  │   INGRESS-NGINX │ │
│  │   NAMESPACE     │  │   NAMESPACE     │  │   NAMESPACE     │ │
│  │                 │  │                 │  │                 │ │
│  │ • Prometheus    │  │ • cert-manager  │  │ • Ingress       │ │
│  │ • Grafana       │  │ • ClusterIssuer │  │   Controller    │ │
│  │ • Node Exporter │  │ • Let's Encrypt │  │ • NLB           │ │
│  │ • Loki          │  │                 │  │                 │ │
│  │ • Promtail      │  │                 │  │                 │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Pré-requisitos

### 1. Cluster EKS Criado
```bash
# Executar script de criação do cluster
./scripts/create-eks-cluster.sh

# Verificar se o cluster está funcionando
kubectl get nodes
kubectl cluster-info

# Verificar add-ons AWS
aws eks list-addons --cluster-name observability-lab-cluster
```

### 2. Helm Instalado
```bash
# Verificar versão do Helm
helm version

# Se não estiver instalado
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 3. Repositórios Helm Necessários
```bash
# Adicionar repositórios
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io

# Atualizar repositórios
helm repo update

# Verificar repositórios
helm repo list
```

## Passo 1: Instalar Ingress NGINX Controller

O Ingress Controller permite expor serviços HTTP/HTTPS com roteamento avançado e Load Balancer da AWS.

```bash
# Instalar Ingress NGINX
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --values helm-values/ingress-nginx/values.yaml \
  --wait \
  --timeout 10m

# Verificar instalação
kubectl get pods -n ingress-nginx

# Verificar LoadBalancer (aguardar External IP)
kubectl get svc -n ingress-nginx ingress-nginx-controller -w
```

**Configurações importantes:**
- **Service Type**: LoadBalancer com Network Load Balancer (NLB) da AWS
- **Métricas**: Habilitadas para Prometheus
- **Logs**: Formato JSON estruturado para observabilidade
- **Recursos**: Otimizados (CPU: 100m-200m, Memory: 90Mi-256Mi)
- **Réplicas**: 2 para alta disponibilidade

## Passo 2: Instalar cert-manager

O cert-manager automatiza a criação e renovação de certificados SSL/TLS via Let's Encrypt.

```bash
# Instalar cert-manager
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --values helm-values/cert-manager/values.yaml \
  --wait \
  --timeout 10m

# Verificar instalação
kubectl get pods -n cert-manager

# Aplicar ClusterIssuers
kubectl apply -f helm-values/cert-manager/cluster-issuer.yaml

# Verificar ClusterIssuers
kubectl get clusterissuer
```

**Componentes instalados:**
- **cert-manager**: Controller principal
- **cert-manager-webhook**: Validação de recursos
- **cert-manager-cainjector**: Injeção de CA
- **ClusterIssuer**: Configuração para Let's Encrypt (prod e staging)

## Passo 3: Instalar kube-prometheus-stack

Esta é a peça central da observabilidade, incluindo Prometheus, Grafana com SSL automático.

```bash
# Instalar kube-prometheus-stack
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values helm-values/kube-prometheus-stack/values.yaml \
  --wait \
  --timeout 15m

# Verificar instalação
kubectl get pods -n monitoring

# Verificar Ingresses e certificados
kubectl get ingress -n monitoring
kubectl get certificates -n monitoring
```

**Componentes instalados:**
- **Prometheus**: Coleta de métricas com retenção de 7 dias
- **Grafana**: Interface de visualização com SSL (admin/admin123)
- **Node Exporter**: Métricas dos nodes (DaemonSet)
- **Kube State Metrics**: Métricas dos recursos Kubernetes
- **Prometheus Operator**: Gerenciamento declarativo

**Configurações importantes:**
- **Ingress**: Desabilitado (será criado via Ingress centralizado)
- **Domínios**: grafana.demo.lynxnetwork.com.br e prometheus.demo.lynxnetwork.com.br
- **Storage**: Volumes persistentes (Prometheus: 20GB, Grafana: 10GB)
- **Datasource Loki**: Pré-configurado para integração

## Passo 4: Criar Ingress Centralizado com ALB

Após instalar o kube-prometheus-stack, crie o Ingress centralizado que expõe Grafana e Prometheus através de um único ALB.

```bash
# Aplicar Ingress centralizado
kubectl apply -f kubernetes/eks-lab-ingress.yaml

# Verificar Ingress criado
kubectl get ingress -n monitoring

# Aguardar ALB ser provisionado (pode levar 2-3 minutos)
kubectl get ingress -n monitoring eks-lab-ingress -w
```

**O que o Ingress faz:**
- Cria um único ALB chamado `eks-lab-alb`
- Configura HTTPS com certificado ACM
- Redireciona HTTP para HTTPS automaticamente
- Roteia tráfego baseado em hostname:
  - `grafana.demo.lynxnetwork.com.br` → Grafana
  - `prometheus.demo.lynxnetwork.com.br` → Prometheus

**Verificar ALB criado:**
```bash
# Obter endereço do ALB
kubectl get ingress -n monitoring eks-lab-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Verificar no Console AWS
# EC2 → Load Balancers → Procurar por "eks-lab-alb"
```

## Passo 5: Instalar Loki Stack (SimpleScalable Mode)

Loki fornece agregação de logs escalável para Kubernetes usando storage S3.

### 5.1 Configurar S3 e Permissões IAM

Antes de instalar o Loki, é necessário criar buckets S3 e configurar permissões IAM.

#### Opção 1: Via Script (Recomendado)

O script `scripts/setup-eks.sh` já cria automaticamente todos os recursos necessários:

```bash
# Executar script de setup (se ainda não executou)
./scripts/setup-eks.sh

# O script irá:
# ✅ Criar OIDC Provider (se não existir)
# ✅ Criar 3 buckets S3 com versionamento (nomes incluem Account ID para unicidade global)
#    • loki-observability-lab-chunks-ACCOUNT_ID
#    • loki-observability-lab-ruler-ACCOUNT_ID
#    • loki-observability-lab-admin-ACCOUNT_ID
# ✅ Criar IAM Policy LokiS3AccessPolicy
# ✅ Criar IAM Role LokiS3AccessRole com IRSA
# ✅ Atualizar helm-values/loki-stack/values.yaml com ARN da role e nomes dos buckets
```

Após executar o script, pule para a seção **5.2 Instalar Loki**.

#### Opção 2: Via Console AWS (Manual)

**Passo 1: Criar Buckets S3**

1. **S3 Console** → **Buckets** → **Create bucket**

2. Criar 3 buckets com as seguintes configurações (substituir `ACCOUNT_ID` pelo seu Account ID obtido via `aws sts get-caller-identity --query Account --output text`):

   **Bucket 1: Chunks (dados de logs)**
   - **Bucket name**: `loki-observability-lab-chunks-ACCOUNT_ID`
   - **AWS Region**: `us-east-1`
   - **Block Public Access**: Manter todas as opções marcadas (bloquear acesso público)
   - **Bucket Versioning**: Enable
   - **Tags** (opcional):
     - Key: `Project`, Value: `observability-lab`
     - Key: `Component`, Value: `loki-chunks`
   - **Create bucket**

   **Bucket 2: Ruler (regras de alertas)**
   - **Bucket name**: `loki-observability-lab-ruler-ACCOUNT_ID`
   - **AWS Region**: `us-east-1`
   - Mesmas configurações do Bucket 1
   - **Tags**: Component: `loki-ruler`

   **Bucket 3: Admin (dados administrativos)**
   - **Bucket name**: `loki-observability-lab-admin-ACCOUNT_ID`
   - **AWS Region**: `us-east-1`
   - Mesmas configurações do Bucket 1
   - **Tags**: Component: `loki-admin`

3. **Configurar Lifecycle Policy** (opcional, para economizar custos):
   
   Para cada bucket:
   - Abrir o bucket → **Management** → **Create lifecycle rule**
   - **Lifecycle rule name**: `DeleteOldObjects`
   - **Rule scope**: Apply to all objects in the bucket
   - **Lifecycle rule actions**:
     - ✅ Expire current versions of objects: `30 days`
     - ✅ Permanently delete noncurrent versions of objects: `7 days`
   - **Create rule**

**Passo 2: Criar IAM Policy**

1. **IAM Console** → **Policies** → **Create policy**

2. **JSON** tab, colar o conteúdo ajustando os nomes dos buckets com seu Account ID:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowListBuckets",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": [
                "arn:aws:s3:::loki-observability-lab-chunks-ACCOUNT_ID",
                "arn:aws:s3:::loki-observability-lab-ruler-ACCOUNT_ID",
                "arn:aws:s3:::loki-observability-lab-admin-ACCOUNT_ID"
            ]
        },
        {
            "Sid": "AllowObjectOperations",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::loki-observability-lab-chunks-ACCOUNT_ID/*",
                "arn:aws:s3:::loki-observability-lab-ruler-ACCOUNT_ID/*",
                "arn:aws:s3:::loki-observability-lab-admin-ACCOUNT_ID/*"
            ]
        }
    ]
}
```

**Nota:** Substitua `ACCOUNT_ID` pelo seu Account ID em todos os lugares. Você pode obter seu Account ID com:

```bash
aws sts get-caller-identity --query Account --output text
```

3. **Next: Tags** (opcional)
4. **Next: Review**
5. **Policy name**: `LokiS3AccessPolicy`
6. **Description**: `Policy for Loki to access S3 buckets for log storage`
7. **Create policy**

**Passo 3: Obter OIDC Provider ID do Cluster**

Antes de criar a role, você precisa do OIDC Provider ID:

```bash
# Obter OIDC Provider URL
aws eks describe-cluster \
  --name observability-lab-cluster \
  --region us-east-1 \
  --query "cluster.identity.oidc.issuer" \
  --output text

# Resultado será algo como:
# https://oidc.eks.us-east-1.amazonaws.com/id/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
# Copie apenas o ID (últimos 32 caracteres)
```

**Passo 4: Criar IAM Role com IRSA (IAM Roles for Service Accounts)**

1. **IAM Console** → **Roles** → **Create role**

2. **Trusted entity type**: Web identity

3. **Web identity**:
   - **Identity provider**: Selecionar o OIDC provider do seu cluster EKS
     - Formato: `oidc.eks.us-east-1.amazonaws.com/id/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`
     - Se não aparecer na lista, você precisa criar o OIDC provider primeiro (ver Passo 5)
   - **Audience**: `sts.amazonaws.com`

4. **Add permissions**:
   - Buscar e selecionar: `LokiS3AccessPolicy`

5. **Role name**: `LokiS3AccessRole`

6. **Description**: `Role for Loki ServiceAccount to access S3 buckets`

7. **Create role**

8. **Editar Trust Relationship** (IMPORTANTE):
   - Abrir a role criada → **Trust relationships** → **Edit trust policy**
   - Usar o template `kubernetes/loki-trust-policy-template.json` como base
   - Substituir `OIDC_ID` (aparece 3 vezes) pelo ID do OIDC provider obtido no Passo 3:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/OIDC_ID"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "oidc.eks.us-east-1.amazonaws.com/id/OIDC_ID:sub": "system:serviceaccount:monitoring:loki",
                    "oidc.eks.us-east-1.amazonaws.com/id/OIDC_ID:aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}
```

   - **Update policy**

9. **Copiar o ARN da Role** (você vai precisar no próximo passo):
   - Formato: `arn:aws:iam::ACCOUNT_ID:role/LokiS3AccessRole`
   - Substitua `ACCOUNT_ID` pelo seu Account ID real

**Passo 5: Criar OIDC Provider (se não existir)**

Se o OIDC provider não apareceu no Passo 4:

**Opção A: Via Console AWS**

1. **IAM Console** → **Identity providers** → **Add provider**

2. **Provider type**: OpenID Connect

3. **Provider URL**: 
   - Usar o URL obtido no Passo 3
   - Formato: `https://oidc.eks.us-east-1.amazonaws.com/id/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`

4. **Audience**: `sts.amazonaws.com`

5. **Add provider**

**Opção B: Via AWS CLI**

```bash
# Obter OIDC Issuer URL
OIDC_URL=$(aws eks describe-cluster \
  --name observability-lab-cluster \
  --region us-east-1 \
  --query "cluster.identity.oidc.issuer" \
  --output text)

# Criar OIDC Provider
aws iam create-open-id-connect-provider \
  --url $OIDC_URL \
  --client-id-list sts.amazonaws.com \
  --region us-east-1
```

Após criar o OIDC provider, volte ao Passo 4 para criar a role.

**Passo 6: Atualizar values.yaml com Role ARN**

⚠️ **IMPORTANTE**: O script `setup-eks.sh` já faz isso automaticamente! Você só precisa executar:

```bash
./scripts/setup-eks.sh
```

O script irá:
- ✅ Obter automaticamente seu Account ID
- ✅ Criar buckets S3 com nomes únicos (incluindo Account ID)
- ✅ Criar IAM Policy e Role
- ✅ Atualizar `helm-values/loki-stack/values.yaml` com os valores corretos

Se você criou a role manualmente e precisa atualizar o values.yaml, o formato será:

```yaml
serviceAccount:
  create: true
  name: loki
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::SEU_ACCOUNT_ID:role/LokiS3AccessRole
```

**Nota:** Substitua `SEU_ACCOUNT_ID` pelo seu Account ID real. O script faz isso automaticamente.

### 5.2 Instalar Loki

```bash
# Instalar Loki em modo SimpleScalable
helm upgrade --install loki grafana/loki \
  --namespace monitoring \
  --values helm-values/loki-stack/values.yaml \
  --wait \
  --timeout 10m

# Verificar instalação
kubectl get pods -n monitoring -l app.kubernetes.io/name=loki

# Verificar componentes
kubectl get pods -n monitoring | grep loki
```

**Componentes instalados (SimpleScalable):**
- **Loki Read** (2 réplicas): Componente de query/leitura
- **Loki Write** (2 réplicas): Componente de ingestão/escrita
- **Loki Gateway** (1 réplica): Gateway HTTP para roteamento

### 5.3 Instalar Promtail

```bash
# Instalar Promtail (agente de coleta de logs)
helm upgrade --install promtail grafana/promtail \
  --namespace monitoring \
  --values helm-values/loki-stack/promtail-values.yaml \
  --wait \
  --timeout 10m

# Verificar instalação (deve ter 1 pod por node)
kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail -o wide

# Verificar logs do Promtail
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail --tail=50
```

**Configurações importantes:**
- **Modo**: SimpleScalable (escalável horizontalmente)
- **Storage**: S3 (durável e escalável) para dados de logs
- **Volumes locais (EBS)**:
  - Write: 2GB para WAL (Write-Ahead Log) - buffer temporário antes de enviar ao S3
  - Backend: 5GB para Compactor working directory - índices e compactação temporária
  - Total: ~9GB de EBS (volumes temporários, dados permanentes ficam no S3)
- **Recursos**: 
  - Read: 256Mi-512Mi RAM, 100m-200m CPU
  - Write: 512Mi-1Gi RAM, 200m-400m CPU
  - Backend: 256Mi-512Mi RAM, 100m-200m CPU
  - Promtail: 64Mi-128Mi RAM, 25m-50m CPU
- **Retenção**: 7 dias de logs
- **Coleta automática**: Logs de todos os pods Kubernetes via Promtail (DaemonSet)
- **Integração**: Datasource pré-configurado no Grafana

### 5.4 Verificar Integração com Grafana

```bash
# Verificar se o datasource Loki está configurado no Grafana
kubectl exec -n monitoring deployment/kube-prometheus-stack-grafana -- \
  curl -s http://localhost:3000/api/datasources | jq '.[] | select(.type=="loki")'

# Acessar Grafana e testar
# 1. Abrir https://grafana.demo.lynxnetwork.com.br
# 2. Ir em Explore
# 3. Selecionar datasource "Loki"
# 4. Executar query: {namespace="monitoring"}
```

**Vantagens do SimpleScalable vs SingleBinary:**
- ✅ Escalável horizontalmente (pode aumentar réplicas)
- ✅ Storage durável em S3 (não perde dados)
- ✅ Melhor performance para alto volume de logs
- ✅ Separação de componentes (read/write/backend)
- ✅ Adequado para produção

**Por que o Loki usa volumes EBS mesmo com S3?**
- **WAL (Write-Ahead Log)**: Buffer local para garantir durabilidade antes de enviar ao S3
- **Compactor**: Precisa de espaço temporário para compactar e indexar dados
- **Dados permanentes**: Ficam no S3 (buckets configurados)
- **Volumes EBS**: Apenas para dados temporários e cache

## Passo 6: Configurar DNS

Para acessar via domínios personalizados, configure os registros DNS:

```bash
# Obter hostname do Load Balancer
LOAD_BALANCER=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Load Balancer: $LOAD_BALANCER"
```

**Registros DNS necessários:**
```
grafana.demo.lynxnetwork.com.br     CNAME   <LOAD_BALANCER_HOSTNAME>
prometheus.demo.lynxnetwork.com.br  CNAME   <LOAD_BALANCER_HOSTNAME>
```

## Verificação da Instalação

### 1. Verificar Todos os Pods
```bash
# Pods de monitoramento
kubectl get pods -n monitoring

# Pods do ingress
kubectl get pods -n ingress-nginx

# Pods do cert-manager
kubectl get pods -n cert-manager
```

### 2. Verificar Certificados SSL
```bash
# Verificar certificados
kubectl get certificates -n monitoring

# Verificar secrets TLS
kubectl get secrets -n monitoring | grep tls

# Testar certificados
curl -I https://grafana.demo.lynxnetwork.com.br
curl -I https://prometheus.demo.lynxnetwork.com.br
```

### 3. Verificar ServiceMonitors
```bash
# Listar ServiceMonitors
kubectl get servicemonitor -n monitoring

# Verificar targets no Prometheus
# Acessar: https://prometheus.demo.lynxnetwork.com.br/targets
```

## Acessar as Interfaces

### 1. Grafana (HTTPS com SSL)
```bash
# URL: https://grafana.demo.lynxnetwork.com.br
# Credenciais: admin / admin123
```

**Datasources pré-configurados:**
- **Prometheus**: Métricas do cluster
- **Loki**: Logs agregados

### 2. Prometheus (HTTPS com SSL)
```bash
# URL: https://prometheus.demo.lynxnetwork.com.br
```

## Dashboards Disponíveis

O kube-prometheus-stack inclui 27+ dashboards automáticos:

### Dashboards Kubernetes
- **Kubernetes / Compute Resources / Cluster**
- **Kubernetes / Compute Resources / Namespace (Pods)**
- **Kubernetes / Compute Resources / Node (Pods)**
- **Kubernetes / Compute Resources / Pod**

### Dashboards de Infraestrutura
- **Node Exporter / Nodes**
- **Prometheus / Overview**
- **Grafana / Overview**

### Dashboards de Rede
- **Kubernetes / Networking / Cluster**
- **Kubernetes / Networking / Namespace (Pods)**

## Testar a Stack de Observabilidade

### 1. Verificar Métricas
```bash
# Métricas de nodes
kubectl top nodes

# Métricas de pods
kubectl top pods -A

# Acessar Prometheus
open https://prometheus.demo.lynxnetwork.com.br
```

### 2. Verificar Logs
```bash
# Logs do Loki
kubectl logs -n monitoring loki-0

# Logs do Promtail
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail

# Acessar Grafana → Explore → Loki
# Consulta exemplo: {namespace="kube-system"}
```

### 3. Verificar SSL/TLS
```bash
# Testar certificados
openssl s_client -connect grafana.demo.lynxnetwork.com.br:443 -servername grafana.demo.lynxnetwork.com.br

# Verificar redirecionamento HTTPS
curl -I http://grafana.demo.lynxnetwork.com.br
```

## Troubleshooting

### Problema: Certificados não são criados
```bash
# Verificar cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Verificar challenges
kubectl get challenges -A

# Verificar orders
kubectl get orders -A

# Verificar ClusterIssuer
kubectl describe clusterissuer letsencrypt-prod
```

### Problema: Pods em Pending (Recursos Insuficientes)
```bash
# Verificar eventos
kubectl get events -n monitoring --sort-by='.lastTimestamp'

# Verificar recursos dos nodes
kubectl describe nodes

# Reduzir recursos nos values files se necessário
```

### Problema: Loki não recebe logs
```bash
# Verificar Promtail
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail

# Verificar conectividade
kubectl exec -n monitoring -l app.kubernetes.io/name=promtail -- nslookup loki.monitoring.svc.cluster.local

# Testar endpoint do Loki
kubectl exec -n monitoring loki-0 -- wget -qO- http://localhost:3100/ready
```

### Problema: Grafana não carrega dashboards
```bash
# Verificar sidecar
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -c grafana-sc-dashboard

# Verificar ConfigMaps de dashboards
kubectl get configmaps -n monitoring -l grafana_dashboard=1
```

## Comandos Úteis

### Helm
```bash
# Listar releases
helm list -A

# Status de um release
helm status kube-prometheus-stack -n monitoring

# Upgrade de um release
helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f helm-values/kube-prometheus-stack/values.yaml

# Rollback
helm rollback kube-prometheus-stack 1 -n monitoring
```

### Certificados
```bash
# Forçar renovação de certificado
kubectl delete certificate grafana-demo-lynxnetwork-tls -n monitoring

# Verificar logs do cert-manager
kubectl logs -n cert-manager deployment/cert-manager -f
```

### Loki
```bash
# Testar API do Loki
kubectl port-forward -n monitoring svc/loki 3100:3100
curl http://localhost:3100/ready

# Consultar logs via API
curl "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={namespace="monitoring"}' \
  --data-urlencode 'start=1h' | jq
```

## Estrutura de Arquivos

```
helm-values/
├── cert-manager/
│   ├── values.yaml           # Configuração do cert-manager
│   └── cluster-issuer.yaml   # ClusterIssuers Let's Encrypt
├── ingress-nginx/
│   └── values.yaml           # Configuração do Ingress Controller
├── kube-prometheus-stack/
│   └── values.yaml           # Prometheus + Grafana com Ingress SSL
└── loki-stack/
    ├── values.yaml           # Configuração do Loki
    └── promtail-values.yaml  # Configuração do Promtail
```

## Resumo dos Recursos Criados

| Componente | Namespace | Acesso | URL |
|------------|-----------|---------|-----|
| Grafana | monitoring | HTTPS | https://grafana.demo.lynxnetwork.com.br |
| Prometheus | monitoring | HTTPS | https://prometheus.demo.lynxnetwork.com.br |
| Loki | monitoring | Interno | http://loki.monitoring.svc.cluster.local:3100 |
| cert-manager | cert-manager | Interno | - |
| Ingress NGINX | ingress-nginx | Load Balancer | NLB da AWS |

## Estimativa de Recursos (Otimizada)

| Componente | CPU Request | Memory Request | Storage |
|------------|-------------|----------------|---------|
| Prometheus | 500m | 1Gi | 20Gi (EBS) |
| Grafana | 100m | 256Mi | 10Gi (EBS) |
| Loki Read | 100m × 2 | 256Mi × 2 | - |
| Loki Write | 200m × 2 | 512Mi × 2 | 2Gi × 2 (EBS WAL) |
| Loki Backend | 100m | 256Mi | 5Gi (EBS) |
| Loki Gateway | 25m | 64Mi | - |
| Loki S3 | - | - | Ilimitado (S3) |
| Promtail | 25m × 3 | 64Mi × 3 | - |
| cert-manager | 10m × 3 | 32Mi × 3 | - |
| Ingress NGINX | 100m × 2 | 90Mi × 2 | - |
| **Total** | **~1.5 CPU** | **~3Gi** | **~39Gi EBS + S3** |

**Nota sobre Storage:**
- **EBS (39GB)**: Volumes locais para Prometheus, Grafana, WAL do Loki e Compactor
- **S3 (Ilimitado)**: Armazenamento permanente de logs do Loki (pay-as-you-go)

## Próximos Passos

Após a instalação completa:

1. **Configurar DNS** nos seus provedores
2. **Explorar Dashboards** no Grafana
3. **Criar Alertas Customizados**
4. **Monitorar Aplicações** com ServiceMonitors
5. **Analisar Logs** com Loki no Grafana

A stack está otimizada para ambientes de laboratório com SSL automático e pode ser facilmente escalada para produção ajustando os resources nos values files.