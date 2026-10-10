# 🚀 پنل مدیریت تانل ایران - Iran Tunnel Panel

سیستم کامل مدیریت تانل‌های Backhaul برای اتصال سرور ایران به خارج با وب پنل تحت وب

## ✨ ویژگی‌ها

- 🔐 **امنیت بالا**: استفاده از توکن امنیتی و رمزنگاری ترافیک
- 🌐 **وب پنل کامل**: مدیریت آسان تانل‌ها از طریق مرورگر
- 📊 **مانیتورینگ Real-time**: نظارت زنده بر وضعیت تانل‌ها و سرورها
- 🔄 **همگام‌سازی خودکار**: اتصال به X-UI و ایجاد خودکار تانل‌ها
- 🚀 **چند پروتکل**: پشتیبانی از TCP, WebSocket (WS), WebSocket Secure (WSS)
- 💪 **پایداری بالا**: اتصال حتی در بدترین شرایط اینترنت
- 🎯 **مخفی‌سازی ترافیک**: استفاده از SNI و پروتکل‌های مخفی
- 📱 **رابط کاربری فارسی**: کاملاً به زبان فارسی

## 📋 پیش‌نیازها

- سیستم عامل: Ubuntu 20.04+ / Debian 10+ / CentOS 7+
- دسترسی Root
- Python 3.8+
- حداقل 512MB RAM
- اتصال اینترنت

## 🛠️ نصب

### نصب سرور ایران (Iran Server)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/abasniyati/iran-tunnel-panel/main/install.sh)
```

سپس گزینه **1** را انتخاب کنید.

### نصب سرور خارج (Foreign Server)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/abasniyati/iran-tunnel-panel/main/install.sh)
```

سپس گزینه **2** را انتخاب کنید.

## 📖 راهنمای استفاده

### 1️⃣ پیکربندی سرور خارج

1. نصب را انجام دهید
2. اطلاعات X-UI را وارد کنید (در صورت وجود)
3. توکن امنیتی را یادداشت کنید

### 2️⃣ پیکربندی سرور ایران

1. نصب را انجام دهید
2. IP سرور خارج را وارد کنید
3. توکن امنیتی سرور خارج را وارد کنید
4. نوع پروتکل را انتخاب کنید

### 3️⃣ دسترسی به وب پنل

پس از نصب سرور ایران:

```
URL: http://YOUR_SERVER_IP:8443
Username: admin
Password: admin123
```

**⚠️ مهم**: حتماً پس از اولین ورود، رمز عبور را تغییر دهید!

## 🎯 استفاده از پنل

### ایجاد تانل دستی

1. وارد تب **تانل‌ها** شوید
2. روی **➕ ایجاد تانل جدید** کلیک کنید
3. اطلاعات را وارد کنید:
   - نام تانل
   - پورت محلی
   - آدرس ریموت (IP:Port)
   - SNI (اختیاری)
4. **💾 ذخیره** کنید
5. روی **▶ شروع** کلیک کنید

### همگام‌سازی با X-UI

1. وارد تب **اینباندهای X-UI** شوید
2. روی **🔄 بروزرسانی لیست** کلیک کنید
3. برای هر اینباند روی **➕ ایجاد تانل** کلیک کنید

یا:

1. در تب **تانل‌ها**
2. روی **🔄 همگام‌سازی با X-UI** کلیک کنید
3. تانل‌ها به صورت خودکار ایجاد می‌شوند

## 🔧 دستورات مدیریت

### سرور ایران

```bash
# مشاهده وضعیت
systemctl status tunnel-panel

# ری‌استارت پنل
systemctl restart tunnel-panel

# مشاهده لاگ‌ها
journalctl -u tunnel-panel -f

# توقف پنل
systemctl stop tunnel-panel

# شروع پنل
systemctl start tunnel-panel
```

### سرور خارج

```bash
# مشاهده وضعیت Agent
systemctl status tunnel-agent

# ری‌استارت Agent
systemctl restart tunnel-agent

# مشاهده لاگ‌ها
journalctl -u tunnel-agent -f

# مشاهده لاگ Backhaul
tail -f /opt/tunnel-panel/logs/backhaul_server.log
```

## 📁 ساختار فایل‌ها

```
/opt/tunnel-panel/
├── bin/
│   └── backhaul          # باینری Backhaul
├── config/
│   ├── config.json       # تنظیمات اصلی
│   └── users.json        # کاربران پنل
├── web/                  # فایل‌های وب پنل (سرور ایران)
│   ├── app.py
│   ├── templates/
│   └── venv/
├── agent/                # فایل‌های Agent (سرور خارج)
│   ├── agent.py
│   └── venv/
└── logs/                 # لاگ‌ها
    ├── tunnel_*.log
    └── backhaul_server.log
```

## 🔐 امنیت

### توکن امنیتی

توکن امنیتی برای احراز هویت بین سرور ایران و خارج استفاده می‌شود. این توکن باید در هر دو سرور یکسان باشد.

### تغییر رمز عبور پنل

1. وارد پنل شوید
2. به تب **تنظیمات** بروید
3. رمز عبور فعلی و جدید را وارد کنید
4. روی **🔐 تغییر رمز عبور** کلیک کنید

### فایروال

پورت‌های لازم را باز کنید:

**سرور ایران:**
```bash
# پورت وب پنل
ufw allow 8443/tcp

# پورت‌های Cloudflare (اگر استفاده می‌کنید)
ufw allow 80/tcp
ufw allow 443/tcp
```

**سرور خارج:**
```bash
# پورت Backhaul
ufw allow 8080/tcp

# پورت Agent
ufw allow 8444/tcp

# پورت‌های X-UI
ufw allow 54321/tcp
```

## 🌐 استفاده با Cloudflare

1. دامنه خود را به Cloudflare اضافه کنید
2. یک رکورد A برای IP سرور ایران ایجاد کنید
3. پروکسی Cloudflare را فعال کنید (ابر نارنجی)
4. در تنظیمات SSL/TLS، حالت را روی **Full** قرار دهید
5. کاربران به جای IP، از دامنه استفاده کنند

## ⚙️ تنظیمات پیشرفته

### فایل پیکربندی سرور ایران

```json
{
    "server_type": "iran",
    "foreign_ip": "1.2.3.4",
    "foreign_port": 8080,
    "protocol": "tcp",
    "security_token": "your-secret-token",
    "web_port": 8443,
    "tunnels": []
}
```

### فایل پیکربندی سرور خارج

```json
{
    "server_type": "foreign",
    "listen_port": 8080,
    "security_token": "your-secret-token",
    "agent_port": 8444,
    "xui_enabled": true,
    "xui_port": 54321,
    "xui_username": "admin",
    "xui_password": "admin",
    "inbounds": []
}
```

## 🐛 عیب‌یابی

### خطا: "agent در دسترس نیست"

1. بررسی کنید که Agent روی سرور خارج در حال اجرا است:
   ```bash
   systemctl status tunnel-agent
   ```

2. بررسی کنید که IP و پورت Agent در تنظیمات سرور ایران صحیح است

3. بررسی کنید که توکن امنیتی در هر دو سرور یکسان است

4. فایروال را بررسی کنید:
   ```bash
   ufw status
   ```

### تانل اتصال برقرار نمی‌کند

1. لاگ‌های تانل را بررسی کنید:
   ```bash
   tail -f /opt/tunnel-panel/logs/tunnel_*.log
   ```

2. بررسی کنید که Backhaul server روی سرور خارج در حال اجرا است

3. پورت‌های فایروال را بررسی کنید

4. تانل را ری‌استارت کنید

### وب پنل باز نمی‌شود

1. بررسی وضعیت سرویس:
   ```bash
   systemctl status tunnel-panel
   ```

2. بررسی لاگ‌ها:
   ```bash
   journalctl -u tunnel-panel -f
   ```

3. بررسی کنید که پورت 8443 باز است:
   ```bash
   netstat -tlnp | grep 8443
   ```

## 🔄 بروزرسانی

برای بروزرسانی:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/iran-tunnel-panel/main/install.sh)
```

و نصب مجدد انجام دهید. تنظیمات و تانل‌های قبلی حفظ می‌شوند.

## 🗑️ حذف

برای حذف کامل:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/iran-tunnel-panel/main/install.sh)
```

سپس گزینه **3** را انتخاب کنید.

## 📊 مانیتورینگ

پنل به صورت خودکار اطلاعات زیر را نمایش می‌دهد:

- تعداد تانل‌های فعال
- مصرف CPU سیستم
- مصرف RAM سیستم
- تعداد اتصالات فعال
- وضعیت هر تانل (CPU, RAM, اتصالات)
- ترافیک ورودی و خروجی

## 🤝 مشارکت

برای گزارش باگ یا پیشنهادات:

1. Issue ایجاد کنید
2. Pull Request ارسال کنید

## 📝 لایسنس

MIT License

## ⚠️ توجه

این ابزار صرفاً برای اهداف آموزشی و استفاده شخصی طراحی شده است. مسئولیت استفاده از آن بر عهده کاربر است.

## 📞 پشتیبانی

برای سوالات و مشکلات:

- Telegram: @YourChannel


---

**ساخته شده با ❤️ برای جامعه ایرانی**
