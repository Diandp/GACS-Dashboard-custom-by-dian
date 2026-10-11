#!/bin/bash

################################################################################
# GACS Dashboard - Production Deployment Validator
# Purpose: Verify all components are correctly installed and configured
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
WARNED=0
FAILED=0

print_banner() {
    clear
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║     GACS Dashboard - Production Deployment Validator            ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_pass() {
    echo -e "${GREEN}[✓]${NC} $1"
    PASSED=$((PASSED + 1))
}

check_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
    WARNED=$((WARNED + 1))
}

check_fail() {
    echo -e "${RED}[✗]${NC} $1"
    FAILED=$((FAILED + 1))
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        check_pass "Running as root"
    else
        check_warn "Not running as root (use sudo for full validation)"
    fi
}

check_ubuntu() {
    if grep -q "Ubuntu 22.04" /etc/os-release; then
        check_pass "Ubuntu 22.04 LTS detected"
    else
        check_warn "Not Ubuntu 22.04 LTS"
    fi
}

check_php() {
    if command -v php &> /dev/null; then
        local version=$(php -v | head -1)
        check_pass "PHP installed: $version"
    else
        check_fail "PHP not found"
    fi
}

check_mysql() {
    if command -v mysql &> /dev/null; then
        check_pass "MySQL client installed"
    else
        check_fail "MySQL client not found"
    fi
    
    if systemctl is-active --quiet mysql; then
        check_pass "MySQL is running"
    elif systemctl is-active --quiet mariadb; then
        check_pass "MariaDB is running"
    else
        check_fail "MySQL/MariaDB not running"
    fi
}

check_apache() {
    if command -v apache2 &> /dev/null; then
        check_pass "Apache2 installed"
        
        if systemctl is-active --quiet apache2; then
            check_pass "Apache2 is running"
        else
            check_fail "Apache2 not running"
        fi
        
        if apache2ctl -M 2>/dev/null | grep -q rewrite; then
            check_pass "Apache rewrite module enabled"
        else
            check_warn "Apache rewrite module not enabled"
        fi
    else
        check_warn "Apache2 not installed"
    fi
}

check_nginx() {
    if command -v nginx &> /dev/null; then
        check_pass "Nginx installed"
        
        if systemctl is-active --quiet nginx; then
            check_pass "Nginx is running"
        else
            check_fail "Nginx not running"
        fi
    else
        check_warn "Nginx not installed"
    fi
}

check_application() {
    local app_path="/var/www/html/gacs-dashboard"
    
    if [ -d "$app_path" ]; then
        check_pass "Application directory found"
    else
        check_fail "Application directory not found: $app_path"
        return 1
    fi
    
    if [ -f "${app_path}/dashboard.php" ]; then
        check_pass "Application files present"
    else
        check_fail "Application files missing"
    fi
    
    if [ -f "${app_path}/config/database.php" ]; then
        check_pass "Database config present"
    else
        check_fail "Database config missing"
    fi
    
    if [ -f "${app_path}/database.sql" ]; then
        check_pass "Database schema present"
    else
        check_warn "Database schema not found"
    fi
}

check_permissions() {
    local app_path="/var/www/html/gacs-dashboard"
    
    if [ ! -d "$app_path" ]; then
        return
    fi
    
    # Check ownership
    local owner=$(stat -c "%U" "$app_path" 2>/dev/null || echo "unknown")
    if [ "$owner" = "www-data" ]; then
        check_pass "Application owned by www-data"
    else
        check_warn "Application not owned by www-data (current: $owner)"
    fi
    
    # Check config permissions
    local config_perms=$(stat -c "%a" "${app_path}/config/database.php" 2>/dev/null || echo "unknown")
    if [ "$config_perms" = "600" ]; then
        check_pass "Config file permissions correct (600)"
    else
        check_warn "Config file permissions not optimal (current: $config_perms)"
    fi
}

check_database() {
    if ! command -v mysql &> /dev/null; then
        check_fail "MySQL client not available"
        return
    fi
    
    # Try default credentials
    if mysql -u root -e "SELECT 1" 2>/dev/null | grep -q 1; then
        check_pass "MySQL root access verified"
    elif mysql -u gacs_dev -p -e "SELECT 1" 2>/dev/null | grep -q 1; then
        check_pass "MySQL gacs_dev user access verified"
    else
        check_warn "Cannot verify MySQL connection (may require password)"
    fi
}

check_cron() {
    if command -v crontab &> /dev/null; then
        local cron_count=$(sudo crontab -u www-data -l 2>/dev/null | grep -c "GACS" || echo 0)
        
        if [ $cron_count -gt 0 ]; then
            check_pass "Cron jobs configured ($cron_count tasks)"
        else
            check_warn "No GACS cron jobs found"
        fi
    else
        check_fail "Cron not available"
    fi
}

check_ssl() {
    if command -v certbot &> /dev/null; then
        check_pass "Certbot installed"
        
        local cert_count=$(sudo certbot certificates 2>/dev/null | grep -c "Certificate" || echo 0)
        if [ $cert_count -gt 0 ]; then
            check_pass "SSL certificates found ($cert_count)"
        else
            check_warn "No SSL certificates configured"
        fi
    else
        check_warn "Certbot not installed"
    fi
}

check_firewall() {
    if command -v ufw &> /dev/null; then
        if sudo ufw status | grep -q "Status: active"; then
            check_pass "UFW firewall enabled"
            
            if sudo ufw status | grep -q "80"; then
                check_pass "HTTP port (80) allowed"
            else
                check_warn "HTTP port (80) not in UFW rules"
            fi
            
            if sudo ufw status | grep -q "443"; then
                check_pass "HTTPS port (443) allowed"
            else
                check_warn "HTTPS port (443) not in UFW rules"
            fi
        else
            check_warn "UFW firewall disabled"
        fi
    else
        check_warn "UFW not available"
    fi
}

check_disk_space() {
    local disk_usage=$(df / | tail -1 | awk '{print int($5)}')
    
    if [ $disk_usage -lt 80 ]; then
        check_pass "Disk space OK (${disk_usage}% used)"
    elif [ $disk_usage -lt 90 ]; then
        check_warn "Disk space moderate (${disk_usage}% used)"
    else
        check_fail "Disk space critical (${disk_usage}% used)"
    fi
}

check_memory() {
    local mem_available=$(free | grep Mem | awk '{print int($7/$2 * 100)}')
    
    if [ $mem_available -gt 50 ]; then
        check_pass "Memory available (${mem_available}% free)"
    elif [ $mem_available -gt 20 ]; then
        check_warn "Memory moderate (${mem_available}% free)"
    else
        check_warn "Memory low (${mem_available}% free)"
    fi
}

check_logs() {
    local app_path="/var/www/html/gacs-dashboard"
    
    if [ -d "${app_path}/logs" ]; then
        check_pass "Application logs directory exists"
        
        local log_count=$(find "${app_path}/logs" -type f 2>/dev/null | wc -l)
        if [ $log_count -gt 0 ]; then
            check_pass "Log files present ($log_count files)"
        else
            check_warn "No log files found"
        fi
    else
        check_warn "Logs directory not found"
    fi
}

check_backups() {
    local backup_path="/var/backups/gacs-dashboard"
    
    if [ -d "$backup_path" ]; then
        check_pass "Backup directory exists"
        
        local backup_count=$(find "$backup_path" -type f -mtime -7 2>/dev/null | wc -l)
        if [ $backup_count -gt 0 ]; then
            check_pass "Recent backups found ($backup_count in last 7 days)"
        else
            check_warn "No recent backups found"
        fi
    else
        check_warn "Backup directory not found"
    fi
}

generate_report() {
    print_banner
    echo ""
    echo -e "${BLUE}=== VALIDATION RESULTS ===${NC}"
    echo ""
    echo -e "${GREEN}Passed:${NC}  $PASSED"
    echo -e "${YELLOW}Warned:${NC}  $WARNED"
    echo -e "${RED}Failed:${NC}  $FAILED"
    echo ""
    
    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ Deployment validation successful!${NC}"
        if [ $WARNED -gt 0 ]; then
            echo -e "${YELLOW}Note: $WARNED warnings found. Please review above.${NC}"
        fi
    else
        echo -e "${RED}✗ Deployment validation failed!${NC}"
        echo -e "${RED}Please fix the $FAILED error(s) above.${NC}"
    fi
    echo ""
}

main() {
    print_banner
    echo ""
    
    echo -e "${BLUE}=== SYSTEM CHECKS ===${NC}"
    check_root
    check_ubuntu
    echo ""
    
    echo -e "${BLUE}=== LANGUAGE & RUNTIME ===${NC}"
    check_php
    check_mysql
    echo ""
    
    echo -e "${BLUE}=== WEB SERVER ===${NC}"
    check_apache
    check_nginx
    echo ""
    
    echo -e "${BLUE}=== APPLICATION ===${NC}"
    check_application
    check_permissions
    check_logs
    echo ""
    
    echo -e "${BLUE}=== DATABASE ===${NC}"
    check_database
    check_backups
    echo ""
    
    echo -e "${BLUE}=== AUTOMATION ===${NC}"
    check_cron
    echo ""
    
    echo -e "${BLUE}=== SECURITY ===${NC}"
    check_ssl
    check_firewall
    echo ""
    
    echo -e "${BLUE}=== RESOURCES ===${NC}"
    check_disk_space
    check_memory
    echo ""
    
    generate_report
}

main "$@"
