# Instalação e Configuração do Helm

Guia completo para instalar e configurar o Helm, o gerenciador de pacotes para Kubernetes.

## O que é o Helm?

Helm é o gerenciador de pacotes para Kubernetes, similar ao apt/yum para Linux ou npm para Node.js. Ele simplifica o deployment e gerenciamento de aplicações Kubernetes através de "charts" - pacotes pré-configurados de recursos Kubernetes.

### Principais Funcionalidades

📦 **Gerenciamento de Pacotes**: Instalar aplicações complexas com um único comando  
🔄 **Versionamento**: Controlar versões de releases e fazer rollback facilmente  
⚙️ **Configuração**: Customizar aplicações através de valores (values)  
🎯 **Reutilização**: Compartilhar charts entre projetos e equipes  
📊 **Templating**: Criar manifests Kubernetes dinâmicos  
🔍 **Repositórios**: Acessar milhares de charts prontos  

## Conceitos Básicos

- **Chart**: Pacote Helm contendo recursos Kubernetes
- **Release**: Instância de um chart rodando no cluster
- **Repository**: Coleção de charts disponíveis para instalação
- **Values**: Configurações customizáveis de um chart

## Instalação

### macOS

**Opção 1: Usando Homebrew (Recomendado)**

```bash
# Instalar Helm
brew install helm

# Verificar instalação
helm version
```

**Opção 2: Download Direto**

```bash
# Baixar versão mais recente
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3

# Tornar executável
chmod 700 get_helm.sh

# Executar instalador
./get_helm.sh

# Verificar instalação
helm version
```

### Linux

**Ubuntu/Debian**

```bash
# Instalar via Snap
sudo snap install helm --classic

# Verificar instalação
helm version
```

**Usando Script de Instalação (Qualquer Distribuição)**

```bash
# Baixar e executar script
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verificar instalação
helm version
```

**Download Direto**

```bash
# Baixar versão específica
wget https://get.helm.sh/helm-v3.14.0-linux-amd64.tar.gz

# Extrair
tar -zxvf helm-v3.14.0-linux-amd64.tar.gz

# Mover para PATH
sudo mv linux-amd64/helm /usr/local/bin/helm

# Verificar instalação
helm version
```

### Windows

**Opção 1: Usando Chocolatey (Recomendado)**

```powershell
# Instalar Helm
choco install kubernetes-helm

# Verificar instalação
helm version
```

**Opção 2: Usando Winget**

```powershell
# Instalar Helm
winget install Helm.Helm

# Verificar instalação
helm version
```

**Opção 3: Usando Scoop**

```powershell
# Instalar Helm
scoop install helm

# Verificar instalação
helm version
```

**Opção 4: Download Direto**

```powershell
# Baixar do site oficial
# https://github.com/helm/helm/releases

# Extrair arquivo ZIP
# Adicionar helm.exe ao PATH

# Verificar instalação
helm version
```

## Configuração Inicial

### Adicionar Repositórios

```bash
# Adicionar repositório oficial de charts estáveis
helm repo add stable https://charts.helm.sh/stable

# Adicionar repositório Bitnami (recomendado)
helm repo add bitnami https://charts.bitnami.com/bitnami

# Adicionar repositório Prometheus Community
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Adicionar repositório Grafana
helm repo add grafana https://grafana.github.io/helm-charts

# Atualizar repositórios
helm repo update

# Listar repositórios
helm repo list
```

### Repositórios Úteis para Observabilidade

```bash
# Prometheus Stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Grafana
helm repo add grafana https://grafana.github.io/helm-charts

# Loki
helm repo add grafana https://grafana.github.io/helm-charts

# Ingress NGINX
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

# Cert Manager
helm repo add jetstack https://charts.jetstack.io

# Metrics Server
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server

# Atualizar todos
helm repo update
```

## Comandos Essenciais

### Buscar Charts

```bash
# Buscar chart em todos os repositórios
helm search repo prometheus

# Buscar chart no Artifact Hub
helm search hub prometheus

# Ver versões disponíveis
helm search repo prometheus-community/kube-prometheus-stack --versions
```

### Instalar Charts

```bash
# Instalação básica
helm install meu-release nome-repo/nome-chart

# Instalar em namespace específico
helm install meu-release nome-repo/nome-chart --namespace monitoring --create-namespace

# Instalar com valores customizados
helm install meu-release nome-repo/nome-chart -f values.yaml

# Instalar com valores inline
helm install meu-release nome-repo/nome-chart --set key=value

# Instalar versão específica
helm install meu-release nome-repo/nome-chart --version 1.2.3

# Dry-run (simular instalação)
helm install meu-release nome-repo/nome-chart --dry-run --debug
```

### Listar Releases

```bash
# Listar releases no namespace atual
helm list

# Listar em todos os namespaces
helm list --all-namespaces

# Listar releases com status específico
helm list --failed
helm list --pending
```

### Atualizar Releases

```bash
# Atualizar release
helm upgrade meu-release nome-repo/nome-chart

# Atualizar com novos valores
helm upgrade meu-release nome-repo/nome-chart -f values.yaml

# Atualizar ou instalar se não existir
helm upgrade --install meu-release nome-repo/nome-chart

# Atualizar para versão específica
helm upgrade meu-release nome-repo/nome-chart --version 2.0.0
```

### Desinstalar Releases

```bash
# Desinstalar release
helm uninstall meu-release

# Desinstalar de namespace específico
helm uninstall meu-release --namespace monitoring

# Manter histórico
helm uninstall meu-release --keep-history
```

### Inspecionar Charts

```bash
# Ver informações do chart
helm show chart nome-repo/nome-chart

# Ver valores padrão
helm show values nome-repo/nome-chart

# Ver README
helm show readme nome-repo/nome-chart

# Ver tudo
helm show all nome-repo/nome-chart

# Baixar chart localmente
helm pull nome-repo/nome-chart

# Baixar e extrair
helm pull nome-repo/nome-chart --untar
```

### Histórico e Rollback

```bash
# Ver histórico de releases
helm history meu-release

# Fazer rollback para revisão anterior
helm rollback meu-release

# Rollback para revisão específica
helm rollback meu-release 2

# Ver status do release
helm status meu-release

# Ver manifests gerados
helm get manifest meu-release

# Ver valores usados
helm get values meu-release
```

## Exemplo Prático: Instalar Prometheus Stack

```bash
# Adicionar repositório
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Ver valores padrão
helm show values prometheus-community/kube-prometheus-stack > values.yaml

# Editar values.yaml conforme necessário
# vim values.yaml

# Instalar
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f values.yaml

# Verificar instalação
helm list -n monitoring
kubectl get pods -n monitoring

# Acessar Grafana (port-forward)
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

## Criar Seu Próprio Chart

```bash
# Criar estrutura de chart
helm create meu-app

# Estrutura criada:
# meu-app/
#   Chart.yaml          # Metadados do chart
#   values.yaml         # Valores padrão
#   charts/             # Dependências
#   templates/          # Templates Kubernetes
#     deployment.yaml
#     service.yaml
#     ingress.yaml
#     ...

# Validar chart
helm lint meu-app

# Empacotar chart
helm package meu-app

# Instalar chart local
helm install meu-release ./meu-app

# Testar templates
helm template meu-release ./meu-app
```

## Trabalhando com Values

### Arquivo values.yaml

```yaml
# values.yaml
replicaCount: 3

image:
  repository: nginx
  tag: "1.21"
  pullPolicy: IfNotPresent

service:
  type: LoadBalancer
  port: 80

resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

### Usar Values

```bash
# Instalar com values customizados
helm install meu-release ./meu-app -f values.yaml

# Sobrescrever valores específicos
helm install meu-release ./meu-app \
  --set replicaCount=5 \
  --set image.tag=1.22

# Múltiplos arquivos de values (último tem precedência)
helm install meu-release ./meu-app \
  -f values.yaml \
  -f values-prod.yaml

# Ver valores computados
helm get values meu-release
```

## Gerenciar Repositórios

```bash
# Adicionar repositório
helm repo add meu-repo https://exemplo.com/charts

# Atualizar repositórios
helm repo update

# Listar repositórios
helm repo list

# Remover repositório
helm repo remove meu-repo

# Buscar em repositório específico
helm search repo meu-repo/
```

## Plugins Úteis

### Helm Diff

```bash
# Instalar plugin
helm plugin install https://github.com/databus23/helm-diff

# Ver diferenças antes de upgrade
helm diff upgrade meu-release nome-repo/nome-chart -f values.yaml
```

### Helm Secrets

```bash
# Instalar plugin
helm plugin install https://github.com/jkroepke/helm-secrets

# Usar secrets criptografados
helm secrets install meu-release ./meu-app -f secrets.yaml
```

### Helm Dashboard

```bash
# Instalar plugin
helm plugin install https://github.com/komodorio/helm-dashboard

# Abrir dashboard
helm dashboard
```

## Auto-Completion

### Bash

```bash
# Adicionar ao ~/.bashrc
echo 'source <(helm completion bash)' >> ~/.bashrc
source ~/.bashrc
```

### Zsh

```bash
# Adicionar ao ~/.zshrc
echo 'source <(helm completion zsh)' >> ~/.zshrc
source ~/.zshrc
```

### PowerShell

```powershell
# Adicionar ao perfil
helm completion powershell | Out-String | Invoke-Expression
```

## Troubleshooting

### Erro: "Error: Kubernetes cluster unreachable"

**Solução**: kubectl não está configurado corretamente.

```bash
# Verificar conexão
kubectl cluster-info

# Reconfigurar kubeconfig
aws eks update-kubeconfig --name observability-lab-cluster --region us-east-1
```

### Erro: "Error: release: not found"

**Solução**: Release não existe ou está em namespace diferente.

```bash
# Listar releases em todos os namespaces
helm list --all-namespaces

# Especificar namespace
helm list -n monitoring
```

### Erro: "Error: rendered manifests contain a resource that already exists"

**Solução**: Recurso já existe no cluster.

```bash
# Usar upgrade ao invés de install
helm upgrade --install meu-release nome-repo/nome-chart

# Ou deletar recurso existente
kubectl delete deployment nome-do-deployment
```

### Chart não encontrado

**Solução**: Atualizar repositórios.

```bash
# Atualizar repositórios
helm repo update

# Verificar se repositório está adicionado
helm repo list

# Buscar chart
helm search repo nome-do-chart
```

### Valores não estão sendo aplicados

**Solução**: Verificar sintaxe e precedência.

```bash
# Ver valores computados
helm get values meu-release

# Testar template localmente
helm template meu-release ./meu-app -f values.yaml --debug
```

## Boas Práticas

✅ **Use versionamento semântico** para seus charts  
✅ **Documente valores** no values.yaml com comentários  
✅ **Teste charts** com `helm lint` e `helm template`  
✅ **Use namespaces** para isolar releases  
✅ **Mantenha values.yaml** em controle de versão  
✅ **Use `--dry-run`** antes de instalar em produção  
✅ **Faça backup** de valores customizados  
✅ **Atualize repositórios** regularmente  

## Cheat Sheet

```bash
# Repositórios
helm repo add <nome> <url>          # Adicionar repositório
helm repo update                    # Atualizar repositórios
helm repo list                      # Listar repositórios

# Buscar
helm search repo <chart>            # Buscar chart
helm search hub <chart>             # Buscar no Artifact Hub

# Instalar
helm install <release> <chart>      # Instalar chart
helm install <release> <chart> -f values.yaml
helm install <release> <chart> --set key=value

# Listar
helm list                           # Listar releases
helm list -A                        # Todos os namespaces

# Atualizar
helm upgrade <release> <chart>      # Atualizar release
helm upgrade --install <release> <chart>

# Desinstalar
helm uninstall <release>            # Desinstalar release

# Informações
helm show values <chart>            # Ver valores padrão
helm get values <release>           # Ver valores usados
helm status <release>               # Status do release
helm history <release>              # Histórico

# Rollback
helm rollback <release>             # Rollback
helm rollback <release> <revision>  # Rollback para revisão
```

## Recursos Adicionais

- [Documentação Oficial Helm](https://helm.sh/docs/)
- [Artifact Hub](https://artifacthub.io/) - Repositório de charts
- [Helm Charts GitHub](https://github.com/helm/charts)
- [Best Practices](https://helm.sh/docs/chart_best_practices/)

## Próximos Passos

Com o Helm instalado e configurado, você está pronto para:

1. [Configurar o ambiente EKS](setup-eks-lab.md)
2. Instalar stack de observabilidade (Prometheus, Grafana, Loki)
3. Gerenciar aplicações complexas facilmente
4. Criar seus próprios charts customizados

## Dicas Profissionais

💡 **Use `helm diff`** antes de fazer upgrade  
💡 **Mantenha charts atualizados** com `helm repo update`  
💡 **Use `--dry-run --debug`** para testar antes de aplicar  
💡 **Organize values** em arquivos separados por ambiente  
💡 **Documente dependências** no Chart.yaml  
💡 **Use `helm template`** para debugar problemas de templating  
