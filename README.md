# Aula 07 - Observabilidade no Kubernetes

Materiais práticos da **Aula 07** do módulo **Monitoramento OpenSource** da PosTech DevOps e Arquitetura Cloud.

---

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Versões Recomendadas](#versões-recomendadas)
- [Arquitetura](#arquitetura)
- [Início Rápido](#início-rápido)
- [Guias Detalhados](#guias-detalhados)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Comandos Úteis](#comandos-úteis)
- [Limpeza do Ambiente](#limpeza-do-ambiente)

---

## Visão Geral

Aprenda a implementar observabilidade completa em ambientes Kubernetes usando ferramentas open-source modernas.

### 🎯 Objetivos

- Integrar stack de observabilidade (Prometheus, Grafana, Loki) em cluster Kubernetes
- Entender melhores práticas de deployment e coleta de dados
- Dominar Prometheus Operator e descoberta automática de métricas
- Configurar ServiceMonitor e PodMonitor
- Analisar logs com Loki e correlacionar com métricas

### 📚 Teoria Abordada

- Observabilidade em ambientes orquestrados vs. monitoramento tradicional
- Prometheus Operator e gerenciamento declarativo
- Service Discovery automático no Kubernetes
- Labels e Selectors para organização
- Agregação de logs em ambientes distribuídos
- Boas práticas de deployment para produção

---

## Versões Recomendadas

| Componente | Versão | Status |
|------------|--------|--------|
| **Kubernetes** | 1.34 (estável) ou 1.35 (mais recente) | ✅ Testado |
| **EKS** | Suporta 1.31 a 1.35 | ✅ Compatível |
| **kube-prometheus-stack** | 77.x+ | ✅ Recomendado |
| **Loki** | 6.x+ | ✅ Recomendado |
| **Promtail** | 6.x+ | ✅ Recomendado |

💡 **Nota**: Este laboratório foi testado com Kubernetes 1.34. Versões mais recentes devem funcionar, mas podem requerer ajustes nos add-ons.

---

## Arquitetura

### Componentes Principais

```
┌─────────────────────────────────────────────────────────────┐
│                    EKS CLUSTER (Auto Mode)                  │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │   MONITORING    │  │   APPLICATIONS  │  │   INGRESS   │ │
│  │                 │  │                 │  │             │ │
│  │ • Prometheus    │  │ • Demo Apps     │  │ • ALB       │ │
│  │ • Grafana       │  │ • ServiceMon    │  │ • HTTPS     │ │
│  │ • Loki          │  │ • PodMonitor    │  │ • DNS       │ │
│  │ • Alertmanager  │  │                 │  │             │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Stack de Observabilidade

- **Prometheus Operator**: Gerenciamento declarativo de monitoramento
- **Grafana**: Visualização unificada de métricas e logs
- **Loki**: Agregação de logs otimizada para Kubernetes
- **Promtail**: Coleta automática de logs de todos os pods
- **ServiceMonitor/PodMonitor**: Descoberta automática de targets
- **Node Exporter**: Métricas dos nodes
- **Kube State Metrics**: Métricas dos recursos Kubernetes

### Novidades do EKS Auto Mode

- ✅ Gerenciamento automático de nodes
- ✅ Escalonamento inteligente baseado em demanda
- ✅ Atualizações automáticas de nodes e componentes
- ✅ Storage gerenciado (EBS volumes)
- ✅ Load Balancing integrado (ALB/NLB)
- ✅ Suporte a GPU workloads (instâncias G, P, Trn)

---

## Início Rápido

### Pré-requisitos

- ✅ Conta AWS com permissões administrativas
- ✅ AWS CLI instalado e configurado → [Guia](docs/install-aws-cli.md)
- ✅ kubectl instalado → [Guia](docs/install-kubectl.md)
- ✅ Helm instalado → [Guia](docs/install-helm.md)
- ✅ Lens Desktop (opcional, mas recomendado) → [Guia](docs/install-lens.md)

### Setup em 5 Passos

#### 1️⃣ Criar Cluster EKS

```bash
# Via Console AWS (recomendado para iniciantes)
# Seguir: docs/setup-eks-lab.md

# Ou via AWS CLI
aws eks create-cluster \
  --name observability-lab-cluster \
  --version 1.34 \
  --role-arn arn:aws:iam::ACCOUNT:role/eks-service-role \
  --resources-vpc-config subnetIds=subnet-xxx,subnet-yyy
```

📖 **Guia Completo**: [docs/setup-eks-lab.md](docs/setup-eks-lab.md)

#### 2️⃣ Configurar Cluster

```bash
# Executar script de configuração automática
./scripts/setup-eks.sh

# Ou com certificado ACM para HTTPS
./scripts/setup-eks.sh --certificate-arn arn:aws:acm:...

# Ou para ambiente de desenvolvimento (família T + Spot)
./scripts/setup-eks.sh --env-dev
```

O script configura automaticamente:
- ✅ Tags nas subnets para ALB
- ✅ OIDC Provider
- ✅ Buckets S3 para Loki
- ✅ IAM Roles (IRSA)
- ✅ IngressClass e StorageClass
- ✅ Certificado ACM (se fornecido)

📖 **Documentação**: [scripts/README.md](scripts/README.md)

#### 3️⃣ Instalar Stack de Observabilidade

```bash
# Instalar kube-prometheus-stack
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values helm-values/kube-prometheus-stack/values.yaml

# Instalar Loki
helm upgrade --install loki grafana/loki \
  --namespace monitoring \
  --values helm-values/loki-stack/values.yaml

# Instalar Promtail
helm upgrade --install promtail grafana/promtail \
  --namespace monitoring \
  --values helm-values/loki-stack/promtail-values.yaml
```

📖 **Guia Completo**: [docs/deploy-observability-stack.md](docs/deploy-observability-stack.md)

#### 4️⃣ Configurar DNS

```bash
# Obter endereço do ALB
kubectl get ingress -n monitoring eks-lab-ingress

# Criar registros DNS (no seu provedor)
# grafana.demo.lynxnetwork.com.br → CNAME → ALB_HOSTNAME
# prometheus.demo.lynxnetwork.com.br → CNAME → ALB_HOSTNAME
```

#### 5️⃣ Acessar Interfaces

- **Grafana**: https://grafana.demo.lynxnetwork.com.br
  - Usuário: `admin`
  - Senha: `admin123`
- **Prometheus**: https://prometheus.demo.lynxnetwork.com.br

---

## Guias Detalhados

### 📖 Documentação Principal

| Guia | Descrição |
|------|-----------|
| [Setup do Laboratório EKS](docs/setup-eks-lab.md) | Criação e configuração do cluster EKS com Auto Mode |
| [Deploy da Stack de Observabilidade](docs/deploy-observability-stack.md) | Instalação completa de Prometheus, Grafana e Loki |
| [Deploy OpenTelemetry Demo](docs/deploy-opentelemetry-demo.md) | Aplicação de teste com múltiplos microserviços |

### 🛠️ Guias de Instalação

| Ferramenta | Guia |
|------------|------|
| AWS CLI | [docs/install-aws-cli.md](docs/install-aws-cli.md) |
| kubectl | [docs/install-kubectl.md](docs/install-kubectl.md) |
| Helm | [docs/install-helm.md](docs/install-helm.md) |
| Lens Desktop | [docs/install-lens.md](docs/install-lens.md) |

### 🔧 Scripts de Automação

| Script | Descrição |
|--------|-----------|
| [setup-eks.sh](scripts/README.md) | Configuração automática do cluster |
| Documentação completa | [scripts/README.md](scripts/README.md) |

### 📁 Configurações

| Diretório | Descrição |
|-----------|-----------|
| [helm-values/](helm-values/) | Valores customizados para Helm charts |
| [kubernetes/](kubernetes/README.md) | Manifests e templates Kubernetes |

---

## Estrutura do Projeto

```
.
├── README.md                           # Este arquivo
├── docs/                               # Documentação detalhada
│   ├── setup-eks-lab.md                # Setup do cluster EKS
│   ├── deploy-observability-stack.md   # Deploy da stack
│   ├── deploy-opentelemetry-demo.md    # Deploy da demo app
│   ├── install-aws-cli.md              # Instalação AWS CLI
│   ├── install-kubectl.md              # Instalação kubectl
│   ├── install-helm.md                 # Instalação Helm
│   └── install-lens.md                 # Instalação Lens
├── scripts/                            # Scripts de automação
│   ├── README.md                       # Documentação dos scripts
│   └── setup-eks.sh                    # Setup automático do cluster
├── helm-values/                        # Valores Helm customizados
│   ├── kube-prometheus-stack/          # Prometheus + Grafana
│   ├── loki-stack/                     # Loki + Promtail
│   └── opentelemetry-demo/             # Aplicação demo
└── kubernetes/                         # Manifests Kubernetes
    ├── README.md                       # Documentação dos manifests
    ├── alb-ingressclass.yaml           # IngressClass para ALB
    ├── eks-lab-ingress.yaml            # Ingress compartilhado
    ├── gp3-storageclass.yaml           # StorageClass GP3
    ├── loki-s3-policy.json             # Policy IAM para Loki
    └── loki-trust-policy-template.json # Trust policy para IRSA
```

---

## Comandos Úteis

### Kubernetes

```bash
# Verificar cluster
kubectl cluster-info
kubectl get nodes

# Monitoramento
kubectl get pods -n monitoring
kubectl get servicemonitor -A
kubectl get podmonitor -A

# Logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana

# Port-forward (acesso local)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

### Helm

```bash
# Listar releases
helm list -A

# Status
helm status kube-prometheus-stack -n monitoring
helm status loki -n monitoring

# Upgrade
helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring -f helm-values/kube-prometheus-stack/values.yaml
```

### Troubleshooting

```bash
# Eventos
kubectl get events -n monitoring --sort-by='.lastTimestamp'

# Recursos
kubectl top nodes
kubectl top pods -n monitoring

# Diagnóstico
kubectl describe pod <pod-name> -n monitoring
kubectl get ingress -n monitoring
```

---

## Limpeza do Ambiente

```bash
# 1. Deletar releases Helm
helm uninstall kube-prometheus-stack -n monitoring
helm uninstall loki -n monitoring
helm uninstall promtail -n monitoring

# 2. Deletar namespace
kubectl delete namespace monitoring

# 3. Deletar cluster EKS
aws eks delete-nodegroup --cluster-name observability-lab-cluster --nodegroup-name worker-nodes
aws eks delete-cluster --name observability-lab-cluster

# 4. Deletar recursos IAM (opcional)
aws iam delete-role --role-name LokiS3AccessRole
aws iam delete-policy --policy-arn arn:aws:iam::ACCOUNT:policy/LokiS3AccessPolicy

# 5. Deletar buckets S3 (opcional)
aws s3 rb s3://loki-observability-lab-chunks-ACCOUNT_ID --force
aws s3 rb s3://loki-observability-lab-ruler-ACCOUNT_ID --force
aws s3 rb s3://loki-observability-lab-admin-ACCOUNT_ID --force
```

---

## Custos Estimados

| Recurso | Configuração | Custo/hora (aprox.) |
|---------|--------------|-------------------|
| EKS Control Plane | Managed | $0.10 |
| Worker Nodes | 3x t3.medium spot | $0.14 |
| EBS Volumes | ~40GB gp3 | $0.01 |
| S3 (Loki) | Pay-as-you-go | Variável |
| ALB | 1 ALB | $0.02 |
| **Total Base** | | **~$0.27/hora** |

💡 **Dicas de Economia**:
- Use instâncias Spot (já configurado por padrão)
- Delete o cluster quando não estiver usando
- Configure lifecycle policies nos buckets S3
- Use `--env-dev` para restringir a família T

---

## Suporte e Contribuições

### Problemas Conhecidos

Consulte a documentação específica de cada componente para troubleshooting detalhado.

### Reportar Problemas

Se encontrar problemas:
1. Verifique se está usando as versões recomendadas
2. Consulte os logs: `kubectl logs -n monitoring <pod-name>`
3. Verifique eventos: `kubectl get events -n monitoring`
4. Abra uma issue no repositório com detalhes

---

## Licença

Este material é parte do curso PosTech DevOps e Arquitetura Cloud.

## Autores

- **Instrutor**: Ed Carlos Marinho
- **Instituição**: PosTech

---

**Última atualização**: Fevereiro 2026  
**Versão do Kubernetes**: 1.34  
**Versão do documento**: 2.0
