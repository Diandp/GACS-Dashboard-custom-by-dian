#!/bin/bash

# GACS Dashboard - Quick Interactive Installer
# For users who want guided step-by-step installation

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     GACS Dashboard - Interactive Quick Installer               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: Script ini harus dijalankan dengan sudo${NC}"
    echo "Usage: sudo bash quick-install.sh"
    exit 1
fi

echo ""
echo -e "${BLUE}Konfigurasi Installation:${NC}"
echo ""

# Ask for configuration
read -p "Domain/Hostname [gacs.local]: " DOMAIN
DOMAIN=${DOMAIN:-gacs.local}

read -p "Database name [gacs_dev]: " DB_NAME
DB_NAME=${DB_NAME:-gacs_dev}

read -p "Database user [gacs_dev]: " DB_USER
DB_USER=${DB_USER:-gacs_dev}

read -sp "Database password: " DB_PASSWORD
echo ""

read -p "Installation path [/var/www/html/gacs-dashboard]: " APP_PATH
APP_PATH=${APP_PATH:-/var/www/html/gacs-dashboard}

echo ""
echo -e "${YELLOW}Summary:${NC}"
echo "  Domain: $DOMAIN"
echo "  Database: $DB_NAME"
echo "  DB User: $DB_USER"
echo "  Path: $APP_PATH"
echo ""
read -p "Lanjutkan dengan konfigurasi ini? (y/n): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

echo ""
echo -e "${BLUE}Starting installation...${NC}"

# Download and run main installer
if command -v curl &> /dev/null; then
    bash <(curl -fsSL https://raw.githubusercontent.com/Diandp/GACS-Dashboard-custom-by-dian/ubuntu-22-04-installer/install.sh)
else
    echo -e "${RED}curl not found. Installing...${NC}"
    apt-get install -y curl
    bash <(curl -fsSL https://raw.githubusercontent.com/Diandp/GACS-Dashboard-custom-by-dian/ubuntu-22-04-installer/install.sh)
fi
