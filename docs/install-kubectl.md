# Instalação e Configuração do kubectl

Guia completo para instalar e configurar o kubectl, a ferramenta de linha de comando para interagir com clusters Kubernetes.

## O que é o kubectl?

O kubectl é a ferramenta de linha de comando oficial do Kubernetes. Com ela, você pode executar comandos contra clusters Kubernetes para fazer deploy de aplicações, inspecionar e gerenciar recursos do cluster, e visualizar logs.

### Principais Funcionalidades

✨ **Gerenciamento de Recursos**: Criar, atualizar e deletar recursos Kubernetes  
📊 **Inspeção de Cluster**: Visualizar status de pods, nodes, services e mais  
🔍 **Logs e Debug**: Acessar logs de containers e fazer debug de aplicações  
⚡ **Execução de Comandos**: Executar comandos dentro de containers  
🎯 **Multi-Cluster**: Alternar entre diferentes clusters facilmente  
📝 **Manifests YAML**: Aplicar configurações declarativas  

## Instalação

### macOS

**Opção 1: Usando Homebrew (Recomendado)**

```bash
# Instalar kubectl
brew install kubectl

# Verificar instalação
kubectl version --client
```

**Opção 2: Download Direto**

```bash
# Baixar versão mais recente
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"

# Tornar executável
chmod +x ./kubectl

# Mover para PATH
sudo mv ./kubectl /usr/local/bin/kubectl

# Verificar instalação
kubectl version --client
```

**Para Apple Silicon (M1/M2/M3)**

```bash
# Baixar versão ARM64
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/arm64/kubectl"

# Tornar executável
chmod +x ./kubectl

# Mover para PATH
sudo mv ./kubectl /usr/local/bin/kubectl

# Verificar instalação
kubectl version --client
```

### Linux

**Ubuntu/Debian**

```bash
# Atualizar índice de pacotes e instalar dependências
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

# Adicionar chave de assinatura do Kubernetes
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Adicionar repositório
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Atualizar e instalar kubectl
sudo apt-get update
sudo apt-get install -y kubectl

# Verificar instalação
kubectl version --client
```

**Fedora/RHEL/CentOS**

```bash
# Adicionar repositório
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.34/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.34/rpm/repodata/repomd.xml.key
EOF

# Instalar kubectl
sudo dnf install -y kubectl

# Verificar instalação
kubectl version --client
```

**Download Direto (Qualquer Distribuição)**

```bash
# Baixar versão mais recente
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Tornar executável
chmod +x ./kubectl

# Mover para PATH
sudo mv ./kubectl /usr/local/bin/kubectl

# Verificar instalação
kubectl version --client
```

### Windows

**Opção 1: Usando Chocolatey (Recomendado)**

```powershell
# Instalar kubectl
choco install kubernetes-cli

# Verificar instalação
kubectl version --client
```

**Opção 2: Usando Winget**

```powershell
# Instalar kubectl
winget install Kubernetes.kubectl

# Verificar instalação
kubectl version --client
```

**Opção 3: Download Direto**

```powershell
# Baixar versão mais recente (verificar versão atual em https://kubernetes.io/releases/)
curl.exe -LO "https://dl.k8s.io/release/v1.34.0/bin/windows/amd64/kubectl.exe"

# Adicionar ao PATH (PowerShell como Administrador)
$env:Path += ";C:\caminho\para\kubectl"

# Tornar permanente
[Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::Machine)

# Verificar instalação
kubectl version --client
```

## Configuração

### Arquivo kubeconfig

O kubectl usa um arquivo de configuração chamado `kubeconfig` para se conectar aos clusters. Por padrão, está localizado em:

- **Linux/macOS**: `~/.kube/config`
- **Windows**: `%USERPROFILE%\.kube\config`

### Conectar ao Cluster EKS

```bash
# Configurar acesso ao cluster EKS
aws eks update-kubeconfig --name observability-lab-cluster --region us-east-1

# Verificar configuração
kubectl config view

# Testar conexão
kubectl cluster-info
kubectl get nodes
```

### Gerenciar Múltiplos Clusters

```bash
# Listar contextos (clusters) disponíveis
kubectl config get-contexts

# Ver contexto atual
kubectl config current-context

# Alternar entre contextos
kubectl config use-context nome-do-contexto

# Renomear contexto
kubectl config rename-context nome-antigo nome-novo

# Deletar contexto
kubectl config delete-context nome-do-contexto
```

## Comandos Essenciais

### Informações do Cluster

```bash
# Informações do cluster
kubectl cluster-info

# Versão do Kubernetes
kubectl version

# Listar nodes
kubectl get nodes

# Detalhes de um node
kubectl describe node nome-do-node
```

### Gerenciar Namespaces

```bash
# Listar namespaces
kubectl get namespaces

# Criar namespace
kubectl create namespace meu-namespace

# Deletar namespace
kubectl delete namespace meu-namespace

# Definir namespace padrão
kubectl config set-context --current --namespace=meu-namespace
```

### Trabalhar com Pods

```bash
# Listar pods
kubectl get pods

# Listar pods em todos os namespaces
kubectl get pods --all-namespaces

# Listar pods com mais detalhes
kubectl get pods -o wide

# Descrever pod
kubectl describe pod nome-do-pod

# Ver logs de um pod
kubectl logs nome-do-pod

# Ver logs em tempo real
kubectl logs -f nome-do-pod

# Logs de container específico (multi-container pod)
kubectl logs nome-do-pod -c nome-do-container

# Executar comando em pod
kubectl exec nome-do-pod -- comando

# Abrir shell interativo
kubectl exec -it nome-do-pod -- /bin/bash

# Copiar arquivos
kubectl cp nome-do-pod:/caminho/arquivo ./arquivo-local
```

### Deployments

```bash
# Listar deployments
kubectl get deployments

# Criar deployment
kubectl create deployment nginx --image=nginx

# Escalar deployment
kubectl scale deployment nginx --replicas=3

# Atualizar imagem
kubectl set image deployment/nginx nginx=nginx:1.21

# Ver status do rollout
kubectl rollout status deployment/nginx

# Histórico de rollout
kubectl rollout history deployment/nginx

# Fazer rollback
kubectl rollout undo deployment/nginx

# Deletar deployment
kubectl delete deployment nginx
```

### Services

```bash
# Listar services
kubectl get services

# Criar service
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Descrever service
kubectl describe service nginx

# Deletar service
kubectl delete service nginx
```

### Aplicar Manifests YAML

```bash
# Aplicar arquivo YAML
kubectl apply -f deployment.yaml

# Aplicar múltiplos arquivos
kubectl apply -f deployment.yaml -f service.yaml

# Aplicar diretório inteiro
kubectl apply -f ./manifests/

# Aplicar de URL
kubectl apply -f https://exemplo.com/manifest.yaml

# Deletar recursos de arquivo
kubectl delete -f deployment.yaml
```

### Port Forwarding

```bash
# Encaminhar porta local para pod
kubectl port-forward pod/nome-do-pod 8080:80

# Encaminhar para service
kubectl port-forward service/nome-do-service 8080:80

# Encaminhar para deployment
kubectl port-forward deployment/nome-do-deployment 8080:80
```

### Recursos Diversos

```bash
# Listar todos os recursos
kubectl get all

# Listar recursos específicos
kubectl get pods,services,deployments

# Formato de saída JSON
kubectl get pods -o json

# Formato de saída YAML
kubectl get pod nome-do-pod -o yaml

# Usar JSONPath
kubectl get pods -o jsonpath='{.items[*].metadata.name}'

# Watch (atualização contínua)
kubectl get pods --watch
```

## Auto-Completion

### Bash

```bash
# Instalar auto-completion
echo 'source <(kubectl completion bash)' >> ~/.bashrc

# Alias 'k' para kubectl
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc

# Recarregar
source ~/.bashrc
```

### Zsh

```bash
# Instalar auto-completion
echo 'source <(kubectl completion zsh)' >> ~/.zshrc

# Alias 'k' para kubectl
echo 'alias k=kubectl' >> ~/.zshrc
echo 'compdef __start_kubectl k' >> ~/.zshrc

# Recarregar
source ~/.zshrc
```

### PowerShell

```powershell
# Adicionar ao perfil
kubectl completion powershell | Out-String | Invoke-Expression

# Tornar permanente
kubectl completion powershell >> $PROFILE
```

## Plugins Úteis

### Krew (Gerenciador de Plugins)

```bash
# Instalar Krew (macOS/Linux)
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)

# Adicionar ao PATH
echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Listar plugins disponíveis
kubectl krew search

# Instalar plugin
kubectl krew install ctx
kubectl krew install ns
```

### Plugins Recomendados

```bash
# ctx - Alternar contextos facilmente
kubectl krew install ctx
kubectl ctx

# ns - Alternar namespaces facilmente
kubectl krew install ns
kubectl ns

# tree - Visualizar hierarquia de recursos
kubectl krew install tree
kubectl tree deployment nginx

# neat - Limpar output YAML
kubectl krew install neat
kubectl get pod nome-do-pod -o yaml | kubectl neat
```

## Configurações Avançadas

### Aliases Úteis

Adicione ao seu `~/.bashrc` ou `~/.zshrc`:

```bash
# Alias kubectl
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgd='kubectl get deployments'
alias kgn='kubectl get nodes'
alias kdp='kubectl describe pod'
alias kds='kubectl describe service'
alias kdd='kubectl describe deployment'
alias kl='kubectl logs'
alias klf='kubectl logs -f'
alias kex='kubectl exec -it'
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'
```

### Variáveis de Ambiente

```bash
# Definir namespace padrão
export KUBECTL_NAMESPACE=meu-namespace

# Definir editor padrão
export KUBE_EDITOR=vim

# Definir kubeconfig customizado
export KUBECONFIG=~/.kube/config:~/.kube/config-cluster2
```

## Troubleshooting

### Erro: "The connection to the server was refused"

**Solução**: Cluster não está acessível ou kubeconfig incorreto.

```bash
# Verificar contexto
kubectl config current-context

# Verificar configuração
kubectl config view

# Reconfigurar cluster EKS
aws eks update-kubeconfig --name observability-lab-cluster --region us-east-1
```

### Erro: "error: You must be logged in to the server (Unauthorized)"

**Solução**: Credenciais AWS expiradas ou inválidas.

```bash
# Verificar credenciais AWS
aws sts get-caller-identity

# Reconfigurar AWS CLI
aws configure

# Atualizar kubeconfig
aws eks update-kubeconfig --name observability-lab-cluster --region us-east-1
```

### Erro: "Unable to connect to the server: dial tcp: lookup"

**Solução**: Problema de DNS ou conectividade.

```bash
# Verificar conectividade
ping 8.8.8.8

# Verificar DNS
nslookup google.com

# Verificar endpoint do cluster
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
```

### kubectl está lento

**Solução**: Limpar cache ou verificar plugins.

```bash
# Limpar cache
rm -rf ~/.kube/cache

# Desabilitar plugins temporariamente
kubectl get pods --v=6
```

## Cheat Sheet

```bash
# Recursos
kubectl get pods                    # Listar pods
kubectl get svc                     # Listar services
kubectl get deploy                  # Listar deployments
kubectl get all                     # Listar todos os recursos

# Detalhes
kubectl describe pod <nome>         # Descrever pod
kubectl logs <pod>                  # Ver logs
kubectl logs -f <pod>               # Seguir logs
kubectl exec -it <pod> -- bash      # Shell interativo

# Criar/Aplicar
kubectl create -f <arquivo>         # Criar recurso
kubectl apply -f <arquivo>          # Aplicar configuração
kubectl delete -f <arquivo>         # Deletar recurso

# Escalar
kubectl scale deploy <nome> --replicas=3

# Port Forward
kubectl port-forward <pod> 8080:80

# Contextos
kubectl config get-contexts         # Listar contextos
kubectl config use-context <nome>   # Usar contexto
kubectl config current-context      # Ver contexto atual

# Namespaces
kubectl get ns                      # Listar namespaces
kubectl config set-context --current --namespace=<ns>
```

## Recursos Adicionais

- [Documentação Oficial kubectl](https://kubernetes.io/docs/reference/kubectl/)
- [Kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Kubectl Book](https://kubectl.docs.kubernetes.io/)
- [Kubernetes API Reference](https://kubernetes.io/docs/reference/kubernetes-api/)

## Próximos Passos

Com o kubectl instalado e configurado, você está pronto para:

1. [Instalar o Helm](install-helm.md)
2. [Configurar o ambiente EKS](setup-eks-lab.md)
3. Gerenciar recursos Kubernetes via linha de comando
4. Fazer deploy e debug de aplicações

## Dicas Profissionais

💡 **Use aliases** para comandos frequentes (k, kgp, kgs)  
💡 **Habilite auto-completion** para produtividade  
💡 **Use `-o wide`** para ver mais informações  
💡 **Use `--watch`** para monitorar mudanças em tempo real  
💡 **Instale plugins** via Krew para funcionalidades extras  
💡 **Use `kubectl explain`** para documentação inline de recursos  
