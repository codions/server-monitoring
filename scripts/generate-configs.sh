#!/bin/sh

# Gera a configuração do Prometheus
cat > /etc/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - /etc/prometheus/alert.rules.yml

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
EOF

# Adiciona configuração de autenticação básica se as credenciais estiverem definidas
if [ -n "${NODE_EXPORTER_USERNAME}" ] && [ -n "${NODE_EXPORTER_PASSWORD}" ]; then
  cat >> /etc/prometheus/prometheus.yml << EOF
    basic_auth:
      username: "${NODE_EXPORTER_USERNAME}"
      password: "${NODE_EXPORTER_PASSWORD}"
EOF
fi

# Adiciona configuração de TLS se habilitado
if [ "${TLS_ENABLED}" = "true" ]; then
  cat >> /etc/prometheus/prometheus.yml << EOF
    scheme: https
    tls_config:
      insecure_skip_verify: true
EOF
else
  cat >> /etc/prometheus/prometheus.yml << EOF
    scheme: http
EOF
fi

# Adiciona os servidores monitorados
cat >> /etc/prometheus/prometheus.yml << EOF
    static_configs:
EOF

IFS=','
for server in ${MONITORED_SERVERS}; do
  echo "      - targets: ['${server}']" >> /etc/prometheus/prometheus.yml
  echo "        labels:" >> /etc/prometheus/prometheus.yml
  echo "          environment: production" >> /etc/prometheus/prometheus.yml
done

# Gera as regras de alerta
cat > /etc/prometheus/alert.rules.yml << EOF
groups:
  - name: node_alerts
    rules:
      - alert: HighCpuUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > ${ALERT_CPU_THRESHOLD}
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Alto uso de CPU em {{ \$labels.instance }}"
          description: "O uso de CPU está acima de ${ALERT_CPU_THRESHOLD}% por 5 minutos em {{ \$labels.instance }}"

      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > ${ALERT_MEMORY_THRESHOLD}
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Alto uso de memória em {{ \$labels.instance }}"
          description: "O uso de memória está acima de ${ALERT_MEMORY_THRESHOLD}% por 5 minutos em {{ \$labels.instance }}"

      - alert: HighDiskUsage
        expr: 100 - ((node_filesystem_avail_bytes{mountpoint="/"} * 100) / node_filesystem_size_bytes{mountpoint="/"}) > ${ALERT_DISK_THRESHOLD}
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Alto uso de disco em {{ \$labels.instance }}"
          description: "O uso de disco está acima de ${ALERT_DISK_THRESHOLD}% por 5 minutos em {{ \$labels.instance }}"

      - alert: InstanceDown
        expr: up == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Instância fora do ar: {{ \$labels.instance }}"
          description: "A instância {{ \$labels.instance }} está fora do ar há 5 minutos"
EOF

# Gera a configuração do AlertManager
cat > /etc/alertmanager/alertmanager.yml << EOF
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'instance']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 1h
  receiver: 'default-receiver'

receivers:
  - name: 'default-receiver'
EOF

# Processa os canais de notificação ativos
IFS=','
for channel in ${ALERT_CHANNELS:-email}; do
  case $channel in
    email)
      if [ -n "${EMAIL_RECEIVERS}" ]; then
        echo "    email_configs:" >> /etc/alertmanager/alertmanager.yml
        IFS=','
        for email in ${EMAIL_RECEIVERS}; do
          cat >> /etc/alertmanager/alertmanager.yml << EMAIL_EOF
      - to: '${email}'
        from: '${EMAIL_FROM:-alertmanager@example.com}'
        smarthost: '${EMAIL_SMARTHOST:-smtp.example.com:587}'
        auth_username: '${EMAIL_AUTH_USERNAME:-alertmanager}'
        auth_password: '${EMAIL_AUTH_PASSWORD:-password}'
        send_resolved: true
EMAIL_EOF
        done
      fi
      ;;
      
    slack)
      if [ -n "${SLACK_WEBHOOK_URL}" ]; then
        echo "    slack_configs:" >> /etc/alertmanager/alertmanager.yml
        cat >> /etc/alertmanager/alertmanager.yml << SLACK_EOF
      - api_url: '${SLACK_WEBHOOK_URL}'
        channel: '${SLACK_CHANNEL:-#alertas}'
        username: '${SLACK_USERNAME:-AlertManager}'
        send_resolved: true
        title: '{{ .Status | toUpper }} {{ .CommonLabels.alertname }}'
        text: >-
          {{ range .Alerts }}
            *Alerta:* {{ .Annotations.summary }}
            *Descrição:* {{ .Annotations.description }}
            *Severidade:* {{ .Labels.severity }}
            *Instância:* {{ .Labels.instance }}
            *Início:* {{ .StartsAt | since }}
          {{ end }}
SLACK_EOF
      fi
      ;;
      
    telegram)
      if [ -n "${TELEGRAM_BOT_TOKEN}" ] && [ -n "${TELEGRAM_CHAT_ID}" ]; then
        echo "    telegram_configs:" >> /etc/alertmanager/alertmanager.yml
        cat >> /etc/alertmanager/alertmanager.yml << TELEGRAM_EOF
      - bot_token: '${TELEGRAM_BOT_TOKEN}'
        chat_id: ${TELEGRAM_CHAT_ID}
        parse_mode: 'HTML'
        send_resolved: true
        message: >-
          <b>{{ .Status | toUpper }}</b> {{ .CommonLabels.alertname }}
          {{ range .Alerts }}
            <b>Alerta:</b> {{ .Annotations.summary }}
            <b>Descrição:</b> {{ .Annotations.description }}
            <b>Severidade:</b> {{ .Labels.severity }}
            <b>Instância:</b> {{ .Labels.instance }}
            <b>Início:</b> {{ .StartsAt | since }}
          {{ end }}
TELEGRAM_EOF
      fi
      ;;
  esac
done

# Adiciona configuração de inibição para evitar spam de alertas
cat >> /etc/alertmanager/alertmanager.yml << EOF

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['instance']
EOF

echo "Configurações geradas com sucesso!" 