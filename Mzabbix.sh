#!/bin/bash
# Variables
DB_ROOT_PASSWORD="MZABBIX"
DB_ZABBIX_PASSWORD="MZABBIXP"
DB_NAME="zabbix"
DB_USER="zabbix"
ZABBIX_VERSION="6.0"

# Update system and install necessary packages
sudo apt update -y
sudo apt install -y wget

# Add Zabbix repository
wget https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/ubuntu/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-2+ubuntu22.04_all.deb
sudo dpkg -i zabbix-release_${ZABBIX_VERSION}-2+ubuntu22.04_all.deb
sudo apt update -y

# Install Zabbix server, frontend, and agent
sudo apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-nginx-conf zabbix-agent

# Install and start MySQL
sudo apt install -y mysql-server
sudo systemctl start mysql
sudo systemctl enable mysql

# Secure MySQL installation
sudo mysql -uroot <<-EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH 'mysql_native_password' BY '${DB_ROOT_PASSWORD}';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

# Create Zabbix database and user
sudo mysql -uroot -p${DB_ROOT_PASSWORD} <<-EOF
CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_ZABBIX_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

# Import initial schema and data
zcat /usr/share/doc/zabbix-sql-scripts/mysql/server.sql.gz | mysql -u${DB_USER} -p${DB_ZABBIX_PASSWORD} ${DB_NAME}

# Configure Zabbix server
sudo sed -i "s/^# DBPassword=/DBPassword=${DB_ZABBIX_PASSWORD}/" /etc/zabbix/zabbix_server.conf

# Configure PHP for Zabbix frontend
sudo sed -i "s|^; php_value\[date.timezone\] =.*|php_value[date.timezone] = Europe/Riga|" /etc/zabbix/nginx.conf

# Start and enable Zabbix server, agent, and Nginx
sudo systemctl restart zabbix-server zabbix-agent nginx php-fpm
sudo systemctl enable zabbix-server zabbix-agent nginx php-fpm

# Output message
echo "Zabbix installation and setup completed. Access Zabbix frontend at http://your_server_ip/zabbix"
