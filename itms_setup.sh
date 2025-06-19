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
cd /opt/itms_script
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

echo "🛡️ Granting privileges from root user..."
sudo mysql -e "GRANT ALL PRIVILEGES ON itms_primeedge.* TO 'itms_primeedge'@'127.0.0.1' IDENTIFIED BY '123';
GRANT ALL PRIVILEGES ON itms_primeedge.* TO 'itms_primeedge'@'localhost' IDENTIFIED BY '123';
FLUSH PRIVILEGES;"
echo "🛠️ Creating required tables in itms_primeedg..."
sudo mysql -u itms_primeedge -p123 itms_primeedge <<EOF
CREATE TABLE IF NOT EXISTS raw_data_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    raw_data TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS itms_data (
    id INT AUTO_INCREMENT PRIMARY KEY,
    packet_header VARCHAR(50),
    mode VARCHAR(10),
    device_type VARCHAR(10),
    packet_type VARCHAR(10),
    firmware_version VARCHAR(50),
    device_id VARCHAR(25),
    ignition VARCHAR(10),
    driver_id INT,
    time VARCHAR(20),
    date VARCHAR(20),
    gps VARCHAR(5),
    lat DECIMAL(10,6),
    lat_dir VARCHAR(2),
    lon DECIMAL(10,6),
    lon_dir VARCHAR(2),
    speed_knots INT,
    network VARCHAR(20),
    route_no VARCHAR(20),
    speed_kmh DECIMAL(10,2),
    odo_meter INT,
    Led_health_1 INT,
    Led_health_2 INT,
    Led_health_3 INT,
    Led_health_4 INT,
    partition_key INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF

echo "✅ Setup Complete. Server is running and database is ready."
sudo systemctl status itms_script.service
