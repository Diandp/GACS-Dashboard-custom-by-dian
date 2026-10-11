# GACS Dashboard - Ubuntu 22.04 Installation Guide

> 📌 Panduan lengkap instalasi GACS Dashboard di Ubuntu 22.04 LTS

## Prerequisites

- Ubuntu 22.04 LTS (server atau desktop)
- Akses root/sudo
- Koneksi internet
- Domain atau IP address untuk akses

## Instalasi Cepat (Rekomendasi)

### Opsi 1: Menggunakan Script Otomatis

Jalankan satu command untuk instalasi complete:

```bash
sudo bash <(curl -fsSL https://raw.githubusercontent.com/Diandp/GACS-Dashboard-custom-by-dian/ubuntu-22-04-installer/install.sh)
```

**Atau** jika sudah di-clone repository:

```bash
sudo bash install.sh
```

Script ini akan:
- ✅ Update sistem dan install semua dependencies
- ✅ Setup Apache2 dan PHP 8.3
- ✅ Setup MySQL/MariaDB
- ✅ Clone/setup GACS Dashboard
- ✅ Setup database dan import schema
- ✅ Konfigurasi Apache virtual host
- ✅ Setup file permissions
- ✅ Siap akses langsung

---

## Instalasi Manual (Step-by-Step)

### Step 1: Update Sistem

```bash
sudo apt update
sudo apt upgrade -y
```

### Step 2: Install Dependencies

```bash
sudo apt install -y \
  apache2 \
  php8.3 \
  php8.3-cli \
  php8.3-fpm \
  php8.3-mysql \
  php8.3-mbstring \
  php8.3-xml \
  php8.3-curl \
  php8.3-json \
  php8.3-bcmath \
  php8.3-zip \
  php8.3-gd \
  php8.3-intl \
  composer \
  mysql-server \
  wget \
  curl \
  git \
  nano \
  unzip
```

### Step 3: Setup MySQL Database

```bash
# Login ke MySQL
sudo mysql -u root
```

Jalankan query berikut:

```sql
-- Buat database
CREATE DATABASE gacs_dev CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

-- Buat user dan berikan privilege
CREATE USER 'gacs_dev'@'localhost' IDENTIFIED BY 'gacs_secure_password';
GRANT ALL PRIVILEGES ON gacs_dev.* TO 'gacs_dev'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

**⚠️ Catatan:** Ganti `gacs_secure_password` dengan password yang kuat!

### Step 4: Clone Repository

```bash
cd /var/www/html
sudo git clone https://github.com/Diandp/GACS-Dashboard-custom-by-dian.git gacs-dashboard
cd gacs-dashboard
```

### Step 5: Setup Composer Dependencies

```bash
sudo composer install --no-dev
```

### Step 6: Import Database Schema

```bash
mysql -u gacs_dev -p gacs_dev < database.sql
```

Masukkan password yang Anda set tadi.

### Step 7: Konfigurasi Database Connection

```bash
sudo nano config/database.php
```

Ubah isi file seperti ini:

```php
<?php
// Database Configuration
define('DB_HOST', 'localhost');
define('DB_USER', 'gacs_dev');
define('DB_PASS', 'gacs_secure_password');  // Ganti dengan password Anda
define('DB_NAME', 'gacs_dev');

// Create database connection
function getDBConnection() {
    static $conn = null;

    if ($conn === null) {
        $conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);

        if ($conn->connect_error) {
            die("Connection failed: " . $conn->connect_error);
        }

        $conn->set_charset("utf8mb4");
    }

    return $conn;
}
```

Simpan dengan `Ctrl+X` → `Y` → `Enter`

### Step 8: Konfigurasi Apache Virtual Host

```bash
sudo nano /etc/apache2/sites-available/gacs-dashboard.conf
```

Isi dengan:

```apache
<VirtualHost *:80>
    ServerName gacs.local
    ServerAlias *.gacs.local
    
    DocumentRoot /var/www/html/gacs-dashboard
    
    <Directory /var/www/html/gacs-dashboard>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
        
        # URL Rewriting untuk API
        <IfModule mod_rewrite.c>
            RewriteEngine On
            RewriteBase /
            RewriteCond %{REQUEST_FILENAME} !-f
            RewriteCond %{REQUEST_FILENAME} !-d
            RewriteRule ^api/(.*)$ api/$1 [QSA,L]
        </IfModule>
    </Directory>
    
    # Error & Access Logs
    ErrorLog ${APACHE_LOG_DIR}/gacs-dashboard_error.log
    CustomLog ${APACHE_LOG_DIR}/gacs-dashboard_access.log combined
    
    # Security Headers
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-XSS-Protection "1; mode=block"
</VirtualHost>
```

### Step 9: Enable Apache Modules & Site

```bash
sudo a2enmod rewrite
sudo a2enmod headers
sudo a2ensite gacs-dashboard.conf
sudo systemctl reload apache2
```

### Step 10: Setup File Permissions

```bash
cd /var/www/html/gacs-dashboard

# Set owner ke www-data (Apache user)
sudo chown -R www-data:www-data .

# Set permissions
sudo chmod -R 755 .
sudo chmod 600 config/config.php config/database.php
sudo chmod -R 775 cron/
```

### Step 11: Update /etc/hosts (untuk testing lokal)

Jika menggunakan domain lokal:

```bash
sudo nano /etc/hosts
```

Tambahkan:

```
127.0.0.1   gacs.local
127.0.0.1   dashboard.gacs.local
```

---

## Akses Dashboard

### Step 1: Setup Awal

Buka browser dan akses:

```
http://gacs.local/init.php
```

**Login dengan kredensial default:**
- Username: `user1234`
- Password: `mostech`

### Step 2: Ikuti Wizard Setup

Wizard akan memandu Anda untuk:
1. Verifikasi database connection
2. Setup GenieACS credentials (opsional)
3. Setup MikroTik credentials (opsional)
4. Setup Telegram Bot (opsional)

### Step 3: Hapus init.php

**⚠️ PENTING:** Setelah setup selesai, hapus file init.php:

```bash
sudo rm /var/www/html/gacs-dashboard/init.php
```

### Step 4: Akses Dashboard

```
http://gacs.local
```

Login dengan:
- Username: `user1234`
- Password: `mostech`

**⚠️ SEGERA ganti password default setelah login pertama!**

---

## Konfigurasi Production (HTTPS)

### Install SSL Certificate (Let's Encrypt)

```bash
sudo apt install -y certbot python3-certbot-apache
sudo certbot --apache -d gacs.yourdomain.com
```

Certbot akan:
- Auto-setup SSL
- Auto-renew setiap 90 hari
- Redirect HTTP ke HTTPS

### Verifikasi SSL

```bash
sudo certbot renew --dry-run
```

---

## Troubleshooting

### Problem: "Connection refused" ke database

```bash
# Cek MySQL running
sudo systemctl status mysql

# Restart MySQL
sudo systemctl restart mysql

# Test connection
mysql -u gacs_dev -p -h localhost gacs_dev
```

### Problem: Permission denied pada file

```bash
cd /var/www/html/gacs-dashboard
sudo chown -R www-data:www-data .
sudo chmod -R 755 .
sudo chmod 600 config/*.php
```

### Problem: Apache 404 Not Found

```bash
# Enable rewrite module
sudo a2enmod rewrite

# Check syntax
sudo apache2ctl configtest

# Reload Apache
sudo systemctl reload apache2
```

### Problem: PHP error/blank page

```bash
# Check error log
tail -f /var/log/apache2/gacs-dashboard_error.log

# Enable error display (development only)
sudo nano config/config.php
# Set: ini_set('display_errors', 1);
```

---

## Setup Cron Jobs (Production)

Untuk monitoring dan reports otomatis:

```bash
sudo crontab -e
```

Tambahkan:

```bash
# Device monitoring - setiap 5 menit
*/5 * * * * /usr/bin/php /var/www/html/gacs-dashboard/cron/device-monitor.php

# Backup database - setiap hari jam 2 pagi
0 2 * * * /usr/bin/php /var/www/html/gacs-dashboard/cron/backup.php

# Telegram reports - setiap hari jam 8 pagi
0 8 * * * /usr/bin/php /var/www/html/gacs-dashboard/cron/telegram-reports.php
```

---

## Verifikasi Instalasi

```bash
# Check PHP version
php -v

# Check Apache modules
apache2ctl -M | grep rewrite
apache2ctl -M | grep headers

# Check MySQL connection
mysql -u gacs_dev -p -e "SELECT VERSION();"

# Check file ownership
ls -la /var/www/html/gacs-dashboard/config/
```

---

## Panduan Keamanan

1. **Ganti Password Default**
   - Login ke dashboard
   - Pergi ke Configuration → Change Password
   - Ganti dari `mostech` ke password yang kuat

2. **Set File Permissions Proper**
   ```bash
   sudo chmod 600 config/config.php config/database.php
   ```

3. **Enable HTTPS**
   - Gunakan Let's Encrypt (lihat bagian Production)
   - Set `SESSION_SECURE=true` di config

4. **Backup Regular**
   ```bash
   # Database backup
   mysqldump -u gacs_dev -p gacs_dev > gacs_backup_$(date +%Y%m%d).sql
   
   # Full backup
   tar -czf gacs_backup_$(date +%Y%m%d).tar.gz /var/www/html/gacs-dashboard/
   ```

5. **Monitor Logs**
   ```bash
   tail -f /var/log/apache2/gacs-dashboard_error.log
   tail -f /var/log/apache2/gacs-dashboard_access.log
   ```

---

## Uninstall

Jika ingin menghapus instalasi:

```bash
# Disable site
sudo a2dissite gacs-dashboard.conf

# Remove files
sudo rm -rf /var/www/html/gacs-dashboard

# Drop database
sudo mysql -u root -p -e "DROP DATABASE gacs_dev; DROP USER 'gacs_dev'@'localhost';"

# Reload Apache
sudo systemctl reload apache2
```

---

## Support & Documentation

- 📖 **README**: https://github.com/Diandp/GACS-Dashboard-custom-by-dian
- 💬 **Telegram Group**: https://t.me/mostechsharing
- 🐛 **Issues**: https://github.com/Diandp/GACS-Dashboard-custom-by-dian/issues

---

**Last Updated**: 2025-11-15
**Version**: 1.1.0-beta
