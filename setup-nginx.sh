#!/bin/bash

################################################################################
# GACS Dashboard - Nginx Configuration Setup
# Purpose: Setup Nginx as reverse proxy (alternative to Apache)
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║     GACS Dashboard - Nginx Setup Script                        ║"
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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Script ini harus dijalankan dengan sudo/root"
        exit 1
    fi
}

install_nginx() {
    print_step "Menginstall Nginx..."
    apt-get update > /dev/null 2>&1
    apt-get install -y nginx > /dev/null 2>&1
    systemctl enable nginx > /dev/null 2>&1
    systemctl start nginx > /dev/null 2>&1
    print_success "Nginx installed"
}

setup_nginx_config() {
    print_step "Mengkonfigurasi Nginx..."
    
    cat > /etc/nginx/sites-available/gacs-dashboard << 'EOF'
upstream php_backend {
    server unix:/run/php/php8.3-fpm.sock;
}

server {
    listen 80;
    server_name gacs.local;
    
    root /var/www/html/gacs-dashboard;
    index index.php;
    
    # Logs
    access_log /var/log/nginx/gacs-dashboard_access.log;
    error_log /var/log/nginx/gacs-dashboard_error.log;
    
    # Security headers
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1000;
    gzip_types text/plain text/css text/xml text/javascript 
               application/x-javascript application/xml+rss 
               application/json application/javascript;
    
    # Client upload size
    client_max_body_size 100M;
    
    # Deny access to sensitive files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    location ~ ~\\.php$ {
        deny all;
    }
    
    # PHP-FPM
    location ~ \\.php$ {
        fastcgi_pass php_backend;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        include fastcgi_params;
        
        # Timeouts for long-running requests
        fastcgi_read_timeout 300s;
        fastcgi_connect_timeout 75s;
    }
    
    # URL rewriting for API
    location /api/ {
        if (!-f $request_filename) {
            rewrite ^/api/(.*)$ /api/$1 last;
        }
    }
    
    # Static files cache
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    # Default location
    location / {
        try_files $uri $uri/ =404;
    }
}
EOF
    
    # Enable site
    ln -sf /etc/nginx/sites-available/gacs-dashboard /etc/nginx/sites-enabled/gacs-dashboard
    rm -f /etc/nginx/sites-enabled/default
    
    # Test configuration
    if nginx -t 2>&1 | grep -q "successful"; then
        systemctl reload nginx > /dev/null 2>&1
        print_success "Nginx configured and reloaded"
    else
        print_error "Nginx configuration error!"
        nginx -t
        exit 1
    fi
}

main() {
    print_header
    check_root
    install_nginx
    setup_nginx_config
    
    echo ""
    echo -e "${GREEN}✓ Nginx setup complete!${NC}"
    echo ""
    echo -e "${BLUE}Nginx status:${NC}"
    systemctl status nginx --no-pager
}

main "$@"
