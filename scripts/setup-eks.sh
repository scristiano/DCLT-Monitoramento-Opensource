#!/bin/bash

# =============================================================================
# SETUP EKS
# =============================================================================
# Script para configurar tags necessárias nas subnets para EKS Auto Mode
# e opcionalmente configurar NodePool para ambiente de desenvolvimento
# Aula 07 - PosTech DevOps - Observabilidade no Kubernetes
# =============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações padrão
CLUSTER_NAME="${CLUSTER_NAME:-observability-lab-cluster}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ENV_DEV=false
ACM_CERTIFICATE_ARN=""

# Parse argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --env-dev)
            ENV_DEV=true
            shift
            ;;
        --cluster-name)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --region)
            AWS_REGION="$2"
            shift 2
            ;;
        --certificate-arn)
            ACM_CERTIFICATE_ARN="$2"
            shift 2
            ;;
        --help)
            echo "Uso: $0 [opções]"
            echo ""
            echo "Opções:"
            echo "  --env-dev              Configura NodePool com família T (apenas para desenvolvimento)"
            echo "  --cluster-name NAME    Nome do cluster EKS (padrão: observability-lab-cluster)"
            echo "  --region REGION        Região AWS (padrão: us-east-1)"
            echo "  --certificate-arn ARN  ARN do certificado ACM para HTTPS (opcional)"
            echo "  --help                 Mostra esta mensagem"
            echo ""
            echo "Exemplos:"
            echo "  $0                                    # Produção (sem restrição de instâncias)"
            echo "  $0 --env-dev                          # Desenvolvimento (família T apenas)"
            echo "  $0 --certificate-arn arn:aws:acm:... # Com certificado ACM específico"
            echo "  $0 --env-dev --cluster-name meu-cluster --region us-west-2"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Argumento desconhecido: $1${NC}"
            echo "Use --help para ver as opções disponíveis"
            exit 1
            ;;
    esac
done

echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}SETUP EKS - Configuração de Cluster${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo -e "Cluster: ${YELLOW}${CLUSTER_NAME}${NC}"
echo -e "Região: ${YELLOW}${AWS_REGION}${NC}"
if [ "$ENV_DEV" = true ]; then
    echo -e "Ambiente: ${BLUE}DESENVOLVIMENTO${NC} (NodePool família T)"
else
    echo -e "Ambiente: ${GREEN}PRODUÇÃO${NC} (sem restrição de instâncias)"
fi
if [ -n "$ACM_CERTIFICATE_ARN" ]; then
    echo -e "Certificado ACM: ${GREEN}Fornecido${NC}"
else
    echo -e "Certificado ACM: ${YELLOW}Será detectado ou solicitado${NC}"
fi
echo ""

# Verificar se AWS CLI está instalado
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI não está instalado!${NC}"
    echo "Instale o AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Verificar credenciais AWS
echo -e "${YELLOW}🔍 Verificando credenciais AWS...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ Credenciais AWS não configuradas!${NC}"
    echo "Execute: aws configure"
    exit 1
fi
echo -e "${GREEN}✅ Credenciais AWS OK${NC}"
echo ""

# =============================================================================
# CONFIGURAR CERTIFICADO ACM
# =============================================================================
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}CONFIGURAR CERTIFICADO ACM (HTTPS)${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""

# Se o certificado não foi fornecido via argumento, tentar detectar ou solicitar
if [ -z "$ACM_CERTIFICATE_ARN" ]; then
    echo -e "${YELLOW}🔍 Buscando certificados ACM na região ${AWS_REGION}...${NC}"
    
    # Listar certificados disponíveis
    CERTIFICATES=$(aws acm list-certificates --region ${AWS_REGION} --query 'CertificateSummaryList[*].[CertificateArn,DomainName]' --output text 2>/dev/null)
    
    if [ -z "$CERTIFICATES" ]; then
        echo -e "${YELLOW}⚠️  Nenhum certificado ACM encontrado na região ${AWS_REGION}${NC}"
        echo ""
        echo -e "${BLUE}ℹ️  Para usar HTTPS, você precisa de um certificado ACM.${NC}"
        echo ""
        echo -e "Opções:"
        echo -e "  1. Criar certificado via AWS Console:"
        echo -e "     ${YELLOW}AWS Console → Certificate Manager → Request certificate${NC}"
        echo ""
        echo -e "  2. Criar certificado via AWS CLI:"
        echo -e "     ${YELLOW}aws acm request-certificate --domain-name '*.demo.lynxnetwork.com.br' --validation-method DNS --region ${AWS_REGION}${NC}"
        echo ""
        echo -e "  3. Executar este script novamente com:"
        echo -e "     ${YELLOW}$0 --certificate-arn arn:aws:acm:...${NC}"
        echo ""
        echo -e "${YELLOW}⚠️  Continuando sem certificado ACM (HTTP apenas)${NC}"
        echo -e "${YELLOW}⚠️  Os Ingress serão criados mas não terão HTTPS configurado${NC}"
        echo ""
        ACM_CERTIFICATE_ARN="NONE"
    else
        echo -e "${GREEN}✅ Certificados ACM encontrados:${NC}"
        echo ""
        
        # Mostrar certificados em formato tabular
        echo "$CERTIFICATES" | nl -w2 -s'. '
        echo ""
        
        # Contar certificados
        CERT_COUNT=$(echo "$CERTIFICATES" | wc -l | tr -d ' ')
        
        if [ "$CERT_COUNT" -eq 1 ]; then
            # Apenas um certificado, usar automaticamente
            ACM_CERTIFICATE_ARN=$(echo "$CERTIFICATES" | awk '{print $1}')
            CERT_DOMAIN=$(echo "$CERTIFICATES" | awk '{print $2}')
            echo -e "${GREEN}✅ Usando certificado automaticamente:${NC}"
            echo -e "   ARN: ${YELLOW}${ACM_CERTIFICATE_ARN}${NC}"
            echo -e "   Domínio: ${YELLOW}${CERT_DOMAIN}${NC}"
        else
            # Múltiplos certificados, perguntar ao usuário
            echo -e "${YELLOW}Selecione o certificado a usar (1-${CERT_COUNT}) ou 0 para pular:${NC}"
            read -p "Opção: " CERT_CHOICE
            
            if [ "$CERT_CHOICE" = "0" ]; then
                echo -e "${YELLOW}⚠️  Continuando sem certificado ACM (HTTP apenas)${NC}"
                ACM_CERTIFICATE_ARN="NONE"
            elif [ "$CERT_CHOICE" -ge 1 ] && [ "$CERT_CHOICE" -le "$CERT_COUNT" ]; then
                ACM_CERTIFICATE_ARN=$(echo "$CERTIFICATES" | sed -n "${CERT_CHOICE}p" | awk '{print $1}')
                CERT_DOMAIN=$(echo "$CERTIFICATES" | sed -n "${CERT_CHOICE}p" | awk '{print $2}')
                echo -e "${GREEN}✅ Certificado selecionado:${NC}"
                echo -e "   ARN: ${YELLOW}${ACM_CERTIFICATE_ARN}${NC}"
                echo -e "   Domínio: ${YELLOW}${CERT_DOMAIN}${NC}"
            else
                echo -e "${RED}❌ Opção inválida. Continuando sem certificado.${NC}"
                ACM_CERTIFICATE_ARN="NONE"
            fi
        fi
    fi
else
    # Certificado fornecido via argumento, validar
    echo -e "${YELLOW}🔍 Validando certificado fornecido...${NC}"
    
    if aws acm describe-certificate --certificate-arn ${ACM_CERTIFICATE_ARN} --region ${AWS_REGION} &> /dev/null; then
        CERT_DOMAIN=$(aws acm describe-certificate --certificate-arn ${ACM_CERTIFICATE_ARN} --region ${AWS_REGION} --query 'Certificate.DomainName' --output text)
        echo -e "${GREEN}✅ Certificado válido:${NC}"
        echo -e "   ARN: ${YELLOW}${ACM_CERTIFICATE_ARN}${NC}"
        echo -e "   Domínio: ${YELLOW}${CERT_DOMAIN}${NC}"
    else
        echo -e "${RED}❌ Certificado inválido ou não encontrado!${NC}"
        echo -e "Verifique o ARN e a região."
        exit 1
    fi
fi

echo ""

# =============================================================================
# VERIFICAR ADD-ONS ESSENCIAIS
# =============================================================================
echo -e "${YELLOW}🔍 Verificando add-ons essenciais do cluster...${NC}"

REQUIRED_ADDONS=("aws-ebs-csi-driver" "aws-efs-csi-driver" "coredns" "metrics-server")
MISSING_ADDONS=()

for addon in "${REQUIRED_ADDONS[@]}"; do
    if aws eks describe-addon --cluster-name ${CLUSTER_NAME} --addon-name ${addon} --region ${AWS_REGION} &> /dev/null; then
        ADDON_STATUS=$(aws eks describe-addon --cluster-name ${CLUSTER_NAME} --addon-name ${addon} --region ${AWS_REGION} --query 'addon.status' --output text)
        if [ "$ADDON_STATUS" == "ACTIVE" ]; then
            echo -e "  ✅ ${addon}: ${GREEN}ACTIVE${NC}"
        else
            echo -e "  ⚠️  ${addon}: ${YELLOW}${ADDON_STATUS}${NC}"
        fi
    else
        echo -e "  ❌ ${addon}: ${RED}NOT INSTALLED${NC}"
        MISSING_ADDONS+=("${addon}")
    fi
done

echo ""

if [ ${#MISSING_ADDONS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Add-ons essenciais faltando:${NC}"
    for addon in "${MISSING_ADDONS[@]}"; do
        echo -e "   • ${addon}"
    done
    echo ""
    echo -e "${YELLOW}Para instalar os add-ons faltantes:${NC}"
    echo ""
    for addon in "${MISSING_ADDONS[@]}"; do
        echo -e "  ${YELLOW}aws eks create-addon --cluster-name ${CLUSTER_NAME} --addon-name ${addon} --region ${AWS_REGION}${NC}"
    done
    echo ""
    echo -e "${BLUE}ℹ️  Ou instale via Console AWS: EKS → Clusters → ${CLUSTER_NAME} → Add-ons → Get more add-ons${NC}"
    echo ""
else
    echo -e "${GREEN}✅ Todos os add-ons essenciais estão instalados${NC}"
    echo ""
fi

# =============================================================================
# CONFIGURAR IAM ROLE PARA LOKI (IRSA)
# =============================================================================
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}CONFIGURAR IAM ROLE PARA LOKI${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""

# Obter Account ID automaticamente
echo -e "${YELLOW}🔍 Obtendo Account ID da AWS...${NC}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)

if [ -z "$ACCOUNT_ID" ] || [ "$ACCOUNT_ID" == "None" ]; then
    echo -e "${RED}❌ Não foi possível obter o Account ID!${NC}"
    echo "Verifique se as credenciais AWS estão configuradas corretamente."
    exit 1
fi

echo -e "${GREEN}✅ Account ID: ${ACCOUNT_ID}${NC}"

# Obter OIDC Provider
echo -e "${YELLOW}🔍 Obtendo OIDC Provider do cluster...${NC}"
OIDC_URL=$(aws eks describe-cluster \
    --name ${CLUSTER_NAME} \
    --region ${AWS_REGION} \
    --query 'cluster.identity.oidc.issuer' \
    --output text 2>/dev/null)

if [ -z "$OIDC_URL" ] || [ "$OIDC_URL" == "None" ]; then
    echo -e "${RED}❌ Cluster '${CLUSTER_NAME}' não encontrado na região ${AWS_REGION}!${NC}"
    echo "Verifique se o cluster existe e se a região está correta."
    exit 1
fi

OIDC_ID=$(echo $OIDC_URL | awk -F'/' '{print $NF}')
echo -e "${GREEN}✅ OIDC Provider ID: ${OIDC_ID}${NC}"
echo ""

# Verificar se OIDC Provider existe
echo -e "${YELLOW}🔍 Verificando OIDC Provider no IAM...${NC}"
OIDC_PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/oidc.eks.${AWS_REGION}.amazonaws.com/id/${OIDC_ID}"

if aws iam get-open-id-connect-provider --open-id-connect-provider-arn ${OIDC_PROVIDER_ARN} &> /dev/null; then
    echo -e "${GREEN}✅ OIDC Provider já existe${NC}"
else
    echo -e "${YELLOW}📦 Criando OIDC Provider...${NC}"
    aws iam create-open-id-connect-provider \
        --url ${OIDC_URL} \
        --client-id-list sts.amazonaws.com \
        --region ${AWS_REGION} &> /dev/null
    echo -e "${GREEN}✅ OIDC Provider criado${NC}"
fi
echo ""

# Criar buckets S3 para Loki (com Account ID para garantir unicidade global)
echo -e "${YELLOW}🪣 Verificando buckets S3 para Loki...${NC}"
BUCKET_SUFFIX="${ACCOUNT_ID}"
BUCKETS=(
    "loki-observability-lab-chunks-${BUCKET_SUFFIX}"
    "loki-observability-lab-ruler-${BUCKET_SUFFIX}"
    "loki-observability-lab-admin-${BUCKET_SUFFIX}"
)

for bucket in "${BUCKETS[@]}"; do
    if aws s3 ls "s3://${bucket}" --region ${AWS_REGION} &> /dev/null; then
        echo -e "  ✅ Bucket ${bucket} já existe"
    else
        echo -e "  ${YELLOW}📦 Criando bucket ${bucket}...${NC}"
        
        # Criar bucket
        if aws s3 mb "s3://${bucket}" --region ${AWS_REGION} 2>/dev/null; then
            # Habilitar versionamento
            aws s3api put-bucket-versioning \
                --bucket ${bucket} \
                --versioning-configuration Status=Enabled \
                --region ${AWS_REGION}
            
            # Adicionar tags
            aws s3api put-bucket-tagging \
                --bucket ${bucket} \
                --tagging "TagSet=[{Key=Project,Value=observability-lab},{Key=ManagedBy,Value=setup-eks-script}]" \
                --region ${AWS_REGION}
            
            echo -e "  ${GREEN}✅ Bucket ${bucket} criado com versionamento e tags${NC}"
        else
            echo -e "  ${RED}❌ Erro ao criar bucket ${bucket}${NC}"
            echo -e "  ${YELLOW}Verifique se o nome já está em uso ou se há permissões suficientes${NC}"
        fi
    fi
done
echo ""

# Criar IAM Policy para Loki
echo -e "${YELLOW}🔐 Verificando IAM Policy para Loki...${NC}"
POLICY_NAME="LokiS3AccessPolicy"
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

if aws iam get-policy --policy-arn ${POLICY_ARN} &> /dev/null; then
    echo -e "${GREEN}✅ Policy ${POLICY_NAME} já existe${NC}"
else
    echo -e "${YELLOW}📦 Criando Policy ${POLICY_NAME}...${NC}"
    
    # Criar policy JSON temporário com os nomes corretos dos buckets
    cat > /tmp/loki-s3-policy.json <<EOF
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
                "arn:aws:s3:::loki-observability-lab-chunks-${ACCOUNT_ID}",
                "arn:aws:s3:::loki-observability-lab-ruler-${ACCOUNT_ID}",
                "arn:aws:s3:::loki-observability-lab-admin-${ACCOUNT_ID}"
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
                "arn:aws:s3:::loki-observability-lab-chunks-${ACCOUNT_ID}/*",
                "arn:aws:s3:::loki-observability-lab-ruler-${ACCOUNT_ID}/*",
                "arn:aws:s3:::loki-observability-lab-admin-${ACCOUNT_ID}/*"
            ]
        }
    ]
}
EOF
    
    # Criar policy usando o arquivo JSON temporário
    aws iam create-policy \
        --policy-name ${POLICY_NAME} \
        --policy-document file:///tmp/loki-s3-policy.json \
        --description "Policy for Loki to access S3 buckets for log storage" \
        --region ${AWS_REGION} &> /dev/null
    
    # Limpar arquivo temporário
    rm /tmp/loki-s3-policy.json
    
    echo -e "${GREEN}✅ Policy ${POLICY_NAME} criada${NC}"
fi
echo ""

# Criar IAM Role para Loki
echo -e "${YELLOW}🔐 Verificando IAM Role para Loki...${NC}"
ROLE_NAME="LokiS3AccessRole"

if aws iam get-role --role-name ${ROLE_NAME} &> /dev/null; then
    echo -e "${GREEN}✅ Role ${ROLE_NAME} já existe${NC}"
else
    echo -e "${YELLOW}📦 Criando Role ${ROLE_NAME}...${NC}"
    
    # Criar trust policy temporário
    cat > /tmp/loki-trust-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/oidc.eks.${AWS_REGION}.amazonaws.com/id/${OIDC_ID}"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "oidc.eks.${AWS_REGION}.amazonaws.com/id/${OIDC_ID}:sub": "system:serviceaccount:monitoring:loki",
                    "oidc.eks.${AWS_REGION}.amazonaws.com/id/${OIDC_ID}:aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}
EOF
    
    # Criar role
    aws iam create-role \
        --role-name ${ROLE_NAME} \
        --assume-role-policy-document file:///tmp/loki-trust-policy.json \
        --description "Role for Loki ServiceAccount to access S3 buckets" \
        --region ${AWS_REGION} &> /dev/null
    
    # Anexar policy à role
    aws iam attach-role-policy \
        --role-name ${ROLE_NAME} \
        --policy-arn ${POLICY_ARN} \
        --region ${AWS_REGION}
    
    # Limpar arquivo temporário
    rm /tmp/loki-trust-policy.json
    
    echo -e "${GREEN}✅ Role ${ROLE_NAME} criada e policy anexada${NC}"
fi

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo -e "${GREEN}✅ Role ARN: ${ROLE_ARN}${NC}"
echo ""

echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}✅ Configuração IAM para Loki concluída!${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo -e "Recursos criados/verificados:"
echo -e "  ✅ OIDC Provider: ${YELLOW}${OIDC_ID}${NC}"
echo -e "  ✅ Buckets S3:"
echo -e "     • ${YELLOW}loki-observability-lab-chunks-${ACCOUNT_ID}${NC}"
echo -e "     • ${YELLOW}loki-observability-lab-ruler-${ACCOUNT_ID}${NC}"
echo -e "     • ${YELLOW}loki-observability-lab-admin-${ACCOUNT_ID}${NC}"
echo -e "  ✅ IAM Policy: ${YELLOW}${POLICY_NAME}${NC}"
echo -e "  ✅ IAM Role: ${YELLOW}${ROLE_NAME}${NC}"
echo ""

# =============================================================================
# ATUALIZAR VALUES.YAML DO LOKI
# =============================================================================
echo -e "${YELLOW}📝 Atualizando helm-values/loki-stack/values.yaml...${NC}"

# Atualizar nomes dos buckets (substituir ACCOUNT_ID pelo valor real)
echo -e "${YELLOW}📝 Atualizando nomes dos buckets no values.yaml...${NC}"

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s|chunks: loki-observability-lab-chunks-[0-9]*|chunks: loki-observability-lab-chunks-${ACCOUNT_ID}|" helm-values/loki-stack/values.yaml
    sed -i '' "s|chunks: loki-observability-lab-chunks-ACCOUNT_ID|chunks: loki-observability-lab-chunks-${ACCOUNT_ID}|" helm-values/loki-stack/values.yaml
    
    sed -i '' "s|ruler: loki-observability-lab-ruler-[0-9]*|ruler: loki-observability-lab-ruler-${ACCOUNT_ID}|" helm-values/loki-stack/values.yaml
    sed -i '' "s|ruler: loki-observability-lab-ruler-ACCOUNT_ID|ruler: loki-observability-lab-ruler-${ACCOUNT_ID}|" helm-values/loki-stack/values.yaml
    
    sed -i '' "s|admin: loki-observability-lab-admin-[0-9]*|admin: loki-observability-lab-admin-${ACCOUNT_ID}|" helm-values/loki-stack/values.yaml
    sed -i '' "s|admin: loki-observability-lab-admin-ACCOUNT_ID|admin: loki-observability-lab-admin-${ACCOUNT_ID}|" helm-values/loki-stack/values.yaml
else
    # Linux
    sed -i "s|chunks: loki-observability-lab-chunks-[0-9]*|chunks: loki-observability-lab-chunks-${ACCOUNT_ID}|" helm-values/loki-stack/values.yaml
    sed -i "s|chunks: loki-observability-lab-chunks-ACCOUNT_ID|chunks: loki-observability-lab-chunks-${ACCOUNT_ID}|" helm-values/loki-stack/values.yaml
    
    sed -i "s|ruler: loki-observability-lab-ruler-[0-9]*|ruler: loki-observability-lab-ruler-${ACCOUNT_ID}|" helm-values/loki-stack/values.yaml
    sed -i "s|ruler: loki-observability-lab-ruler-ACCOUNT_ID|ruler: loki-observability-lab-ruler-${ACCOUNT_ID}|" helm-values/loki-stack/values.yaml
    
    sed -i "s|admin: loki-observability-lab-admin-[0-9]*|admin: loki-observability-lab-admin-${ACCOUNT_ID}|" helm-values/loki-stack/values.yaml
    sed -i "s|admin: loki-observability-lab-admin-ACCOUNT_ID|admin: loki-observability-lab-admin-${ACCOUNT_ID}|" helm-values/loki-stack/values.yaml
fi
echo -e "${GREEN}✅ Nomes dos buckets atualizados no values.yaml${NC}"

# Atualizar ARN da role (substituir ACCOUNT_ID pelo valor real)
echo -e "${YELLOW}📝 Atualizando ARN da role no values.yaml...${NC}"

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s|arn:aws:iam::[0-9]*:role/LokiS3AccessRole|arn:aws:iam::${ACCOUNT_ID}:role/LokiS3AccessRole|" helm-values/loki-stack/values.yaml
    sed -i '' "s|arn:aws:iam::ACCOUNT_ID:role/LokiS3AccessRole|arn:aws:iam::${ACCOUNT_ID}:role/LokiS3AccessRole|" helm-values/loki-stack/values.yaml
else
    # Linux
    sed -i "s|arn:aws:iam::[0-9]*:role/LokiS3AccessRole|arn:aws:iam::${ACCOUNT_ID}:role/LokiS3AccessRole|" helm-values/loki-stack/values.yaml
    sed -i "s|arn:aws:iam::ACCOUNT_ID:role/LokiS3AccessRole|arn:aws:iam::${ACCOUNT_ID}:role/LokiS3AccessRole|" helm-values/loki-stack/values.yaml
fi
echo -e "${GREEN}✅ ARN da role atualizado no values.yaml${NC}"

echo -e "${GREEN}✅ Arquivo values.yaml atualizado com sucesso!${NC}"
echo ""
echo -e "${BLUE}ℹ️  Verificar configuração:${NC}"
echo -e "   ${YELLOW}grep -A 3 'bucketNames:' helm-values/loki-stack/values.yaml${NC}"
echo -e "   ${YELLOW}grep 'eks.amazonaws.com/role-arn' helm-values/loki-stack/values.yaml${NC}"
echo ""

# Obter VPC ID do cluster
echo -e "${YELLOW}🔍 Obtendo VPC ID do cluster...${NC}"
VPC_ID=$(aws eks describe-cluster \
    --name ${CLUSTER_NAME} \
    --region ${AWS_REGION} \
    --query 'cluster.resourcesVpcConfig.vpcId' \
    --output text 2>/dev/null)

if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
    echo -e "${RED}❌ Cluster '${CLUSTER_NAME}' não encontrado na região ${AWS_REGION}!${NC}"
    echo "Verifique se o cluster existe e se a região está correta."
    exit 1
fi

echo -e "${GREEN}✅ VPC ID: ${VPC_ID}${NC}"
echo ""

# Obter subnets públicas
echo -e "${YELLOW}🔍 Obtendo subnets públicas...${NC}"
PUBLIC_SUBNETS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=${VPC_ID}" "Name=map-public-ip-on-launch,Values=true" \
    --region ${AWS_REGION} \
    --query 'Subnets[*].SubnetId' \
    --output text)

if [ -z "$PUBLIC_SUBNETS" ]; then
    echo -e "${RED}❌ Nenhuma subnet pública encontrada!${NC}"
    exit 1
fi

SUBNET_COUNT=$(echo $PUBLIC_SUBNETS | wc -w)
echo -e "${GREEN}✅ Encontradas ${SUBNET_COUNT} subnets públicas${NC}"
echo ""

# Adicionar tags nas subnets
echo -e "${YELLOW}🏷️  Adicionando tags nas subnets...${NC}"
echo ""

for subnet in $PUBLIC_SUBNETS; do
    echo -e "  Processando subnet: ${YELLOW}${subnet}${NC}"
    
    # Tag para ELB (Load Balancers públicos)
    aws ec2 create-tags \
        --resources ${subnet} \
        --tags Key=kubernetes.io/role/elb,Value=1 \
        --region ${AWS_REGION}
    
    # Tag para o cluster específico
    aws ec2 create-tags \
        --resources ${subnet} \
        --tags Key=kubernetes.io/cluster/${CLUSTER_NAME},Value=shared \
        --region ${AWS_REGION}
    
    echo -e "  ${GREEN}✅ Tags adicionadas${NC}"
done

echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}✅ Configuração de tags concluída com sucesso!${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo -e "Tags adicionadas:"
echo -e "  • ${YELLOW}kubernetes.io/role/elb=1${NC} (para Load Balancers públicos)"
echo -e "  • ${YELLOW}kubernetes.io/cluster/${CLUSTER_NAME}=shared${NC} (para o cluster)"
echo ""

# =============================================================================
# CONFIGURAR INGRESSCLASS ALB
# =============================================================================
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}CONFIGURAR INGRESSCLASS - ALB${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""

# Verificar se kubectl está instalado
if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}⚠️  kubectl não está instalado - pulando configuração de IngressClass${NC}"
    echo -e "Instale kubectl e execute: ${YELLOW}kubectl apply -f kubernetes/alb-ingressclass.yaml${NC}"
else
    # Verificar conexão com cluster
    echo -e "${YELLOW}🔍 Verificando conexão com cluster...${NC}"
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${YELLOW}⚠️  Não conectado ao cluster - pulando configuração de IngressClass${NC}"
        echo -e "Execute: ${YELLOW}aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}${NC}"
        echo -e "Depois: ${YELLOW}kubectl apply -f kubernetes/alb-ingressclass.yaml${NC}"
    else
        echo -e "${GREEN}✅ Conectado ao cluster${NC}"
        echo ""
        
        # Aplicar configuração de IngressClass
        echo -e "${YELLOW}🚀 Aplicando IngressClass para ALB...${NC}"
        if kubectl apply -f kubernetes/alb-ingressclass.yaml 2>/dev/null; then
            echo -e "${GREEN}✅ IngressClass ALB configurada${NC}"
            echo ""
            echo -e "${YELLOW}📋 IngressClasses disponíveis:${NC}"
            kubectl get ingressclass
            echo ""
            echo -e "${YELLOW}📋 IngressClassParams:${NC}"
            kubectl get ingressclassparams
        else
            echo -e "${YELLOW}⚠️  Não foi possível aplicar IngressClass${NC}"
            echo -e "Execute manualmente: ${YELLOW}kubectl apply -f kubernetes/alb-ingressclass.yaml${NC}"
        fi
        
        echo ""
        
        # Aplicar StorageClass GP3
        echo -e "${YELLOW}🚀 Aplicando StorageClass GP3 (EBS CSI Driver)...${NC}"
        
        if kubectl apply -f kubernetes/gp3-storageclass.yaml 2>/dev/null; then
            echo -e "${GREEN}✅ StorageClass GP3 configurado${NC}"
            echo ""
            echo -e "${YELLOW}📋 StorageClasses disponíveis:${NC}"
            kubectl get storageclass
        else
            echo -e "${YELLOW}⚠️  Não foi possível aplicar StorageClass${NC}"
            echo -e "Execute manualmente: ${YELLOW}kubectl apply -f kubernetes/gp3-storageclass.yaml${NC}"
        fi
        
        echo ""
        
        # Criar namespace monitoring se não existir
        echo -e "${YELLOW}🔍 Verificando namespace monitoring...${NC}"
        if ! kubectl get namespace monitoring &> /dev/null; then
            echo -e "${YELLOW}📦 Criando namespace monitoring...${NC}"
            kubectl create namespace monitoring
            echo -e "${GREEN}✅ Namespace monitoring criado${NC}"
        else
            echo -e "${GREEN}✅ Namespace monitoring já existe${NC}"
        fi
        
        echo ""
        
        # Aplicar Ingress base (sem regras específicas)
        echo -e "${YELLOW}🚀 Aplicando Ingress base (eks-lab-ingress)...${NC}"
        
        # Atualizar certificado ACM no Ingress antes de aplicar
        if [ "$ACM_CERTIFICATE_ARN" != "NONE" ]; then
            echo -e "${YELLOW}📝 Atualizando certificado ACM no Ingress...${NC}"
            
            # Criar arquivo temporário com o certificado atualizado
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                sed "s|alb.ingress.kubernetes.io/certificate-arn:.*|alb.ingress.kubernetes.io/certificate-arn: ${ACM_CERTIFICATE_ARN}|" kubernetes/eks-lab-ingress.yaml > /tmp/eks-lab-ingress-temp.yaml
            else
                # Linux
                sed "s|alb.ingress.kubernetes.io/certificate-arn:.*|alb.ingress.kubernetes.io/certificate-arn: ${ACM_CERTIFICATE_ARN}|" kubernetes/eks-lab-ingress.yaml > /tmp/eks-lab-ingress-temp.yaml
            fi
            
            if kubectl apply -f /tmp/eks-lab-ingress-temp.yaml 2>/dev/null; then
                echo -e "${GREEN}✅ Ingress base configurado com HTTPS${NC}"
                rm /tmp/eks-lab-ingress-temp.yaml
            else
                echo -e "${YELLOW}⚠️  Não foi possível aplicar Ingress base${NC}"
                echo -e "Execute manualmente: ${YELLOW}kubectl apply -f kubernetes/eks-lab-ingress.yaml${NC}"
                rm /tmp/eks-lab-ingress-temp.yaml
            fi
        else
            echo -e "${YELLOW}⚠️  Aplicando Ingress sem certificado ACM (HTTP apenas)${NC}"
            
            # Criar arquivo temporário sem a linha do certificado
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                sed '/alb.ingress.kubernetes.io\/certificate-arn:/d' kubernetes/eks-lab-ingress.yaml | \
                sed '/alb.ingress.kubernetes.io\/ssl-redirect:/d' > /tmp/eks-lab-ingress-temp.yaml
            else
                # Linux
                sed '/alb.ingress.kubernetes.io\/certificate-arn:/d' kubernetes/eks-lab-ingress.yaml | \
                sed '/alb.ingress.kubernetes.io\/ssl-redirect:/d' > /tmp/eks-lab-ingress-temp.yaml
            fi
            
            if kubectl apply -f /tmp/eks-lab-ingress-temp.yaml 2>/dev/null; then
                echo -e "${GREEN}✅ Ingress base configurado (HTTP apenas)${NC}"
                rm /tmp/eks-lab-ingress-temp.yaml
            else
                echo -e "${YELLOW}⚠️  Não foi possível aplicar Ingress base${NC}"
                echo -e "Execute manualmente: ${YELLOW}kubectl apply -f kubernetes/eks-lab-ingress.yaml${NC}"
                rm /tmp/eks-lab-ingress-temp.yaml
            fi
        fi
        
        echo ""
        echo -e "${YELLOW}📋 Ingress criado:${NC}"
        kubectl get ingress -n monitoring eks-lab-ingress 2>/dev/null || echo "Ingress não encontrado"
            echo ""
            echo -e "${BLUE}ℹ️  O ALB será criado automaticamente pelo Auto Mode${NC}"
            echo -e "   Nome do ALB: ${YELLOW}eks-lab-alb${NC}"
            echo ""
            echo -e "${BLUE}ℹ️  Ao instalar o kube-prometheus-stack, os Ingress de Grafana e Prometheus${NC}"
            echo -e "   serão criados automaticamente e usarão este ALB compartilhado.${NC}"
        else
            echo -e "${YELLOW}⚠️  Não foi possível aplicar Ingress base${NC}"
            echo -e "Execute manualmente: ${YELLOW}kubectl apply -f kubernetes/eks-lab-ingress.yaml${NC}"
        fi
    fi
fi

# =============================================================================
# CONFIGURAR NODEPOOL (APENAS DESENVOLVIMENTO)
# =============================================================================
if [ "$ENV_DEV" = true ]; then
    echo -e "${GREEN}==============================================================================${NC}"
    echo -e "${GREEN}CONFIGURAR NODEPOOL - Família T (Desenvolvimento)${NC}"
    echo -e "${GREEN}==============================================================================${NC}"
    echo ""

    # Verificar se kubectl está instalado
    if ! command -v kubectl &> /dev/null; then
        echo -e "${YELLOW}⚠️  kubectl não está instalado - pulando configuração de NodePool${NC}"
        echo -e "Instale kubectl e execute: ${YELLOW}kubectl apply -f kubernetes/nodepool-t-family.yaml${NC}"
    else
        # Verificar conexão com cluster
        echo -e "${YELLOW}🔍 Verificando conexão com cluster...${NC}"
        if ! kubectl cluster-info &> /dev/null; then
            echo -e "${YELLOW}⚠️  Não conectado ao cluster - pulando configuração de NodePool${NC}"
            echo -e "Execute: ${YELLOW}aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}${NC}"
            echo -e "Depois: ${YELLOW}kubectl apply -f kubernetes/nodepool-t-family.yaml${NC}"
        else
            echo -e "${GREEN}✅ Conectado ao cluster${NC}"
            echo ""
            
            # Aplicar patch no NodePool
            echo -e "${YELLOW}🚀 Configurando NodePools para família T com Spot...${NC}"
            
            # Patch no general-purpose
            if kubectl patch nodepool general-purpose --type=merge --patch-file=kubernetes/nodepool-t-family-patch.yaml 2>/dev/null; then
                echo -e "${GREEN}✅ NodePool general-purpose configurado (até t3.xlarge)${NC}"
            else
                echo -e "${YELLOW}⚠️  Não foi possível aplicar patch no NodePool general-purpose${NC}"
            fi
            
            # Patch no system
            if kubectl patch nodepool system --type=merge --patch-file=kubernetes/nodepool-system-patch.yaml 2>/dev/null; then
                echo -e "${GREEN}✅ NodePool system configurado (t3.small/medium)${NC}"
            else
                echo -e "${YELLOW}⚠️  Não foi possível aplicar patch no NodePool system${NC}"
            fi
            
            echo ""
            echo -e "${YELLOW}📋 Tamanhos permitidos:${NC}"
            echo -e "  • general-purpose: t3.nano até t3.xlarge"
            echo -e "  • system: t3.small e t3.medium"
        fi
    fi
else
    echo ""
    echo -e "${BLUE}ℹ️  Modo PRODUÇÃO: NodePool não será restrito${NC}"
    echo -e "   O Auto Mode selecionará instâncias automaticamente"
    echo -e "   Para ambiente de desenvolvimento, use: ${YELLOW}$0 --env-dev${NC}"
fi

echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}✅ Setup EKS concluído!${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo -e "Configurações aplicadas:"
echo -e "  ✅ OIDC Provider"
echo -e "  ✅ Buckets S3 para Loki"
echo -e "  ✅ IAM Policy e Role para Loki (IRSA)"
echo -e "  ✅ Tags nas subnets"
echo -e "  ✅ IngressClass ALB"
echo -e "  ✅ StorageClass GP3"
echo -e "  ✅ Namespace monitoring"
echo -e "  ✅ Ingress base (eks-lab-alb)"
if [ "$ACM_CERTIFICATE_ARN" != "NONE" ]; then
    echo -e "  ✅ Certificado ACM configurado (HTTPS)"
else
    echo -e "  ⚠️  Certificado ACM não configurado (HTTP apenas)"
fi
if [ "$ENV_DEV" = true ]; then
    echo -e "  ✅ NodePool família T + Spot (desenvolvimento)"
fi
echo ""
echo -e "Próximos passos:"
echo -e "  1. Instalar kube-prometheus-stack: ${YELLOW}helm upgrade --install ...${NC}"
echo -e "     (Os Ingress de Grafana e Prometheus serão criados automaticamente)"
echo -e "  2. Instalar Loki: ${YELLOW}helm upgrade --install loki grafana/loki ...${NC}"
echo -e "     (Role IAM já configurada no values.yaml)"
echo -e "  3. Verificar ALB e Ingress: ${YELLOW}kubectl get ingress -n monitoring${NC}"
if [ "$ACM_CERTIFICATE_ARN" != "NONE" ]; then
    echo -e "  4. Configurar DNS apontando para o ALB"
    echo -e "     ${YELLOW}kubectl get ingress -n monitoring eks-lab-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'${NC}"
else
    echo -e "  4. ${YELLOW}[OPCIONAL]${NC} Configurar certificado ACM para HTTPS:"
    echo -e "     a. Criar certificado no ACM"
    echo -e "     b. Executar novamente: ${YELLOW}$0 --certificate-arn arn:aws:acm:...${NC}"
fi
echo ""
