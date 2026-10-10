#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITHUB_REPO="https://raw.githubusercontent.com/YOUR_USERNAME/iran-tunnel-panel/main"
BACKHAUL_VERSION="0.6.5"
BACKHAUL_URL="https://github.com/Musixal/Backhaul/releases/download/v${BACKHAUL_VERSION}/backhaul_linux_amd64.tar.gz"
INSTALL_DIR="/opt/tunnel-panel"
WEB_PORT="8443"
AGENT_PORT="8444"

# Banner
clear
echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║     تانل ایران - پنل مدیریت هوشمند Backhaul            ║
║     Iran Tunnel Panel - Smart Backhaul Management        ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}این اسکریپت باید با دسترسی root اجرا شود!${NC}"
   exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo -e "${RED}سیستم عامل شناسایی نشد!${NC}"
    exit 1
fi

# Function: Install dependencies
install_dependencies() {
    echo -e "${YELLOW}نصب وابستگی‌ها...${NC}"

    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        apt-get update -qq
        apt-get install -y curl wget tar python3 python3-pip python3-venv jq net-tools iproute2 >/dev/null 2>&1
    elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" ]]; then
        yum install -y curl wget tar python3 python3-pip jq net-tools iproute >/dev/null 2>&1
    else
        echo -e "${RED}سیستم عامل پشتیبانی نمی‌شود!${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ وابستگی‌ها نصب شدند${NC}"
}

# Function: Download Backhaul
download_backhaul() {
    echo -e "${YELLOW}دانلود Backhaul...${NC}"

    mkdir -p "$INSTALL_DIR/bin"
    cd /tmp

    wget -q --show-progress "$BACKHAUL_URL" -O backhaul.tar.gz

    if [ $? -ne 0 ]; then
        echo -e "${RED}خطا در دانلود Backhaul!${NC}"
        exit 1
    fi

    tar -xzf backhaul.tar.gz
    mv backhaul "$INSTALL_DIR/bin/"
    chmod +x "$INSTALL_DIR/bin/backhaul"
    rm -f backhaul.tar.gz

    echo -e "${GREEN}✓ Backhaul دانلود و نصب شد${NC}"
}

# Function: Setup Iran Server
setup_iran_server() {
    echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}   نصب سرور ایران (Iran Server)${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

    # Get configuration
    read -p "آدرس IP سرور خارج: " FOREIGN_IP
    read -p "پورت اتصال به سرور خارج [8080]: " FOREIGN_PORT
    FOREIGN_PORT=${FOREIGN_PORT:-8080}

    read -p "رمز عبور امنیتی [$(openssl rand -hex 16)]: " SECURITY_TOKEN
    SECURITY_TOKEN=${SECURITY_TOKEN:-$(openssl rand -hex 16)}

    echo -e "\n${YELLOW}انتخاب نوع تانل:${NC}"
    echo "1) TCP (پیش‌فرض)"
    echo "2) WebSocket (WS)"
    echo "3) WebSocket Secure (WSS)"
    read -p "انتخاب [1]: " TUNNEL_TYPE
    TUNNEL_TYPE=${TUNNEL_TYPE:-1}

    case $TUNNEL_TYPE in
        1) PROTOCOL="tcp" ;;
        2) PROTOCOL="ws" ;;
        3) PROTOCOL="wss" ;;
        *) PROTOCOL="tcp" ;;
    esac

    # Create directories
    mkdir -p "$INSTALL_DIR/config"
    mkdir -p "$INSTALL_DIR/logs"
    mkdir -p "$INSTALL_DIR/web"

    # Save config
    cat > "$INSTALL_DIR/config/config.json" <<EOF
{
    "server_type": "iran",
    "foreign_ip": "$FOREIGN_IP",
    "foreign_port": $FOREIGN_PORT,
    "protocol": "$PROTOCOL",
    "security_token": "$SECURITY_TOKEN",
    "web_port": $WEB_PORT,
    "tunnels": []
}
EOF

    # Download web panel files
    echo -e "${YELLOW}دانلود فایل‌های وب پنل...${NC}"
    download_panel_files

    # Create systemd services
    create_systemd_services "iran"

    # Setup web panel
    setup_web_panel

    # Start services
    systemctl daemon-reload
    systemctl enable tunnel-panel
    systemctl start tunnel-panel

    # Get server IP
    SERVER_IP=$(curl -s ifconfig.me)

    echo -e "\n${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ نصب سرور ایران با موفقیت انجام شد!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "\n${YELLOW}اطلاعات دسترسی:${NC}"
    echo -e "وب پنل: ${BLUE}http://$SERVER_IP:$WEB_PORT${NC}"
    echo -e "یوزرنیم: ${BLUE}admin${NC}"
    echo -e "پسورد: ${BLUE}admin123${NC}"
    echo -e "\n${RED}⚠️  حتماً پسورد را در پنل تغییر دهید!${NC}"
    echo -e "\n${YELLOW}توکن امنیتی (برای سرور خارج):${NC}"
    echo -e "${BLUE}$SECURITY_TOKEN${NC}"
    echo -e "\n${YELLOW}دستورات مدیریت:${NC}"
    echo -e "مشاهده وضعیت: ${BLUE}systemctl status tunnel-panel${NC}"
    echo -e "ری‌استارت: ${BLUE}systemctl restart tunnel-panel${NC}"
    echo -e "مشاهده لاگ‌ها: ${BLUE}journalctl -u tunnel-panel -f${NC}"
}

# Function: Setup Foreign Server
setup_foreign_server() {
    echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}   نصب سرور خارج (Foreign Server)${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

    # Get configuration
    read -p "پورت گوش‌دهی برای اتصالات ایران [8080]: " LISTEN_PORT
    LISTEN_PORT=${LISTEN_PORT:-8080}

    read -p "رمز عبور امنیتی (همان توکن سرور ایران): " SECURITY_TOKEN

    read -p "آیا X-UI نصب است؟ (y/n) [y]: " HAS_XUI
    HAS_XUI=${HAS_XUI:-y}

    XUI_PORT=54321
    XUI_USERNAME=""
    XUI_PASSWORD=""

    if [[ "$HAS_XUI" == "y" || "$HAS_XUI" == "Y" ]]; then
        read -p "پورت X-UI [54321]: " XUI_PORT
        XUI_PORT=${XUI_PORT:-54321}
        read -p "یوزرنیم X-UI: " XUI_USERNAME
        read -sp "پسورد X-UI: " XUI_PASSWORD
        echo
    fi

    # Create directories
    mkdir -p "$INSTALL_DIR/config"
    mkdir -p "$INSTALL_DIR/logs"

    # Save config
    cat > "$INSTALL_DIR/config/config.json" <<EOF
{
    "server_type": "foreign",
    "listen_port": $LISTEN_PORT,
    "security_token": "$SECURITY_TOKEN",
    "agent_port": $AGENT_PORT,
    "xui_enabled": $([ "$HAS_XUI" == "y" ] && echo "true" || echo "false"),
    "xui_port": $XUI_PORT,
    "xui_username": "$XUI_USERNAME",
    "xui_password": "$XUI_PASSWORD",
    "inbounds": []
}
EOF

    # Download agent files
    echo -e "${YELLOW}دانلود فایل‌های Agent...${NC}"
    download_agent_files

    # Create systemd services
    create_systemd_services "foreign"

    # Setup Agent
    setup_agent

    # Start services
    systemctl daemon-reload
    systemctl enable tunnel-agent
    systemctl start tunnel-agent

    # Get server IP
    SERVER_IP=$(curl -s ifconfig.me)

    echo -e "\n${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ نصب سرور خارج با موفقیت انجام شد!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "\n${YELLOW}اطلاعات سرور:${NC}"
    echo -e "آدرس IP: ${BLUE}$SERVER_IP${NC}"
    echo -e "پورت اتصال: ${BLUE}$LISTEN_PORT${NC}"
    echo -e "پورت Agent: ${BLUE}$AGENT_PORT${NC}"
    echo -e "\n${YELLOW}دستورات مدیریت:${NC}"
    echo -e "مشاهده وضعیت Agent: ${BLUE}systemctl status tunnel-agent${NC}"
    echo -e "ری‌استارت Agent: ${BLUE}systemctl restart tunnel-agent${NC}"
    echo -e "مشاهده لاگ‌ها: ${BLUE}journalctl -u tunnel-agent -f${NC}"
}

# Function: Download panel files
download_panel_files() {
    echo -e "${YELLOW}دانلود فایل‌های پنل...${NC}"

    mkdir -p "$INSTALL_DIR/web/templates"
    mkdir -p "$INSTALL_DIR/web/static"

    # Download app.py
    cat > "$INSTALL_DIR/web/app.py" << 'APP_PY_EOF'
#!/usr/bin/env python3
# App.py will be embedded here
APP_PY_EOF

    # Create inline templates
    create_web_templates

    # Create requirements.txt
    cat > "$INSTALL_DIR/web/requirements.txt" << 'EOF'
flask>=2.3.0
flask-cors>=4.0.0
requests>=2.31.0
psutil>=5.9.0
EOF

    echo -e "${GREEN}✓ فایل‌های پنل دانلود شدند${NC}"
}

# Function: Download agent files
download_agent_files() {
    mkdir -p "$INSTALL_DIR/agent"
    cd "$INSTALL_DIR/agent"

    # We'll create these files in the next steps
    touch agent.py requirements.txt
}

# Function: Setup web panel
setup_web_panel() {
    echo -e "${YELLOW}راه‌اندازی وب پنل...${NC}"

    cd "$INSTALL_DIR/web"

    # Create virtual environment
    python3 -m venv venv
    source venv/bin/activate

    # Install requirements
    pip install -q --upgrade pip
    pip install -q flask flask-cors requests psutil

    deactivate

    echo -e "${GREEN}✓ وب پنل راه‌اندازی شد${NC}"
}

# Function: Setup agent
setup_agent() {
    echo -e "${YELLOW}راه‌اندازی Agent...${NC}"

    cd "$INSTALL_DIR/agent"

    # Create virtual environment
    python3 -m venv venv
    source venv/bin/activate

    # Install requirements
    pip install -q --upgrade pip
    pip install -q flask requests psutil

    deactivate

    echo -e "${GREEN}✓ Agent راه‌اندازی شد${NC}"
}

# Function: Create systemd services
create_systemd_services() {
    local server_type=$1

    if [ "$server_type" == "iran" ]; then
        # Web Panel Service
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
    else
        # Agent Service
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
    fi
}

# Function: Uninstall
uninstall() {
    echo -e "${RED}آیا مطمئن هستید که می‌خواهید حذف کنید؟ (y/n)${NC}"
    read -p "جواب: " confirm

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}لغو شد.${NC}"
        exit 0
    fi

    echo -e "${YELLOW}در حال حذف...${NC}"

    # Stop services
    systemctl stop tunnel-panel 2>/dev/null
    systemctl stop tunnel-agent 2>/dev/null
    systemctl disable tunnel-panel 2>/dev/null
    systemctl disable tunnel-agent 2>/dev/null

    # Remove files
    rm -rf "$INSTALL_DIR"
    rm -f /etc/systemd/system/tunnel-panel.service
    rm -f /etc/systemd/system/tunnel-agent.service

    systemctl daemon-reload

    echo -e "${GREEN}✓ حذف با موفقیت انجام شد${NC}"
}

# Main Menu
show_menu() {
    echo -e "\n${YELLOW}لطفاً نوع سرور را انتخاب کنید:${NC}"
    echo -e "${BLUE}1)${NC} نصب سرور ایران (Iran Server)"
    echo -e "${BLUE}2)${NC} نصب سرور خارج (Foreign Server)"
    echo -e "${BLUE}3)${NC} حذف (Uninstall)"
    echo -e "${BLUE}4)${NC} خروج"
    echo -e "\n${YELLOW}انتخاب شما:${NC} "
    read choice

    case $choice in
        1)
            install_dependencies
            download_backhaul
            setup_iran_server
            ;;
        2)
            install_dependencies
            download_backhaul
            setup_foreign_server
            ;;
        3)
            uninstall
            ;;
        4)
            echo -e "${GREEN}خداحافظ!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}انتخاب نامعتبر!${NC}"
            show_menu
            ;;
    esac
}

# Run
show_menu
