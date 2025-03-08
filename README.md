# Sistema de Monitoramento de Servidores

Este repositório contém a configuração completa de um sistema de monitoramento de servidores baseado em Prometheus, Node Exporter, AlertManager e Grafana, utilizando Docker e Docker Compose.

## Pré-requisitos

- Docker
- Docker Compose
- Acesso SSH aos servidores que serão monitorados
- Ubuntu Server (recomendado, mas pode funcionar em outras distribuições Linux)

## Estrutura do Projeto

```
.
├── README.md
├── docker-compose.yml      # Configuração unificada dos serviços
├── .env.example            # Exemplo de variáveis de ambiente
├── alertmanager/           # Configurações do AlertManager
├── grafana/                # Configurações e dashboards do Grafana
│   ├── dashboards/         # Dashboards pré-configurados
│   └── provisioning/       # Configuração automática de fontes de dados e dashboards
├── prometheus/             # Configurações do Prometheus
└── scripts/
    ├── generate-configs.sh        # Script de geração de configuração
    ├── create-env-example.sh      # Script para criar o arquivo .env.example
    └── install-node-exporter.sh   # Script de instalação do Node Exporter
```

## Instalação

### 1. Servidor de Monitoramento

1. Clone este repositório:
   ```bash
   git clone https://github.com/fabioassuncao/server-monitoring.git
   cd server-monitoring
   ```

2. Crie um arquivo `.env` baseado no `.env.example`:
   ```bash
   cp .env.example .env
   ```

3. Edite o arquivo `.env` com suas configurações:
   ```bash
   nano .env
   ```

4. Inicie os serviços:
   ```bash
   docker compose up -d
   ```

5. Acesse o Grafana em `http://seu-ip:3000` (credenciais: admin/senha-configurada)

### 2. Configuração dos Servidores Monitorados

Para cada servidor que você deseja monitorar, execute o script de instalação do Node Exporter:

```bash
# Opção 1: Executar com sudo (recomendado para instalação em /opt)
curl -sSL https://raw.githubusercontent.com/fabioassuncao/server-monitoring/main/scripts/install-node-exporter.sh | sudo bash -s -- -u prometheus -s secret -w
```

Ou baixe e execute localmente:

```bash
# Com sudo, configurando firewall automaticamente
sudo ./scripts/install-node-exporter.sh -u prometheus -s secret -w

# Com sudo, configurando firewall para permitir acesso apenas do servidor Prometheus
sudo ./scripts/install-node-exporter.sh -u prometheus -s secret -w -i 192.168.1.10

# Sem sudo, especificando um diretório personalizado
./scripts/install-node-exporter.sh -u prometheus -s secret -d $HOME/.node-exporter
```

Opções disponíveis:
- `-p, --port PORTA`: Define a porta do Node Exporter (padrão: 9100)
- `-n, --name NOME`: Define o nome do container (padrão: node-exporter)
- `-u, --username USUARIO`: Define o usuário para autenticação básica
- `-s, --password SENHA`: Define a senha para autenticação básica
- `-t, --tls`: Habilita TLS para comunicação segura
- `-d, --dir DIRETORIO`: Define o diretório de configuração (padrão: $HOME/.node-exporter)
- `-r, --reset`: Remove completamente o Node Exporter e suas configurações
- `-f, --fix-permissions`: Corrige as permissões dos certificados TLS existentes
- `-w, --firewall`: Configura o firewall (UFW) automaticamente
- `-i, --allow-from IP`: Permite acesso apenas do IP especificado (requer -w)

Para remover completamente o Node Exporter e todas as suas configurações:

```bash
# Com sudo (se instalado com sudo)
sudo ./scripts/install-node-exporter.sh -r

# Sem sudo (se instalado sem sudo)
./scripts/install-node-exporter.sh -r

# Especificando um nome de container personalizado
./scripts/install-node-exporter.sh -r -n node-exporter-custom
```

Para corrigir problemas de permissão com os certificados TLS:

```bash
# Corrigir permissões sem reinstalar
./scripts/install-node-exporter.sh -f

# Especificando um diretório de configuração personalizado
./scripts/install-node-exporter.sh -f -d /caminho/para/config

# Especificando um nome de container personalizado
./scripts/install-node-exporter.sh -f -n node-exporter-custom
```

### 3. Adicionando Novos Servidores

1. Instale o Node Exporter no novo servidor conforme descrito acima.

2. Atualize a variável `MONITORED_SERVERS` no arquivo `.env`:
   ```
   MONITORED_SERVERS=servidor1:9100,servidor2:9100,novo-servidor:9100
   ```

3. Reinicie os serviços para aplicar as alterações:
   ```bash
   docker compose up -d
   ```

## Configuração

### Variáveis de Ambiente

O sistema é totalmente configurável através de variáveis de ambiente. Abaixo estão as principais variáveis disponíveis:

#### Configurações Gerais
```
GRAFANA_PORT=3000                      # Porta do Grafana
GRAFANA_ADMIN_PASSWORD=admin_seguro    # Senha do admin do Grafana
GRAFANA_ROOT_URL=http://seu-ip:3000    # URL raiz do Grafana
PROMETHEUS_PORT=9090                   # Porta do Prometheus
ALERTMANAGER_PORT=9093                 # Porta do AlertManager
```

#### Servidores Monitorados
```
# Lista de servidores monitorados (formato: servidor1:porta,servidor2:porta)
MONITORED_SERVERS=servidor1:9100,servidor2:9100,servidor3:9100
```

#### Configurações de Alerta
```
ALERT_CPU_THRESHOLD=80     # Limiar de alerta para uso de CPU (%)
ALERT_MEMORY_THRESHOLD=85  # Limiar de alerta para uso de memória (%)
ALERT_DISK_THRESHOLD=85    # Limiar de alerta para uso de disco (%)
```

#### Configurações de Segurança
```
NODE_EXPORTER_USERNAME=prometheus  # Usuário para autenticação básica
NODE_EXPORTER_PASSWORD=secret      # Senha para autenticação básica
TLS_ENABLED=false                  # Habilita/desabilita TLS
```

#### Canais de Notificação
```
# Canais de notificação ativos (separados por vírgula)
ALERT_CHANNELS=email,slack,telegram
```

#### Configuração de E-mail
```
EMAIL_FROM=alertas@seudominio.com
EMAIL_SMARTHOST=smtp.seudominio.com:587
EMAIL_AUTH_USERNAME=usuario_smtp
EMAIL_AUTH_PASSWORD=senha_smtp
EMAIL_RECEIVERS=admin@seudominio.com,suporte@seudominio.com
```

#### Configuração do Slack
```
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/XXXX/YYYY/ZZZZ
SLACK_CHANNEL=#monitoramento
SLACK_USERNAME=ServerMonitor
```

#### Configuração do Telegram
```
TELEGRAM_BOT_TOKEN=1234567890:ABCDEFGHIJKLMNOPQRSTUVWXYZ
TELEGRAM_CHAT_ID=-1001234567890
```

### Configuração dos Canais de Notificação

#### Como Configurar o Slack:

1. Crie um aplicativo no Slack: https://api.slack.com/apps
2. Ative os Webhooks de Entrada
3. Crie um novo Webhook para seu workspace e canal
4. Copie a URL do Webhook e use-a na variável `SLACK_WEBHOOK_URL`

#### Como Configurar o Telegram:

1. Crie um bot no Telegram conversando com o @BotFather
2. Obtenha o token do bot
3. Adicione o bot ao grupo/canal onde deseja receber as notificações
4. Obtenha o ID do chat usando o bot @getidsbot ou enviando uma mensagem para o seu bot e acessando `https://api.telegram.org/bot<SEU_TOKEN>/getUpdates`
5. Use o token e o ID do chat nas variáveis correspondentes

#### Como Configurar o E-mail:

1. Configure um servidor SMTP ou use um serviço de e-mail como Gmail, SendGrid, etc.
2. Defina as credenciais e configurações nas variáveis de ambiente
3. Para Gmail, você pode precisar habilitar "Acesso a app menos seguro" ou usar uma senha de aplicativo

## Alertas

Os alertas estão configurados para monitorar:

- Uso elevado de CPU (configurável via `ALERT_CPU_THRESHOLD`)
- Uso elevado de memória (configurável via `ALERT_MEMORY_THRESHOLD`)
- Uso elevado de disco (configurável via `ALERT_DISK_THRESHOLD`)
- Servidor offline

## Segurança

### Autenticação Básica

O Node Exporter é configurado com autenticação básica para proteger o acesso às métricas. Certifique-se de definir um usuário e senha seguros nas variáveis `NODE_EXPORTER_USERNAME` e `NODE_EXPORTER_PASSWORD`.

### TLS

A comunicação entre o Prometheus e o Node Exporter pode ser criptografada com TLS. Para habilitar, defina a variável `TLS_ENABLED=true` e use a opção `-t` ao instalar o Node Exporter.

### Firewall

É essencial configurar o firewall para permitir o tráfego nas portas utilizadas pelo sistema de monitoramento. O script de instalação do Node Exporter pode configurar o firewall automaticamente usando a opção `-w`.

#### Configuração Automática do Firewall
```bash
# Permitir acesso de qualquer origem
sudo ./scripts/install-node-exporter.sh -u prometheus -s secret -w

# Permitir acesso apenas do servidor Prometheus
sudo ./scripts/install-node-exporter.sh -u prometheus -s secret -w -i 192.168.1.10
```

#### Configuração Manual do Firewall

Se preferir configurar manualmente, use os seguintes comandos:

##### No Servidor de Monitoramento
```bash
# Permitir acesso ao Grafana
sudo ufw allow 3000/tcp

# Permitir acesso ao Prometheus
sudo ufw allow 9090/tcp

# Permitir acesso ao AlertManager
sudo ufw allow 9093/tcp
```

##### Nos Servidores Monitorados
```bash
# Permitir acesso ao Node Exporter apenas do servidor de monitoramento
sudo ufw allow from <IP_DO_SERVIDOR_DE_MONITORAMENTO> to any port 9100 proto tcp

# Ou, para permitir acesso de qualquer origem (menos seguro)
sudo ufw allow 9100/tcp
```

Recomenda-se limitar o acesso às portas do Node Exporter apenas ao servidor Prometheus por questões de segurança.

### Verificação da Configuração do Firewall

Para verificar se o firewall está configurado corretamente:

```bash
# Verificar status do firewall
sudo ufw status

# Testar conexão com o Node Exporter
curl -u prometheus:secret http://IP_DO_SERVIDOR:9100/metrics
```

## Manutenção

### Atualizando as Configurações

1. Edite o arquivo `.env` com as novas configurações
2. Reinicie os serviços:
   ```bash
   docker compose up -d
   ```

### Atualizando os Serviços

Para atualizar os serviços para as versões mais recentes:

```bash
docker compose pull
docker compose up -d
```

## Suporte

Para problemas ou sugestões, abra uma issue neste repositório.

## Licença

MIT 

## Solução de Problemas

### Problemas com Autenticação

Se você estiver enfrentando problemas com a autenticação do Node Exporter:

1. Verifique se o Node Exporter está rodando:
   ```bash
   docker ps | grep node-exporter
   ```

2. Verifique os logs do container:
   ```bash
   docker logs node-exporter
   ```

3. Tente reinstalar sem TLS para simplificar a configuração:
   ```bash
   sudo ./scripts/install-node-exporter.sh -r
   sudo ./scripts/install-node-exporter.sh -u prometheus -s secret
   ```

4. Teste a conexão:
   ```bash
   curl -u prometheus:secret http://localhost:9100/metrics
   ```

### Problemas com TLS

Se você estiver enfrentando problemas com TLS:

1. Corrija as permissões dos certificados:
   ```bash
   sudo ./scripts/install-node-exporter.sh -f
   ```

2. Se o problema persistir, tente reinstalar sem TLS:
   ```bash
   sudo ./scripts/install-node-exporter.sh -r
   sudo ./scripts/install-node-exporter.sh -u prometheus -s secret
   ```

3. Verifique se o Prometheus está configurado corretamente para acessar o Node Exporter com TLS.

### Problemas de Conexão

Se você não conseguir se conectar ao Node Exporter:

1. Verifique se a porta está aberta no firewall:
   ```bash
   sudo ufw status
   sudo ufw allow 9100/tcp
   ```

2. Verifique se o Node Exporter está escutando na interface correta:
   ```bash
   netstat -tulpn | grep 9100
   ```

3. Tente acessar localmente primeiro:
   ```bash
   curl http://localhost:9100/metrics
   ``` 