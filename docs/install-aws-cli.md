# Instalação e Configuração do AWS CLI

Guia completo para instalar e configurar o AWS CLI na sua máquina local.

## O que é o AWS CLI?

O AWS Command Line Interface (CLI) é uma ferramenta unificada para gerenciar seus serviços AWS através da linha de comando. Com o AWS CLI, você pode controlar múltiplos serviços AWS e automatizar tarefas através de scripts.

## Instalação

### macOS

**Opção 1: Usando Homebrew (Recomendado)**

```bash
# Instalar AWS CLI
brew install awscli

# Verificar instalação
aws --version
```

**Opção 2: Usando o instalador oficial**

```bash
# Baixar e instalar
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /

# Verificar instalação
aws --version
```

### Linux

**Ubuntu/Debian**

```bash
# Instalar dependências
sudo apt update
sudo apt install unzip curl

# Baixar AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

# Descompactar
unzip awscliv2.zip

# Instalar
sudo ./aws/install

# Verificar instalação
aws --version
```

**Amazon Linux 2 / CentOS / RHEL**

```bash
# Baixar AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

# Descompactar
unzip awscliv2.zip

# Instalar
sudo ./aws/install

# Verificar instalação
aws --version
```

### Windows

**Opção 1: Usando o instalador MSI (Recomendado)**

1. Baixar o instalador: [AWS CLI MSI Installer](https://awscli.amazonaws.com/AWSCLIV2.msi)
2. Executar o arquivo `.msi` baixado
3. Seguir o assistente de instalação
4. Abrir um novo PowerShell ou Command Prompt
5. Verificar instalação:

```powershell
aws --version
```

**Opção 2: Usando Chocolatey**

```powershell
# Instalar AWS CLI
choco install awscli

# Verificar instalação
aws --version
```

## Configuração

### Obter Credenciais AWS

Antes de configurar o AWS CLI, você precisa obter suas credenciais de acesso:

1. **Fazer login no AWS Console**: https://console.aws.amazon.com
2. **Acessar IAM**: Services → IAM
3. **Criar usuário** (se ainda não tiver):
   - IAM → Users → Add users
   - Nome: `seu-usuario-cli`
   - Access type: **Programmatic access**
   - Permissions: Anexar policy `AdministratorAccess` (para laboratório)
   - Criar usuário
4. **Salvar credenciais**:
   - **Access Key ID**: `AKIA...`
   - **Secret Access Key**: `wJalrXUtn...`
   
⚠️ **Importante**: Salve essas credenciais em local seguro. A Secret Access Key só é mostrada uma vez!

### Configurar AWS CLI

Execute o comando de configuração:

```bash
aws configure
```

Você será solicitado a fornecer as seguintes informações:

```
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: us-east-1
Default output format [None]: json
```

**Explicação dos campos:**

- **AWS Access Key ID**: Sua chave de acesso (obtida no IAM)
- **AWS Secret Access Key**: Sua chave secreta (obtida no IAM)
- **Default region name**: Região AWS padrão (use `us-east-1` para o laboratório)
- **Default output format**: Formato de saída (`json`, `yaml`, `text`, ou `table`)

### Verificar Configuração

```bash
# Verificar identidade AWS
aws sts get-caller-identity

# Saída esperada:
# {
#     "UserId": "AIDAI...",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/seu-usuario-cli"
# }

# Verificar região configurada
aws configure get region

# Listar configurações
aws configure list
```

## Configurações Avançadas

### Múltiplos Perfis

Se você trabalha com múltiplas contas AWS, pode configurar perfis diferentes:

```bash
# Configurar perfil adicional
aws configure --profile projeto-a

# Usar perfil específico
aws s3 ls --profile projeto-a

# Definir perfil padrão temporariamente
export AWS_PROFILE=projeto-a
```

### Configuração via Variáveis de Ambiente

Alternativamente, você pode configurar via variáveis de ambiente:

```bash
# Linux/macOS
export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
export AWS_DEFAULT_REGION=us-east-1

# Windows PowerShell
$env:AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
$env:AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
$env:AWS_DEFAULT_REGION="us-east-1"
```

### Arquivos de Configuração

O AWS CLI armazena configurações em:

- **Credenciais**: `~/.aws/credentials`
- **Configurações**: `~/.aws/config`

**Exemplo de `~/.aws/credentials`:**

```ini
[default]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

[projeto-a]
aws_access_key_id = AKIAI44QH8DHBEXAMPLE
aws_secret_access_key = je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY
```

**Exemplo de `~/.aws/config`:**

```ini
[default]
region = us-east-1
output = json

[profile projeto-a]
region = us-west-2
output = yaml
```

## Comandos Úteis

```bash
# Listar buckets S3
aws s3 ls

# Listar clusters EKS
aws eks list-clusters

# Descrever instâncias EC2
aws ec2 describe-instances

# Obter informações da conta
aws sts get-caller-identity

# Listar regiões disponíveis
aws ec2 describe-regions --output table

# Ajuda de comandos
aws help
aws eks help
aws eks create-cluster help
```

## Troubleshooting

### Erro: "aws: command not found"

**Solução**: O AWS CLI não está no PATH. Reinicie o terminal ou adicione ao PATH:

```bash
# macOS/Linux
export PATH=$PATH:/usr/local/bin

# Adicionar ao .bashrc ou .zshrc para tornar permanente
echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
```

### Erro: "Unable to locate credentials"

**Solução**: Credenciais não configuradas. Execute:

```bash
aws configure
```

### Erro: "An error occurred (UnauthorizedOperation)"

**Solução**: Usuário IAM não tem permissões necessárias. Verifique policies anexadas ao usuário no IAM Console.

### Erro: "Could not connect to the endpoint URL"

**Solução**: Região incorreta ou serviço não disponível na região. Verifique:

```bash
aws configure get region
```

## Segurança e Boas Práticas

✅ **Nunca compartilhe suas credenciais AWS**  
✅ **Não commite credenciais no Git** (adicione `~/.aws/` ao `.gitignore`)  
✅ **Use IAM roles quando possível** (em EC2, Lambda, etc.)  
✅ **Rotacione credenciais regularmente**  
✅ **Use MFA (Multi-Factor Authentication)** para usuários com acesso administrativo  
✅ **Aplique princípio do menor privilégio** (conceda apenas permissões necessárias)  
✅ **Delete access keys não utilizadas**  

## Próximos Passos

Com o AWS CLI instalado e configurado, você está pronto para:

1. [Configurar o ambiente EKS](setup-eks-lab.md)
2. Gerenciar recursos AWS via linha de comando
3. Automatizar tarefas com scripts

## Referências

- [Documentação Oficial AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/)
- [AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/)
- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
