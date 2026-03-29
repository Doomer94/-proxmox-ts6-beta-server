#!/usr/bin/env bash

# Modified for TeamSpeak 6 Server

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# === TS6 CONFIG ===
RELEASE="v6.0.0-beta8"
TS_URL="https://github.com/teamspeak/teamspeak6-server/releases/download/v6.0.0%2Fbeta8/teamspeak-server_linux_amd64-${RELEASE}.tar.bz2"

msg_info "Setting up TeamSpeak 6 Server"

# Download
curl -fsSL "$TS_URL" -o ts6server.tar.bz2

# Extract
tar -xf ts6server.tar.bz2

# Move to /opt
mv teamspeak-server_linux_amd64/ /opt/teamspeak-server/

# Accept license
touch /opt/teamspeak-server/.ts3server_license_accepted

# Cleanup
rm -f ~/ts6server.tar.bz2

# Save version
echo "${RELEASE}" > ~/.teamspeak-server

msg_ok "Setup TeamSpeak 6 Server"

# === SYSTEMD SERVICE ===
msg_info "Creating service"

cat <<EOF >/etc/systemd/system/teamspeak-server.service
[Unit]
Description=TeamSpeak 6 Server
Wants=network-online.target
After=network.target

[Service]
WorkingDirectory=/opt/teamspeak-server
User=root
Type=forking
ExecStart=/opt/teamspeak-server/tsserver_startscript.sh start
ExecStop=/opt/teamspeak-server/tsserver_startscript.sh stop
ExecReload=/opt/teamspeak-server/tsserver_startscript.sh restart
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl enable -q --now teamspeak-server

msg_ok "Created service"

motd_ssh
customize
cleanup_lxc