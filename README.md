# Sistema de Monitoramento de Servidores

Este repositório contém a configuração completa de um sistema de monitoramento de servidores baseado em Prometheus, Node Exporter e Grafana, utilizando Docker e Docker Compose.

## Pré-requisitos

- Docker
- Docker Compose
- Acesso SSH aos servidores que serão monitorados
- Ubuntu Server (recomendado, mas pode funcionar em outras distribuições Linux)

## Estrutura do Projeto

```
.
├── README.md
├── prometheus/
│   ├── docker-compose.yml
│   ├── prometheus.yml
│   └── alert.rules.yml
├── grafana/
│   └── docker-compose.yml
└── scripts/
    └── install-node-exporter.sh
```

## Instalação

### 1. Servidor de Monitoramento

1. Clone este repositório:
   ```bash
   git clone https://github.com/seu-usuario/server-monitoring.git
   cd server-monitoring
   ```

2. Crie a rede Docker para o sistema de monitoramento:
   ```bash
   docker network create monitoramento
   ```

3. Inicie o Prometheus:
   ```bash
   cd prometheus
   docker-compose up -d
   ```

4. Inicie o Grafana:
   ```bash
   cd ../grafana
   docker-compose up -d
   ```

5. Acesse o Grafana em `http://seu-ip:3000` (credenciais padrão: admin/admin)

### 2. Configuração dos Servidores Monitorados

Para cada servidor que você deseja monitorar, execute o script de instalação do Node Exporter:

```bash
curl -sSL https://raw.githubusercontent.com/seu-usuario/server-monitoring/main/scripts/install-node-exporter.sh | bash
```

Ou baixe e execute localmente:

```bash
./scripts/install-node-exporter.sh
```

### 3. Configuração do Prometheus

1. Edite o arquivo `prometheus/prometheus.yml` e adicione os servidores que deseja monitorar:

```yaml
scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['servidor1:9100', 'servidor2:9100']
```

2. Reinicie o Prometheus para aplicar as alterações:
```bash
cd prometheus
docker-compose restart
```

### 4. Configuração do Grafana

1. Acesse o Grafana em `http://seu-ip:3000`
2. Adicione o Prometheus como fonte de dados:
   - URL: `http://prometheus:9090`
   - Access: `Server (default)`
3. Importe dashboards recomendados:
   - Node Exporter Full (ID: 1860)
   - Node Exporter Server Metrics (ID: 405)

## Alertas

Os alertas estão configurados no arquivo `prometheus/alert.rules.yml`. Por padrão, incluímos alertas para:

- Uso elevado de CPU (>80%)
- Uso elevado de memória (>85%)
- Uso elevado de disco (>85%)
- Servidor offline

## Manutenção

### Adicionando Novos Servidores

1. Execute o script de instalação do Node Exporter no novo servidor
2. Adicione o novo servidor ao arquivo `prometheus/prometheus.yml`
3. Reinicie o Prometheus

### Atualizando as Configurações

1. Edite os arquivos de configuração conforme necessário
2. Reinicie os serviços afetados:
   ```bash
   docker-compose restart
   ```

## Suporte

Para problemas ou sugestões, abra uma issue neste repositório.

## Licença

MIT 