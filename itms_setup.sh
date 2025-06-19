#!/bin/bash

set -e

echo "📦 Installing required packages..."
sudo apt update
sudo apt install -y php php-cli php-mysql unzip curl git mariadb-server composer ufw

echo "🔓 Allowing port 1047 through firewall..."
sudo ufw allow 1047/tcp || true

echo "📁 Creating directory and downloading script..."
sudo mkdir -p /opt/itms_script
sudo chown $USER:$USER /opt/itms_script
wget -O /opt/itms_script/itms_script.php https://raw.githubusercontent.com/ZarcInd/itms_script/main/tcp_server_performant.php

echo "📦 Installing PHP dependencies (Workerman)..."
composer require workerman/workerman

echo "🛠️ Setting up dummy stats file..."
mkdir -p stats
cat <<EOF > stats/stats.php
<?php
function logError($msg) {
    error_log("LOG: " . \$msg);
}
EOF

echo "🛠️ Setting up systemd service..."
sudo tee /etc/systemd/system/itms_script.service > /dev/null <<EOF
[Unit]
Description=ITMS TCP Server (Workerman)
After=network.target

[Service]
ExecStart=/usr/bin/php /opt/itms_script/itms_script.php start
Restart=always
User=$USER

[Install]
WantedBy=multi-user.target
EOF

echo "📂 Reloading and enabling systemd service..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable itms_script.service
sudo systemctl start itms_script.service

echo "🗃️ Setting up MariaDB database and user..."
sudo mysql -e "CREATE DATABASE IF NOT EXISTS itms_primeedge;"
sudo mysql -e "CREATE USER IF NOT EXISTS 'itms_primeedge'@'localhost' IDENTIFIED BY '123';"
sudo mysql -e "GRANT ALL PRIVILEGES ON itms_primeedge.* TO 'itms_primeedge'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

echo "✅ Setup Complete. Server is running and database is ready."
sudo systemctl status itms_script.service
