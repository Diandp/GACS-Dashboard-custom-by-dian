#!/bin/bash

################################################################################
# GACS Dashboard - Interactive Installation with Custom Database
# Purpose: Allow custom database name, user, and installation paths
################################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Default values
DEFAULT_DB_NAME="gacs_dev"
DEFAULT_DB_USER="gacs_dev"
DEFAULT_DOMAIN="gacs.local"
DEFAULT_APP_PATH="/var/www/html/gacs-dashboard"
DEFAULT_WEB_USER="www-data"
DEFAULT_PHP_VERSION="8.3"

# Global variables
DB_NAME=""
DB_USER=""
DB_PASSWORD=""
DB_PASSWORD_CONFIRM=""
DOMAIN=""
APP_PATH=""
WEB_USER=""
PHP_VERSION=""
WEB_SERVER="apache"
USE_HTTPS="no"
LETSENCRYPT_EMAIL=""
BACKUP_ENABLED="no"
BACKUP_PATH=""

################################################################################
# UI Functions
################################################################################

print_banner() {
    clear
    echo -e "${MAGENTA}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║     GACS Dashboard - Interactive Installer for Ubuntu 22.04    ║"
    echo "║     Powered by Mostech                                        ║"
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

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

read_input() {
    local prompt="$1"
    local default="$2"
    local input
    
    if [ -z "$default" ]; then
        read -p "${BLUE}${prompt}${NC}: " input
    else
        read -p "${BLUE}${prompt}${NC} [${GREEN}${default}${NC}]: " input
        input=${input:-$default}
    fi
    
    echo "$input"
}

read_password() {
    local prompt="$1"
    local password
    
    while true; do
        read -sp "${BLUE}${prompt}${NC}: " password
        echo ""
        
        if [ -z "$password" ]; then
            print_error "Password tidak boleh kosong!"
            continue
        fi
        
        if [ ${#password} -lt 8 ]; then
            print_error "Password minimal 8 karakter!"
            continue
        fi
        
        echo "$password"
        break
    done
}

confirm_action() {
    local prompt="$1"
    local response
    
    read -p "${YELLOW}${prompt}${NC} (y/n): " response
    [[ "$response" =~ ^[Yy]$ ]]
}

################################################################################
# Installation Functions
################################################################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Script ini harus dijalankan dengan sudo/root"
        exit 1
    fi
}

check_ubuntu() {
    if ! grep -q "Ubuntu 22.04" /etc/os-release; then
        print_warning "Script ini dirancang untuk Ubuntu 22.04 LTS"
        if ! confirm_action "Lanjutkan dengan OS lain?"; then
            exit 1
        fi
    fi
}

configure_system() {
    print_banner
    echo -e "${MAGENTA}STEP 1: Konfigurasi Sistem${NC}"
    echo ""
    
    # Web Server selection
    print_info "Pilih web server:"
    echo "  1) Apache2 (default, lebih mudah setup)"
    echo "  2) Nginx (lebih ringan, untuk production)"
    read -p "Pilihan [1]: " ws_choice
    ws_choice=${ws_choice:-1}
    
    if [ "$ws_choice" = "2" ]; then
        WEB_SERVER="nginx"
        print_success "Web server: Nginx"
    else
        WEB_SERVER="apache"
        print_success "Web server: Apache2"
    fi
    
    echo ""
    
    # PHP Version
    print_info "Versi PHP:"
    PHP_VERSION=$(read_input "PHP Version" "8.3")
    print_success "PHP Version: $PHP_VERSION"
    
    echo ""
}

configure_database() {
    print_banner
    echo -e "${MAGENTA}STEP 2: Konfigurasi Database${NC}"
    echo ""
    
    print_info "Atur database connection (biarkan kosong untuk default):"
    echo ""
    
    # Database name
    DB_NAME=$(read_input "Database name" "$DEFAULT_DB_NAME")
    print_success "Database name: $DB_NAME"
    
    # Database user
    DB_USER=$(read_input "Database user" "$DEFAULT_DB_USER")
    print_success "Database user: $DB_USER"
    
    # Database password
    echo ""
    while true; do
        DB_PASSWORD=$(read_password "Database password (min 8 char)")
        DB_PASSWORD_CONFIRM=$(read_password "Confirm password")
        
        if [ "$DB_PASSWORD" = "$DB_PASSWORD_CONFIRM" ]; then
            print_success "Password set"
            break
        else
            print_error "Password tidak cocok!"
        fi
    done
    
    echo ""
}

configure_domain() {
    print_banner
    echo -e "${MAGENTA}STEP 3: Konfigurasi Domain/Hostname${NC}"
    echo ""
    
    print_info "Masukkan domain atau IP address untuk akses dashboard:"
    echo "  (contoh: gacs.local, dashboard.example.com, 192.168.1.100)"
    echo ""
    
    DOMAIN=$(read_input "Domain/Hostname" "$DEFAULT_DOMAIN")
    print_success "Domain: $DOMAIN"
    
    echo ""
    
    # HTTPS setup
    print_info "Setup HTTPS dengan Let's Encrypt?"
    if confirm_action "Setup HTTPS?"; then
        USE_HTTPS="yes"
        
        # Email for Let's Encrypt
        LETSENCRYPT_EMAIL=$(read_input "Email untuk Let's Encrypt" "")
        
        if [ -z "$LETSENCRYPT_EMAIL" ]; then
            print_warning "Email diperlukan untuk Let's Encrypt. HTTPS akan dilewat."
            USE_HTTPS="no"
        else
            print_success "HTTPS: Enabled (Let's Encrypt)"
            print_success "Email: $LETSENCRYPT_EMAIL"
        fi
    else
        print_warning "HTTPS: Disabled (HTTP saja)"
    fi
    
    echo ""
}

configure_paths() {
    print_banner
    echo -e "${MAGENTA}STEP 4: Konfigurasi Path Instalasi${NC}"
    echo ""
    
    APP_PATH=$(read_input "Installation path" "$DEFAULT_APP_PATH")
    print_success "Installation path: $APP_PATH"
    
    echo ""
    
    # Backup configuration
    print_info "Setup automated backup?"
    if confirm_action "Setup backup?"; then
        BACKUP_ENABLED="yes"
        BACKUP_PATH=$(read_input "Backup path" "/var/backups/gacs-dashboard")
        print_success "Backup: Enabled"
        print_success "Backup path: $BACKUP_PATH"
    else
        print_warning "Backup: Disabled"
    fi
    
    echo ""
}

review_configuration() {
    print_banner
    echo -e "${MAGENTA}STEP 5: Review Konfigurasi${NC}"
    echo ""
    
    echo -e "${BLUE}=== Konfigurasi Sistem ===${NC}"
    echo "  Web Server: $WEB_SERVER"
    echo "  PHP Version: $PHP_VERSION"
    echo ""
    
    echo -e "${BLUE}=== Database ===${NC}"
    echo "  Name: $DB_NAME"
    echo "  User: $DB_USER"
    echo "  Password: ****** ($(echo -n $DB_PASSWORD | wc -c) chars)"
    echo ""
    
    echo -e "${BLUE}=== Domain ===${NC}"
    echo "  Hostname: $DOMAIN"
    echo "  HTTPS: $USE_HTTPS"
    if [ "$USE_HTTPS" = "yes" ]; then
        echo "  Email: $LETSENCRYPT_EMAIL"
    fi
    echo ""
    
    echo -e "${BLUE}=== Path ===${NC}"
    echo "  Installation: $APP_PATH"
    echo "  Backup: $BACKUP_ENABLED"
    if [ "$BACKUP_ENABLED" = "yes" ]; then
        echo "  Backup Path: $BACKUP_PATH"
    fi
    echo ""
    
    if ! confirm_action "Konfigurasi sudah benar?"; then
        print_error "Installation dibatalkan."
        exit 1
    fi
    
    echo ""
}

generate_env_file() {
    print_step "Generate .env configuration..."
    
    cat > "$APP_PATH/.env" << EOF
# GACS Dashboard - Auto Generated Configuration
# Generated: $(date)

# Application
APP_URL=http${USE_HTTPS:+s}://${DOMAIN}
APP_ENV=production
APP_DEBUG=false

# Database Configuration
DB_HOST=localhost
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}

# Application Settings
APP_TIMEZONE=Asia/Jakarta
SESSION_NAME=GACS_SESSION
SESSION_LIFETIME=3600
SESSION_SECURE=$([ "$USE_HTTPS" = "yes" ] && echo "true" || echo "false")
SESSION_HTTP_ONLY=true

# Default Admin Credentials (CHANGE AFTER FIRST LOGIN!)
DEFAULT_USERNAME=user1234
DEFAULT_PASSWORD=mostech

# GenieACS Configuration
GENIEACS_HOST=acs.yourdomain.com
GENIEACS_PORT=7557
GENIEACS_USER=admin
GENIEACS_PASS=

# MikroTik Configuration
MIKROTIK_HOST=
MIKROTIK_PORT=8728
MIKROTIK_USER=
MIKROTIK_PASS=

# Telegram Bot Configuration
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=
TELEGRAM_WEBHOOK_URL=http${USE_HTTPS:+s}://${DOMAIN}/webhook/telegram.php

# Security
CSRF_TOKEN_LENGTH=32
PASSWORD_MIN_LENGTH=8

# Backup Settings
BACKUP_ENABLED=${BACKUP_ENABLED}
BACKUP_PATH=${BACKUP_PATH}
BACKUP_RETENTION_DAYS=30
EOF
    
    chmod 600 "$APP_PATH/.env"
    print_success ".env file created"
}

save_configuration() {
    print_step "Save configuration to file..."
    
    cat > "$APP_PATH/.install-config" << EOF
# GACS Dashboard Installation Configuration
# Generated: $(date)
# DO NOT EDIT MANUALLY

DB_NAME="${DB_NAME}"
DB_USER="${DB_USER}"
DB_PASSWORD="${DB_PASSWORD}"
DOMAIN="${DOMAIN}"
APP_PATH="${APP_PATH}"
WEB_SERVER="${WEB_SERVER}"
PHP_VERSION="${PHP_VERSION}"
USE_HTTPS="${USE_HTTPS}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL}"
BACKUP_ENABLED="${BACKUP_ENABLED}"
BACKUP_PATH="${BACKUP_PATH}"
EOF
    
    chmod 600 "$APP_PATH/.install-config"
    print_success "Configuration saved"
}

################################################################################
# Main Execution
################################################################################

main() {
    # Pre-flight checks
    print_banner
    echo -e "${BLUE}Menjalankan pre-flight checks...${NC}"
    echo ""
    
    check_root
    check_ubuntu
    
    print_success "Root access verified"
    print_success "Ubuntu 22.04 detected"
    echo ""
    
    # Interactive configuration
    configure_system
    configure_database
    configure_domain
    configure_paths
    review_configuration
    
    # Generate files
    mkdir -p "$APP_PATH"
    generate_env_file
    save_configuration
    
    # Show next steps
    print_banner
    echo -e "${GREEN}✓ Konfigurasi Interaktif Selesai!${NC}"
    echo ""
    
    echo -e "${BLUE}Konfigurasi Anda:${NC}"
    cat "$APP_PATH/.env"
    echo ""
    
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Run automated installation:"
    echo -e "     ${GREEN}sudo bash install.sh${NC}"
    echo ""
    echo "  2. Atau jalankan manual installation sesuai INSTALL_UBUNTU_22.04.md"
    echo ""
    echo -e "${BLUE}File konfigurasi tersimpan di:${NC}"
    echo -e "  ${GREEN}$APP_PATH/.env${NC}"
    echo -e "  ${GREEN}$APP_PATH/.install-config${NC}"
    echo ""
}

main "$@"
