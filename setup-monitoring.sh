#!/bin/bash

# Instalar docker y docker compose si la pc no tiene instalado

if ! command -v docker &> /dev/null; then
  echo "Instalando Docker..."
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  sudo suermod -aG docker $USER
fi 

if ! command -v docker-compose &> /dev/null; then
  echo "Instalando docker compose..."
  sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
fi

# crear directorio de trabajo
mkdir -p monitoring-setup
cd monitoring-setup

# Crear el archivo docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3'
services:
  zabbix-server:
    image: zabbix/zabbix-server-mysql:ubuntu-6.4-latest
    container_name: zabbix-server
    restart: unless-stopped
    ports:
      - "10051:10051"
    environment:
      - DB_SERVER_HOST=zabbix-mysql
      - MYSQL_DATABASE=zabbix
      - MYSQL_USER=zabbix
      - MYSQL_PASSWORD=zabbix_pwd
      - MYSQL_ROOT_PASSWORD=root_pwd
    networks:
      - monitoring-net
    depends_on:
      - zabbix-mysql


  zabbix-mysql:
    image: mysql:8.0
    container_name: zabbix-mysql
    restart: unless-stopped
    environment:
      - MYSQL_DATABASE=zabbix
      - MYSQL_USER=zabbix
      - MYSQL_PASSWORD=zabbix_pwd
      - MYSQL_ROOT_PASSWORD=root_pwd
    command: --character-set-server=utf8 --collation-server=utf8_bin
    networks:
      - monitoring-net
    volumes:
      - zabbix-mysql-data:/var/lib/mysql

  zabbix-web:
    image: zabbix/zabbix-web-apache-mysql:ubuntu-6.4-latest
    container_name: zabbix-web
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      - ZBX_SERVER_HOST=zabbix-server
      - DB_SERVER_HOST=zabbix-mysql
      - MYSQL_DATABASE=zabbix
      - MYSQL_USER=zabbix
      - MYSQL_PASSWORD=zabbix_pwd
      - MYSQL_ROOT_PASSWORD=root_pwd
    networks:
      - monitoring-net
    depends_on:
      - zabbix-server
      - zabbix-mysql

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    networks:
      - monitoring-net
    volumes:
      - grafana-data:/var/lib/grafana

volumes:
  zabbix-mysql-data:
  grafana-data:

networks:
  monitoring-net:
    driver: bridge
EOF

# Iniciar los contenedores
echo "[+]Iniciando contenedores de monitoreo..."
docker-compose up -d 

echo "[+] Espera a que los servicios esten listos..."
sleep 30

# Instalar herramientas SNMP en el host para testing
echo "Instalando herramientas SNMP..."

sudo apt update
sudo apt install -y snmp snmpd snmp-mibs-downloader

# configuracion SNMPd para testing

sudo cp /etc/snmp/snmp.conf /etc/snmp/snmp.conf.backup
echo "rocommunity public 127.0.0.1" | sudo tee /etc/snmp/snmp.conf
sudo systemctl restart snmpd

# info de acceso

echo "-----------------------------------------------------"
echo "MONITOREO IMPLEMENTADO EXITOSAMENTE"
echo "-----------------------------------------------------"
echo "Zabbix Web: http://localhost:8080"
echo "Usuario: Admin / Contrasena: zabbix"
echo "Grafana: http://localhost:3000"
echo "Usuario: admin / Contrasena: Admin123!"





