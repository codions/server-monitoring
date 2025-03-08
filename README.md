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
├── docker-compose.yml      # Configuração unificada dos serviços
├── prometheus/
│   ├── prometheus.yml     # Configuração do Prometheus
│   └── alert.rules.yml    # Regras de alertas
└── scripts/
    └── install-node-exporter.sh  # Script de instalação do Node Exporter
```

## Instalação

### 1. Servidor de Monitoramento

1. Clone este repositório:
   ```bash
   git clone https://github.com/codions/server-monitoring.git
   cd server-monitoring
   ```

2. Inicie os serviços (Prometheus e Grafana):
   ```bash
   docker compose up -d
   ```

3. Acesse o Grafana em `http://seu-ip:3000` (credenciais padrão: admin/admin)

### 2. Configuração dos Servidores Monitorados

Para cada servidor que você deseja monitorar, execute o script de instalação do Node Exporter:

```bash
curl -sSL https://raw.githubusercontent.com/codions/server-monitoring/main/scripts/install-node-exporter.sh | bash
```

Ou baixe e execute localmente:

```bash
./scripts/install-node-exporter.sh
```

Exemplo de instalação padrão:
```bash
./scripts/install-node-exporter.sh
```

Exemplo com porta e nome personalizados:
```bash
./scripts/install-node-exporter.sh -p 9100 -n node-exporter-prod
```

### 3. Configuração do Prometheus

1. Edite o arquivo `prometheus/prometheus.yml` e adicione os servidores que deseja monitorar:

```yaml
scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['servidor1:9100', 'servidor2:9100']
```

2. Reinicie os serviços para aplicar as alterações:
```bash
docker compose restart prometheus
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
3. Reinicie o Prometheus:
   ```bash
   docker compose restart prometheus
   ```

### Atualizando as Configurações

1. Edite os arquivos de configuração conforme necessário
2. Reinicie os serviços afetados:
   ```bash
   docker compose restart
   ```

## Suporte

Para problemas ou sugestões, abra uma issue neste repositório.

## Licença

MIT 