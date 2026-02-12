# Kubernetes Manifests e Templates

Este diretório contém manifests Kubernetes e templates de configuração para o laboratório de observabilidade.

## Arquivos de Configuração

### IngressClass e Ingress

- **`alb-ingressclass.yaml`**: Define a IngressClass para ALB (Application Load Balancer)
- **`eks-lab-ingress.yaml`**: Ingress base compartilhado para Grafana e Prometheus

### Storage

- **`gp3-storageclass.yaml`**: StorageClass otimizada usando volumes EBS GP3

### NodePool (Desenvolvimento)

- **`nodepool-t-family-patch.yaml`**: Patch para restringir NodePool general-purpose à família T
- **`nodepool-system-patch.yaml`**: Patch para restringir NodePool system à família T

### Templates IAM para Loki

⚠️ **IMPORTANTE**: Estes são arquivos de template. Use o script `setup-eks.sh` para configuração automática.

#### `loki-s3-policy.json`

Template da IAM Policy para acesso do Loki aos buckets S3.

**Placeholders:**
- `ACCOUNT_ID`: Será substituído pelo seu Account ID da AWS

**Uso automático:**
```bash
./scripts/setup-eks.sh
```

O script irá:
1. Obter automaticamente seu Account ID
2. Criar os buckets S3 com nomes únicos
3. Criar a policy com os nomes corretos dos buckets
4. Atualizar o `helm-values/loki-stack/values.yaml`

**Uso manual:**

Se você preferir criar manualmente, substitua `ACCOUNT_ID` pelo seu Account ID:

```bash
# Obter Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Account ID: $ACCOUNT_ID"

# Criar policy (substituir ACCOUNT_ID no JSON antes)
aws iam create-policy \
  --policy-name LokiS3AccessPolicy \
  --policy-document file://kubernetes/loki-s3-policy.json
```

#### `loki-trust-policy-template.json`

Template da Trust Policy para a IAM Role do Loki (IRSA - IAM Roles for Service Accounts).

**Placeholders:**
- `ACCOUNT_ID`: Seu Account ID da AWS
- `REGION`: Região do cluster EKS (ex: us-east-1)
- `OIDC_ID`: ID do OIDC Provider do cluster EKS (aparece 3 vezes)

**Obter OIDC ID:**

```bash
aws eks describe-cluster \
  --name observability-lab-cluster \
  --region us-east-1 \
  --query "cluster.identity.oidc.issuer" \
  --output text

# Resultado: https://oidc.eks.us-east-1.amazonaws.com/id/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
# Copie apenas o ID (últimos 32 caracteres)
```

**Uso automático:**

O script `setup-eks.sh` cria a trust policy automaticamente:

```bash
./scripts/setup-eks.sh
```

**Uso manual:**

1. Obter valores necessários:
```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"
OIDC_ID=$(aws eks describe-cluster --name observability-lab-cluster --region $REGION --query "cluster.identity.oidc.issuer" --output text | awk -F'/' '{print $NF}')
```

2. Criar arquivo temporário com substituições:
```bash
sed -e "s/ACCOUNT_ID/$ACCOUNT_ID/g" \
    -e "s/REGION/$REGION/g" \
    -e "s/OIDC_ID/$OIDC_ID/g" \
    kubernetes/loki-trust-policy-template.json > /tmp/loki-trust-policy.json
```

3. Criar role:
```bash
aws iam create-role \
  --role-name LokiS3AccessRole \
  --assume-role-policy-document file:///tmp/loki-trust-policy.json
```

### Permissões Adicionais para ALB

#### `alb-additional-permissions.json`

Permissões adicionais necessárias para o AWS Load Balancer Controller criar e gerenciar ALBs.

**Nota**: No EKS Auto Mode, o Load Balancer Controller já vem integrado. Este arquivo é apenas para referência ou uso em clusters sem Auto Mode.

## Certificados ACM para HTTPS

### Criar Certificado ACM

**Via Console AWS:**
1. AWS Console → Certificate Manager
2. Request certificate
3. Request a public certificate
4. Domain name: `*.demo.lynxnetwork.com.br` (ou seu domínio)
5. Validation method: DNS validation (recomendado)
6. Request
7. Adicionar registros DNS conforme instruções

**Via AWS CLI:**
```bash
# Solicitar certificado
aws acm request-certificate \
  --domain-name '*.demo.lynxnetwork.com.br' \
  --validation-method DNS \
  --region us-east-1

# Obter detalhes de validação
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:... \
  --region us-east-1
```

### Listar Certificados Existentes

```bash
# Listar todos os certificados
aws acm list-certificates --region us-east-1

# Listar com detalhes
aws acm list-certificates --region us-east-1 --query 'CertificateSummaryList[*].[CertificateArn,DomainName,Status]' --output table
```

### Usar Certificado no Setup

```bash
# Opção 1: Fornecer ARN diretamente
./scripts/setup-eks.sh --certificate-arn arn:aws:acm:us-east-1:123456789012:certificate/abc123...

# Opção 2: Deixar o script detectar (interativo)
./scripts/setup-eks.sh
# O script listará certificados disponíveis e permitirá escolher

# Opção 3: Atualizar manualmente
# Editar kubernetes/eks-lab-ingress.yaml e substituir o ARN
# Depois aplicar: kubectl apply -f kubernetes/eks-lab-ingress.yaml
```

### Validação DNS

Após solicitar o certificado, você precisa adicionar registros DNS:

1. Obter registros de validação:
```bash
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:... \
  --region us-east-1 \
  --query 'Certificate.DomainValidationOptions[*].[ResourceRecord.Name,ResourceRecord.Value]' \
  --output table
```

2. Adicionar registros CNAME no seu provedor DNS

3. Aguardar validação (pode levar alguns minutos):
```bash
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:... \
  --region us-east-1 \
  --query 'Certificate.Status' \
  --output text
```

Status esperado: `ISSUED`

## Fluxo de Configuração Recomendado

### 1. Executar Script de Setup (Recomendado)

```bash
# Configuração completa automática
./scripts/setup-eks.sh

# Para ambiente de desenvolvimento (família T + Spot)
./scripts/setup-eks.sh --env-dev

# Com certificado ACM específico
./scripts/setup-eks.sh --certificate-arn arn:aws:acm:us-east-1:123456789012:certificate/abc123...

# Combinando opções
./scripts/setup-eks.sh --env-dev --certificate-arn arn:aws:acm:...
```

O script configura automaticamente:
- ✅ Tags nas subnets para ALB
- ✅ OIDC Provider
- ✅ Buckets S3 para Loki
- ✅ IAM Policy e Role para Loki
- ✅ IngressClass ALB
- ✅ StorageClass GP3
- ✅ Namespace monitoring
- ✅ Ingress base com certificado ACM (se fornecido)
- ✅ NodePool (se --env-dev)

**Certificado ACM:**
- Se não fornecido, o script tentará detectar certificados existentes
- Se múltiplos certificados, você poderá escolher
- Se nenhum certificado, o Ingress será criado com HTTP apenas

### 2. Aplicar Manifests Manualmente (Alternativa)

Se preferir aplicar manualmente:

```bash
# 1. IngressClass
kubectl apply -f kubernetes/alb-ingressclass.yaml

# 2. StorageClass
kubectl apply -f kubernetes/gp3-storageclass.yaml

# 3. Namespace
kubectl create namespace monitoring

# 4. Ingress base
kubectl apply -f kubernetes/eks-lab-ingress.yaml

# 5. NodePool (opcional, apenas desenvolvimento)
kubectl patch nodepool general-purpose --type=merge --patch-file=kubernetes/nodepool-t-family-patch.yaml
kubectl patch nodepool system --type=merge --patch-file=kubernetes/nodepool-system-patch.yaml
```

## Verificação

Após aplicar as configurações:

```bash
# Verificar IngressClass
kubectl get ingressclass

# Verificar StorageClass
kubectl get storageclass

# Verificar Ingress
kubectl get ingress -n monitoring

# Verificar NodePools (se aplicável)
kubectl get nodepools

# Verificar buckets S3
aws s3 ls | grep loki-observability-lab

# Verificar IAM Role
aws iam get-role --role-name LokiS3AccessRole
```

## Troubleshooting

### Problema: ALB não é criado

**Verificar tags nas subnets:**
```bash
VPC_ID=$(aws eks describe-cluster --name observability-lab-cluster --region us-east-1 --query 'cluster.resourcesVpcConfig.vpcId' --output text)

aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}" --query 'Subnets[*].[SubnetId,Tags]' --output table
```

**Tags necessárias:**
- `kubernetes.io/role/elb=1`
- `kubernetes.io/cluster/observability-lab-cluster=shared`

### Problema: Loki não consegue acessar S3

**Verificar ServiceAccount:**
```bash
kubectl get sa loki -n monitoring -o yaml
```

**Verificar annotation:**
```yaml
annotations:
  eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/LokiS3AccessRole
```

**Verificar buckets:**
```bash
aws s3 ls | grep loki-observability-lab
```

### Problema: Volumes não são criados

**Verificar StorageClass:**
```bash
kubectl get storageclass gp3
```

**Verificar EBS CSI Driver:**
```bash
kubectl get pods -n kube-system | grep ebs-csi
```

## Referências

- [EKS Auto Mode Documentation](https://docs.aws.amazon.com/eks/latest/userguide/automode.html)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [EBS CSI Driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver)
- [IRSA (IAM Roles for Service Accounts)](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
