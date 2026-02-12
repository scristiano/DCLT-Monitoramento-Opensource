# Scripts de Automação EKS

Este diretório contém scripts para automatizar a criação e gerenciamento do cluster EKS para a Aula 07 de Observabilidade no Kubernetes.

## Scripts Disponíveis

### ⚙️ `setup-eks.sh`
Script de configuração pós-criação do cluster EKS. Configura tags, IngressClass, StorageClass, e recursos IAM para Loki.

**Recursos configurados:**
- Tags nas subnets para ALB (kubernetes.io/role/elb)
- OIDC Provider (se não existir)
- Buckets S3 para Loki com Account ID no nome (chunks, ruler, admin)
- IAM Policy e Role para Loki (IRSA)
- IngressClass ALB
- StorageClass GP3
- Namespace monitoring
- Ingress base (eks-lab-alb) com certificado ACM
- NodePool família T + Spot (modo desenvolvimento)

**Uso básico:**
```bash
# Produção (sem restrição de instâncias)
./scripts/setup-eks.sh

# Desenvolvimento (família T + Spot)
./scripts/setup-eks.sh --env-dev

# Com certificado ACM específico
./scripts/setup-eks.sh --certificate-arn arn:aws:acm:us-east-1:123456789012:certificate/abc123...

# Com parâmetros customizados
./scripts/setup-eks.sh --env-dev --cluster-name meu-cluster --region us-west-2 --certificate-arn arn:aws:acm:...
```

**Parâmetros:**
- `--env-dev` - Configura NodePool para família T com Spot (desenvolvimento)
- `--cluster-name NAME` - Nome do cluster (padrão: observability-lab-cluster)
- `--region REGION` - Região AWS (padrão: us-east-1)
- `--certificate-arn ARN` - ARN do certificado ACM para HTTPS (opcional)
- `--help` - Mostra ajuda

**Certificado ACM:**
- Se não fornecido via `--certificate-arn`, o script tentará detectar certificados existentes
- Se múltiplos certificados forem encontrados, você poderá escolher interativamente
- Se nenhum certificado for encontrado, o Ingress será criado com HTTP apenas
- Você pode executar o script novamente com `--certificate-arn` para adicionar HTTPS depois

**Verificações automáticas:**
- Add-ons essenciais (aws-ebs-csi-driver, aws-efs-csi-driver, coredns, metrics-server)
- Credenciais AWS
- Conexão com cluster

### 🚀 `create-eks-cluster.sh`
Script completo para criação automatizada do cluster EKS com todos os add-ons necessários.

**Recursos criados:**
- Cluster EKS com OIDC habilitado
- Node group com instâncias Spot (economia de custos)
- EBS CSI Driver (para volumes persistentes)
- EFS CSI Driver (para volumes compartilhados)
- AWS Load Balancer Controller (para ALB/NLB)
- Storage classes otimizadas (gp3)
- IAM roles e service accounts necessárias

**Nota:** O Metrics Server será instalado separadamente via Helm usando `helm-values/metrics-server/values.yaml`

**Uso básico:**
```bash
./scripts/create-eks-cluster.sh
```

**Uso com parâmetros customizados:**
```bash
# Definir variáveis de ambiente
export CLUSTER_NAME="meu-cluster"
export REGION="us-west-2"
export INSTANCE_TYPE="t3.large"
export DESIRED_SIZE="4"

./scripts/create-eks-cluster.sh
```

**Parâmetros configuráveis:**
- `CLUSTER_NAME` (padrão: observability-lab-cluster)
- `REGION` (padrão: us-east-2)
- `NODE_GROUP_NAME` (padrão: worker-nodes)
- `INSTANCE_TYPE` (padrão: t3.medium)
- `MIN_SIZE` (padrão: 2)
- `MAX_SIZE` (padrão: 6)
- `DESIRED_SIZE` (padrão: 3)
- `KUBERNETES_VERSION` (padrão: 1.34 - versão estável recomendada)

### 🗑️ `delete-eks-cluster.sh`
Script para limpeza completa do cluster EKS e todos os recursos associados.

**Recursos removidos:**
- Cluster EKS e node groups
- Load Balancers criados pelo ALB Controller
- Add-ons do EKS
- IAM roles criadas
- Service accounts e recursos Kubernetes

**Uso:**
```bash
./scripts/delete-eks-cluster.sh
```

**⚠️ ATENÇÃO:** Este script remove PERMANENTEMENTE todos os recursos. Confirme digitando 'DELETE' quando solicitado.

## Pré-requisitos

### Ferramentas Necessárias
- **AWS CLI v2** - Configurado com credenciais válidas
- **eksctl** - Será instalado automaticamente se não estiver presente
- **kubectl** - Será instalado automaticamente se não estiver presente
- **helm** - Necessário para AWS Load Balancer Controller
- **jq** - Para processamento JSON (geralmente já instalado)

### Permissões AWS Necessárias
Sua conta AWS deve ter as seguintes permissões:

**EKS:**
- `eks:*`

**EC2:**
- `ec2:*`

**IAM:**
- `iam:CreateRole`
- `iam:AttachRolePolicy`
- `iam:CreateServiceLinkedRole`
- `iam:CreateInstanceProfile`
- `iam:TagRole`

**CloudFormation:**
- `cloudformation:*`

**Auto Scaling:**
- `autoscaling:*`

### Configuração AWS CLI
```bash
# Configurar credenciais
aws configure

# Verificar configuração
aws sts get-caller-identity
```

## Exemplos de Uso

### Cenário 0: Configuração Inicial do Cluster
```bash
# Após criar o cluster, executar setup
./scripts/setup-eks.sh --env-dev

# Verificar recursos criados
kubectl get ingressclass
kubectl get storageclass
kubectl get ingress -n monitoring

# Verificar buckets S3 (incluem Account ID no nome)
aws s3 ls | grep loki-observability-lab

# Verificar IAM Role
aws iam get-role --role-name LokiS3AccessRole

# Verificar values.yaml atualizado
grep -A 3 "bucketNames:" helm-values/loki-stack/values.yaml
grep "eks.amazonaws.com/role-arn" helm-values/loki-stack/values.yaml
```

### Cenário 1: Cluster para Desenvolvimento
```bash
export CLUSTER_NAME="dev-observability"
export INSTANCE_TYPE="t3.small"
export DESIRED_SIZE="2"
export REGION="us-east-2"

./scripts/create-eks-cluster.sh
```

### Cenário 2: Cluster para Produção
```bash
export CLUSTER_NAME="prod-observability"
export INSTANCE_TYPE="t3.large"
export MIN_SIZE="3"
export MAX_SIZE="10"
export DESIRED_SIZE="5"
export REGION="us-west-2"

./scripts/create-eks-cluster.sh
```

### Cenário 3: Cluster Multi-AZ
```bash
export CLUSTER_NAME="multi-az-cluster"
export REGION="eu-west-1"
export DESIRED_SIZE="6"  # 2 nodes por AZ

./scripts/create-eks-cluster.sh
```

## Verificação Pós-Criação

Após executar o script de criação, verifique se tudo está funcionando:

```bash
# Verificar nodes
kubectl get nodes -o wide

# Verificar add-ons
aws eks list-addons --cluster-name observability-lab-cluster

# Verificar storage classes
kubectl get storageclass

# Verificar pods do sistema (exceto metrics-server que será instalado via Helm)
kubectl get pods -n kube-system

# Testar criação de volume
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: gp3
EOF

kubectl get pvc test-pvc
kubectl delete pvc test-pvc
```

## Troubleshooting

### Problema: Script falha na criação do cluster
**Solução:** Verificar se as credenciais AWS têm as permissões necessárias:
```bash
aws sts get-caller-identity
aws iam get-user
```

### Problema: Add-ons não são instalados
**Solução:** Verificar se o OIDC provider foi criado corretamente:
```bash
aws eks describe-cluster --name observability-lab-cluster --query "cluster.identity.oidc.issuer"
```

### Problema: Load Balancer Controller não funciona
**Solução:** Verificar se o service account tem as permissões corretas:
```bash
kubectl describe sa aws-load-balancer-controller -n kube-system
```

### Problema: Volumes EBS não são criados
**Solução:** Verificar se o EBS CSI Driver está funcionando:
```bash
kubectl get pods -n kube-system | grep ebs-csi
kubectl logs -n kube-system deployment/ebs-csi-controller
```

## Custos Estimados

| Recurso | Configuração Padrão | Custo/hora (aprox.) |
|---------|-------------------|-------------------|
| EKS Control Plane | Managed | $0.10 |
| Worker Nodes | 3x t3.medium spot | $0.14 |
| EBS Volumes | 3x 30GB gp3 | $0.01 |
| Load Balancers | Conforme uso | Variável |
| **Total Base** | | **~$0.25/hora** |

💡 **Dicas de economia:**
- Use instâncias Spot (já configurado por padrão)
- Termine o cluster quando não estiver usando
- Use storage gp3 ao invés de gp2 (já configurado)
- Configure auto-scaling para reduzir nodes em horários de baixo uso

## Logs e Debugging

### Logs do Script
Os scripts geram logs detalhados com timestamps e códigos de cores para facilitar o debugging.

### Logs do EKS
```bash
# Logs do control plane (se habilitado)
aws logs describe-log-groups --log-group-name-prefix "/aws/eks/observability-lab-cluster"

# Logs dos nodes
kubectl logs -n kube-system daemonset/aws-node
kubectl logs -n kube-system deployment/coredns
```

### Eventos do Cluster
```bash
# Eventos recentes
kubectl get events --sort-by='.lastTimestamp' -A

# Eventos de um namespace específico
kubectl get events -n kube-system --sort-by='.lastTimestamp'
```

## Próximos Passos

Após criar o cluster com sucesso:

1. **Executar Setup do Cluster:**
   ```bash
   # Configurar tags, IAM, IngressClass, StorageClass, etc.
   ./scripts/setup-eks.sh --env-dev
   ```

2. **Seguir Documentação de Deploy:**
   ```bash
   # Consultar guia completo
   cat docs/deploy-observability-stack.md
   ```

3. **Instalar Stack de Observabilidade:**
   ```bash
   # Instalar kube-prometheus-stack
   helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
     --namespace monitoring \
     --values helm-values/kube-prometheus-stack/values.yaml
   
   # Instalar Loki (role IAM já configurada pelo setup-eks.sh)
   helm upgrade --install loki grafana/loki \
     --namespace monitoring \
     --values helm-values/loki-stack/values.yaml
   
   # Instalar Promtail
   helm upgrade --install promtail grafana/promtail \
     --namespace monitoring \
     --values helm-values/loki-stack/promtail-values.yaml
   ```

4. **Verificar Instalação:**
   ```bash
   kubectl get pods -n monitoring
   kubectl get ingress -n monitoring
   ```

5. **Acessar Grafana:**
   ```bash
   # Obter URL do ALB
   kubectl get ingress -n monitoring eks-lab-ingress
   # Acessar: https://grafana.demo.lynxnetwork.com.br
   # Credenciais: admin / admin123
   ```