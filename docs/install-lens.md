# Instalação e Configuração do Lens Desktop

Guia completo para instalar e configurar o Lens Desktop, a IDE Kubernetes mais poderosa para gerenciar clusters.

## O que é o Lens Desktop?

Lens Desktop é uma IDE (Integrated Development Environment) para Kubernetes que oferece uma interface gráfica intuitiva para gerenciar clusters, visualizar recursos, debugar aplicações e muito mais. É a ferramenta mais popular para trabalhar com Kubernetes, com milhões de usuários em todo o mundo.

### Principais Recursos

✨ **Interface Visual Intuitiva**: Navegue facilmente por namespaces, pods, deployments e outros recursos  
📊 **Monitoramento em Tempo Real**: Visualize métricas de CPU, memória e rede  
🔍 **Logs Integrados**: Acesse logs de containers diretamente na interface  
⚡ **Terminal Integrado**: Execute comandos kubectl sem sair da aplicação  
🎯 **Multi-Cluster**: Gerencie múltiplos clusters simultaneamente  
🔐 **Segurança**: Suporte completo para RBAC e autenticação  
🛠️ **Extensível**: Suporte para extensões e plugins  

## Instalação

### macOS

**Opção 1: Usando Homebrew (Recomendado)**

```bash
# Adicionar tap do Lens
brew install --cask lens

# Verificar instalação
open -a Lens
```

**Opção 2: Download Direto**

1. Acessar: https://lenshq.io/
2. Clicar em **Download for macOS**
3. Abrir o arquivo `.dmg` baixado
4. Arrastar Lens para a pasta Applications
5. Abrir Lens pela primeira vez (pode solicitar permissão de segurança)

### Linux

**Ubuntu/Debian**

```bash
# Baixar pacote .deb
curl -fsSL https://downloads.k8slens.dev/keys/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/lens-archive-keyring.gpg > /dev/null

# Adicionar repositório
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/lens-archive-keyring.gpg] https://downloads.k8slens.dev/apt/debian stable main" | sudo tee /etc/apt/sources.list.d/lens.list > /dev/null

# Atualizar e instalar
sudo apt update
sudo apt install lens

# Executar
lens-desktop
```

**Fedora/RHEL/CentOS**

```bash
# Adicionar repositório
cat <<EOF | sudo tee /etc/yum.repos.d/lens.repo
[lens]
name=Lens
baseurl=https://downloads.k8slens.dev/rpm/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.k8slens.dev/keys/gpg
EOF

# Instalar
sudo dnf install lens

# Executar
lens-desktop
```

**AppImage (Universal)**

```bash
# Baixar AppImage
wget https://api.k8slens.dev/binaries/Lens-latest.x86_64.AppImage

# Tornar executável
chmod +x Lens-latest.x86_64.AppImage

# Executar
./Lens-latest.x86_64.AppImage
```

### Windows

**Opção 1: Instalador EXE (Recomendado)**

1. Acessar: https://lenshq.io/
2. Clicar em **Download for Windows**
3. Executar o arquivo `.exe` baixado
4. Seguir o assistente de instalação
5. Iniciar Lens Desktop pelo menu Iniciar

**Opção 2: Usando Chocolatey**

```powershell
# Instalar Lens
choco install lens

# Executar
lens-desktop
```

**Opção 3: Usando Winget**

```powershell
# Instalar Lens
winget install Lens.Lens

# Executar
lens-desktop
```

## Primeira Configuração

### 1. Iniciar o Lens Desktop

Ao abrir o Lens pela primeira vez, você verá a tela de boas-vindas.

### 2. Adicionar Cluster Kubernetes

O Lens detecta automaticamente clusters configurados no seu `~/.kube/config`.

**Método 1: Detecção Automática**

1. Abrir Lens Desktop
2. Clicar em **Catalog** (barra lateral esquerda)
3. Clicar em **Clusters**
4. Lens mostrará automaticamente clusters do kubeconfig
5. Clicar no cluster para conectar

**Método 2: Adicionar Manualmente**

1. Clicar em **+** (Add Cluster)
2. Selecionar **From kubeconfig**
3. Colar o conteúdo do kubeconfig ou selecionar arquivo
4. Clicar em **Add Cluster**

**Método 3: Via Linha de Comando**

```bash
# Lens detecta automaticamente clusters após executar:
aws eks update-kubeconfig --name observability-lab-cluster --region us-east-1

# Abrir Lens
lens-desktop
```

### 3. Conectar ao Cluster EKS

```bash
# Configurar acesso ao cluster EKS
aws eks update-kubeconfig --name observability-lab-cluster --region us-east-1

# Abrir Lens Desktop
lens-desktop

# O cluster aparecerá automaticamente na lista
# Clicar no cluster para conectar
```

## Interface do Lens

### Navegação Principal

```
┌─────────────────────────────────────────────────────────┐
│  Lens Desktop                                    [- □ ×] │
├──────┬──────────────────────────────────────────────────┤
│      │  Cluster: observability-lab-cluster              │
│ 📁   │  ┌────────────────────────────────────────────┐  │
│ Cata │  │  Workloads                                 │  │
│ log  │  │  • Pods                                    │  │
│      │  │  • Deployments                             │  │
│ 🔧   │  │  • StatefulSets                            │  │
│ Clus │  │  • DaemonSets                              │  │
│ ter  │  │                                            │  │
│      │  │  Configuration                             │  │
│ ⚙️   │  │  • ConfigMaps                              │  │
│ Sett │  │  • Secrets                                 │  │
│ ings│  │                                            │  │
│      │  │  Network                                   │  │
│ 📊   │  │  • Services                                │  │
│ Metr │  │  • Ingresses                               │  │
│ ics  │  │                                            │  │
│      │  │  Storage                                   │  │
│      │  │  • PersistentVolumes                       │  │
│      │  │  • PersistentVolumeClaims                  │  │
│      │  └────────────────────────────────────────────┘  │
└──────┴──────────────────────────────────────────────────┘
```

### Recursos Principais

**Workloads**
- **Pods**: Visualizar, inspecionar logs, abrir shell
- **Deployments**: Escalar, editar, visualizar status
- **StatefulSets**: Gerenciar aplicações stateful
- **DaemonSets**: Visualizar pods em cada node
- **Jobs/CronJobs**: Monitorar tarefas agendadas

**Configuration**
- **ConfigMaps**: Editar configurações
- **Secrets**: Visualizar (ofuscado) e editar secrets

**Network**
- **Services**: Visualizar endpoints e portas
- **Ingresses**: Gerenciar rotas HTTP/HTTPS

**Storage**
- **PersistentVolumes**: Visualizar volumes
- **PersistentVolumeClaims**: Gerenciar claims

**Nodes**
- Visualizar nodes do cluster
- Métricas de CPU, memória, disco
- Taints e labels

## Funcionalidades Úteis

### Visualizar Logs de Pods

1. Navegar para **Workloads** → **Pods**
2. Clicar no pod desejado
3. Aba **Logs** mostra logs em tempo real
4. Opções:
   - Download logs
   - Filtrar por container (se multi-container)
   - Seguir logs (tail -f)

### Abrir Shell em Pod

1. Navegar para **Workloads** → **Pods**
2. Clicar no pod desejado
3. Aba **Shell** abre terminal interativo
4. Executar comandos dentro do container

### Editar Recursos

1. Clicar em qualquer recurso
2. Clicar no ícone **Edit** (lápis)
3. Editar YAML diretamente
4. Salvar alterações

### Visualizar Métricas

1. Navegar para **Cluster** → **Nodes**
2. Visualizar métricas de CPU, memória, disco
3. Gráficos em tempo real

### Port Forwarding

1. Navegar para **Workloads** → **Pods**
2. Clicar no pod
3. Aba **Port Forwarding**
4. Adicionar porta local → porta do container
5. Acessar via `localhost:porta`

### Executar kubectl

1. Pressionar **Ctrl+`** (ou **Cmd+`** no macOS)
2. Terminal integrado abre
3. Executar comandos kubectl normalmente

## Atalhos de Teclado

| Atalho | Ação |
|--------|------|
| `Ctrl/Cmd + K` | Busca rápida de recursos |
| `Ctrl/Cmd + T` | Alternar entre clusters |
| `Ctrl/Cmd + `` | Abrir/fechar terminal |
| `Ctrl/Cmd + ,` | Abrir configurações |
| `Ctrl/Cmd + W` | Fechar aba |
| `Ctrl/Cmd + Shift + F` | Buscar em todos os recursos |

## Configurações Recomendadas

### Habilitar Métricas

1. **Settings** → **Kubernetes**
2. Habilitar **Metrics**
3. Lens instalará metrics-server automaticamente (se necessário)

### Tema

1. **Settings** → **Appearance**
2. Escolher tema: Light, Dark, ou System

### Terminal

1. **Settings** → **Terminal**
2. Configurar shell preferido
3. Ajustar fonte e tamanho

## Extensões Úteis

Lens suporta extensões para funcionalidades adicionais:

1. **Settings** → **Extensions**
2. Explorar extensões disponíveis:
   - **@alebcay/openlens-node-pod-menu**: Menu adicional para nodes e pods
   - **@nevalla/kube-resource-map**: Visualização de dependências
   - **@lens-extension/resource-map**: Mapa visual de recursos

## Troubleshooting

### Lens não detecta cluster

**Solução**: Verificar kubeconfig:

```bash
# Verificar contexto atual
kubectl config current-context

# Listar contextos
kubectl config get-contexts

# Reconfigurar cluster EKS
aws eks update-kubeconfig --name observability-lab-cluster --region us-east-1
```

### Erro de autenticação

**Solução**: Atualizar credenciais AWS:

```bash
# Verificar credenciais
aws sts get-caller-identity

# Reconfigurar se necessário
aws configure
```

### Métricas não aparecem

**Solução**: Instalar metrics-server:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### Lens está lento

**Solução**: 
- Fechar clusters não utilizados
- Limpar cache: **Settings** → **Application** → **Clear Cache**
- Reiniciar Lens

## Alternativas ao Lens

Se preferir outras ferramentas:

- **k9s**: Interface TUI (Terminal) para Kubernetes
- **Octant**: Interface web open-source da VMware
- **Kubernetes Dashboard**: Dashboard oficial do Kubernetes
- **kubectl**: Linha de comando pura

## Recursos Adicionais

- [Documentação Oficial](https://docs.k8slens.dev/)
- [Lens GitHub](https://github.com/lensapp/lens)
- [Comunidade Lens](https://forums.k8slens.dev/)
- [Tutoriais em Vídeo](https://www.youtube.com/c/LensIDE)

## Próximos Passos

Com o Lens instalado e configurado, você está pronto para:

1. [Configurar o ambiente EKS](setup-eks-lab.md)
2. Visualizar e gerenciar recursos Kubernetes graficamente
3. Debugar aplicações com logs e shell integrados
4. Monitorar métricas do cluster em tempo real

## Dicas Profissionais

💡 **Use a busca rápida** (`Ctrl/Cmd + K`) para encontrar recursos rapidamente  
💡 **Favoritar clusters** frequentemente usados para acesso rápido  
💡 **Usar múltiplas abas** para comparar recursos lado a lado  
💡 **Configurar hotkeys** personalizados para ações frequentes  
💡 **Explorar extensões** para adicionar funcionalidades específicas  
