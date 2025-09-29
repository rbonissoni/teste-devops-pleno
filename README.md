# 🛠️ Desafio DevOps Pleno

Este projeto implementa uma **infraestrutura completa na AWS** usando **Terraform** e uma esteira **CI/CD com Jenkins**, além de provisionamento automatizado com **user_data** e monitoramento via **Datadog**.  

O objetivo é simular um cenário real de **DevOps Pleno**, desde a criação da rede e instâncias até deploy automatizado, health checks, logs e observabilidade.

---

## 📁 Arquitetura do Projeto

A solução provisiona e integra os seguintes componentes:

- ☁️ **AWS Infrastructure**:  
  - **VPC**, **Subnets**, **Internet Gateway**, **Route Tables**  
  - **Security Groups**  
  - **EC2** (com Nginx, Node.js e Datadog instalados via `user_data.sh`)  
  - **S3 + DynamoDB** para state remoto e lock do Terraform  

- ⚙️ **CI/CD Pipeline (Jenkins)**  
  - Pipeline automatizado com stages de **checkout**, **build/test**, **deploy via SSH** e **health checks**
  - Publicação automatizada na EC2 e verificação do serviço

- 📊 **Monitoramento (Datadog)**  
  - Instalação automática do agente via script  
  - Coleta de métricas de sistema, logs do Nginx e health do app  
  - Criação automática de monitor de erros 5xx no Nginx

- 📦 **Aplicação Node.js + Nginx**  
  - Aplicação simples com endpoints `/` e `/health`  
  - Proxy reverso Nginx para porta 3000  

---

## 📂 Estrutura do Projeto

```
.
├── terraform/
│   ├── backend/           # Configuração de backend remoto (S3 + DynamoDB)
│   ├── network/           # Criação de VPC, Subnets, IGW, SG
│   ├── ec2/               # Criação da instância e configuração via user_data
│   └── variables.tf
├── scripts/
│   └── user_data.sh       # Script de bootstrap da EC2 com Nginx, Node.js e Datadog
├── Jenkinsfile           # Pipeline CI/CD completo
└── README.md             # Este arquivo
```

---

## 🚀 Pré-requisitos

Antes de iniciar, garanta que possui:

- ✅ **AWS CLI** configurado com credenciais válidas  
- ✅ **Terraform >= 1.5.0** instalado  
- ✅ **SSH key** cadastrada no Jenkins (`ec2-ssh`)  
- ✅ **Bucket S3** e **tabela DynamoDB** criados para o state remoto  
- ✅ **Datadog API Key e Site** disponíveis (`DD_API_KEY`, `DD_SITE`)

---

## ☁️ 1. Configurar Backend (State Remoto)

Antes de aplicar a infraestrutura, configure o **backend remoto** do Terraform:

```bash
cd terraform/backend
terraform init
terraform apply -auto-approve
```

Isso criará:
- 🪣 Bucket S3 para armazenar o `terraform.tfstate`
- 📊 DynamoDB para controle de lock e concorrência

---

## 🏗️ 2. Provisionar Infraestrutura (Network + EC2)

```bash
cd terraform/
terraform init
terraform plan
terraform apply -auto-approve
```

O Terraform irá:
- Criar rede (`VPC`, `Subnets`, `IGW`, `SG`)  
- Criar e configurar a EC2 com `user_data.sh`  
- Instalar **Nginx**, **Node.js**, **Datadog** e **Jenkins (opcional)**  

---

## 🔁 3. Executar Pipeline Jenkins

Após a infraestrutura criada, execute a pipeline configurada no Jenkins:

- 📦 **Checkout** do repositório  
- 🧪 **Build/Test** (caso exista `package.json`)  
- 🚀 **Deploy via SSH** na EC2  
- ✅ **Health Checks** via `/health` e porta `3000`  
- 🌐 **Smoke Test externo** para validar a aplicação

---

## 📊 4. Monitoramento com Datadog

A instalação do Datadog ocorre automaticamente via `user_data.sh`:

- Coleta de métricas de sistema e aplicação  
- Logs do Nginx  
- Endpoint `/nginx_status` habilitado  
- Monitor de erros HTTP 5xx criado automaticamente (se `DD_APP_KEY` for definido)

Exemplo de configuração gerada:

```yaml
api_key: ${DD_API_KEY}
site: ${DD_SITE}
process_config:
  enabled: "true"
apm_config:
  enabled: false
```

---

## ✅ Verificações de Saúde

Após o deploy, valide o funcionamento da aplicação:

```bash
curl -i http://<PUBLIC_IP>/health
curl -I http://<PUBLIC_IP>
```

Saída esperada:

```
HTTP/1.1 200 OK
Content-Type: application/json
{"status": "ok"}
```

---

## 📸 Evidências que você pode coletar

Para comprovar o funcionamento do projeto:

1. ✅ **Pipeline no Jenkins** com todos os stages em verde  
2. 📜 **Console Output** mostrando health checks e deploy concluído  
3. 🌐 **Resposta do /health** via `curl`  
4. 📊 **Painel do Datadog** com métricas e logs coletados  
5. ☁️ **AWS Console** com VPC, EC2 e S3 criados corretamente

---

## 📘 Próximos Passos

- Adicionar **ALB** e **autoscaling** para ambientes de produção  
- Criar **pipelines multi-branch** e deploy automatizado por tag  
- Adicionar **testes automatizados** e integração com GitHub Actions  

---

### 🧑‍💻 Autor

**Renan Bonissoni**  
Desafio DevOps Pleno — 2025  
Infraestrutura e automação completa com Terraform, Jenkins, Nginx, Node.js e Datadog.
