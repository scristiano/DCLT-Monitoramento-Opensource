# Setup do Laboratório EKS - Observabilidade no Kubernetes

Guia completo para configurar o ambiente de laboratório da Aula 07, incluindo criação do cluster EKS com Auto Mode e instância EC2 bastion.

## Índice

- [O que é EKS Auto Mode?](#o-que-é-eks-auto-mode)
  - [Versões Suportadas](#versões-suportadas)
  - [Vantagens do Auto Mode](#vantagens-do-auto-mode)
- [Arquitetura do Laboratório](#arquitetura-do-laboratório)
- [Pré-requisitos](#pré-requisitos)
- [Passo 1: Criar IAM Roles Necessárias](#passo-1-criar-iam-roles-necessárias)
  - [1.1 Role para EKS Auto Mode Cluster](#11-role-para-eks-auto-mode-cluster)
  - [1.2 Role para EKS Auto Mode Nodes](#12-role-para-eks-auto-mode-nodes)
- [Passo 2: Criar Cluster EKS com Auto Mode](#passo-2-criar-cluster-eks-com-auto-mode)
  - [2.1 Via Console AWS (Recomendado)](#21-via-console-aws-recomendado)
  - [2.2 Via AWS CLI (Alternativo)](#22-via-aws-cli-alternativo)
- [Passo 3: Verificar Node Pools do Auto Mode](#passo-3-verificar-node-pools-do-auto-mode)
  - [3.1 Verificar Node Pools](#31-verificar-node-pools)
  - [3.2 Como Funciona o Auto Mode](#32-como-funciona-o-auto-mode)
- [Passo 4: Instalar Add-ons Essenciais](#passo-4-instalar-add-ons-essenciais)
  - [4.1 Listar Add-ons Disponíveis](#41-listar-add-ons-disponíveis)
  - [4.2 Instalar Add-ons Essenciais](#42-instalar-add-ons-essenciais)
  - [4.3 Verificar Add-ons Instalados](#43-verificar-add-ons-instalados)
- [Passo 5: Configurar IngressClass e Tags para ALB](#passo-5-configurar-ingressclass-e-tags-para-alb)
  - [5.1 Executar Script de Configuração Automática](#51-executar-script-de-configuração-automática)
  - [5.2 Configuração Manual (Alternativa)](#52-configuração-manual-alternativa)
- [Passo 6: Deploy do OpenTelemetry Demo](#passo-6-deploy-do-opentelemetry-demo)
  - [6.1 Adicionar Repositório Helm do OpenTelemetry](#61-adicionar-repositório-helm-do-opentelemetry)
  - [6.2 Criar Namespace](#62-criar-namespace)
  - [6.3 Instalar OpenTelemetry Demo](#63-instalar-opentelemetry-demo)
  - [6.4 Verificar Instalação](#64-verificar-instalação)
  - [6.5 Acessar a Aplicação](#65-acessar-a-aplicação)
- [Passo 7: Próximos Passos](#passo-7-próximos-passos)
- [Custos Estimados](#custos-estimados)
- [Limpeza do Ambiente](#limpeza-do-ambiente)

## O que é EKS Auto Mode?

O **EKS Auto Mode** é uma funcionalidade que automatiza o gerenciamento completo da infraestrutura do cluster Kubernetes, incluindo:

- **Gerenciamento automático de nodes**: Provisiona e remove nodes baseado na demanda
- **Escalonamento inteligente**: Ajusta capacidade automaticamente conforme workloads
- **Atualizações automáticas**: Mantém nodes e componentes sempre atualizados
- **Storage gerenciado**: Cria e gerencia volumes EBS automaticamente
- **Load Balancing integrado**: Provisiona ELBs conforme necessário
- **Networking simplificado**: Configura VPC CNI e networking automaticamente

### Versões Suportadas

- **Kubernetes**: 1.31 a 1.35 (recomendado: 1.34)
- **EKS Auto Mode**: Disponível em todas as regiões AWS
- **Add-ons**: Versões compatíveis são selecionadas automaticamente

💡 **Novidades 2025**: EKS Auto Mode agora suporta GPU workloads (instâncias G, P, Trn) com SOCI parallel pull para melhor performance.

### Vantagens do Auto Mode

✅ **Menos complexidade**: Não precisa gerenciar Node Groups manualmente  
✅ **Redução de custos**: Nodes são criados apenas quando necessário  
✅ **Segurança aprimorada**: Patches e atualizações automáticas  
✅ **Melhor disponibilidade**: AWS gerencia a saúde dos nodes  
✅ **Foco no workload**: Menos tempo gerenciando infraestrutura  
✅ **Load Balancing integrado**: AWS Load Balancer Controller já incluído (ALB/NLB)  

## Arquitetura do Laboratório

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS Account                          │
│                                                             │
│                 ┌─────────────────────────────────┐         │
│                 │    EKS Cluster (Auto Mode)      │         │
│                 │                                 │         │
│                 │ • Auto-managed Nodes           │         │
│                 │ • Prometheus Operator          │         │
│                 │ • Grafana                       │         │
│                 │ • Loki                          │         │
│                 │ • Demo Applications             │         │
│                 │ • Auto Scaling & Updates        │         │
│                 └─────────────────────────────────┘         │
│                            ▲                                │
│                            │                                │
└────────────────────────────┼────────────────────────────────┘
                             │
                    ┌────────┴────────┐
                    │  Máquina Local  │
                    │                 │
                    │ • AWS CLI       │
                    │ • kubectl       │
                    │ • helm          │
                    │ • Lens Desktop  │
                    └─────────────────┘
```

## Pré-requisitos

- Conta AWS com permissões administrativas
- **AWS CLI instalado e configurado** → [Ver guia de instalação](install-aws-cli.md)
- **kubectl instalado** → [Ver guia de instalação](install-kubectl.md)
- **Helm instalado** → [Ver guia de instalação](install-helm.md)
- **Lens Desktop instalado** (opcional, mas recomendado) → [Ver guia de instalação](install-lens.md)
- Conhecimento básico de AWS Console e Kubernetes

## Passo 1: Criar IAM Roles Necessárias

### 1.1 Role para EKS Auto Mode Cluster

1. **IAM Console** → **Roles** → **Create role**
2. **Trusted entity**: AWS service → EKS → EKS - Cluster
3. **Permissions**: Anexar as seguintes policies:
   - `AmazonEKSClusterPolicy`
   - `AmazonEKSComputePolicy`
   - `AmazonEKSBlockStoragePolicy`
   - `AmazonEKSLoadBalancingPolicy`
   - `AmazonEKSNetworkingPolicy`
4. **Role name**: `EKSAutoClusterRole-ObservabilityLab`
5. **Create role**

💡 **Importante**: A policy `AmazonEKSLoadBalancingPolicy` é essencial para que o Auto Mode possa criar e gerenciar Application Load Balancers (ALB) e Network Load Balancers (NLB).

### 1.2 Role para EKS Auto Mode Nodes

1. **IAM Console** → **Roles** → **Create role**
2. **Trusted entity**: AWS service → EC2
3. **Permissions**: Anexar as seguintes policies:
   - `AmazonEKSWorkerNodeMinimalPolicy`
   - `AmazonEC2ContainerRegistryPullOnly`
4. **Role name**: `EKSAutoNodeRole-ObservabilityLab`
5. **Create role**

## Passo 2: Criar Cluster EKS com Auto Mode

### 2.1 Via Console AWS (Recomendado)

1. **EKS Console** → **Clusters** → **Create cluster**

2. **Step 1: Configure cluster**
   - **Name**: `observability-lab-cluster`
   - **Kubernetes version**: `1.34` (ou versão mais recente disponível)
   - **Cluster service role**: `EKSAutoClusterRole-ObservabilityLab`
   - **Next**

3. **Step 2: Specify networking**
   - **VPC**: Default VPC (ou criar nova se preferir)
   - **Subnets**: Selecionar pelo menos 2 subnets em AZs diferentes
   - **Security groups**: Default (será criado automaticamente)
   - **Cluster endpoint access**: Public and private
   - **Next**

4. **Step 3: Configure observability**
   - **Control plane logging**: Habilitar todos os tipos (opcional)
   - **Next**

5. **Step 4: Configure compute, networking, and storage**
   - **Compute**: Habilitar **EKS Auto Mode**
     - **Node role**: `EKSAutoNodeRole-ObservabilityLab`
     - **Node pools**: Selecionar `general-purpose` e `system`
   - **Networking**: Habilitar **Elastic Load Balancing**
   - **Storage**: Habilitar **Block storage**
   - **Next**

6. **Step 5: Configure access**
   - **Authentication mode**: API
   - **Next**

7. **Step 6: Review and create**
   - Revisar configurações
   - **Create**

⏱️ **Aguardar**: O cluster levará cerca de 15 minutos para ser criado.

### 2.2 Via AWS CLI (Alternativo)

```bash
# Definir variáveis
export AWS_REGION="us-east-1"
export CLUSTER_NAME="observability-lab-cluster"
export K8S_VERSION="1.34"
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export CLUSTER_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/EKSAutoClusterRole-ObservabilityLab"
export NODE_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/EKSAutoNodeRole-ObservabilityLab"

# Obter subnet IDs da VPC default
export SUBNETS_JSON=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$(aws ec2 describe-vpcs --query 'Vpcs[?IsDefault==`true`].VpcId' --output text)" \
  --query 'Subnets[0:2].SubnetId' \
  --output json)

# Criar cluster com Auto Mode
aws eks create-cluster \
  --region ${AWS_REGION} \
  --cli-input-json \
  "{
      \"name\": \"${CLUSTER_NAME}\",
      \"version\": \"${K8S_VERSION}\",
      \"roleArn\": \"${CLUSTER_ROLE_ARN}\",
      \"resourcesVpcConfig\": {
        \"subnetIds\": ${SUBNETS_JSON},
        \"endpointPublicAccess\": true,
        \"endpointPrivateAccess\": true
      },
      \"computeConfig\": {
        \"enabled\": true,
        \"nodeRoleArn\":\"${NODE_ROLE_ARN}\",
        \"nodePools\": [\"general-purpose\", \"system\"]
      },
      \"kubernetesNetworkConfig\": {
        \"elasticLoadBalancing\": {
          \"enabled\": true
        }
      },
      \"storageConfig\": {
        \"blockStorage\": {
          \"enabled\": true
        }
      },
      \"accessConfig\": {
        \"authenticationMode\": \"API\"
      }
    }"

# Aguardar cluster ficar ativo
aws eks wait cluster-active --name ${CLUSTER_NAME} --region ${AWS_REGION}
```

## Passo 3: Verificar Node Pools do Auto Mode

Com o EKS Auto Mode, não é necessário criar Node Groups manualmente. O Auto Mode gerencia automaticamente os nodes através de Node Pools.

### 3.1 Verificar Node Pools

```bash
# Atualizar kubeconfig
aws eks update-kubeconfig --name observability-lab-cluster --region us-east-1

# Listar Node Pools
kubectl get nodepools

# Verificar detalhes dos Node Pools
kubectl describe nodepool general-purpose
kubectl describe nodepool system
```

### 3.2 Como Funciona o Auto Mode

O EKS Auto Mode automaticamente:
- **Provisiona nodes** quando há pods pendentes
- **Escala nodes** baseado na demanda de workloads
- **Remove nodes** quando não são mais necessários
- **Atualiza nodes** automaticamente com patches de segurança
- **Gerencia storage** (EBS volumes) e networking (Load Balancers)
- **Configura Load Balancers** (ALB e NLB) através de Ingress e Services

Os Node Pools incluídos são:
- **general-purpose**: Para workloads de aplicação
- **system**: Para componentes do sistema Kubernetes

💡 **Nota**: Nodes serão criados automaticamente quando você fizer deploy de aplicações. Não é necessário pré-provisionar nodes.

💡 **Load Balancer Controller**: O AWS Load Balancer Controller já vem integrado no Auto Mode. Não é necessário instalar manualmente. Basta criar recursos `Ingress` (para ALB) ou `Service` do tipo `LoadBalancer` (para NLB) que o Auto Mode cuidará da criação e configuração automaticamente.

## Passo 4: Instalar Add-ons Essenciais

O EKS Auto Mode requer alguns add-ons para funcionar corretamente. Instale os add-ons essenciais para storage, networking e métricas.

### 4.1 Listar Add-ons Disponíveis

```bash
# Ver add-ons disponíveis para a versão do cluster
aws eks describe-addon-versions --kubernetes-version 1.34 \
  --query 'addons[*].addonName' --output table --region us-east-1
```

### 4.2 Instalar Add-ons Essenciais

**Via Console AWS:**

1. **EKS Console** → **Clusters** → `observability-lab-cluster` → **Add-ons** → **Get more add-ons**

2. Selecionar e instalar os seguintes add-ons:
   - **Amazon EBS CSI Driver** (versão mais recente disponível)
     - Necessário para volumes persistentes EBS
     - Compatível com Kubernetes 1.34+
   
   - **Amazon EFS CSI Driver** (versão mais recente disponível)
     - Necessário para volumes compartilhados EFS (opcional)
     - Compatível com Kubernetes 1.34+
   
   - **CoreDNS** (versão mais recente disponível)
     - Resolução DNS dentro do cluster
     - Geralmente já instalado automaticamente
   
   - **Metrics Server** (versão mais recente disponível)
     - Métricas de CPU/Memory para HPA e kubectl top
     - Essencial para observabilidade

3. Para cada add-on:
   - Selecionar versão mais recente
   - Manter configurações padrão
   - Clicar em **Next** → **Create**

**Via AWS CLI:**

```bash
# Definir variáveis
export CLUSTER_NAME="observability-lab-cluster"
export AWS_REGION="us-east-1"

# Instalar Amazon EBS CSI Driver
aws eks create-addon \
  --cluster-name ${CLUSTER_NAME} \
  --addon-name aws-ebs-csi-driver \
  --region ${AWS_REGION}

# Instalar Amazon EFS CSI Driver (opcional)
aws eks create-addon \
  --cluster-name ${CLUSTER_NAME} \
  --addon-name aws-efs-csi-driver \
  --region ${AWS_REGION}

# Instalar CoreDNS (se não estiver instalado)
aws eks create-addon \
  --cluster-name ${CLUSTER_NAME} \
  --addon-name coredns \
  --region ${AWS_REGION}

# Instalar Metrics Server
aws eks create-addon \
  --cluster-name ${CLUSTER_NAME} \
  --addon-name metrics-server \
  --region ${AWS_REGION}
```

### 4.3 Verificar Add-ons Instalados

```bash
# Listar add-ons instalados
aws eks list-addons --cluster-name observability-lab-cluster --region us-east-1

# Verificar status de cada add-on
aws eks describe-addon \
  --cluster-name observability-lab-cluster \
  --addon-name aws-ebs-csi-driver \
  --region us-east-1

# Verificar pods dos add-ons
kubectl get pods -n kube-system | grep -E "ebs|efs|coredns|metrics-server"
```

**Saída esperada:**
```
ADDONS:
- aws-ebs-csi-driver (ACTIVE)
- aws-efs-csi-driver (ACTIVE)
- coredns (ACTIVE)
- metrics-server (ACTIVE)
```

💡 **Importante**: Aguarde todos os add-ons ficarem com status `ACTIVE` antes de prosseguir. Isso pode levar 2-3 minutos.

## Passo 5: Configurar IngressClass e Tags para ALB

O Auto Mode requer configurações específicas para criar Application Load Balancers. Use o script automatizado para configurar tudo de uma vez.

### 5.1 Executar Script de Configuração Automática

**Opção 1: Ambiente de Produção (Recomendado)**

```bash
# Executa configuração completa sem restrição de instâncias
./scripts/setup-eks.sh

# O que faz:
# ✅ Configura tags nas subnets
# ✅ Cria IngressClass ALB
# ❌ Não restringe tipos de instâncias (Auto Mode escolhe automaticamente)
```

**Opção 2: Ambiente de Desenvolvimento**

```bash
# Executa configuração com NodePool restrito à família T + Spot
./scripts/setup-eks.sh --env-dev

# O que faz:
# ✅ Configura tags nas subnets
# ✅ Cria IngressClass ALB
# ✅ Configura NodePool para usar apenas família T (t3, t3a) com Spot
```

**Configuração aplicada no modo desenvolvimento:**
- Categoria de instância: `t` (família T)
- Geração: `> 2` (t3, t3a ou superior)
- Arquitetura: `amd64` (x86_64)
- Tipo de capacidade: `spot` (economia de até 90%)

💡 **Economia**: Instâncias Spot da família T podem custar até 90% menos que On-Demand!

**Opções do script:**

```bash
# Ver ajuda
./scripts/setup-eks.sh --help

# Customizar cluster e região
./scripts/setup-eks.sh --cluster-name meu-cluster --region us-west-2

# Desenvolvimento com cluster customizado
./scripts/setup-eks.sh --env-dev --cluster-name meu-cluster --region us-west-2
```

💡 **Recomendação**: Use o modo produção (sem `--env-dev`) para permitir que o Auto Mode escolha automaticamente os melhores tipos de instâncias baseado na carga de trabalho.

### 5.2 Configuração Manual (Alternativa)

Se preferir configurar manualmente ao invés de usar o script:

**Passo 1: Configurar Tags nas Subnets**

```bash
# 1. Obter VPC ID
VPC_ID=$(aws eks describe-cluster --name observability-lab-cluster --region us-east-1 --query 'cluster.resourcesVpcConfig.vpcId' --output text)

# 2. Obter subnets públicas
PUBLIC_SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}" "Name=map-public-ip-on-launch,Values=true" --region us-east-1 --query 'Subnets[*].SubnetId' --output text)

# 3. Adicionar tags em cada subnet
for subnet in $PUBLIC_SUBNETS; do
  aws ec2 create-tags --resources $subnet --tags Key=kubernetes.io/role/elb,Value=1 --region us-east-1
  aws ec2 create-tags --resources $subnet --tags Key=kubernetes.io/cluster/observability-lab-cluster,Value=shared --region us-east-1
done
```

**Passo 2: Criar IngressClass**

```bash
kubectl apply -f kubernetes/alb-ingressclass.yaml
```

**Tags necessárias:**
- `kubernetes.io/role/elb=1` - Identifica subnets para Load Balancers públicos
- `kubernetes.io/cluster/observability-lab-cluster=shared` - Associa subnet ao cluster

💡 **Nota**: Sem essas tags, o Auto Mode não conseguirá criar ALBs e você verá erros como "couldn't auto-discover subnets".

## Passo 6: Deploy do OpenTelemetry Demo

Com o ambiente configurado, vamos fazer o deploy da aplicação de demonstração do OpenTelemetry.

### 6.1 Adicionar Repositório Helm do OpenTelemetry

```bash
# Adicionar repositório
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts

# Atualizar repositórios
helm repo update
```

### 6.2 Criar Namespace

```bash
# Criar namespace para o OpenTelemetry Demo
kubectl create namespace app
```

### 6.3 Instalar OpenTelemetry Demo

```bash
# Instalar usando o arquivo de valores customizado
helm upgrade --install opentelemetry-demo open-telemetry/opentelemetry-demo \
  --namespace app \
  --values helm-values/opentelemetry-demo/values.yaml

# Aguardar pods ficarem prontos (pode levar 3-5 minutos)
kubectl get pods -n app -w
```

### 6.4 Verificar Instalação

```bash
# Verificar todos os pods
kubectl get pods -n app

# Verificar services
kubectl get svc -n app

# Verificar ingress (se configurado)
kubectl get ingress -n app
```

### 6.5 Acessar a Aplicação

```bash
# Obter URL do frontend (via Ingress ou LoadBalancer)
kubectl get ingress -n app

# Ou via port-forward para teste local
kubectl port-forward -n app svc/opentelemetry-demo-frontendproxy 8080:8080
```

Acesse no navegador: `http://localhost:8080`

💡 **Nota**: O OpenTelemetry Demo é uma aplicação de e-commerce completa que gera traces, métricas e logs automaticamente, ideal para testar a stack de observabilidade.

## Passo 7: Próximos Passos

Com o OpenTelemetry Demo rodando, você pode prosseguir para:

1. **Deploy da Stack de Observabilidade**
   ```bash
   # Consultar documentação detalhada
   cat docs/deploy-observability-stack.md
   
   # Seguir passo a passo para instalação manual
   ```

2. **Exercícios Práticos**
   ```bash
   cd exercises/01-deploy-prometheus-stack
   cat README.md
   ```

3. **Explorar o Ambiente**
   ```bash
   # Usar Lens para visualizar o cluster graficamente
   # Abrir Lens Desktop e explorar recursos
   
   # Via linha de comando
   kubectl get all --all-namespaces
   ```

## Custos Estimados

| Recurso | Tipo | Custo/hora (aprox.) |
|---------|------|-------------------|
| EKS Cluster | Managed | $0.10 |
| Auto Mode Nodes | Sob demanda (t3.medium) | Variável* |
| **Total** | | **~$0.10/hora + nodes** |

💡 **Vantagens do Auto Mode**:
- Nodes são criados apenas quando necessário
- Escala automaticamente baseado na demanda
- Reduz custos quando não há workloads rodando
- *Custo de nodes varia conforme uso (aproximadamente $0.04/hora por t3.medium spot)

💡 **Dica**: Para economizar, delete deployments quando não estiver usando. O Auto Mode removerá os nodes automaticamente.

## Limpeza do Ambiente

Quando terminar o laboratório:

1. **Deletar Workloads (opcional, mas recomendado)**
   ```bash
   # Deletar todos os deployments para remover nodes automaticamente
   kubectl delete deployments --all --all-namespaces
   kubectl delete services --all --all-namespaces
   ```

2. **Deletar Cluster EKS com Auto Mode**
   ```bash
   # O Auto Mode limpará automaticamente nodes, load balancers e volumes
   aws eks delete-cluster --name observability-lab-cluster --region us-east-1
   ```

3. **Deletar IAM Roles** (opcional)
   - Via Console AWS: IAM → Roles → Delete
   - Roles: `EKSAutoClusterRole-ObservabilityLab` e `EKSAutoNodeRole-ObservabilityLab`

💡 **Nota**: O Auto Mode limpa automaticamente todos os recursos gerenciados (nodes, EBS volumes, Load Balancers, Security Groups) quando o cluster é deletado.