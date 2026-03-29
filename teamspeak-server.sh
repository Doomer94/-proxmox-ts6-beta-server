#!/bin/bash
set -e

# ====== Параметры установки ======
TS_USER="teamspeak"
TS_HOME="/opt/teamspeak6"
DOWNLOAD_URL="https://github.com/teamspeak/teamspeak6-server/releases/download/v6.0.0%2Fbeta8/teamspeak-server_linux_amd64-v6.0.0-beta8.tar.bz2"
VOICE_PORT=9987  # стандартный порт TS6 UDP

# ====== Обновление системы и установка зависимостей ======
apt update && apt upgrade -y
apt install -y bzip2 tar wget curl

# ====== Создание пользователя ======
useradd -m -d "$TS_HOME" -s /usr/sbin/nologin "$TS_USER" || true

# ====== Скачивание и распаковка архива ======
mkdir -p "$TS_HOME"
cd /tmp
wget -O teamspeak6.tar.bz2 "$DOWNLOAD_URL"
tar xjf teamspeak6.tar.bz2

# ====== Перемещение файлов на верхний уровень ======
mv teamspeak-server_linux_amd64/* "$TS_HOME"/
rmdir teamspeak-server_linux_amd64
chown -R "$TS_USER":"$TS_USER" "$TS_HOME"

# ====== Принятие лицензии ======
touch "$TS_HOME/.tsserver_license_accepted"
chown "$TS_USER":"$TS_USER" "$TS_HOME/.tsserver_license_accepted"

# ====== Даем права на исполняемый бинарник ======
chmod +x "$TS_HOME/tsserver"

# ====== Создание systemd unit ======
cat > /etc/systemd/system/teamspeak6.service << 'EOF'
[Unit]
Description=TeamSpeak 6 Server
After=network.target

[Service]
User=teamspeak
Group=teamspeak
WorkingDirectory=/opt/teamspeak6
Type=forking
ExecStart=/opt/teamspeak6/tsserver --accept-license --daemon --pid-file /opt/teamspeak6/tsserver.pid
ExecStartPre=/bin/rm -f /opt/teamspeak6/tsserver.pid
PIDFile=/opt/teamspeak6/tsserver.pid
ExecStop=/bin/kill -TERM $MAINPID
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# ====== Перезагрузка systemd и автозапуск ======
systemctl daemon-reload
systemctl enable teamspeak6.service
systemctl start teamspeak6.service

# ====== Определение локального IP ======
LOCAL_IP=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -n1)

# ====== Вывод информации ======
echo "=============================================="
echo "TeamSpeak 6 Server установлен и запущен!"
echo "Локальный IP сервера: $LOCAL_IP"
echo "Порт для подключения: $VOICE_PORT (UDP)"
echo "Статус сервера: systemctl status teamspeak6.service"
echo "Для логов: journalctl -u teamspeak6.service -f"
echo "=============================================="