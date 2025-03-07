#!/bin/bash

# Função para exibir ajuda
show_help() {
    echo "Uso: $0 [OPÇÕES]"
    echo ""
    echo "Script para instalar e configurar o Node Exporter usando Docker"
    echo ""
    echo "Opções:"
    echo "  -h, --help                 Mostra esta mensagem de ajuda"
    echo "  -p, --port PORTA          Define a porta do Node Exporter (padrão: 9100)"
    echo "  -n, --name NOME           Define o nome do container (padrão: node-exporter)"
    echo ""
    echo "Exemplo:"
    echo "  $0 -p 9100 -n node-exporter-prod"
    exit 0
}

# Valores padrão
PORT=9100
CONTAINER_NAME="node-exporter"

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

# Inicia o Node Exporter
echo "Iniciando Node Exporter na porta $PORT..."
docker run -d \
    --name $CONTAINER_NAME \
    --restart unless-stopped \
    --net="host" \
    --pid="host" \
    -v "/:/host:ro,rslave" \
    quay.io/prometheus/node-exporter:latest \
    --path.rootfs=/host \
    --web.listen-address=:$PORT

# Verifica se o container está rodando
if docker ps | grep -q $CONTAINER_NAME; then
    echo "Node Exporter instalado e rodando com sucesso!"
    echo "Porta: $PORT"
    echo "Nome do container: $CONTAINER_NAME"
else
    echo "Erro ao iniciar o Node Exporter. Verifique os logs do Docker:"
    docker logs $CONTAINER_NAME
    exit 1
fi 