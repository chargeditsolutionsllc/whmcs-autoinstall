#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Validate environment and requirements
check_root
load_env
validate_env

log "INFO" "Starting WHMCS installation process..."

# Update system first
log "INFO" "Updating system packages..."
apt update
apt upgrade -y

# Install basic requirements
log "INFO" "Installing basic requirements..."
apt install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common

# Configure Cloudflare mirror for faster downloads
log "INFO" "Configuring package mirrors..."
backup_file "/etc/apt/sources.list"
cat > "/etc/apt/sources.list" << EOF
deb https://cloudflaremirrors.com/debian bookworm main contrib non-free
deb https://cloudflaremirrors.com/debian bookworm-updates main contrib non-free
deb https://cloudflaremirrors.com/debian-security bookworm-security main contrib non-free
EOF

apt update

# Generate passwords if not provided
if [ -z "$MYSQL_PASSWORD" ]; then
    MYSQL_PASSWORD=$(generate_password)
    log "INFO" "Generated MySQL password: $MYSQL_PASSWORD"
    echo "MYSQL_PASSWORD=$MYSQL_PASSWORD" >> ../.env
fi

if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
    MYSQL_ROOT_PASSWORD=$(generate_password)
    log "INFO" "Generated MySQL root password: $MYSQL_ROOT_PASSWORD"
    echo "MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD" >> ../.env
fi

# Create necessary directories
ensure_directory "$WHMCS_PATH"
ensure_directory "$WHMCS_PUBLIC"
ensure_directory "$WHMCS_SECURE"
ensure_directory "$WHMCS_SECURE/includes"
ensure_directory "$WHMCS_SECURE/downloads"
ensure_directory "$WHMCS_SECURE/attachments"
ensure_directory "$BACKUP_PATH"

# Run individual setup scripts
log "INFO" "Setting up PHP..."
bash "${SCRIPT_DIR}/setup-php.sh"
check_status "PHP setup"

log "INFO" "Setting up MySQL..."
bash "${SCRIPT_DIR}/setup-mysql.sh"
check_status "MySQL setup"

log "INFO" "Setting up Apache..."
bash "${SCRIPT_DIR}/setup-apache.sh"
check_status "Apache setup"

log "INFO" "Configuring security..."
bash "${SCRIPT_DIR}/setup-security.sh"
check_status "Security configuration"

# Set final permissions
log "INFO" "Setting final permissions..."
set_secure_permissions "$WHMCS_PATH"
set_secure_permissions "$WHMCS_SECURE" "www-data:www-data" "750" "640"

# Verify services
log "INFO" "Verifying services..."
services=("apache2" "mariadb" "php${PHP_VERSION}-fpm")
for service in "${services[@]}"; do
    wait_for_service "$service"
done

# Create basic installation verification file
cat > "${WHMCS_PUBLIC}/info.php" << EOF
<?php
phpinfo();
EOF

# Set temporary read permission for verification
chmod 644 "${WHMCS_PUBLIC}/info.php"

log "INFO" "Installation completed successfully!"
log "INFO" "Please save the following credentials:"
log "INFO" "MySQL User: $MYSQL_USER"
log "INFO" "MySQL Password: $MYSQL_PASSWORD"
log "INFO" "MySQL Root Password: $MYSQL_ROOT_PASSWORD"
log "INFO" "MySQL Database: $MYSQL_DATABASE"

log "INFO" "Next steps:"
log "INFO" "1. Upload your WHMCS files to $WHMCS_PUBLIC"
log "INFO" "2. Navigate to https://$DOMAIN/install/install.php"
log "INFO" "3. Follow the WHMCS installation wizard"
log "INFO" "4. Remove the installation directory and info.php after completion"
log "INFO" "5. Verify security settings and file permissions"

# Print verification URLs
log "INFO" "Verification URLs:"
log "INFO" "- PHP Info: https://${DOMAIN}/info.php (remove this file after verification)"
log "INFO" "- Database: Check connection using WHMCS installer"
log "INFO" "- Web Server: https://${DOMAIN} should show WHMCS installer"

# Security reminder
log "WARN" "Remember to:"
log "WARN" "- Remove info.php after verification"
log "WARN" "- Delete the install directory after WHMCS installation"
log "WARN" "- Secure the admin directory with additional authentication"
log "WARN" "- Regularly backup your database and files"
log "WARN" "- Keep WHMCS and all components updated"
