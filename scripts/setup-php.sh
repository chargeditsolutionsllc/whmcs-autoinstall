#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Load and validate environment
load_env
check_root

log "INFO" "Starting PHP installation..."

# Add PHP repository
log "INFO" "Adding PHP repository..."
curl -sSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg
echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ bookworm main" > /etc/apt/sources.list.d/sury-php.list
apt update

# Install PHP and extensions
log "INFO" "Installing PHP ${PHP_VERSION} and extensions..."
apt install -y php${PHP_VERSION} php${PHP_VERSION}-cli php${PHP_VERSION}-common php${PHP_VERSION}-curl \
    php${PHP_VERSION}-gd php${PHP_VERSION}-intl php${PHP_VERSION}-mbstring php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-xml php${PHP_VERSION}-zip php${PHP_VERSION}-bcmath php${PHP_VERSION}-soap \
    php${PHP_VERSION}-imap php${PHP_VERSION}-gmp

# Backup original PHP configuration
backup_file "/etc/php/${PHP_VERSION}/apache2/php.ini"

# Configure PHP
log "INFO" "Configuring PHP..."
sed -i "s/memory_limit = .*/memory_limit = ${PHP_MEMORY_LIMIT}/" "/etc/php/${PHP_VERSION}/apache2/php.ini"
sed -i "s/upload_max_filesize = .*/upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE}/" "/etc/php/${PHP_VERSION}/apache2/php.ini"
sed -i "s/post_max_size = .*/post_max_size = ${PHP_POST_MAX_SIZE}/" "/etc/php/${PHP_VERSION}/apache2/php.ini"
sed -i "s/max_execution_time = .*/max_execution_time = ${PHP_MAX_EXECUTION_TIME}/" "/etc/php/${PHP_VERSION}/apache2/php.ini"
sed -i "s/max_input_time = .*/max_input_time = ${PHP_MAX_INPUT_TIME}/" "/etc/php/${PHP_VERSION}/apache2/php.ini"

# Install IonCube Loader
log "INFO" "Installing IonCube Loader..."
cd /tmp
wget https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz
tar xfz ioncube_loaders_lin_x86-64.tar.gz
PHP_EXT_DIR=$(php -i | grep "extension_dir" | sed 's/.*=> //' | sed 's/ =>.*//')
cp "/tmp/ioncube/ioncube_loader_lin_${PHP_VERSION}.so" "${PHP_EXT_DIR}/ioncube_loader_lin_${PHP_VERSION}.so"
echo "zend_extension=${PHP_EXT_DIR}/ioncube_loader_lin_${PHP_VERSION}.so" > "/etc/php/${PHP_VERSION}/mods-available/ioncube.ini"
ln -s "/etc/php/${PHP_VERSION}/mods-available/ioncube.ini" "/etc/php/${PHP_VERSION}/apache2/conf.d/00-ioncube.ini"

# Clean up
rm -rf /tmp/ioncube*

# Verify PHP installation
log "INFO" "Verifying PHP installation..."
php -v
if [ $? -ne 0 ]; then
    log "ERROR" "PHP installation verification failed"
    exit 1
fi

# Test PHP extensions
required_extensions=("curl" "gd" "intl" "mbstring" "mysqli" "xml" "zip" "bcmath" "soap" "imap" "gmp")
missing_extensions=()

for ext in "${required_extensions[@]}"; do
    if ! php -m | grep -q "^${ext}$"; then
        missing_extensions+=("$ext")
    fi
done

if [ ${#missing_extensions[@]} -ne 0 ]; then
    log "ERROR" "Missing PHP extensions: ${missing_extensions[*]}"
    exit 1
fi

# Restart PHP-FPM if it's installed
if systemctl is-active --quiet "php${PHP_VERSION}-fpm"; then
    systemctl restart "php${PHP_VERSION}-fpm"
    wait_for_service "php${PHP_VERSION}-fpm"
fi

log "INFO" "PHP setup completed successfully"
