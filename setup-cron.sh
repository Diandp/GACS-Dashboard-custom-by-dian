#!/bin/bash

################################################################################
# GACS Dashboard - Cron Job Setup
# Purpose: Setup automated scheduled tasks
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    clear
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║     GACS Dashboard - Cron Job Setup                            ║"
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

setup_crontab() {
    local app_path="$1"
    local db_name="$2"
    local db_user="$3"
    local db_pass="$4"
    local backup_path="$5"
    
    print_step "Setting up cron jobs for www-data user..."
    
    # Create temporary cron file
    local temp_cron=$(mktemp)
    
    # Add environment variables
    cat > "$temp_cron" << EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
MAILTO=

# GACS Dashboard - Device monitoring every 5 minutes
*/5 * * * * /usr/bin/php ${app_path}/cron/device-monitor.php >> ${app_path}/logs/cron-monitor.log 2>&1

# GACS Dashboard - Backup database daily at 2 AM
0 2 * * * APP_PATH="${app_path}" DB_NAME="${db_name}" DB_USER="${db_user}" DB_PASS="${db_pass}" BACKUP_PATH="${backup_path}" /bin/bash ${app_path}/backup.sh >> ${backup_path}/cron-backup.log 2>&1

# GACS Dashboard - Telegram reports daily at 8 AM
0 8 * * * /usr/bin/php ${app_path}/cron/telegram-reports.php >> ${app_path}/logs/cron-telegram.log 2>&1

# GACS Dashboard - Webhook monitor every minute
* * * * * /usr/bin/php ${app_path}/cron/webhook-monitor.php >> ${app_path}/logs/cron-webhook.log 2>&1

# GACS Dashboard - Cleanup old logs weekly
0 3 * * 0 /usr/bin/find ${app_path}/logs -type f -mtime +30 -delete >> ${app_path}/logs/cron-cleanup.log 2>&1

EOF
    
    # Install cron file
    crontab -u www-data "$temp_cron" 2>/dev/null || {
        print_error "Failed to install crontab"
        rm -f "$temp_cron"
        return 1
    }
    
    rm -f "$temp_cron"
    print_success "Cron jobs installed for www-data"
    return 0
}

verify_crontab() {
    print_step "Verifying cron installation..."
    
    local cron_count=$(crontab -u www-data -l 2>/dev/null | grep -c "GACS" || true)
    
    echo ""
    echo -e "${BLUE}Installed cron jobs:${NC}"
    crontab -u www-data -l 2>/dev/null | grep -E "^[0-9*]" || true
    echo ""
    
    if [ $cron_count -gt 0 ]; then
        print_success "$cron_count GACS cron jobs installed"
        return 0
    else
        print_warning "No GACS cron jobs found"
        return 1
    fi
}

setup_log_rotation() {
    local app_path="$1"
    
    print_step "Setting up log rotation..."
    
    cat > /etc/logrotate.d/gacs-dashboard << EOF
${app_path}/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data www-data
    sharedscripts
}

/var/log/nginx/gacs-dashboard*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        if [ -f /var/run/nginx.pid ]; then
            kill -USR1 \`cat /var/run/nginx.pid\`
        fi
    endscript
}
EOF
    
    print_success "Log rotation configured"
}

main() {
    print_header
    check_root
    
    echo ""
    read -p "Enter application path [/var/www/html/gacs-dashboard]: " app_path
    app_path=${app_path:-/var/www/html/gacs-dashboard}
    
    read -p "Enter database name [gacs_dev]: " db_name
    db_name=${db_name:-gacs_dev}
    
    read -p "Enter database user [gacs_dev]: " db_user
    db_user=${db_user:-gacs_dev}
    
    read -sp "Enter database password (leave empty if none): " db_pass
    echo ""
    
    read -p "Enter backup path [/var/backups/gacs-dashboard]: " backup_path
    backup_path=${backup_path:-/var/backups/gacs-dashboard}
    
    # Create directories
    mkdir -p "${app_path}/logs" "${backup_path}"
    chown -R www-data:www-data "${app_path}/logs" "${backup_path}"
    chmod 755 "${app_path}/logs" "${backup_path}"
    
    echo ""
    echo -e "${BLUE}Configuration:${NC}"
    echo "  App Path: $app_path"
    echo "  DB Name: $db_name"
    echo "  DB User: $db_user"
    echo "  Backup Path: $backup_path"
    echo ""
    
    read -p "Proceed with cron setup? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_error "Setup cancelled"
        exit 1
    fi
    
    echo ""
    
    # Setup cron
    if setup_crontab "$app_path" "$db_name" "$db_user" "$db_pass" "$backup_path"; then
        setup_log_rotation "$app_path"
        verify_crontab
        
        print_header
        echo -e "${GREEN}✓ Cron Setup Complete!${NC}"
        echo ""
        echo -e "${BLUE}Configured Tasks:${NC}"
        echo "  ✓ Device monitoring - every 5 minutes"
        echo "  ✓ Database backup - daily 2 AM"
        echo "  ✓ Telegram reports - daily 8 AM"
        echo "  ✓ Webhook monitor - every minute"
        echo "  ✓ Log cleanup - weekly Sunday 3 AM"
        echo ""
        echo -e "${BLUE}Log Files:${NC}"
        echo -e "  ${app_path}/logs/cron-monitor.log"
        echo -e "  ${app_path}/logs/cron-telegram.log"
        echo -e "  ${backup_path}/cron-backup.log"
        echo ""
        echo -e "${BLUE}View Current Cron Jobs:${NC}"
        echo -e "  ${GREEN}sudo crontab -u www-data -l${NC}"
        echo ""
    else
        print_error "Cron setup failed"
        exit 1
    fi
}

main "$@"
