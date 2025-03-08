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
    echo "  -r, --reset                Remove completamente o Node Exporter e suas configurações"
    echo "  -f, --fix-permissions      Corrige as permissões dos certificados TLS existentes"
    echo "  -w, --firewall             Configura o firewall (UFW) automaticamente"
    echo "  -i, --allow-from IP        Permite acesso apenas do IP especificado (requer -w)"
    echo ""
    echo "Exemplo:"
    echo "  $0 -p 9100 -n node-exporter-prod -u prometheus -s secret -t -w"
    echo "  $0 -r -n node-exporter     # Remove completamente o Node Exporter"
    echo "  $0 -f -d /caminho/para/config  # Corrige permissões dos certificados"
    echo "  $0 -w -i 192.168.1.10      # Configura firewall para permitir acesso apenas do IP 192.168.1.10"
    exit 0
}

# Função para remover completamente o Node Exporter
do_reset() {
    local container_name=$1
    local config_dir=$2

    echo "Realizando hard reset do Node Exporter..."
    
    # Para e remove o container se estiver rodando
    if docker ps -a | grep -q $container_name; then
        echo "Parando e removendo container $container_name..."
        docker stop $container_name >/dev/null 2>&1
        docker rm $container_name >/dev/null 2>&1
    fi
    
    # Remove o diretório de configuração
    if [ -d "$config_dir" ]; then
        echo "Removendo diretório de configuração $config_dir..."
        rm -rf "$config_dir"
    fi
    
    # Remove também o diretório /opt/node-exporter se existir e tivermos permissão
    if [ -d "/opt/node-exporter" ] && [ -w "/opt/node-exporter" ]; then
        echo "Removendo diretório /opt/node-exporter..."
        rm -rf "/opt/node-exporter"
    elif [ -d "/opt/node-exporter" ]; then
        echo "Aviso: Diretório /opt/node-exporter existe mas não temos permissão para removê-lo."
        echo "Para remover completamente, execute: sudo rm -rf /opt/node-exporter"
    fi
    
    echo "Hard reset concluído. O Node Exporter foi completamente removido."
    exit 0
}

# Função para corrigir permissões dos certificados
fix_permissions() {
    local config_dir=$1
    local container_name=$2
    
    echo "Corrigindo permissões dos certificados TLS..."
    
    # Verifica se os diretórios existem
    if [ ! -d "$config_dir/certs" ]; then
        echo "Diretório de certificados não encontrado: $config_dir/certs"
        echo "Criando diretório..."
        mkdir -p "$config_dir/certs"
    fi
    
    if [ ! -d "$config_dir/config" ]; then
        echo "Diretório de configuração não encontrado: $config_dir/config"
        echo "Criando diretório..."
        mkdir -p "$config_dir/config"
    fi
    
    # Verifica se os certificados existem
    if [ -f "$config_dir/certs/server.crt" ] && [ -f "$config_dir/certs/server.key" ]; then
        echo "Certificados encontrados. Ajustando permissões..."
        chmod 666 "$config_dir/certs/server.crt"
        chmod 666 "$config_dir/certs/server.key"
        echo "Permissões dos certificados ajustadas para 666 (rw-rw-rw-)."
    else
        echo "Certificados não encontrados. Gerando novos certificados..."
        docker run --rm -v "$config_dir/certs:/certs" alpine/openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -subj "/CN=node-exporter" -keyout /certs/server.key -out /certs/server.crt
        chmod 666 "$config_dir/certs/server.crt"
        chmod 666 "$config_dir/certs/server.key"
        echo "Novos certificados gerados com permissões 666 (rw-rw-rw-)."
    fi
    
    # Verifica se o arquivo de configuração existe
    if [ -f "$config_dir/config/web.yml" ]; then
        echo "Arquivo de configuração encontrado. Ajustando permissões..."
        chmod 666 "$config_dir/config/web.yml"
        echo "Permissões do arquivo de configuração ajustadas para 666 (rw-rw-rw-)."
    else
        echo "Arquivo de configuração não encontrado."
    fi
    
    echo "Permissões dos arquivos:"
    ls -la "$config_dir/certs/"
    ls -la "$config_dir/config/"
    
    # Reinicia o container se estiver rodando
    if docker ps -a | grep -q "$container_name"; then
        echo "Reiniciando o container $container_name para aplicar as novas permissões..."
        docker restart "$container_name"
        echo "Container reiniciado."
    else
        echo "Container $container_name não encontrado. As permissões foram corrigidas, mas você precisa iniciar o container manualmente."
    fi
    
    echo "Correção de permissões concluída."
    exit 0
}

# Função para configurar o firewall (UFW)
configure_firewall() {
    local port=$1
    local allow_from=$2
    
    # Verifica se o UFW está instalado
    if ! command -v ufw &> /dev/null; then
        echo "UFW não está instalado. Tentando instalar..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y ufw
        elif command -v yum &> /dev/null; then
            sudo yum install -y ufw
        else
            echo "Não foi possível instalar o UFW automaticamente. Por favor, instale manualmente."
            return 1
        fi
    fi
    
    # Verifica se o UFW está ativo
    if ! sudo ufw status | grep -q "Status: active"; then
        echo "UFW não está ativo. Ativando..."
        # Garante que a regra SSH esteja permitida antes de ativar o UFW
        sudo ufw allow 22/tcp
        sudo ufw --force enable
    fi
    
    # Configura a regra do firewall
    if [ -n "$allow_from" ]; then
        echo "Configurando firewall para permitir acesso à porta $port apenas do IP $allow_from..."
        # Remove regras existentes para a porta
        sudo ufw delete allow $port/tcp &>/dev/null
        # Adiciona a nova regra
        sudo ufw allow from $allow_from to any port $port proto tcp
    else
        echo "Configurando firewall para permitir acesso à porta $port de qualquer origem..."
        # Adiciona a regra
        sudo ufw allow $port/tcp
    fi
    
    # Mostra o status do firewall
    echo "Status do firewall:"
    sudo ufw status
    
    return 0
}

# Valores padrão
PORT=9100
CONTAINER_NAME="node-exporter"
USERNAME="prometheus"
PASSWORD="secret"
TLS_ENABLED=false
CONFIG_DIR="$HOME/.node-exporter"
RESET_MODE=false
FIX_PERMISSIONS=false
CONFIGURE_FIREWALL=false
ALLOW_FROM=""

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
        -r|--reset)
            RESET_MODE=true
            shift
            ;;
        -f|--fix-permissions)
            FIX_PERMISSIONS=true
            shift
            ;;
        -w|--firewall)
            CONFIGURE_FIREWALL=true
            shift
            ;;
        -i|--allow-from)
            ALLOW_FROM="$2"
            shift 2
            ;;
        *)
            echo "Opção inválida: $1"
            show_help
            ;;
    esac
done

# Se o modo reset estiver ativado, remove tudo e sai
if [ "$RESET_MODE" = true ]; then
    do_reset "$CONTAINER_NAME" "$CONFIG_DIR"
fi

# Se o modo de correção de permissões estiver ativado, corrige as permissões e sai
if [ "$FIX_PERMISSIONS" = true ]; then
    fix_permissions "$CONFIG_DIR" "$CONTAINER_NAME"
fi

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
mkdir -p $CONFIG_DIR/certs

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
    # Garante que o arquivo de configuração tenha permissões adequadas
    chmod 644 $CONFIG_DIR/config/web.yml
    AUTH_ARGS="--web.config.file=/config/web.yml"
else
    AUTH_ARGS=""
fi

# Configura TLS se habilitado
if [ "$TLS_ENABLED" = true ]; then
    echo "Configurando TLS..."
    # Gera certificados autoassinados
    docker run --rm -v $CONFIG_DIR/certs:/certs alpine/openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -subj "/CN=node-exporter" -keyout /certs/server.key -out /certs/server.crt
    
    # Garante que os certificados tenham permissões adequadas
    chmod 644 $CONFIG_DIR/certs/server.crt
    chmod 644 $CONFIG_DIR/certs/server.key
    
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
    
    # Garante que o arquivo de configuração tenha permissões adequadas
    chmod 644 $CONFIG_DIR/config/web.yml
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
    echo "Diretório de configuração: $CONFIG_DIR"
    
    # Configura o firewall se solicitado
    if [ "$CONFIGURE_FIREWALL" = true ]; then
        if configure_firewall "$PORT" "$ALLOW_FROM"; then
            echo "Firewall configurado com sucesso!"
        else
            echo "Aviso: Não foi possível configurar o firewall automaticamente."
            echo "Por favor, configure manualmente com os seguintes comandos:"
            if [ -n "$ALLOW_FROM" ]; then
                echo "  sudo ufw allow from $ALLOW_FROM to any port $PORT proto tcp"
            else
                echo "  sudo ufw allow $PORT/tcp"
            fi
        fi
    else
        echo ""
        echo "Aviso: O firewall não foi configurado automaticamente."
        echo "Para configurar o firewall manualmente, execute:"
        echo "  sudo ufw allow $PORT/tcp"
        echo ""
        echo "Ou para permitir acesso apenas de um IP específico:"
        echo "  sudo ufw allow from IP_DO_SERVIDOR to any port $PORT proto tcp"
    fi
    
    # Testa a conexão local
    echo ""
    echo "Testando conexão local..."
    if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
        if curl -s -u "$USERNAME:$PASSWORD" http://localhost:$PORT/metrics > /dev/null; then
            echo "Conexão local com autenticação: OK"
        else
            echo "Aviso: Não foi possível conectar localmente com autenticação."
        fi
    else
        if curl -s http://localhost:$PORT/metrics > /dev/null; then
            echo "Conexão local: OK"
        else
            echo "Aviso: Não foi possível conectar localmente."
        fi
    fi
else
    echo "Erro ao iniciar o Node Exporter. Verifique os logs do Docker:"
    docker logs $CONTAINER_NAME
    exit 1
fi 