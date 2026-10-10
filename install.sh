#!/usr/bin/env bash
set -Eeuo pipefail

# Iran Tunnel Panel - installer
# Repository: https://github.com/abasniyati/iran-tunnel-panel

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

GITHUB_REPO="https://raw.githubusercontent.com/abasniyati/iran-tunnel-panel/main"
BACKHAUL_VERSION="0.6.5"
BACKHAUL_URL="https://github.com/Musixal/Backhaul/releases/download/v${BACKHAUL_VERSION}/backhaul_linux_amd64.tar.gz"
INSTALL_DIR="/opt/tunnel-panel"
WEB_PORT="8443"
AGENT_PORT_DEFAULT="8444"

log() { echo -e "${BLUE}[*]${NC} $*"; }
ok() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
die() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

on_error() {
    local code=$?
    echo -e "${RED}[ERROR]${NC} Installer stopped at line ${BASH_LINENO[0]} (exit ${code}). Installation was not reported as successful." >&2
    exit "$code"
}
trap on_error ERR

clear 2>/dev/null || true
printf '%b' "$BLUE"
cat <<'BANNER'
╔═══════════════════════════════════════════════════════════╗
║     تانل ایران - پنل مدیریت هوشمند Backhaul              ║
║     Iran Tunnel Panel - Smart Backhaul Management         ║
╚═══════════════════════════════════════════════════════════╝
BANNER
printf '%b\n' "$NC"

[[ $EUID -eq 0 ]] || die "این اسکریپت باید با دسترسی root اجرا شود."
[[ -r /etc/os-release ]] || die "سیستم عامل شناسایی نشد."
# shellcheck disable=SC1091
source /etc/os-release
OS_ID="${ID:-unknown}"

install_dependencies() {
    log "نصب وابستگی‌های سیستم..."
    if command -v apt-get >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y curl wget tar python3 python3-pip python3-venv jq net-tools iproute2 openssl ca-certificates
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y curl wget tar python3 python3-pip jq net-tools iproute openssl ca-certificates
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl wget tar python3 python3-pip jq net-tools iproute openssl ca-certificates
    else
        die "فقط سیستم‌های دارای apt-get، dnf یا yum پشتیبانی می‌شوند."
    fi
    command -v python3 >/dev/null 2>&1 || die "python3 نصب نشد."
    python3 -m venv --help >/dev/null 2>&1 || die "ماژول venv پایتون نصب نیست."
    ok "وابستگی‌های سیستم آماده‌اند."
}

fetch_file() {
    local url="$1" destination="$2"
    mkdir -p "$(dirname "$destination")"
    curl --fail --location --silent --show-error \
        --connect-timeout 12 --max-time 180 --retry 2 --retry-delay 2 \
        "$url" --output "$destination"
    [[ -s "$destination" ]] || die "فایل دانلودشده خالی است: $url"
}

download_backhaul() {
    log "دانلود Backhaul v${BACKHAUL_VERSION}..."
    local temp_dir archive binary
    temp_dir="$(mktemp -d)"
    archive="$temp_dir/backhaul.tar.gz"
    fetch_file "$BACKHAUL_URL" "$archive"
    tar -tzf "$archive" >/dev/null || die "فایل Backhaul دانلودشده آرشیو معتبر نیست."
    tar -xzf "$archive" -C "$temp_dir"
    binary="$(find "$temp_dir" -type f -name backhaul -print -quit)"
    [[ -n "$binary" && -s "$binary" ]] || die "فایل اجرایی backhaul داخل آرشیو پیدا نشد."
    install -d "$INSTALL_DIR/bin"
    install -m 0755 "$binary" "$INSTALL_DIR/bin/backhaul"
    rm -rf "$temp_dir"
    "$INSTALL_DIR/bin/backhaul" --help >/dev/null 2>&1 || true
    ok "Backhaul نصب شد."
}

# Try mirrors first because files.pythonhosted.org may not resolve on some Iranian networks.
pip_install_with_fallback() {
    local pip_bin="$1"
    shift
    local index
    local -a indexes=(
        "https://pypi.tuna.tsinghua.edu.cn/simple"
        "https://mirrors.aliyun.com/pypi/simple/"
        "https://mirrors.cloud.tencent.com/pypi/simple/"
        "https://pypi.org/simple"
    )
    for index in "${indexes[@]}"; do
        log "تلاش برای نصب وابستگی‌های Python از: $index"
        if "$pip_bin" install --disable-pip-version-check --no-input \
            --retries 1 --timeout 20 --index-url "$index" "$@"; then
            return 0
        fi
        warn "این منبع در دسترس نبود؛ منبع بعدی امتحان می‌شود."
    done
    die "نصب وابستگی‌های Python از همه مخازن ناموفق بود. سرویس اجرا نخواهد شد."
}

download_panel_files() {
    log "دریافت فایل‌های واقعی وب‌پنل از GitHub..."
    install -d "$INSTALL_DIR/web/templates" "$INSTALL_DIR/web/static" "$INSTALL_DIR/config" "$INSTALL_DIR/logs"
    fetch_file "$GITHUB_REPO/app.py" "$INSTALL_DIR/web/app.py"
    fetch_file "$GITHUB_REPO/templates/index.html" "$INSTALL_DIR/web/templates/index.html"
    fetch_file "$GITHUB_REPO/templates/login.html" "$INSTALL_DIR/web/templates/login.html"
    cat > "$INSTALL_DIR/web/requirements.txt" <<'REQ'
flask>=2.3.0
flask-cors>=4.0.0
requests>=2.31.0
psutil>=5.9.0
REQ
    python3 -m py_compile "$INSTALL_DIR/web/app.py" || die "فایل app.py از نظر نحوی معتبر نیست."
    [[ -s "$INSTALL_DIR/web/templates/index.html" ]] || die "قالب index.html دریافت نشده است."
    [[ -s "$INSTALL_DIR/web/templates/login.html" ]] || die "قالب login.html دریافت نشده است."
    ok "فایل‌های واقعی وب‌پنل دریافت شدند."
}

download_agent_files() {
    log "دریافت فایل واقعی Agent از GitHub..."
    install -d "$INSTALL_DIR/agent" "$INSTALL_DIR/config" "$INSTALL_DIR/logs"
    fetch_file "$GITHUB_REPO/agent.py" "$INSTALL_DIR/agent/agent.py"
    cat > "$INSTALL_DIR/agent/requirements.txt" <<'REQ'
flask>=2.3.0
requests>=2.31.0
psutil>=5.9.0
REQ
    python3 -m py_compile "$INSTALL_DIR/agent/agent.py" || die "فایل agent.py از نظر نحوی معتبر نیست."
    ok "فایل Agent دریافت شد."
}

setup_python_environment() {
    local component="$1"
    local component_dir="$INSTALL_DIR/$component"
    log "ساخت محیط مجازی و نصب وابستگی‌های $component..."
    python3 -m venv "$component_dir/venv"
    pip_install_with_fallback "$component_dir/venv/bin/pip" -r "$component_dir/requirements.txt"
    "$component_dir/venv/bin/python" -m py_compile "$component_dir/$( [[ "$component" == "web" ]] && echo app.py || echo agent.py )"
    ok "محیط Python مربوط به $component آماده شد."
}

write_systemd_service() {
    local server_type="$1"
    if [[ "$server_type" == "iran" ]]; then
        cat > /etc/systemd/system/tunnel-panel.service <<SERVICE
[Unit]
Description=Iran Tunnel Management Web Panel
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR/web
Environment=PYTHONUNBUFFERED=1
ExecStart=$INSTALL_DIR/web/venv/bin/python $INSTALL_DIR/web/app.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE
    else
        cat > /etc/systemd/system/tunnel-agent.service <<SERVICE
[Unit]
Description=Foreign Server Tunnel Agent
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR/agent
Environment=PYTHONUNBUFFERED=1
ExecStart=$INSTALL_DIR/agent/venv/bin/python $INSTALL_DIR/agent/agent.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE
    fi
    systemctl daemon-reload
}

valid_port() { [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 )); }

setup_iran_server() {
    local foreign_ip foreign_port token token_default tunnel_choice protocol
    printf '\n%bنصب سرور ایران%b\n' "$BLUE" "$NC"
    read -r -p "آدرس IP یا دامنه سرور خارج: " foreign_ip
    [[ -n "$foreign_ip" ]] || die "آدرس سرور خارج نمی‌تواند خالی باشد."
    read -r -p "پورت Backhaul سرور خارج [8080]: " foreign_port
    foreign_port="${foreign_port:-8080}"
    valid_port "$foreign_port" || die "پورت نامعتبر است."

    token_default="$(openssl rand -hex 24)"
    read -r -p "توکن امنیتی (در سرور خارج هم همین را وارد کنید) [$token_default]: " token
    token="${token:-$token_default}"

    echo "در نسخه فعلی Agent، سمت سرور فقط TCP پیکربندی شده است."
    read -r -p "پروتکل TCP انتخاب شود؟ [Y/n]: " tunnel_choice
    [[ -z "$tunnel_choice" || "$tunnel_choice" =~ ^[Yy]$ ]] || die "برای WS/WSS ابتدا باید Agent نیز با همان پروتکل اصلاح شود؛ نصب متوقف شد."
    protocol="tcp"

    install -d "$INSTALL_DIR/config" "$INSTALL_DIR/logs"
    python3 - "$INSTALL_DIR/config/config.json" "$foreign_ip" "$foreign_port" "$token" "$WEB_PORT" "$AGENT_PORT_DEFAULT" "$protocol" <<'PY'
import json, sys
path, foreign_ip, foreign_port, token, web_port, agent_port, protocol = sys.argv[1:]
config = {
    "server_type": "iran",
    "foreign_ip": foreign_ip,
    "foreign_port": int(foreign_port),
    "protocol": protocol,
    "security_token": token,
    "web_port": int(web_port),
    "agent_port": int(agent_port),
    "tunnels": []
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
PY
    chmod 600 "$INSTALL_DIR/config/config.json"

    download_panel_files
    setup_python_environment web
    write_systemd_service iran
    systemctl enable --now tunnel-panel
    sleep 2
    systemctl is-active --quiet tunnel-panel || {
        systemctl --no-pager --full status tunnel-panel || true
        journalctl -u tunnel-panel -n 40 --no-pager || true
        die "وب‌پنل اجرا نشد؛ نصب موفق اعلام نمی‌شود."
    }
    if ! curl --fail --silent --show-error --max-time 5 "http://127.0.0.1:${WEB_PORT}/login" >/dev/null; then
        journalctl -u tunnel-panel -n 40 --no-pager || true
        die "سرویس فعال است اما مسیر /login پاسخ معتبر نداد."
    fi

    local panel_ip
    panel_ip="$(curl -4fsS --connect-timeout 3 --max-time 5 https://api.ipify.org 2>/dev/null || true)"
    [[ "$panel_ip" =~ ^[0-9]+(\.[0-9]+){3}$ ]] || panel_ip="<IP-SERVER-IRAN>"
    ok "نصب سرور ایران تأیید شد؛ سرویس و صفحه ورود پاسخ می‌دهند."
    echo
    echo -e "آدرس پنل: ${BLUE}http://${panel_ip}:${WEB_PORT}${NC}"
    echo "نام کاربری پیش‌فرض برنامه: admin"
    echo "رمز پیش‌فرض برنامه: admin123"
    warn "پس از ورود، رمز پیش‌فرض را فوراً تغییر دهید و پنل HTTP را بدون فایروال/HTTPS عمومی نگذارید."
    echo "توکن امنیتی موردنیاز سرور خارج: $token"
    echo "در سرور خارج همین توکن و پورت Backhaul برابر ${foreign_port} را وارد کنید."
    echo "وضعیت: systemctl status tunnel-panel"
    echo "لاگ: journalctl -u tunnel-panel -f"
}

setup_foreign_server() {
    local listen_port agent_port token token_default
    printf '\n%bنصب سرور خارج%b\n' "$BLUE" "$NC"
    read -r -p "پورت شنونده Backhaul [8080]: " listen_port
    listen_port="${listen_port:-8080}"
    valid_port "$listen_port" || die "پورت Backhaul نامعتبر است."
    read -r -p "پورت API مربوط به Agent [${AGENT_PORT_DEFAULT}]: " agent_port
    agent_port="${agent_port:-$AGENT_PORT_DEFAULT}"
    valid_port "$agent_port" || die "پورت Agent نامعتبر است."
    token_default="$(openssl rand -hex 24)"
    read -r -p "توکن امنیتی (باید با سرور ایران یکسان باشد) [$token_default]: " token
    token="${token:-$token_default}"

    install -d "$INSTALL_DIR/config" "$INSTALL_DIR/logs"
    python3 - "$INSTALL_DIR/config/config.json" "$listen_port" "$agent_port" "$token" <<'PY'
import json, sys
path, listen_port, agent_port, token = sys.argv[1:]
config = {
    "server_type": "foreign",
    "listen_port": int(listen_port),
    "agent_port": int(agent_port),
    "security_token": token,
    "protocol": "tcp",
    "xui_enabled": False,
    "xui_port": 54321,
    "inbounds": []
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
PY
    chmod 600 "$INSTALL_DIR/config/config.json"

    download_agent_files
    setup_python_environment agent
    write_systemd_service foreign
    systemctl enable --now tunnel-agent
    sleep 2
    systemctl is-active --quiet tunnel-agent || {
        systemctl --no-pager --full status tunnel-agent || true
        journalctl -u tunnel-agent -n 40 --no-pager || true
        die "Agent اجرا نشد؛ نصب موفق اعلام نمی‌شود."
    }
    if ! curl --fail --silent --show-error --max-time 5 "http://127.0.0.1:${agent_port}/health" >/dev/null; then
        journalctl -u tunnel-agent -n 40 --no-pager || true
        die "سرویس فعال است اما API مربوط به Agent پاسخ معتبر نداد."
    fi
    if ! pgrep -x backhaul >/dev/null 2>&1; then
        journalctl -u tunnel-agent -n 40 --no-pager || true
        die "Agent پاسخ می‌دهد، اما پردازش Backhaul اجرا نیست؛ نصب موفق اعلام نمی‌شود."
    fi

    local server_ip
    server_ip="$(curl -4fsS --connect-timeout 3 --max-time 5 https://api.ipify.org 2>/dev/null || true)"
    [[ "$server_ip" =~ ^[0-9]+(\.[0-9]+){3}$ ]] || server_ip="<IP-SERVER-KHAREJ>"
    ok "نصب سرور خارج تأیید شد؛ Agent و Backhaul اجرا شده‌اند."
    echo
    echo "IP سرور خارج: $server_ip"
    echo "پورت Backhaul: $listen_port"
    echo "پورت Agent: $agent_port"
    echo "توکن امنیتی (باید در سرور ایران هم عیناً وارد شود): $token"
    warn "پورت‌های ${listen_port}/TCP و ${agent_port}/TCP را در فایروال/پنل ارائه‌دهنده مجاز کنید. API Agent را فقط به IP سرور ایران محدود کنید."
    echo "وضعیت: systemctl status tunnel-agent"
    echo "لاگ: journalctl -u tunnel-agent -f"
}

uninstall() {
    read -r -p "تمام فایل‌ها و تنظیمات $INSTALL_DIR و سرویس‌ها حذف شوند؟ (y/N): " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { warn "حذف لغو شد."; return 0; }
    systemctl disable --now tunnel-panel 2>/dev/null || true
    systemctl disable --now tunnel-agent 2>/dev/null || true
    rm -f /etc/systemd/system/tunnel-panel.service /etc/systemd/system/tunnel-agent.service
    rm -rf "$INSTALL_DIR"
    systemctl daemon-reload
    ok "فایل‌های پنل و سرویس‌ها حذف شدند."
}

show_menu() {
    echo
    echo -e "${YELLOW}لطفاً نوع سرور را انتخاب کنید:${NC}"
    echo "1) نصب سرور ایران (وب‌پنل)"
    echo "2) نصب سرور خارج (Agent و Backhaul)"
    echo "3) حذف پنل/Agent"
    echo "4) خروج"
    read -r -p "انتخاب: " choice
    case "$choice" in
        1) install_dependencies; download_backhaul; setup_iran_server ;;
        2) install_dependencies; download_backhaul; setup_foreign_server ;;
        3) uninstall ;;
        4) echo "خروج." ;;
        *) die "انتخاب نامعتبر است؛ اسکریپت را دوباره اجرا کنید." ;;
    esac
}

show_menu
