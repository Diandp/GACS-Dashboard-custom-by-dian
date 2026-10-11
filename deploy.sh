#!/bin/bash

################################################################################
# GACS Dashboard - Production Deployment Package
# Purpose: Complete ready-to-deploy package for production servers
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

################################################################################
# Functions
################################################################################

print_banner() {
    clear
    echo -e "${MAGENTA}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  GACS Dashboard - Production Deployment Package v1.0           ║"
    echo "║  Ready-to-Deploy for Ubuntu 22.04 LTS                         ║"
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

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Script ini harus dijalankan dengan sudo/root"
        exit 1
    fi
}

show_menu() {
    echo ""
    echo -e "${MAGENTA}Pilih deployment option:${NC}"
    echo ""
    echo "  1) ${GREEN}Complete Production Setup${NC}"
    echo "     - Apache2 + MySQL + PHP"
    echo "     - Database setup"
    echo "     - SSL (optional)"
    echo "     - Cron jobs"
    echo ""
    echo "  2) ${GREEN}Production with Nginx${NC}"
    echo "     - Nginx + PHP-FPM"
    echo "     - MySQL database"
    echo "     - Let's Encrypt SSL"
    echo "     - Auto renewal"
    echo ""
    echo "  3) ${GREEN}Custom Installation${NC}"
    echo "     - Interactive setup"
    echo "     - Choose components"
    echo "     - Custom paths & config"
    echo ""
    echo "  4) ${GREEN}View Documentation${NC}"
    echo "     - Installation guide"
    echo "     - Configuration options"
    echo "     - Troubleshooting"
    echo ""
    echo "  5) ${RED}Exit${NC}"
    echo ""
    read -p "Select option [1-5]: " choice
}

install_production() {
    print_banner
    echo -e "${MAGENTA}PRODUCTION SETUP WITH APACHE${NC}"
    echo ""
    
    bash "${SCRIPT_DIR}/install.sh"
}

install_nginx_production() {
    print_banner
    echo -e "${MAGENTA}PRODUCTION SETUP WITH NGINX${NC}"
    echo ""
    
    bash "${SCRIPT_DIR}/install-nginx-ssl.sh"
}

install_custom() {
    print_banner
    echo -e "${MAGENTA}CUSTOM INSTALLATION${NC}"
    echo ""
    
    bash "${SCRIPT_DIR}/install-interactive.sh"
}

view_documentation() {
    print_banner
    echo -e "${BLUE}=== INSTALLATION GUIDE ===${NC}"
    echo ""
    
    if [ -f "${SCRIPT_DIR}/INSTALL_UBUNTU_22.04.md" ]; then
        less "${SCRIPT_DIR}/INSTALL_UBUNTU_22.04.md"
    else
        print_error "Documentation file not found"
    fi
}

post_deployment_checklist() {
    print_banner
    echo -e "${MAGENTA}POST-DEPLOYMENT CHECKLIST${NC}"
    echo ""
    
    cat << 'EOF'
☐ INITIAL SETUP
  ☐ Access dashboard at configured domain
  ☐ Complete init.php wizard
  ☐ Verify database connection
  ☐ Delete init.php file after setup
  ☐ Change default admin password

☐ SECURITY CONFIGURATION
  ☐ Configure GenieACS credentials
  ☐ Configure MikroTik credentials
  ☐ Setup Telegram bot (optional)
  ☐ Enable HTTPS (recommended)
  ☐ Configure firewall rules
  ☐ Set file permissions properly

☐ MONITORING & BACKUP
  ☐ Setup automated backups
  ☐ Verify cron jobs running
  ☐ Test database backup
  ☐ Setup email notifications
  ☐ Configure log rotation

☐ PERFORMANCE & OPTIMIZATION
  ☐ Enable PHP caching (OpCache)
  ☐ Configure MySQL optimization
  ☐ Setup web server caching
  ☐ Enable gzip compression
  ☐ Configure rate limiting

☐ PRODUCTION HARDENING
  ☐ Disable debug mode
  ☐ Setup error logging
  ☐ Configure access logs
  ☐ Setup monitoring alerts
  ☐ Document system configuration
  ☐ Create backup restoration plan

EOF
    
    echo ""
    read -p "Press Enter to continue..."
}

show_quick_commands() {
    print_banner
    echo -e "${MAGENTA}QUICK COMMAND REFERENCE${NC}"
    echo ""
    
    cat << 'EOF'
🔍 MONITORING & LOGS
  tail -f /var/log/apache2/gacs-dashboard_error.log       # Apache errors
  tail -f /var/log/nginx/gacs-dashboard_error.log        # Nginx errors
  tail -f /var/www/html/gacs-dashboard/logs/*.log        # App logs
  systemctl status apache2                               # Check Apache
  systemctl status nginx                                 # Check Nginx
  systemctl status mysql                                 # Check MySQL

📄 DATABASE MANAGEMENT
  mysql -u gacs_dev -p gacs_dev                          # Connect to DB
  mysqldump -u gacs_dev -p gacs_dev > backup.sql         # Manual backup
  mysql -u gacs_dev -p gacs_dev < backup.sql             # Restore backup

🗑️ BACKUP & MAINTENANCE
  sudo bash /var/www/html/gacs-dashboard/backup.sh       # Manual backup
  sudo crontab -u www-data -l                            # View cron jobs
  sudo crontab -u www-data -e                            # Edit cron jobs

🔐 SECURITY & PERMISSIONS
  sudo chown -R www-data:www-data /var/www/html/gacs-dashboard
  sudo chmod 600 /var/www/html/gacs-dashboard/config/*.php
  sudo chmod 755 /var/www/html/gacs-dashboard/logs

🔄 RESTART SERVICES
  sudo systemctl restart apache2                         # Restart Apache
  sudo systemctl restart nginx                           # Restart Nginx
  sudo systemctl restart mysql                           # Restart MySQL
  sudo systemctl restart php8.3-fpm                      # Restart PHP-FPM

📋 USEFUL PATHS
  Application:  /var/www/html/gacs-dashboard
  Config:       /var/www/html/gacs-dashboard/config
  Logs:         /var/www/html/gacs-dashboard/logs
  Backups:      /var/backups/gacs-dashboard
  Apache:       /etc/apache2/sites-available
  Nginx:        /etc/nginx/sites-available

EOF
    
    echo ""
    read -p "Press Enter to continue..."
}

show_system_info() {
    print_banner
    echo -e "${MAGENTA}SYSTEM INFORMATION${NC}"
    echo ""
    
    echo -e "${BLUE}OS:${NC}"
    lsb_release -d | cut -f2
    echo ""
    
    echo -e "${BLUE}PHP:${NC}"
    php -v | head -1
    echo ""
    
    echo -e "${BLUE}MySQL:${NC}"
    mysql --version
    echo ""
    
    echo -e "${BLUE}Apache:${NC}"
    apache2 -v 2>/dev/null | head -1 || echo "Not installed"
    echo ""
    
    echo -e "${BLUE}Nginx:${NC}"
    nginx -v 2>&1 || echo "Not installed"
    echo ""
    
    echo -e "${BLUE}Disk Space:${NC}"
    df -h / | tail -1
    echo ""
    
    echo -e "${BLUE}RAM:${NC}"
    free -h | head -2
    echo ""
    
    read -p "Press Enter to continue..."
}

show_deployment_info() {
    print_banner
    echo -e "${MAGENTA}DEPLOYMENT INFORMATION${NC}"
    echo ""
    
    cat << 'EOF'
📁 INCLUDED FILES
  install.sh                    - Main installation script (Apache)
  install-interactive.sh        - Interactive setup wizard
  install-nginx-ssl.sh          - Nginx + SSL production setup
  quick-install.sh              - Quick guided installation
  setup-nginx.sh                - Nginx basic configuration
  backup.sh                     - Automated backup script
  setup-cron.sh                 - Cron job configuration
  deploy.sh                     - This deployment orchestrator
  INSTALL_UBUNTU_22.04.md       - Complete installation guide
  .env.production               - Production environment template
🗐️ DEPLOYMENT SCENARIOS

1. SMALL/MEDIUM (Single Server)
   - Use: install.sh (Apache) or install-nginx-ssl.sh (Nginx)
   - Database: Local MySQL
   - Backup: Daily automated
   - Estimated: 15-30 minutes

2. ENTERPRISE (High Availability)
   - Use: install-interactive.sh with custom settings
   - Database: Remote MySQL with replication
   - Backup: Multiple redundant backups
   - Load balancer required
   - Estimated: 1-2 hours setup

3. DEVELOPMENT/TESTING
   - Use: quick-install.sh with default settings
   - Database: Local SQLite or MySQL
   - Backup: Manual only
   - SSL: Optional
   - Estimated: 5-10 minutes

🔬 PRE-DEPLOYMENT REQUIREMENTS
  ✓ Ubuntu 22.04 LTS server
  ✓ Sudo/root access
  ✓ Internet connection for package downloads
  ✓ Domain name (for HTTPS setup)
  ✓ Email address (for Let's Encrypt)
  ✓ Minimum: 2GB RAM, 20GB disk space
  ✓ Recommended: 4GB RAM, 50GB disk space

EOF
    
    echo ""
    read -p "Press Enter to continue..."
}

################################################################################
# Main
################################################################################

main() {
    while true; do
        show_menu
        
        case $choice in
            1)
                check_root
                install_production
                post_deployment_checklist
                ;;
            2)
                check_root
                install_nginx_production
                post_deployment_checklist
                ;;
            3)
                check_root
                install_custom
                post_deployment_checklist
                ;;
            4)
                view_documentation
                ;;
            5)
                echo ""
                echo "Thank you for using GACS Dashboard!"
                echo ""
                exit 0
                ;;
            *)
                print_error "Invalid option. Please try again."
                ;;
        esac
    done
}

# Show main menu
print_banner
echo -e "${BLUE}Welcome to GACS Dashboard Production Deployment${NC}"
echo ""
echo -e "${BLUE}Available commands:${NC}"
echo ""
echo "  ${GREEN}./deploy.sh${NC}                    - Start deployment menu (interactive)"
echo "  ${GREEN}sudo bash install.sh${NC}           - Direct Apache installation"
echo "  ${GREEN}sudo bash install-nginx-ssl.sh${NC} - Direct Nginx + SSL installation"
echo "  ${GREEN}sudo bash install-interactive.sh${NC} - Custom interactive setup"
echo ""
echo -e "${YELLOW}For production deployment, run: sudo bash deploy.sh${NC}"
echo ""

if [ "$1" = "--auto" ]; then
    check_root
    install_production
    post_deployment_checklist
elif [ "$1" = "--nginx" ]; then
    check_root
    install_nginx_production
    post_deployment_checklist
elif [ "$1" = "--custom" ]; then
    check_root
    install_custom
    post_deployment_checklist
elif [ "$1" = "--docs" ]; then
    view_documentation
elif [ "$1" = "--checklist" ]; then
    post_deployment_checklist
elif [ "$1" = "--help" ]; then
    cat << 'EOF'
GACS Dashboard - Deployment Script

Usage: sudo bash deploy.sh [OPTION]

Options:
  --auto                Production setup with Apache (default)
  --nginx               Production setup with Nginx + SSL
  --custom              Interactive custom installation
  --docs                Show installation documentation
  --checklist           Show post-deployment checklist
  --info                Show system information
  --help                Show this help message

Examples:
  sudo bash deploy.sh --auto
  sudo bash deploy.sh --nginx
  sudo bash deploy.sh --docs

EOF
elif [ "$1" = "--info" ]; then
    check_root
    show_system_info
else
    # Interactive mode
    main
fi
