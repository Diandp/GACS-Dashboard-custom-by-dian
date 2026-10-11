#!/bin/bash

################################################################################
# GACS Dashboard - Automated Backup Script
# Purpose: Backup database and application files
################################################################################

set -e

# Configuration
APP_PATH="${APP_PATH:-/var/www/html/gacs-dashboard}"
DB_NAME="${DB_NAME:-gacs_dev}"
DB_USER="${DB_USER:-gacs_dev}"
DB_PASS="${DB_PASS:-}"
BACKUP_PATH="${BACKUP_PATH:-/var/backups/gacs-dashboard}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
EMAIL_ON_ERROR="${EMAIL_ON_ERROR:-}"

# Log file
LOG_FILE="${BACKUP_PATH}/backup.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

################################################################################
# Functions
################################################################################

log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
    
    case $level in
        SUCCESS)
            echo -e "${GREEN}[✓]${NC} ${message}"
            ;;
        ERROR)
            echo -e "${RED}[✗]${NC} ${message}"
            ;;
        WARNING)
            echo -e "${YELLOW}[!]${NC} ${message}"
            ;;
        INFO)
            echo -e "${BLUE}[i]${NC} ${message}"
            ;;
    esac
}

check_prerequisites() {
    log_message "INFO" "Checking prerequisites..."
    
    # Check if mysqldump exists
    if ! command -v mysqldump &> /dev/null; then
        log_message "ERROR" "mysqldump not found"
        return 1
    fi
    
    # Check backup directory
    if [ ! -d "$BACKUP_PATH" ]; then
        mkdir -p "$BACKUP_PATH" || {
            log_message "ERROR" "Cannot create backup directory: $BACKUP_PATH"
            return 1
        }
    fi
    
    # Check app path
    if [ ! -d "$APP_PATH" ]; then
        log_message "ERROR" "Application path not found: $APP_PATH"
        return 1
    fi
    
    log_message "SUCCESS" "Prerequisites check passed"
    return 0
}

backup_database() {
    log_message "INFO" "Starting database backup..."
    
    local backup_file="${BACKUP_PATH}/db_$(date +%Y%m%d_%H%M%S).sql"
    
    if [ -z "$DB_PASS" ]; then
        mysqldump -u "$DB_USER" "$DB_NAME" > "$backup_file" 2>/dev/null || {
            log_message "ERROR" "Database backup failed"
            return 1
        }
    else
        mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$backup_file" 2>/dev/null || {
            log_message "ERROR" "Database backup failed (check credentials)"
            return 1
        }
    fi
    
    # Compress
    gzip "$backup_file" || {
        log_message "ERROR" "Failed to compress database backup"
        return 1
    }
    
    log_message "SUCCESS" "Database backed up: ${backup_file}.gz"
    return 0
}

backup_application() {
    log_message "INFO" "Starting application backup..."
    
    local backup_file="${BACKUP_PATH}/app_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    tar --exclude='node_modules' \
        --exclude='vendor' \
        --exclude='.git' \
        --exclude='logs' \
        --exclude='cache' \
        -czf "$backup_file" -C "$(dirname $APP_PATH)" "$(basename $APP_PATH)" 2>/dev/null || {
        log_message "ERROR" "Application backup failed"
        return 1
    }
    
    log_message "SUCCESS" "Application backed up: $backup_file"
    return 0
}

backup_config() {
    log_message "INFO" "Starting config backup..."
    
    local backup_file="${BACKUP_PATH}/config_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    tar -czf "$backup_file" -C "$APP_PATH" config/ .env 2>/dev/null || {
        log_message "WARNING" "Config backup failed (files may not exist)"
    }
    
    # Restrict permissions
    chmod 600 "$backup_file" 2>/dev/null || true
    
    log_message "SUCCESS" "Config backed up: $backup_file"
    return 0
}

cleanup_old_backups() {
    log_message "INFO" "Cleaning up old backups (retention: $RETENTION_DAYS days)..."
    
    local files_deleted=0
    
    while IFS= read -r file; do
        rm -f "$file" || {
            log_message "WARNING" "Failed to delete: $file"
            continue
        }
        files_deleted=$((files_deleted + 1))
        log_message "INFO" "Deleted: $(basename $file)"
    done < <(find "$BACKUP_PATH" -maxdepth 1 -type f -mtime +"$RETENTION_DAYS")
    
    log_message "SUCCESS" "Cleanup complete (deleted $files_deleted files)"
    return 0
}

generate_summary() {
    log_message "INFO" "Generating backup summary..."
    
    local backup_count=$(find "$BACKUP_PATH" -maxdepth 1 -type f | wc -l)
    local total_size=$(du -sh "$BACKUP_PATH" 2>/dev/null | awk '{print $1}')
    local latest_backup=$(ls -t "$BACKUP_PATH"/*.gz 2>/dev/null | head -1 || echo "None")
    
    echo ""
    echo -e "${BLUE}=== Backup Summary ===${NC}"
    echo "  Timestamp: $(date)"
    echo "  Backup Path: $BACKUP_PATH"
    echo "  Total Files: $backup_count"
    echo "  Total Size: $total_size"
    echo "  Latest: $(basename $latest_backup)"
    echo "  Retention: $RETENTION_DAYS days"
    echo ""
}

send_notification() {
    local status="$1"
    local message="$2"
    
    if [ -z "$EMAIL_ON_ERROR" ]; then
        return 0
    fi
    
    if [ "$status" = "ERROR" ]; then
        echo "$message" | mail -s "GACS Backup Failed" "$EMAIL_ON_ERROR" 2>/dev/null || true
    fi
}

################################################################################
# Main
################################################################################

main() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║     GACS Dashboard - Automated Backup                           ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    # Verify prerequisites
    if ! check_prerequisites; then
        send_notification "ERROR" "GACS Backup prerequisite check failed"
        exit 1
    fi
    
    # Perform backups
    local errors=0
    
    backup_database || errors=$((errors + 1))
    backup_application || errors=$((errors + 1))
    backup_config || errors=$((errors + 1))
    
    # Cleanup
    cleanup_old_backups || errors=$((errors + 1))
    
    # Summary
    generate_summary
    
    # Check errors
    if [ $errors -gt 0 ]; then
        log_message "ERROR" "Backup completed with $errors error(s)"
        send_notification "ERROR" "GACS Backup completed with errors. Check log: $LOG_FILE"
        exit 1
    else
        log_message "SUCCESS" "Backup completed successfully"
    fi
}

main "$@"
