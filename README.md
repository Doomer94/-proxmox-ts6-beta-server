# -proxmox-ts6-beta-server

# Переходим в папку для установки, например /tmp
cd /tmp

# Скачиваем raw‑скрипт
wget -O teamspeak-server.sh https://raw.githubusercontent.com/Doomer94/-proxmox-ts6-beta-server/main/teamspeak-server.sh

# Делаем его исполняемым
chmod +x teamspeak-server.sh

# Запускаем скрипт
sudo ./teamspeak-server.sh