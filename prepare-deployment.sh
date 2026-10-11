#!/bin/bash

# GACS Dashboard - Quick Copy to Server Script
# This script prepares all deployment files for copying to a production server

set -e

echo "GACS Dashboard - Deployment Package Preparation"
echo ""

# Get current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create deployment package
PACKAGE_DIR="gacs-dashboard-deployment-$(date +%Y%m%d)"
mkdir -p "$PACKAGE_DIR"

echo "Copying deployment files to $PACKAGE_DIR/..."

# Copy main scripts
cp -v deploy.sh "$PACKAGE_DIR/" 2>/dev/null || true
cp -v install.sh "$PACKAGE_DIR/" 2>/dev/null || true
cp -v install-interactive.sh "$PACKAGE_DIR/" 2>/dev/null || true
cp -v install-nginx-ssl.sh "$PACKAGE_DIR/" 2>/dev/null || true
cp -v quick-install.sh "$PACKAGE_DIR/" 2>/dev/null || true
cp -v setup-nginx.sh "$PACKAGE_DIR/" 2>/dev/null || true
cp -v setup-cron.sh "$PACKAGE_DIR/" 2>/dev/null || true
cp -v backup.sh "$PACKAGE_DIR/" 2>/dev/null || true
cp -v validate-deployment.sh "$PACKAGE_DIR/" 2>/dev/null || true

# Copy documentation
cp -v INSTALL_UBUNTU_22.04.md "$PACKAGE_DIR/" 2>/dev/null || true
cp -v DEPLOYMENT_GUIDE.md "$PACKAGE_DIR/" 2>/dev/null || true
cp -v .env.production "$PACKAGE_DIR/" 2>/dev/null || true

# Make scripts executable
chmod +x "$PACKAGE_DIR"/*.sh 2>/dev/null || true

# Create README for deployment
cat > "$PACKAGE_DIR/README.md" << 'EOF'
# GACS Dashboard - Deployment Package

This is a complete, ready-to-deploy package for installing GACS Dashboard on Ubuntu 22.04.

## Quick Start

### 1. Copy to Server

```bash
scp -r gacs-dashboard-deployment-20250115 user@your-server:/tmp/
ssh user@your-server
cd /tmp/gacs-dashboard-deployment-20250115
```

### 2. Run Deployment

**Option A: Interactive Menu (Recommended)**
```bash
sudo bash deploy.sh
```

**Option B: Direct Apache Installation**
```bash
sudo bash install.sh
```

**Option C: Production Nginx + SSL**
```bash
sudo bash install-nginx-ssl.sh
```

**Option D: Custom Setup**
```bash
sudo bash install-interactive.sh
```

## Included Files

- `deploy.sh` - Main deployment orchestrator
- `install.sh` - Full Apache installation
- `install-interactive.sh` - Interactive custom setup
- `install-nginx-ssl.sh` - Nginx + Let's Encrypt SSL production setup
- `quick-install.sh` - Quick 5-minute setup
- `setup-cron.sh` - Automated cron job setup
- `backup.sh` - Backup utility script
- `validate-deployment.sh` - Post-deployment validation
- `DEPLOYMENT_GUIDE.md` - Complete deployment guide
- `INSTALL_UBUNTU_22.04.md` - Detailed installation guide
- `.env.production` - Production environment template

## Pre-Deployment Requirements

✓ Ubuntu 22.04 LTS
✓ Sudo/root access
✓ Internet connection
✓ 2GB+ RAM
✓ 20GB+ disk space
✓ Domain name (for HTTPS)

## Post-Deployment

1. Access dashboard at `https://your-domain.com/init.php`
2. Complete the setup wizard
3. Delete `init.php` file
4. Change default password
5. Configure GenieACS/MikroTik
6. Setup automated backups

## Validation

After deployment, run validation:

```bash
sudo bash validate-deployment.sh
```

## Support

- GitHub: https://github.com/Diandp/GACS-Dashboard-custom-by-dian
- Telegram: https://t.me/mostechsharing

EOF

# Create tar archive
echo ""
echo "Creating archive..."
tar -czf "${PACKAGE_DIR}.tar.gz" "$PACKAGE_DIR"

echo ""
echo "✓ Deployment package ready!"
echo ""
echo "To deploy to server:"
echo ""
echo "  Step 1: Copy to server"
echo "    scp ${PACKAGE_DIR}.tar.gz user@your-server:/tmp/"
echo ""
echo "  Step 2: Extract on server"
echo "    ssh user@your-server"
echo "    cd /tmp"
echo "    tar -xzf ${PACKAGE_DIR}.tar.gz"
echo "    cd $PACKAGE_DIR"
echo ""
echo "  Step 3: Run deployment"
echo "    sudo bash deploy.sh"
echo ""
echo "Files created:"
ls -lh "${PACKAGE_DIR}.tar.gz"
echo ""
