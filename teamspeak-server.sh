#!/usr/bin/env bash
# TeamSpeak 6 Server — установка на Debian 12 + systemd (автозапуск)
# Запуск: sudo bash install-ts6-debian.sh
#
# Переменные окружения (необязательно):
#   TS_URL      — URL архива (.tar.bz2)
#   INSTALL_DIR — каталог установки (по умолчанию /opt/teamspeak6)
#   TS_USER     — системный пользователь (по умолчанию teamspeak)
#   OPEN_UFW=1  — открыть порты в UFW (9987/udp, 30033/tcp)

set -euo pipefail

TS_URL="${TS_URL:-https://github.com/teamspeak/teamspeak6-server/releases/download/v6.0.0%2Fbeta8/teamspeak-server_linux_amd64-v6.0.0-beta8.tar.bz2}"
INSTALL_DIR="${INSTALL_DIR:-/opt/teamspeak6}"
TS_USER="${TS_USER:-teamspeak}"
SERVICE_NAME="teamspeak6"
VOICE_PORT="${VOICE_PORT:-9987}"
FILETRANSFER_PORT="${FILETRANSFER_PORT:-30033}"

die() { echo "Ошибка: $*" >&2; exit 1; }

[[ "$(id -u)" -eq 0 ]] || die "Запустите от root: sudo bash $0"

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends wget ca-certificates bzip2

mkdir -p "$INSTALL_DIR"

if id -u "$TS_USER" &>/dev/null; then
  echo "Пользователь $TS_USER уже существует."
else
  useradd -r -m -d "$INSTALL_DIR" -s /usr/sbin/nologin "$TS_USER" || die "useradd"
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Скачивание: $TS_URL"
wget -q --show-progress -O "$TMP/ts6.tar.bz2" "$TS_URL" || die "wget"

echo "Распаковка..."
tar -xjf "$TMP/ts6.tar.bz2" -C "$TMP"

TSBIN=$(find "$TMP" -name tsserver -type f -perm /111 2>/dev/null | head -1)
[[ -n "$TSBIN" ]] || TSBIN=$(find "$TMP" -name tsserver -type f 2>/dev/null | head -1)
[[ -n "$TSBIN" ]] || die "В архиве не найден бинарник tsserver"
chmod +x "$TSBIN"

TSROOT=$(dirname "$TSBIN")
# Копируем всё из каталога с tsserver в INSTALL_DIR
shopt -s dotglob nullglob
for item in "$TSROOT"/*; do
  name=$(basename "$item")
  rm -rf "$INSTALL_DIR/$name"
  cp -a "$item" "$INSTALL_DIR/"
done
shopt -u dotglob nullglob

chown -R "$TS_USER:$TS_USER" "$INSTALL_DIR"
chmod +x "$INSTALL_DIR/tsserver"

UNIT="/etc/systemd/system/${SERVICE_NAME}.service"
cat >"$UNIT" <<EOF
[Unit]
Description=TeamSpeak 6 Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$TS_USER
Group=$TS_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/tsserver --accept-license
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$INSTALL_DIR

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"

# Первый запуск: останавливаем, если вдруг уже был, чтобы получить ключ из чистого старта при новой БД
if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
  systemctl stop "$SERVICE_NAME" || true
fi

systemctl start "$SERVICE_NAME"
sleep 4

if [[ "${OPEN_UFW:-0}" == "1" ]]; then
  if command -v ufw &>/dev/null; then
    ufw allow "${VOICE_PORT}/udp" comment 'TS6 voice' || true
    ufw allow "${FILETRANSFER_PORT}/tcp" comment 'TS6 filetransfer' || true
    echo "UFW: добавлены правила для портов $VOICE_PORT/udp и $FILETRANSFER_PORT/tcp."
  else
    echo "OPEN_UFW=1, но ufw не установлен — пропуск."
  fi
fi

# --- Вывод IP и порта ---
echo ""
echo "========== TeamSpeak 6 — сводка =========="
echo ""

PUB_IP=""
PUB_IP=$(wget -qO- --timeout=5 https://api.ipify.org 2>/dev/null || true)
[[ -n "$PUB_IP" ]] || PUB_IP=$(wget -qO- --timeout=5 https://ifconfig.me 2>/dev/null || true)

echo "1) Подключение клиента (голос): адрес:порт"
if [[ -n "$PUB_IP" ]]; then
  echo "   Публичный IP (если верен): ${PUB_IP}:${VOICE_PORT}  (UDP)"
else
  echo "   Публичный IP не определён автоматически (нет выхода в интернет или блокировка wget)."
fi
echo "   Локальные адреса этой машины:"
ip -4 addr show scope global 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | while read -r a; do
  echo "     ${a}:${VOICE_PORT}"
done
echo "   Также нужен TCP ${FILETRANSFER_PORT} (файлы) при использовании передачи файлов."
echo ""

# --- ServerAdmin privilege key (только при первом создании БД) ---
echo "2) Учётные данные администратора (первый вход в клиенте)"
LOG_LINES=$(journalctl -u "$SERVICE_NAME" -n 400 --no-pager 2>/dev/null || true)
KEY_LINES=$(echo "$LOG_LINES" | grep -iE 'privilege|serveradmin|token|administrator' || true)

if [[ -n "$KEY_LINES" ]]; then
  echo "   ServerAdmin privilege key — вставьте в TeamSpeak 6 клиент при запросе прав администратора:"
  echo "$KEY_LINES" | sed 's/^/   /'
else
  echo "   Строка с ключом не найдена (часто если сервер уже запускался раньше — ключ показывается один раз)."
  echo "   Ищите вручную:"
  echo "     journalctl -u $SERVICE_NAME --no-pager | grep -iE 'privilege|serveradmin|token'"
fi

echo ""
echo "Сервис: systemctl status $SERVICE_NAME"
echo "Логи:   journalctl -u $SERVICE_NAME -f"
echo "=========================================="
