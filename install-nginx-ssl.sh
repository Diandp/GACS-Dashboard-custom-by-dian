#!/bin/bash

################################################################################
# GACS Dashboard - Nginx + SSL Production Setup
# Purpose: Complete production-ready Nginx setup with Let's Encrypt
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
    echo "║     GACS Dashboard - Nginx + SSL Production Setup              ║"
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

install_nginx() {
    print_step "Menginstall Nginx..."
    apt-get update > /dev/null 2>&1
    apt-get install -y nginx certbot python3-certbot-nginx > /dev/null 2>&1
    systemctl enable nginx > /dev/null 2>&1
    systemctl start nginx > /dev/null 2>&1
    print_success "Nginx installed"
}

setup_nginx_config() {
    local domain="$1"
    local app_path="$2"
    
    print_step "Configuring Nginx for $domain..."
    
    cat > /etc/nginx/sites-available/gacs-dashboard << EOF
upstream php_backend {
    server unix:/run/php/php8.3-fpm.sock;
}

# Rate limiting zone
limit_req_zone \$binary_remote_addr zone=api_limit:10m rate=100r/m;
limit_req_zone \$binary_remote_addr zone=general_limit:10m rate=1000r/m;

# HTTP redirect to HTTPS (will be configured by certbot)
server {
    listen 80;
    listen [::]:80;
    server_name ${domain};
    return 301 https://\$server_name\$request_uri;
}

# HTTPS Server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${domain};
    
    root ${app_path};
    index index.php index.html;
    
    # SSL certificates (will be auto-configured by certbot)
    ssl_certificate /etc/letsencrypt/live/${domain}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${domain}/privkey.pem;
    
    # SSL Configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_stapling on;
    ssl_stapling_verify on;
    
    # Logs
    access_log /var/log/nginx/gacs-dashboard_access.log combined buffer=32k flush=5s;
    error_log /var/log/nginx/gacs-dashboard_error.log warn;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1000;
    gzip_types text/plain text/css text/xml text/javascript 
               application/x-javascript application/xml+rss 
               application/json application/javascript;
    
    # Client upload size
    client_max_body_size 100M;
    
    # Timeouts
    client_body_timeout 12;
    client_header_timeout 12;
    keepalive_timeout 15;
    send_timeout 10;
    
    # Deny access to sensitive files
    location ~ /\\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    location ~ ~\\\.php\$ {
        deny all;
    }
    
    # PHP-FPM handling
    location ~ \\\.php\$ {
        limit_req zone=general_limit burst=20 nodelay;
        
        fastcgi_pass php_backend;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        include fastcgi_params;
        
        # Timeouts
        fastcgi_read_timeout 300s;
        fastcgi_connect_timeout 75s;
        fastcgi_send_timeout 75s;
        
        # Buffer settings
        fastcgi_buffer_size 32k;
        fastcgi_buffers 8 32k;
        fastcgi_busy_buffers_size 64k;
    }
    
    # API rate limiting
    location /api/ {
        limit_req zone=api_limit burst=50 nodelay;
        
        if (!-f \$request_filename) {
            rewrite ^/api/(.*)\$ /api/\$1 last;
        }
    }
    
    # Static files cache
    location ~* \\.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)\$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
        log_not_found off;
    }
    
    # Default location
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
    
    # Enable site
    ln -sf /etc/nginx/sites-available/gacs-dashboard /etc/nginx/sites-enabled/gacs-dashboard
    rm -f /etc/nginx/sites-enabled/default
    
    # Test configuration
    if nginx -t 2>&1 | grep -q "successful"; then
        systemctl reload nginx > /dev/null 2>&1
        print_success "Nginx configured"
    else
        print_error "Nginx configuration error!"
        nginx -t
        exit 1
    fi
}

setup_ssl() {
    local domain="$1"
    local email="$2"
    
    print_step "Setting up SSL certificate with Let's Encrypt..."
    
    # Request certificate
    certbot certonly --nginx \
        -d "$domain" \
        --email "$email" \
        --agree-tos \
        --non-interactive \
        --rsa-key-size 4096 > /dev/null 2>&1
    
    if [ -f "/etc/letsencrypt/live/${domain}/fullchain.pem" ]; then
        print_success "SSL certificate installed"
        
        # Setup auto-renewal
        systemctl enable certbot.timer > /dev/null 2>&1
        systemctl start certbot.timer > /dev/null 2>&1
        print_success "SSL auto-renewal enabled (via certbot timer)"
    else
        print_error "Failed to obtain SSL certificate"
        return 1
    fi
}

setup_php_fpm() {
    print_step "Setting up PHP-FPM..."
    
    # Create php-fpm pool config
    cat > /etc/php/8.3/fpm/pool.d/gacs-dashboard.conf << 'EOF'
[gacs-dashboard]
user = www-data
group = www-data
listen = /run/php/php8.3-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

pm = dynamic
pm.max_children = 50
pm.start_servers = 10
pm.min_spare_servers = 5
pm.max_spare_servers = 20
pm.process_idle_timeout = 10s
pm.max_requests = 1000

; Logs
slowlog = /var/log/php8.3-fpm-slow.log
request_slowlog_timeout = 5s
request_terminate_timeout = 300s

; PHP settings
php_flag[display_errors] = off
php_value[memory_limit] = 512M
php_value[max_execution_time] = 300
php_value[upload_max_filesize] = 100M
php_value[post_max_size] = 100M
php_value[default_socket_timeout] = 60
EOF
    
    systemctl restart php8.3-fpm > /dev/null 2>&1
    print_success "PHP-FPM configured"
}

setup_firewall() {
    print_step "Setting up UFW firewall rules..."
    
    # Enable firewall
    echo "y" | ufw enable > /dev/null 2>&1 || true
    
    # Allow SSH
    ufw allow 22/tcp > /dev/null 2>&1 || true
    
    # Allow HTTP/HTTPS
    ufw allow 80/tcp > /dev/null 2>&1 || true
    ufw allow 443/tcp > /dev/null 2>&1 || true
    
    print_success "Firewall rules configured (SSH, HTTP, HTTPS)"
}

verify_installation() {
    print_step "Verifying installation..."
    
    # Check Nginx
    if systemctl is-active --quiet nginx; then
        print_success "Nginx is running"
    else
        print_error "Nginx is not running"
        return 1
    fi
    
    # Check PHP-FPM
    if systemctl is-active --quiet php8.3-fpm; then
        print_success "PHP-FPM is running"
    else
        print_error "PHP-FPM is not running"
        return 1
    fi
    
    # Check SSL
    if [ -f "/etc/letsencrypt/live/gacs.local/fullchain.pem" ]; then
        print_success "SSL certificate found"
    else
        print_warning "SSL certificate not yet configured"
    fi
}

main() {
    print_header
    
    check_root
    
    # Get configuration
    echo ""
    read -p "Enter domain name [gacs.local]: " domain
    domain=${domain:-gacs.local}
    
    read -p "Enter email for Let's Encrypt: " email
    if [ -z "$email" ]; then
        print_error "Email is required for Let's Encrypt"
        exit 1
    fi
    
    read -p "Enter application path [/var/www/html/gacs-dashboard]: " app_path
    app_path=${app_path:-/var/www/html/gacs-dashboard}
    
    echo ""
    echo -e "${BLUE}Configuration:${NC}"
    echo "  Domain: $domain"
    echo "  Email: $email"
    echo "  App Path: $app_path"
    echo ""
    
    read -p "Proceed with installation? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_error "Installation cancelled"
        exit 1
    fi
    
    echo ""
    
    # Installation
    install_nginx
    setup_nginx_config "$domain" "$app_path"
    setup_php_fpm
    setup_ssl "$domain" "$email"
    setup_firewall
    echo ""
    
    if verify_installation; then
        print_header
        echo -e "${GREEN}✓ Nginx + SSL Setup Complete!${NC}"
        echo ""
        echo -e "${BLUE}Access Dashboard:${NC}"
        echo -e "  ${GREEN}https://${domain}${NC}"
        echo ""
        echo -e "${BLUE}SSL Certificate:${NC}"
        echo -e "  ${GREEN}/etc/letsencrypt/live/${domain}/${NC}"
        echo ""
        echo -e "${BLUE}Auto-renewal:${NC}"
        echo -e "  ${GREEN}systemctl status certbot.timer${NC}"
        echo ""
    else
        print_error "Installation failed. Check errors above."
        exit 1
    fi
}

main "$@"
