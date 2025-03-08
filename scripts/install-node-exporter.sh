#!/bin/bash

# Função para exibir ajuda
show_help() {
    echo "Uso: $0 [OPÇÕES]"
    echo ""
    echo "Script para instalar e configurar o Node Exporter usando Docker"
    echo ""
    echo "Opções:"
    echo "  -h, --help                 Mostra esta mensagem de ajuda"
    echo "  -p, --port PORTA           Define a porta do Node Exporter (padrão: 9100)"
    echo "  -n, --name NOME            Define o nome do container (padrão: node-exporter)"
    echo "  -u, --username USUARIO     Define o usuário para autenticação básica"
    echo "  -s, --password SENHA       Define a senha para autenticação básica"
    echo "  -t, --tls                  Habilita TLS para comunicação segura"
    echo "  -d, --dir DIRETORIO        Define o diretório de configuração (padrão: $HOME/.node-exporter)"
    echo ""
    echo "Exemplo:"
    echo "  $0 -p 9100 -n node-exporter-prod -u prometheus -s secret -t"
    exit 0
}

# Valores padrão
PORT=9100
CONTAINER_NAME="node-exporter"
USERNAME="prometheus"
PASSWORD="secret"
TLS_ENABLED=false
CONFIG_DIR="$HOME/.node-exporter"

# Processa os argumentos da linha de comando
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -n|--name)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        -u|--username)
            USERNAME="$2"
            shift 2
            ;;
        -s|--password)
            PASSWORD="$2"
            shift 2
            ;;
        -t|--tls)
            TLS_ENABLED=true
            shift
            ;;
        -d|--dir)
            CONFIG_DIR="$2"
            shift 2
            ;;
        *)
            echo "Opção inválida: $1"
            show_help
            ;;
    esac
done

# Verifica se o Docker está instalado
if ! command -v docker &> /dev/null; then
    echo "Docker não está instalado. Por favor, instale o Docker primeiro."
    exit 1
fi

# Para o container se já estiver rodando
if docker ps -a | grep -q $CONTAINER_NAME; then
    echo "Parando e removendo container existente..."
    docker stop $CONTAINER_NAME
    docker rm $CONTAINER_NAME
fi

# Cria diretório para configurações
mkdir -p $CONFIG_DIR/config

# Gera arquivo de configuração para autenticação básica
if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
    echo "Configurando autenticação básica..."
    # Gera hash da senha
    HASHED_PASSWORD=$(docker run --rm httpd:2.4-alpine htpasswd -nbB "$USERNAME" "$PASSWORD" | cut -d ":" -f 2)
    
    # Cria arquivo de configuração
    cat > $CONFIG_DIR/config/web.yml << EOF
basic_auth_users:
  $USERNAME: $HASHED_PASSWORD
EOF
    AUTH_ARGS="--web.config.file=/config/web.yml"
else
    AUTH_ARGS=""
fi

# Configura TLS se habilitado
if [ "$TLS_ENABLED" = true ]; then
    echo "Configurando TLS..."
    # Gera certificados autoassinados
    mkdir -p $CONFIG_DIR/certs
    docker run --rm -v $CONFIG_DIR/certs:/certs alpine/openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -subj "/CN=node-exporter" -keyout /certs/server.key -out /certs/server.crt
    
    # Adiciona configuração TLS ao arquivo de configuração
    if [ -f "$CONFIG_DIR/config/web.yml" ]; then
        cat >> $CONFIG_DIR/config/web.yml << EOF
tls_server_config:
  cert_file: /certs/server.crt
  key_file: /certs/server.key
EOF
    else
        cat > $CONFIG_DIR/config/web.yml << EOF
tls_server_config:
  cert_file: /certs/server.crt
  key_file: /certs/server.key
EOF
    fi
    
    AUTH_ARGS="--web.config.file=/config/web.yml"
fi

# Inicia o Node Exporter
echo "Iniciando Node Exporter na porta $PORT..."
docker run -d \
    --name $CONTAINER_NAME \
    --restart unless-stopped \
    --net="host" \
    --pid="host" \
    -v "/:/host:ro,rslave" \
    -v "$CONFIG_DIR/config:/config:ro" \
    -v "$CONFIG_DIR/certs:/certs:ro" \
    prom/node-exporter:latest \
    --path.rootfs=/host \
    --web.listen-address=:$PORT \
    $AUTH_ARGS

# Verifica se o container está rodando
if docker ps | grep -q $CONTAINER_NAME; then
    echo "Node Exporter instalado e rodando com sucesso!"
    echo "Porta: $PORT"
    echo "Nome do container: $CONTAINER_NAME"
    if [ -n "$USERNAME" ]; then
        echo "Autenticação básica configurada com usuário: $USERNAME"
    fi
    if [ "$TLS_ENABLED" = true ]; then
        echo "TLS habilitado"
    fi
else
    echo "Erro ao iniciar o Node Exporter. Verifique os logs do Docker:"
    docker logs $CONTAINER_NAME
    exit 1
fi 