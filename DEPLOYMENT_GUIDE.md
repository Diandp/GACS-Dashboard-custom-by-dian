# GACS Dashboard - Production Server Deployment Guide

## 📦 What's Included

This is a complete ready-to-deploy package for production servers:

```
gacs-dashboard-deployment/
├── deploy.sh                 ← START HERE (Main deployment orchestrator)
├── install.sh                ← Full Apache installation
├── install-interactive.sh    ← Custom interactive setup
├── install-nginx-ssl.sh      ← Nginx + Let's Encrypt production
├── quick-install.sh          ← Quick 5-minute setup
├── setup-nginx.sh            ← Nginx basic configuration
├── backup.sh                 ← Automated backup utility
├── setup-cron.sh             ← Cron job automation
├── INSTALL_UBUNTU_22.04.md   ← Full installation guide
├── DEPLOYMENT_GUIDE.md       ← This file
└── .env.production           ← Production environment template
```

## 🚀 Quick Start (Production)

### Option 1: Automated Production Setup (Apache)

```bash
sudo bash deploy.sh --auto
```

Or interactive menu:
```bash
sudo bash deploy.sh
# Select option 1
```

### Option 2: Production with Nginx + SSL

```bash
sudo bash deploy.sh --nginx
```

Or interactive menu:
```bash
sudo bash deploy.sh
# Select option 2
```

### Option 3: Custom Installation

```bash
sudo bash deploy.sh --custom
```

Or interactive menu:
```bash
sudo bash deploy.sh
# Select option 3
```

## 📋 Pre-Deployment Checklist

Before running deployment, verify:

✅ **Server Requirements**
- [ ] Ubuntu 22.04 LTS
- [ ] Sudo/root access
- [ ] Internet connection
- [ ] Minimum 2GB RAM
- [ ] Minimum 20GB disk space

✅ **Network Configuration**
- [ ] Domain name registered (for HTTPS)
- [ ] DNS records pointing to server IP
- [ ] Ports 80 and 443 open
- [ ] SSH access verified

✅ **Preparation**
- [ ] Backup any existing data
- [ ] Document current configuration
- [ ] Notify stakeholders
- [ ] Plan maintenance window

## 🛠️ Deployment Scenarios

### Scenario 1: Simple Single Server (15-30 min)

```bash
# Login to server
ssh user@your-server.com

# Download deployment package
cd /tmp
wget -O gacs-deployment.zip https://github.com/Diandp/GACS-Dashboard-custom-by-dian/archive/refs/heads/ubuntu-22-04-installer.zip
unzip gacs-deployment.zip
cd GACS-Dashboard-custom-by-dian-ubuntu-22-04-installer

# Run deployment
sudo bash deploy.sh --auto

# Follow prompts and wait for completion
```

### Scenario 2: Production with Nginx & SSL (20-40 min)

```bash
# Login to server
ssh user@your-server.com

# Download and run Nginx setup
cd /tmp
wget -O gacs-deployment.zip https://github.com/Diandp/GACS-Dashboard-custom-by-dian/archive/refs/heads/ubuntu-22-04-installer.zip
unzip gacs-deployment.zip
cd GACS-Dashboard-custom-by-dian-ubuntu-22-04-installer

# Run Nginx deployment
sudo bash deploy.sh --nginx

# Enter domain and email for Let's Encrypt
```

### Scenario 3: Custom Enterprise Setup

```bash
# Login to server
ssh user@your-server.com

# Download and run custom setup
cd /tmp
wget -O gacs-deployment.zip https://github.com/Diandp/GACS-Dashboard-custom-by-dian/archive/refs/heads/ubuntu-22-04-installer.zip
unzip gacs-deployment.zip
cd GACS-Dashboard-custom-by-dian-ubuntu-22-04-installer

# Run interactive setup
sudo bash deploy.sh --custom

# Customize all settings step by step
```

## 📝 Post-Deployment Steps

### 1. Initial Setup (5 minutes)

```bash
# Open browser
https://your-domain.com/init.php

# Login with default credentials
Username: user1234
Password: mostech

# Follow the wizard
# - Verify database
# - Configure GenieACS (optional)
# - Configure MikroTik (optional)
# - Configure Telegram (optional)

# After completion, DELETE init.php
sudo rm /var/www/html/gacs-dashboard/init.php
```

### 2. Security Configuration (10 minutes)

```bash
# Change admin password
# Access: https://your-domain.com
# Menu: Configuration → Change Password

# Configure GenieACS
# Menu: Configuration → ACS Config
# Enter: Host, Port, Username, Password
# Click: Test Connection → Save

# (Optional) Configure Telegram
# Menu: Configuration → Bot Config
# Enter: Bot Token, Chat ID
# Click: Test Connection → Save
```

### 3. Backup Verification (5 minutes)

```bash
# Verify automated backups are running
sudo crontab -u www-data -l

# Manual test backup
sudo bash /var/www/html/gacs-dashboard/backup.sh

# Check backup files
ls -lh /var/backups/gacs-dashboard/
```

### 4. Monitoring Setup (10 minutes)

```bash
# Check application logs
tail -f /var/www/html/gacs-dashboard/logs/*.log

# Check web server logs
tail -f /var/log/apache2/gacs-dashboard_error.log
# OR (for Nginx)
tail -f /var/log/nginx/gacs-dashboard_error.log

# Verify cron jobs
sudo systemctl status apache2
# OR (for Nginx)
sudo systemctl status nginx
```

## 🔧 Common Configuration Tasks

### Change Database Credentials

```bash
sudo nano /var/www/html/gacs-dashboard/config/database.php

# Edit:
define('DB_USER', 'new_username');
define('DB_PASS', 'new_password');
define('DB_NAME', 'new_database');

# Save: Ctrl+X → Y → Enter
```

### Configure Email Notifications

```bash
sudo nano /var/www/html/gacs-dashboard/.env

# Add:
EMAIL_ON_ERROR=admin@example.com
EMAIL_HOST=smtp.example.com
EMAIL_PORT=587
EMAIL_USERNAME=notifications@example.com
EMAIL_PASSWORD=password
```

### Enable HTTPS (if using Apache)

```bash
# Install Certbot
sudo apt-get install certbot python3-certbot-apache

# Request certificate
sudo certbot --apache -d your-domain.com

# Auto-renewal test
sudo certbot renew --dry-run
```

## 🔐 Security Hardening

### File Permissions

```bash
cd /var/www/html/gacs-dashboard

# Set proper ownership
sudo chown -R www-data:www-data .

# Restrict config files
sudo chmod 600 config/config.php config/database.php

# App files readable by web server
sudo chmod 755 . -R
sudo chmod 644 *.php

# Writable directories
sudo chmod 777 logs/ cron/ uploads/ -R
```

### Firewall Configuration

```bash
# Enable UFW
sudo ufw enable

# Allow SSH
sudo ufw allow 22/tcp

# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Check status
sudo ufw status
```

### MySQL Hardening

```bash
# Secure MySQL installation
sudo mysql_secure_installation

# Remove test database
sudo mysql -u root -p -e "DROP DATABASE test;"

# Backup user (read-only)
sudo mysql -u root -p << EOF
GRANT SELECT, LOCK TABLES ON gacs_dev.* TO 'gacs_backup'@'localhost' IDENTIFIED BY 'password';
FLUSH PRIVILEGES;
EOF
```

## 📊 Monitoring & Maintenance

### Daily Tasks

```bash
# Check application health
curl -I https://your-domain.com

# Check backup completion
ls -lt /var/backups/gacs-dashboard/ | head -3

# Monitor error logs
tail -50 /var/log/apache2/gacs-dashboard_error.log
```

### Weekly Tasks

```bash
# Review cron job logs
grep CRON /var/log/syslog | tail -20

# Check disk space
df -h

# Verify SSL certificate expiry
sudo certbot certificates

# Database integrity check
sudo mysqlcheck -u root -p gacs_dev
```

### Monthly Tasks

```bash
# Full system updates
sudo apt-get update
sudo apt-get upgrade -y

# Backup review
ls -lh /var/backups/gacs-dashboard/

# Security audit
sudo apt-get install aide
sudo aideinit
sudo aide --check

# Log rotation review
ls -la /var/log/*.1
```

## 🆘 Troubleshooting

### Website Not Accessible

```bash
# Check web server status
sudo systemctl status apache2
# OR
sudo systemctl status nginx

# Check if application is running
curl http://localhost/

# Check error logs
sudo tail -50 /var/log/apache2/gacs-dashboard_error.log

# Check firewall
sudo ufw status

# Check DNS
nslookup your-domain.com
```

### Database Connection Error

```bash
# Check MySQL status
sudo systemctl status mysql

# Test connection
mysql -u gacs_dev -p -e "SELECT 1;"

# Check credentials in config
sudo cat /var/www/html/gacs-dashboard/config/database.php

# Restart MySQL
sudo systemctl restart mysql
```

### SSL Certificate Issues

```bash
# Check certificate expiry
sudo certbot certificates

# Renew certificate
sudo certbot renew

# View Nginx SSL config
sudo nano /etc/nginx/sites-available/gacs-dashboard

# Restart Nginx
sudo systemctl restart nginx
```

### Permission Denied Errors

```bash
# Fix ownership
sudo chown -R www-data:www-data /var/www/html/gacs-dashboard

# Fix permissions
sudo chmod 755 /var/www/html/gacs-dashboard
sudo chmod 600 /var/www/html/gacs-dashboard/config/*.php
sudo chmod 777 /var/www/html/gacs-dashboard/logs

# Verify
ls -la /var/www/html/gacs-dashboard/config/
```

## 📚 Additional Resources

- **Full Guide**: See `INSTALL_UBUNTU_22.04.md`
- **GitHub**: https://github.com/Diandp/GACS-Dashboard-custom-by-dian
- **Issues**: https://github.com/Diandp/GACS-Dashboard-custom-by-dian/issues
- **Telegram**: https://t.me/mostechsharing

## ✅ Deployment Validation

After deployment, run validation:

```bash
# Check all services
sudo systemctl status apache2
sudo systemctl status mysql
sudo systemctl status nginx  # if using Nginx

# Verify application access
curl -I https://your-domain.com

# Check logs for errors
sudo tail -20 /var/log/apache2/gacs-dashboard_error.log

# Verify backup setup
sudo crontab -u www-data -l

# Test database
mysql -u gacs_dev -p gacs_dev -e "SELECT COUNT(*) FROM users;"

# Check file permissions
ls -la /var/www/html/gacs-dashboard/config/database.php
```

If all checks pass, your production deployment is complete! 🎉

---

**Last Updated**: 2025-11-15  
**Version**: 1.1.0-beta  
**Support**: https://t.me/mostechsharing
