#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="/opt/tunnel-panel"

# Check if installed
if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${RED}پنل نصب نشده است!${NC}"
    exit 1
fi

# Load config
if [ -f "$INSTALL_DIR/config/config.json" ]; then
    SERVER_TYPE=$(grep -o '"server_type"[[:space:]]*:[[:space:]]*"[^"]*"' "$INSTALL_DIR/config/config.json" | sed 's/.*"\([^"]*\)"/\1/')
else
    echo -e "${RED}فایل پیکربندی یافت نشد!${NC}"
    exit 1
fi

show_banner() {
    clear
    echo -e "${BLUE}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║     اسکریپت مدیریت پنل تانل ایران                        ║
║     Tunnel Panel Management Script                        ║
╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "${YELLOW}نوع سرور: ${GREEN}$SERVER_TYPE${NC}\n"
}

show_status() {
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}   وضعیت سرویس‌ها${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

    if [ "$SERVER_TYPE" == "iran" ]; then
        systemctl is-active --quiet tunnel-panel
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Web Panel: در حال اجرا${NC}"
        else
            echo -e "${RED}✗ Web Panel: متوقف${NC}"
        fi

        # Count running tunnels
        RUNNING_TUNNELS=$(ps aux | grep -c "[b]ackhaul.*-c")
        echo -e "${GREEN}تانل‌های فعال: $RUNNING_TUNNELS${NC}"
    else
        systemctl is-active --quiet tunnel-agent
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Agent: در حال اجرا${NC}"
        else
            echo -e "${RED}✗ Agent: متوقف${NC}"
        fi

        # Check Backhaul server
        if pgrep -f "backhaul.*-s" > /dev/null; then
            echo -e "${GREEN}✓ Backhaul Server: در حال اجرا${NC}"
        else
            echo -e "${RED}✗ Backhaul Server: متوقف${NC}"
        fi
    fi

    echo
}

show_logs() {
    echo -e "${YELLOW}انتخاب کنید:${NC}"
    echo "1) لاگ‌های پنل/Agent"
    echo "2) لاگ‌های Backhaul"
    echo "3) لاگ‌های تانل خاص"
    read -p "انتخاب: " choice

    case $choice in
        1)
            if [ "$SERVER_TYPE" == "iran" ]; then
                journalctl -u tunnel-panel -f
            else
                journalctl -u tunnel-agent -f
            fi
            ;;
        2)
            if [ -f "$INSTALL_DIR/logs/backhaul_server.log" ]; then
                tail -f "$INSTALL_DIR/logs/backhaul_server.log"
            else
                echo -e "${RED}فایل لاگ یافت نشد!${NC}"
            fi
            ;;
        3)
            echo -e "${YELLOW}لیست تانل‌ها:${NC}"
            ls -1 "$INSTALL_DIR/logs/" | grep "tunnel_.*\.log"
            read -p "نام فایل لاگ: " logfile
            if [ -f "$INSTALL_DIR/logs/$logfile" ]; then
                tail -f "$INSTALL_DIR/logs/$logfile"
            else
                echo -e "${RED}فایل یافت نشد!${NC}"
            fi
            ;;
        *)
            echo -e "${RED}انتخاب نامعتبر!${NC}"
            ;;
    esac
}

restart_service() {
    echo -e "${YELLOW}در حال ری‌استارت...${NC}"

    if [ "$SERVER_TYPE" == "iran" ]; then
        systemctl restart tunnel-panel
        sleep 2
        systemctl is-active --quiet tunnel-panel
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ پنل با موفقیت ری‌استارت شد${NC}"
        else
            echo -e "${RED}✗ خطا در ری‌استارت${NC}"
        fi
    else
        systemctl restart tunnel-agent
        sleep 2
        systemctl is-active --quiet tunnel-agent
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Agent با موفقیت ری‌استارت شد${NC}"
        else
            echo -e "${RED}✗ خطا در ری‌استارت${NC}"
        fi
    fi
}

stop_service() {
    echo -e "${YELLOW}در حال توقف...${NC}"

    if [ "$SERVER_TYPE" == "iran" ]; then
        systemctl stop tunnel-panel
        echo -e "${GREEN}✓ پنل متوقف شد${NC}"
    else
        systemctl stop tunnel-agent
        echo -e "${GREEN}✓ Agent متوقف شد${NC}"
    fi
}

start_service() {
    echo -e "${YELLOW}در حال شروع...${NC}"

    if [ "$SERVER_TYPE" == "iran" ]; then
        systemctl start tunnel-panel
        sleep 2
        systemctl is-active --quiet tunnel-panel
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ پنل شروع شد${NC}"
        else
            echo -e "${RED}✗ خطا در شروع${NC}"
        fi
    else
        systemctl start tunnel-agent
        sleep 2
        systemctl is-active --quiet tunnel-agent
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Agent شروع شد${NC}"
        else
            echo -e "${RED}✗ خطا در شروع${NC}"
        fi
    fi
}

show_info() {
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}   اطلاعات سیستم${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

    # Server IP
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "Unknown")
    echo -e "${YELLOW}آدرس IP سرور:${NC} ${GREEN}$SERVER_IP${NC}"

    # Load config
    if [ -f "$INSTALL_DIR/config/config.json" ]; then
        if [ "$SERVER_TYPE" == "iran" ]; then
            WEB_PORT=$(grep -o '"web_port"[[:space:]]*:[[:space:]]*[0-9]*' "$INSTALL_DIR/config/config.json" | grep -o '[0-9]*')
            FOREIGN_IP=$(grep -o '"foreign_ip"[[:space:]]*:[[:space:]]*"[^"]*"' "$INSTALL_DIR/config/config.json" | sed 's/.*"\([^"]*\)"/\1/')
            PROTOCOL=$(grep -o '"protocol"[[:space:]]*:[[:space:]]*"[^"]*"' "$INSTALL_DIR/config/config.json" | sed 's/.*"\([^"]*\)"/\1/')

            echo -e "${YELLOW}پورت وب پنل:${NC} ${GREEN}$WEB_PORT${NC}"
            echo -e "${YELLOW}آدرس وب پنل:${NC} ${GREEN}http://$SERVER_IP:$WEB_PORT${NC}"
            echo -e "${YELLOW}سرور خارج:${NC} ${GREEN}$FOREIGN_IP${NC}"
            echo -e "${YELLOW}پروتکل:${NC} ${GREEN}$PROTOCOL${NC}"
        else
            LISTEN_PORT=$(grep -o '"listen_port"[[:space:]]*:[[:space:]]*[0-9]*' "$INSTALL_DIR/config/config.json" | grep -o '[0-9]*')
            AGENT_PORT=$(grep -o '"agent_port"[[:space:]]*:[[:space:]]*[0-9]*' "$INSTALL_DIR/config/config.json" | grep -o '[0-9]*')

            echo -e "${YELLOW}پورت Backhaul:${NC} ${GREEN}$LISTEN_PORT${NC}"
            echo -e "${YELLOW}پورت Agent:${NC} ${GREEN}$AGENT_PORT${NC}"
        fi
    fi

    echo

    # System info
    echo -e "${YELLOW}مصرف CPU:${NC} ${GREEN}$(top -bn1 | grep 'Cpu(s)' | awk '{print $2}')%${NC}"
    echo -e "${YELLOW}مصرف RAM:${NC} ${GREEN}$(free -m | awk 'NR==2{printf "%s/%sMB (%.2f%%)", $3,$2,$3*100/$2 }')${NC}"
    echo -e "${YELLOW}فضای دیسک:${NC} ${GREEN}$(df -h / | awk 'NR==2{print $3"/"$2" ("$5")"}')${NC}"

    echo
}

backup_config() {
    BACKUP_FILE="/tmp/tunnel-panel-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    echo -e "${YELLOW}در حال پشتیبان‌گیری...${NC}"

    tar -czf "$BACKUP_FILE" -C "$INSTALL_DIR" config/ 2>/dev/null

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ پشتیبان‌گیری با موفقیت انجام شد${NC}"
        echo -e "${YELLOW}فایل پشتیبان:${NC} ${GREEN}$BACKUP_FILE${NC}"
    else
        echo -e "${RED}✗ خطا در پشتیبان‌گیری${NC}"
    fi
}

restore_config() {
    read -p "مسیر فایل پشتیبان: " backup_file

    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}فایل یافت نشد!${NC}"
        return
    fi

    echo -e "${YELLOW}در حال بازیابی...${NC}"

    # Stop service
    if [ "$SERVER_TYPE" == "iran" ]; then
        systemctl stop tunnel-panel
    else
        systemctl stop tunnel-agent
    fi

    # Backup current config
    mv "$INSTALL_DIR/config" "$INSTALL_DIR/config.backup-$(date +%Y%m%d-%H%M%S)"

    # Restore
    tar -xzf "$backup_file" -C "$INSTALL_DIR/"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ بازیابی با موفقیت انجام شد${NC}"

        # Restart service
        if [ "$SERVER_TYPE" == "iran" ]; then
            systemctl start tunnel-panel
        else
            systemctl start tunnel-agent
        fi
    else
        echo -e "${RED}✗ خطا در بازیابی${NC}"
        # Restore backup
        mv "$INSTALL_DIR/config.backup"* "$INSTALL_DIR/config"
    fi
}

show_menu() {
    show_banner
    show_status

    echo -e "${YELLOW}منوی مدیریت:${NC}"
    echo "1) مشاهده وضعیت"
    echo "2) شروع سرویس"
    echo "3) توقف سرویس"
    echo "4) ری‌استارت سرویس"
    echo "5) مشاهده لاگ‌ها"
    echo "6) اطلاعات سیستم"
    echo "7) پشتیبان‌گیری از تنظیمات"
    echo "8) بازیابی تنظیمات"
    echo "9) خروج"
    echo
    read -p "انتخاب شما: " choice

    case $choice in
        1)
            show_status
            read -p "برای بازگشت Enter بزنید..."
            show_menu
            ;;
        2)
            start_service
            read -p "برای بازگشت Enter بزنید..."
            show_menu
            ;;
        3)
            stop_service
            read -p "برای بازگشت Enter بزنید..."
            show_menu
            ;;
        4)
            restart_service
            read -p "برای بازگشت Enter بزنید..."
            show_menu
            ;;
        5)
            show_logs
            ;;
        6)
            show_info
            read -p "برای بازگشت Enter بزنید..."
            show_menu
            ;;
        7)
            backup_config
            read -p "برای بازگشت Enter بزنید..."
            show_menu
            ;;
        8)
            restore_config
            read -p "برای بازگشت Enter بزنید..."
            show_menu
            ;;
        9)
            echo -e "${GREEN}خداحافظ!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}انتخاب نامعتبر!${NC}"
            sleep 2
            show_menu
            ;;
    esac
}

# Main
if [ $# -eq 0 ]; then
    show_menu
else
    case $1 in
        status)
            show_status
            ;;
        start)
            start_service
            ;;
        stop)
            stop_service
            ;;
        restart)
            restart_service
            ;;
        logs)
            show_logs
            ;;
        info)
            show_info
            ;;
        backup)
            backup_config
            ;;
        *)
            echo "Usage: $0 {status|start|stop|restart|logs|info|backup}"
            exit 1
            ;;
    esac
fi
