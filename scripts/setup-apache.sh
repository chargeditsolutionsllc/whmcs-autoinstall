#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Load and validate environment
load_env
check_root

log "INFO" "Starting Apache installation..."

# Install Apache and required modules
log "INFO" "Installing Apache and modules..."
apt install -y apache2

# Enable required modules
log "INFO" "Enabling Apache modules..."
a2enmod rewrite
a2enmod headers
a2enmod ssl
a2enmod http2

# Backup Apache configuration
backup_file "/etc/apache2/apache2.conf"

# Create Apache virtual host configuration
log "INFO" "Creating Apache virtual host configuration..."
cat > "/etc/apache2/sites-available/whmcs.conf" << EOF
<VirtualHost *:443>
    ServerAdmin webmaster@${DOMAIN}
    ServerName ${DOMAIN}
    DocumentRoot ${WHMCS_PUBLIC}
    
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/${DOMAIN}/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/${DOMAIN}/privkey.pem
    
    Protocols h2 http/1.1
    
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-XSS-Protection "1; mode=block"
    Header always set X-Content-Type-Options "nosniff"
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
    
    <Directory ${WHMCS_PUBLIC}>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    <DirectoryMatch .*\.(ini|php|inc|po|sh|.*sql)$>
        Require all denied
    </DirectoryMatch>
    
    # Protect sensitive files
    <FilesMatch "\.(inc|po|sh|.*sql)$">
        Require all denied
    </FilesMatch>

    # Block access to specific locations
    <DirectoryMatch "^/.*/.*/(templates_c|templates/compiler)/.*">
        Require all denied
    </DirectoryMatch>

    # Custom error pages
    ErrorDocument 400 /error/400.html
    ErrorDocument 401 /error/401.html
    ErrorDocument 403 /error/403.html
    ErrorDocument 404 /error/404.html
    ErrorDocument 500 /error/500.html
    
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>

<VirtualHost *:80>
    ServerName ${DOMAIN}
    Redirect permanent / https://${DOMAIN}/
</VirtualHost>
EOF

# Create HTTPS redirect for HTTP traffic
log "INFO" "Creating HTTP to HTTPS redirect..."
cat > "/etc/apache2/sites-available/000-default.conf" << EOF
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html
    Redirect permanent / https://${DOMAIN}/
</VirtualHost>
EOF

# Create directory structure
log "INFO" "Creating directory structure..."
ensure_directory "${WHMCS_PUBLIC}"
ensure_directory "${WHMCS_SECURE}/includes"
ensure_directory "${WHMCS_SECURE}/downloads"
ensure_directory "${WHMCS_SECURE}/attachments"

# Set directory permissions
log "INFO" "Setting directory permissions..."
set_secure_permissions "${WHMCS_PATH}" "www-data:www-data"
set_secure_permissions "${WHMCS_SECURE}" "www-data:www-data" "750" "640"

# Create error pages directory
ensure_directory "${WHMCS_PUBLIC}/error"

# Create basic error pages
for code in 400 401 403 404 500; do
    cat > "${WHMCS_PUBLIC}/error/${code}.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Error ${code}</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: #444; }
        .error-code { font-size: 72px; color: #666; margin: 0; }
        .error-text { color: #666; }
    </style>
</head>
<body>
    <h1 class="error-code">${code}</h1>
    <p class="error-text">Something went wrong. Please try again later.</p>
</body>
</html>
EOF
done

# Enable sites and disable default
log "INFO" "Enabling virtual host..."
a2ensite whmcs.conf
a2dissite 000-default.conf

# Test Apache configuration
log "INFO" "Testing Apache configuration..."
if ! apache2ctl configtest; then
    log "ERROR" "Apache configuration test failed"
    exit 1
fi

# Restart Apache
log "INFO" "Restarting Apache..."
systemctl restart apache2
wait_for_service "apache2"

log "INFO" "Apache setup completed successfully"
log "INFO" "Virtual host configuration created at /etc/apache2/sites-available/whmcs.conf"
