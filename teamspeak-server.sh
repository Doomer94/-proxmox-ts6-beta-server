#!/bin/bash
set -e

### ПЕРЕМЕННЫЕ НАСТРОЙКИ
TS_USER="teamspeak"
TS_HOME="/opt/teamspeak6"
DOWNLOAD_URL="https://github.com/teamspeak/teamspeak6-server/releases/download/v6.0.0%2Fbeta8/teamspeak-server_linux_amd64-v6.0.0-beta8.tar.bz2"

### Обновление системы
apt update && apt upgrade -y

### Создаём пользователя
useradd -m -d "$TS_HOME" -s /usr/sbin/nologin "$TS_USER" || true

### Установка зависимостей (если нужны)
apt install -y bzip2 tar

### Скачиваем и распаковываем
mkdir -p "$TS_HOME"
cd /tmp
wget -O teamspeak6.tar.bz2 "$DOWNLOAD_URL"
tar xjf teamspeak6.tar.bz2

# Перемещаем в папку teamspeak
mv ./teamspeak-server_linux_amd64 "$TS_HOME"
chown -R "$TS_USER":"$TS_USER" "$TS_HOME"

### Принятие лицензии (файл)
touch "$TS_HOME/.tsserver_license_accepted"
chown "$TS_USER":"$TS_USER" "$TS_HOME/.tsserver_license_accepted"

### systemd‑unit
cat > /etc/systemd/system/teamspeak6.service << 'EOF'
[Unit]
Description=TeamSpeak 6 Server
After=network.target

[Service]
User=teamspeak
Group=teamspeak
WorkingDirectory=/opt/teamspeak6
Type=forking
ExecStart=/opt/teamspeak6/tsserver --accept-license --daemon --pid-file /opt/teamspeak6/ts6server.pid
ExecStartPre=/bin/rm -f /opt/teamspeak6/ts6server.pid
PIDFile=/opt/teamspeak6/ts6server.pid
ExecStop=/bin/kill -TERM $MAINPID
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

### Перезагружаем systemd и включаем автозапуск
systemctl daemon-reload
systemctl enable teamspeak6.service

echo "Установка завершена! Запустить сервер: systemctl start teamspeak6.service"
echo "Посмотреть статус: systemctl status teamspeak6.service"