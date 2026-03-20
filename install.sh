#!/bin/sh
set -e

BIN_PATH="/root/router-agent"
CONFIG_PATH="/etc/router-agent.conf"
INIT_PATH="/etc/init.d/router-agent"
DOWNLOAD_DIR="/tmp/router-agent"

SHARED_SECRET="9f4e9e0e8b0b1d3f7c2a8f91c4e62d7b_router_secret"
HEARTBEAT_INTERVAL="15"
LAN_IP="auto"

AGENT_URL="https://raw.githubusercontent.com/Naobgon/router-agent-openwrt/main/router-agent"

CLIENT_ID=""
SERVER_IP=""
SERVER_PORT=""
SERVER_ADDR=""

require_root() {
    [ "$(id -u)" -eq 0 ] || {
        echo "Запусти от root"
        exit 1
    }
}

need_value() {
    [ -n "$2" ] || {
        echo "Для аргумента $1 не указано значение"
        exit 1
    }
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --client-id)
                need_value "$1" "$2"
                CLIENT_ID="$2"
                shift 2
                ;;
            --server-ip)
                need_value "$1" "$2"
                SERVER_IP="$2"
                shift 2
                ;;
            --server-port)
                need_value "$1" "$2"
                SERVER_PORT="$2"
                shift 2
                ;;
            --server-addr)
                need_value "$1" "$2"
                SERVER_ADDR="$2"
                shift 2
                ;;
            *)
                echo "Неизвестный аргумент: $1"
                exit 1
                ;;
        esac
    done
}

ask() {
    var="$1"
    text="$2"

    eval val=\"\${$var}\"

    if [ -z "$val" ]; then
        printf "%s: " "$text"
        read input
        eval "$var=\"\$input\""
    fi
}

build_server_addr() {
    if [ -z "$SERVER_ADDR" ]; then
        ask SERVER_IP "Введите IP сервера"
        ask SERVER_PORT "Введите порт"
        SERVER_ADDR="${SERVER_IP}:${SERVER_PORT}"
    fi
}

download_agent() {
    echo "Скачиваю router-agent..."
    wget -O "$BIN_PATH" "$AGENT_URL"
    chmod +x "$BIN_PATH"
}

backup_config() {
    [ -f "$CONFIG_PATH" ] && cp "$CONFIG_PATH" "$CONFIG_PATH.bak"
}

write_config() {
    echo "Создаю конфиг..."
    mkdir -p "$DOWNLOAD_DIR"

    cat > "$CONFIG_PATH" <<EOF
client_id=$CLIENT_ID
server_addr=$SERVER_ADDR
shared_secret=$SHARED_SECRET
download_dir=$DOWNLOAD_DIR
heartbeat_interval=$HEARTBEAT_INTERVAL
lan_ip=$LAN_IP
EOF
}

write_service() {
    echo "Создаю сервис..."

    cat > "$INIT_PATH" <<'EOF'
#!/bin/sh /etc/rc.common

START=95
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /root/router-agent
    procd_set_param respawn 3600 5 5
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}
EOF

    chmod +x "$INIT_PATH"
}

start_agent_service() {
    /etc/init.d/router-agent enable
    /etc/init.d/router-agent restart
}

main() {
    require_root
    parse_args "$@"

    ask CLIENT_ID "Введите client_id"
    build_server_addr

    download_agent
    backup_config
    write_config
    write_service
    start_agent_service

    echo ""
    echo "Готово:"
    echo "client_id: $CLIENT_ID"
    echo "server:    $SERVER_ADDR"
}

main "$@"
