#!/bin/bash

# Quick Install Script for Iran Tunnel Panel
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/iran-tunnel-panel/main/quick-install.sh)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BACKHAUL_VERSION="0.6.5"
INSTALL_DIR="/opt/tunnel-panel"
GITHUB_REPO="https://raw.githubusercontent.com/YOUR_USERNAME/iran-tunnel-panel/main"

# Check root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}این اسکریپت باید با دسترسی root اجرا شود!${NC}"
   exit 1
fi

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║     تانل ایران - نصب سریع                                ║
║     Iran Tunnel Panel - Quick Install                     ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${YELLOW}1) سرور ایران (Iran Server)${NC}"
echo -e "${YELLOW}2) سرور خارج (Foreign Server)${NC}"
read -p "انتخاب کنید: " SERVER_TYPE

if [[ "$SERVER_TYPE" == "1" ]]; then
    SERVER_MODE="iran"
else
    SERVER_MODE="foreign"
fi

echo -e "${YELLOW}نصب وابستگی‌ها...${NC}"
apt-get update -qq 2>/dev/null || yum update -qq 2>/dev/null
apt-get install -y curl wget tar python3 python3-pip python3-venv jq 2>/dev/null || yum install -y curl wget tar python3 python3-pip jq 2>/dev/null

echo -e "${YELLOW}دانلود Backhaul...${NC}"
mkdir -p "$INSTALL_DIR/bin"
wget -q "https://github.com/Musixal/Backhaul/releases/download/v${BACKHAUL_VERSION}/backhaul_linux_amd64.tar.gz" -O /tmp/backhaul.tar.gz
tar -xzf /tmp/backhaul.tar.gz -C "$INSTALL_DIR/bin/"
chmod +x "$INSTALL_DIR/bin/backhaul"
rm -f /tmp/backhaul.tar.gz

if [ "$SERVER_MODE" == "iran" ]; then
    echo -e "${YELLOW}راه‌اندازی سرور ایران...${NC}"

    mkdir -p "$INSTALL_DIR/web/templates"
    mkdir -p "$INSTALL_DIR/config"
    mkdir -p "$INSTALL_DIR/logs"

    # Download files
    wget -q "$GITHUB_REPO/app.py" -O "$INSTALL_DIR/web/app.py" 2>/dev/null || {
        echo -e "${RED}خطا: فایل‌ها از GitHub قابل دانلود نیستند${NC}"
        echo -e "${YELLOW}لطفاً از اسکریپت کامل استفاده کنید${NC}"
        exit 1
    }

    wget -q "$GITHUB_REPO/templates/index.html" -O "$INSTALL_DIR/web/templates/index.html"
    wget -q "$GITHUB_REPO/templates/login.html" -O "$INSTALL_DIR/web/templates/login.html"

    # Setup Python venv
    cd "$INSTALL_DIR/web"
    python3 -m venv venv
    source venv/bin/activate
    pip install -q flask flask-cors requests psutil
    deactivate

    # Get config
    read -p "IP سرور خارج: " FOREIGN_IP
    read -p "پورت [8080]: " FOREIGN_PORT
    FOREIGN_PORT=${FOREIGN_PORT:-8080}
    read -p "توکن امنیتی: " SECURITY_TOKEN

    cat > "$INSTALL_DIR/config/config.json" <<EOF
{
    "server_type": "iran",
    "foreign_ip": "$FOREIGN_IP",
    "foreign_port": $FOREIGN_PORT,
    "protocol": "tcp",
    "security_token": "$SECURITY_TOKEN",
    "web_port": 8443,
    "agent_port": 8444,
    "tunnels": []
}
EOF

    # Create service
    cat > /etc/systemd/system/tunnel-panel.service <<EOF
[Unit]
Description=Iran Tunnel Management Panel
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR/web
Environment="PATH=$INSTALL_DIR/web/venv/bin"
ExecStart=$INSTALL_DIR/web/venv/bin/python app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable tunnel-panel
    systemctl start tunnel-panel

    SERVER_IP=$(curl -s ifconfig.me)

    echo -e "\n${GREEN}✓ نصب سرور ایران انجام شد!${NC}"
    echo -e "\n${YELLOW}وب پنل:${NC} ${BLUE}http://$SERVER_IP:8443${NC}"
    echo -e "${YELLOW}یوزرنیم:${NC} ${BLUE}admin${NC}"
    echo -e "${YELLOW}پسورد:${NC} ${BLUE}admin123${NC}"

else
    echo -e "${YELLOW}راه‌اندازی سرور خارج...${NC}"

    mkdir -p "$INSTALL_DIR/agent"
    mkdir -p "$INSTALL_DIR/config"
    mkdir -p "$INSTALL_DIR/logs"

    # Download files
    wget -q "$GITHUB_REPO/agent.py" -O "$INSTALL_DIR/agent/agent.py" 2>/dev/null || {
        echo -e "${RED}خطا: فایل‌ها از GitHub قابل دانلود نیستند${NC}"
        echo -e "${YELLOW}لطفاً از اسکریپت کامل استفاده کنید${NC}"
        exit 1
    }

    # Setup Python venv
    cd "$INSTALL_DIR/agent"
    python3 -m venv venv
    source venv/bin/activate
    pip install -q flask requests psutil
    deactivate

    # Get config
    read -p "پورت گوش‌دهی [8080]: " LISTEN_PORT
    LISTEN_PORT=${LISTEN_PORT:-8080}
    read -p "توکن امنیتی: " SECURITY_TOKEN

    cat > "$INSTALL_DIR/config/config.json" <<EOF
{
    "server_type": "foreign",
    "listen_port": $LISTEN_PORT,
    "security_token": "$SECURITY_TOKEN",
    "agent_port": 8444,
    "xui_enabled": false,
    "xui_port": 54321,
    "xui_username": "",
    "xui_password": "",
    "inbounds": []
}
EOF

    # Create service
    cat > /etc/systemd/system/tunnel-agent.service <<EOF
[Unit]
Description=Foreign Server Tunnel Agent
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR/agent
Environment="PATH=$INSTALL_DIR/agent/venv/bin"
ExecStart=$INSTALL_DIR/agent/venv/bin/python agent.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable tunnel-agent
    systemctl start tunnel-agent

    SERVER_IP=$(curl -s ifconfig.me)

    echo -e "\n${GREEN}✓ نصب سرور خارج انجام شد!${NC}"
    echo -e "\n${YELLOW}IP:${NC} ${BLUE}$SERVER_IP${NC}"
    echo -e "${YELLOW}پورت:${NC} ${BLUE}$LISTEN_PORT${NC}"
fi

echo -e "\n${GREEN}نصب کامل شد!${NC}"
