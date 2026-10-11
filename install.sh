#!/bin/bash

################################################################################
# GACS Dashboard - Automated Installation Script for Ubuntu 22.04
# Purpose: Complete setup in one command
# Tested on: Ubuntu 22.04 LTS
################################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
APP_NAME="GACS Dashboard"
APP_PATH="/var/www/html/gacs-dashboard"
DB_NAME="gacs_dev"
DB_USER="gacs_dev"
DB_PASSWORD=""
DOMAIN="gacs.local"
WEB_USER="www-data"
PHP_VERSION="8.3"

################################################################################
# Functions
################################################################################

print_header() {
    clear
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║     ${APP_NAME} - Ubuntu 22.04 Installer              ║"
    echo "║     Automated Setup Script v1.0                             ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "${BLUE}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Script ini harus dijalankan dengan sudo/root"
        exit 1
    fi
}

check_ubuntu() {
    if ! grep -q "Ubuntu 22.04" /etc/os-release; then
        print_warning "Script ini dirancang untuk Ubuntu 22.04 LTS"
        echo -n "Lanjutkan? (y/n): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

generate_password() {
    openssl rand -base64 12
}

install_dependencies() {
    print_step "Mengupdate package list..."
    apt-get update > /dev/null 2>&1
    
    print_step "Menginstall dependencies (ini mungkin memakan waktu...)"
    apt-get install -y \
        apache2 \
        php${PHP_VERSION} \
        php${PHP_VERSION}-cli \
        php${PHP_VERSION}-fpm \
        php${PHP_VERSION}-mysql \
        php${PHP_VERSION}-mbstring \
        php${PHP_VERSION}-xml \
        php${PHP_VERSION}-curl \
        php${PHP_VERSION}-json \
        php${PHP_VERSION}-bcmath \
        php${PHP_VERSION}-zip \
        php${PHP_VERSION}-gd \
        php${PHP_VERSION}-intl \
        composer \
        mysql-server \
        wget \
        curl \
        git \
        nano \
        unzip > /dev/null 2>&1
    
    print_success "Dependencies terinstall"
}

setup_mysql() {
    print_step "Mengsetup MySQL..."
    
    # Generate secure password jika belum ada
    if [ -z "$DB_PASSWORD" ]; then
        DB_PASSWORD=$(generate_password)
    fi
    
    # Ensure MySQL is running
    systemctl start mysql > /dev/null 2>&1 || systemctl start mariadb > /dev/null 2>&1
    systemctl enable mysql > /dev/null 2>&1 || systemctl enable mariadb > /dev/null 2>&1
    
    # Create database and user
    mysql -u root << EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    print_success "Database dan user MySQL dibuat"
    echo -e "  Database: ${GREEN}${DB_NAME}${NC}"
    echo -e "  User: ${GREEN}${DB_USER}${NC}"
    echo -e "  Password: ${GREEN}${DB_PASSWORD}${NC}"
}

clone_repository() {
    print_step "Mengclone repository..."
    
    # Create directory if not exists
    mkdir -p /var/www/html
    
    # Remove if exists
    if [ -d "$APP_PATH" ]; then
        print_warning "Direktori sudah ada. Menggunakan yang sudah ada..."
    else
        git clone https://github.com/Diandp/GACS-Dashboard-custom-by-dian.git "$APP_PATH" > /dev/null 2>&1
        print_success "Repository diklon"
    fi
}

install_composer() {
    print_step "Menginstall PHP dependencies dengan Composer..."
    cd "$APP_PATH"
    composer install --no-dev --quiet
    print_success "Composer dependencies installed"
}

import_database() {
    print_step "Mengimport database schema..."
    
    if [ -f "$APP_PATH/database.sql" ]; then
        mysql -u "${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" < "$APP_PATH/database.sql" 2>/dev/null
        print_success "Database schema imported"
    else
        print_error "File database.sql tidak ditemukan!"
        return 1
    fi
}

setup_config() {
    print_step "Mengkonfigurasi database connection..."
    
    cat > "$APP_PATH/config/database.php" << 'EOF'
<?php
// Database Configuration
// ⚠️ IMPORTANT: Update these values with your actual database credentials
define('DB_HOST', 'localhost');
define('DB_USER', getenv('DB_USER') ?: 'gacs_dev');
define('DB_PASS', getenv('DB_PASS') ?: '');
define('DB_NAME', getenv('DB_NAME') ?: 'gacs_dev');

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
EOF
    
    # Update database credentials
    sed -i "s/'gacs_dev'/'${DB_USER}'/g" "$APP_PATH/config/database.php"
    sed -i "s/=> ''/=> '${DB_PASSWORD}'/" "$APP_PATH/config/database.php"
    sed -i "s/'gacs_dev'/'${DB_NAME}'/g" "$APP_PATH/config/database.php"
    
    print_success "Database configuration updated"
}

setup_permissions() {
    print_step "Mengatur file permissions..."
    
    # Set ownership
    chown -R "${WEB_USER}:${WEB_USER}" "$APP_PATH"
    
    # Set directory permissions
    find "$APP_PATH" -type d -exec chmod 755 {} \;
    
    # Set file permissions
    find "$APP_PATH" -type f -exec chmod 644 {} \;
    
    # Restrict config files
    chmod 600 "$APP_PATH/config/config.php" 2>/dev/null || true
    chmod 600 "$APP_PATH/config/database.php" 2>/dev/null || true
    
    # Make cron/logs writable
    chmod 775 "$APP_PATH/cron" 2>/dev/null || true
    
    print_success "File permissions configured"
}

setup_apache() {
    print_step "Mengkonfigurasi Apache..."
    
    # Enable modules
    a2enmod rewrite > /dev/null 2>&1
    a2enmod headers > /dev/null 2>&1
    a2enmod php${PHP_VERSION} > /dev/null 2>&1
    
    # Remove default site
    a2dissite 000-default.conf > /dev/null 2>&1 || true
    
    # Create virtual host
    cat > /etc/apache2/sites-available/gacs-dashboard.conf << 'EOF'
<VirtualHost *:80>
    ServerName gacs.local
    ServerAlias *.gacs.local
    
    DocumentRoot /var/www/html/gacs-dashboard
    
    <Directory /var/www/html/gacs-dashboard>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
        
        <IfModule mod_rewrite.c>
            RewriteEngine On
            RewriteBase /
            RewriteCond %{REQUEST_FILENAME} !-f
            RewriteCond %{REQUEST_FILENAME} !-d
            RewriteRule ^api/(.*)$ api/$1 [QSA,L]
        </IfModule>
    </Directory>
    
    ErrorLog ${APACHE_LOG_DIR}/gacs-dashboard_error.log
    CustomLog ${APACHE_LOG_DIR}/gacs-dashboard_access.log combined
    
    <IfModule mod_headers.c>
        Header always set X-Content-Type-Options "nosniff"
        Header always set X-Frame-Options "SAMEORIGIN"
        Header always set X-XSS-Protection "1; mode=block"
    </IfModule>
</VirtualHost>
EOF
    
    # Enable site
    a2ensite gacs-dashboard.conf > /dev/null 2>&1
    
    # Test configuration
    if apache2ctl configtest | grep -q "Syntax OK"; then
        systemctl reload apache2 > /dev/null 2>&1
        print_success "Apache configured and reloaded"
    else
        print_error "Apache configuration error!"
        apache2ctl configtest
        return 1
    fi
}

setup_hosts() {
    print_step "Updating /etc/hosts..."
    
    # Add entry if not exists
    if ! grep -q "${DOMAIN}" /etc/hosts; then
        echo "127.0.0.1   ${DOMAIN}" >> /etc/hosts
        print_success "Added ${DOMAIN} to /etc/hosts"
    else
        print_warning "${DOMAIN} already in /etc/hosts"
    fi
}

verify_installation() {
    print_step "Memverifikasi instalasi..."
    
    # Check PHP
    if php -v | grep -q "${PHP_VERSION}"; then
        print_success "PHP ${PHP_VERSION} installed"
    else
        print_error "PHP not found"
        return 1
    fi
    
    # Check Apache modules
    if apache2ctl -M 2>/dev/null | grep -q rewrite; then
        print_success "Apache rewrite module enabled"
    else
        print_error "Apache rewrite module not found"
        return 1
    fi
    
    # Check MySQL connection
    if mysql -u "${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" -e "SELECT 1" > /dev/null 2>&1; then
        print_success "MySQL connection verified"
    else
        print_error "MySQL connection failed"
        return 1
    fi
    
    # Check files exist
    if [ -f "$APP_PATH/dashboard.php" ]; then
        print_success "Application files ready"
    else
        print_error "Application files missing"
        return 1
    fi
}

print_summary() {
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ Instalasi Berhasil!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}📍 Akses Dashboard:${NC}"
    echo -e "   ${GREEN}http://${DOMAIN}${NC}"
    echo ""
    echo -e "${BLUE}🔐 Kredensial Default:${NC}"
    echo -e "   Username: ${GREEN}user1234${NC}"
    echo -e "   Password: ${GREEN}mostech${NC}"
    echo ""
    echo -e "${BLUE}📊 Database:${NC}"
    echo -e "   Host: ${GREEN}localhost${NC}"
    echo -e "   Name: ${GREEN}${DB_NAME}${NC}"
    echo -e "   User: ${GREEN}${DB_USER}${NC}"
    echo -e "   Pass: ${GREEN}${DB_PASSWORD}${NC}"
    echo ""
    echo -e "${BLUE}📁 Installation Path:${NC}"
    echo -e "   ${GREEN}${APP_PATH}${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Next Steps:${NC}"
    echo -e "   1. Buka http://${DOMAIN}/init.php di browser"
    echo -e "   2. Login dengan kredensial di atas"
    echo -e "   3. Ikuti wizard setup"
    echo -e "   4. Hapus file init.php setelah selesai:"
    echo -e "      ${GREEN}sudo rm ${APP_PATH}/init.php${NC}"
    echo -e "   5. Ganti password default di Dashboard → Configuration"
    echo ""
    echo -e "${BLUE}📚 Dokumentasi:${NC}"
    echo -e "   https://github.com/Diandp/GACS-Dashboard-custom-by-dian"
    echo -e "   ${GREEN}${APP_PATH}/INSTALL_UBUNTU_22.04.md${NC}"
    echo ""
}

print_troubleshooting() {
    echo -e "${YELLOW}🔧 Troubleshooting:${NC}"
    echo ""
    echo -e "${BLUE}Jika tidak bisa akses:${NC}"
    echo "  1. Pastikan Apache running:"
    echo -e "     ${GREEN}sudo systemctl status apache2${NC}"
    echo "  2. Cek error log:"
    echo -e "     ${GREEN}sudo tail -f /var/log/apache2/gacs-dashboard_error.log${NC}"
    echo "  3. Cek permissions:"
    echo -e "     ${GREEN}sudo ls -la ${APP_PATH}/config/${NC}"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    print_header
    
    # Pre-flight checks
    print_step "Menjalankan pre-flight checks..."
    check_root
    check_ubuntu
    print_success "Pre-flight checks passed"
    echo ""
    
    # Installation steps
    install_dependencies
    setup_mysql
    clone_repository
    install_composer
    import_database
    setup_config
    setup_permissions
    setup_apache
    setup_hosts
    echo ""
    
    # Verification
    if verify_installation; then
        print_summary
        print_troubleshooting
    else
        print_error "Instalasi tidak selesai dengan sempurna. Lihat error di atas."
        exit 1
    fi
}

# Run main function
main "$@"
