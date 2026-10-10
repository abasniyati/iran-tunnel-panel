# ساختار پروژه برای آپلود به GitHub

## ساختار دایرکتوری

```
iran-tunnel-panel/
├── install.sh                 # اسکریپت نصب اصلی
├── quick-install.sh          # نصب سریع
├── manage.sh                 # اسکریپت مدیریت
├── app.py                    # برنامه وب پنل
├── agent.py                  # برنامه Agent سرور خارج
├── README.md                 # مستندات اصلی (انگلیسی)
├── GUIDE-FA.md              # راهنمای کامل فارسی
├── LICENSE                   # مجوز MIT
├── templates/
│   ├── index.html           # صفحه اصلی پنل
│   └── login.html           # صفحه لاگین
└── docs/
    ├── installation.md      # راهنمای نصب
    ├── configuration.md     # راهنمای پیکربندی
    └── troubleshooting.md   # عیب‌یابی
```

## نحوه آپلود به GitHub

### 1. ایجاد ریپازیتوری

1. به GitHub بروید
2. New Repository کلیک کنید
3. نام: `iran-tunnel-panel`
4. توضیحات: `Smart Backhaul tunnel management panel for Iran-Foreign server connection`
5. Public یا Private
6. Create Repository

### 2. آماده‌سازی فایل‌ها

```bash
# ایجاد دایرکتوری پروژه
mkdir iran-tunnel-panel
cd iran-tunnel-panel

# کپی فایل‌ها به ساختار درست
cp /path/to/install.sh .
cp /path/to/quick-install.sh .
cp /path/to/manage.sh .
cp /path/to/app.py .
cp /path/to/agent.py .
cp /path/to/README.md .
cp /path/to/GUIDE-FA.md .

# ایجاد دایرکتوری templates
mkdir templates
cp /path/to/templates_index.html templates/index.html
cp /path/to/templates_login.html templates/login.html

# اجازه اجرا به اسکریپت‌ها
chmod +x install.sh quick-install.sh manage.sh app.py agent.py
```

### 3. ایجاد LICENSE

```bash
cat > LICENSE << 'EOF'
MIT License

Copyright (c) 2024 Iran Tunnel Panel

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
```

### 4. ایجاد .gitignore

```bash
cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venv/
env/
ENV/

# Config files with secrets
config.json
users.json
*.log

# OS
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
*.swp
*.swo

# Backup files
*.backup
*.tar.gz
EOF
```

### 5. Git Init و Push

```bash
# Initialize git
git init
git add .
git commit -m "Initial commit: Iran Tunnel Panel v1.0"

# اضافه کردن remote
git remote add origin https://github.com/YOUR_USERNAME/iran-tunnel-panel.git

# Push
git branch -M main
git push -u origin main
```

### 6. بروزرسانی لینک‌ها

بعد از آپلود، در فایل‌ها `YOUR_USERNAME` را با یوزرنیم GitHub خود جایگزین کنید:

```bash
# در install.sh
sed -i 's/YOUR_USERNAME/your-github-username/g' install.sh

# در quick-install.sh
sed -i 's/YOUR_USERNAME/your-github-username/g' quick-install.sh

# در README.md
sed -i 's/YOUR_USERNAME/your-github-username/g' README.md

# Commit تغییرات
git add .
git commit -m "Update GitHub username in links"
git push
```

## نحوه استفاده برای کاربران

بعد از آپلود، کاربران می‌توانند با این دستور نصب کنند:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/iran-tunnel-panel/main/install.sh)
```

یا نصب سریع:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/iran-tunnel-panel/main/quick-install.sh)
```

## ویژگی‌های GitHub که باید فعال کنید

### 1. GitHub Pages (برای مستندات)

- Settings → Pages
- Source: Deploy from a branch
- Branch: main / docs
- Save

### 2. Issues

- Settings → Features
- Issues: ✅ فعال

قالب Issue:
```markdown
**توضیح مشکل:**

**محیط:**
- OS: 
- نوع سرور: ایران / خارج
- نسخه: 

**لاگ‌ها:**
```

### 3. Releases

برای هر نسخه:
```bash
git tag -a v1.0.0 -m "نسخه 1.0.0 - انتشار اولیه"
git push origin v1.0.0
```

در GitHub:
- Releases → Create a new release
- Choose tag: v1.0.0
- Release title: نسخه 1.0.0
- توضیحات تغییرات
- Publish release

### 4. README Badge‌ها

به README.md اضافه کنید:

```markdown
![GitHub stars](https://img.shields.io/github/stars/YOUR_USERNAME/iran-tunnel-panel?style=social)
![GitHub forks](https://img.shields.io/github/forks/YOUR_USERNAME/iran-tunnel-panel?style=social)
![GitHub issues](https://img.shields.io/github/issues/YOUR_USERNAME/iran-tunnel-panel)
![GitHub license](https://img.shields.io/github/license/YOUR_USERNAME/iran-tunnel-panel)
```

## مستندات اضافی (اختیاری)

### CONTRIBUTING.md

```markdown
# مشارکت در پروژه

ممنون که می‌خواهید کمک کنید!

## نحوه مشارکت

1. Fork کنید
2. Branch جدید بسازید (`git checkout -b feature/amazing-feature`)
3. Commit کنید (`git commit -m 'Add amazing feature'`)
4. Push کنید (`git push origin feature/amazing-feature`)
5. Pull Request باز کنید

## استانداردهای کد

- Python: PEP 8
- Bash: ShellCheck
- کامنت‌ها به فارسی یا انگلیسی
```

### CHANGELOG.md

```markdown
# تغییرات

## [1.0.0] - 2024-XX-XX
### اضافه شده
- نصب خودکار
- وب پنل مدیریتی
- پشتیبانی از X-UI
- مانیتورینگ Real-time
- راهنمای کامل فارسی
```

## چک‌لیست قبل از انتشار

- [ ] همه فایل‌ها آپلود شدند
- [ ] لینک‌های GitHub درست هستند
- [ ] README کامل است
- [ ] راهنمای نصب تست شده
- [ ] LICENSE اضافه شده
- [ ] .gitignore وجود دارد
- [ ] مثال‌های کد کار می‌کنند
- [ ] اسکریپت‌ها قابل اجرا هستند
- [ ] مستندات فارسی کامل است

## لینک‌های مفید

- مخزن Backhaul: https://github.com/Musixal/Backhaul
- مستندات Flask: https://flask.palletsprojects.com/
- راهنمای Cloudflare: https://developers.cloudflare.com/
