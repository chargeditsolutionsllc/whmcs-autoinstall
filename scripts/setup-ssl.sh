#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Load and validate environment
load_env
check_root

log "INFO" "Starting SSL setup..."

# Create SSL directory
ensure_directory "/etc/ssl/whmcs"

# Backup existing SSL configs
backup_ssl_config() {
    local timestamp=$(date +%Y%m%d%H%M%S)
    if [ -f /etc/apache2/sites-available/default-ssl.conf ]; then
        backup_file "/etc/apache2/sites-available/default-ssl.conf"
    fi
    if [ -d /etc/letsencrypt/live/$DOMAIN ]; then
        cp -r "/etc/letsencrypt/live/$DOMAIN" "/etc/letsencrypt/live/${DOMAIN}.bak.${timestamp}"
    fi
}

# Configure Modern SSL Security
setup_ssl_security() {
    local ssl_conf="/etc/apache2/conf-available/ssl-security.conf"
    
    cat > "$ssl_conf" <<EOL
# Modern SSL Configuration for WHMCS
SSLProtocol -all +TLSv1.2 +TLSv1.3
SSLCipherSuite ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256
SSLCompression off
SSLSessionTickets off

# Enhanced OCSP Stapling
SSLUseStapling on
SSLStaplingCache "shmcb:logs/stapling-cache(150000)"
SSLStaplingResponseMaxAge 900
SSLStaplingReturnResponderErrors off
SSLStaplingFakeTryLater off

# WHMCS-Specific Security Headers
Header always set X-Frame-Options SAMEORIGIN
Header always set X-Content-Type-Options nosniff
Header always set X-XSS-Protection "1; mode=block"
Header always set Referrer-Policy strict-origin-when-cross-origin
# Comprehensive CSP for WHMCS
Header always set Content-Security-Policy "default-src 'self'; \
    script-src 'self' 'unsafe-inline' 'unsafe-eval' *.cloudflare.com *.jquery.com *.googleapis.com *.gstatic.com; \
    style-src 'self' 'unsafe-inline' *.googleapis.com *.gstatic.com; \
    img-src 'self' data: https:; \
    connect-src 'self' *.cloudflare.com; \
    font-src 'self' data: *.googleapis.com *.gstatic.com; \
    frame-ancestors 'self'; \
    form-action 'self'; \
    base-uri 'self'; \
    object-src 'none'"
Header always set Permissions-Policy "geolocation=(), midi=(), camera=(), usb=(), payment=(), microphone=(), magnetometer=(), gyroscope=(), accelerometer=(), document-domain=()"
Header always set Cross-Origin-Opener-Policy "same-origin"
Header always set Cross-Origin-Resource-Policy "same-site"
EOL

    if [ "$SSL_HSTS_ENABLE" = "true" ]; then
        echo 'Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"' >> "$ssl_conf"
    fi

    a2enconf ssl-security
}

# Configure SSL mode based on environment
configure_ssl_mode() {
    if [ "$ENABLE_CLOUDFLARE" = "true" ]; then
        log "INFO" "Configuring SSL for Cloudflare setup..."
        
        # Check if we're in staging
        if [ "$SSL_STAGING" = "true" ]; then
            log "WARN" "SSL staging mode detected with Cloudflare enabled"
            log "INFO" "Ensure Cloudflare SSL/TLS mode is set to 'Full' during testing"
        else
            log "INFO" "Production SSL with Cloudflare - recommend SSL/TLS mode 'Full (strict)'"
        fi

        # Add Cloudflare SSL configuration
        local ssl_mode_conf="/etc/apache2/conf-available/ssl-mode.conf"
        cat > "$ssl_mode_conf" <<EOL
# SSL Configuration for Cloudflare
SSLEngine on
SSLProxyEngine on
SSLProxyVerify none
SSLProxyCheckPeerCN off
SSLProxyCheckPeerName off
RequestHeader set X-Forwarded-Proto "https"
EOL
        a2enconf ssl-mode
    else
        log "INFO" "Configuring direct SSL (no Cloudflare)..."
        if [ "$SSL_STAGING" = "true" ]; then
            log "WARN" "Using Let's Encrypt staging environment for testing"
        fi
    fi
}

# Configure Cloudflare
setup_cloudflare() {
    if [ "$ENABLE_CLOUDFLARE" = "true" ] && [ "$CLOUDFLARE_TRUSTED_IPS_ENABLE" = "true" ]; then
        log "INFO" "Setting up Cloudflare configuration..."

        
        # Create Cloudflare configuration
        local cf_conf="/etc/apache2/conf-available/cloudflare.conf"
        
        # Download latest Cloudflare IPs with retry
        local max_retries=3
        local retry_count=0
        local success=false
        
        while [ $retry_count -lt $max_retries ] && [ "$success" = "false" ]; do
            if ipv4_ips=$(curl -sf https://www.cloudflare.com/ips-v4) && \
               ipv6_ips=$(curl -sf https://www.cloudflare.com/ips-v6); then
                success=true
            else
                retry_count=$((retry_count + 1))
                if [ $retry_count -lt $max_retries ]; then
                    log "WARN" "Failed to fetch Cloudflare IPs, retrying in 5 seconds..."
                    sleep 5
                fi
            fi
        done

        if [ "$success" = "false" ]; then
            log "ERROR" "Failed to fetch Cloudflare IPs after $max_retries attempts"
            return 1
        fi
        
        # Create Apache config for Cloudflare with proper SSL handling
        cat > "$cf_conf" <<EOL
# Cloudflare IP Ranges
RemoteIPHeader CF-Connecting-IP
RemoteIPTrustedProxy 127.0.0.1

# SSL Settings for Cloudflare
SetEnvIf X-Forwarded-Proto "https" HTTPS=on
RequestHeader set X-Forwarded-Proto "https" env=HTTPS

# IPv4 Ranges
EOL
        
        for ip in $ipv4_ips; do
            echo "RemoteIPTrustedProxy $ip" >> "$cf_conf"
        done
        
        echo -e "\n# IPv6 Ranges" >> "$cf_conf"
        for ip in $ipv6_ips; do
            echo "RemoteIPTrustedProxy $ip" >> "$cf_conf"
        done
        
        # Enable required modules
        a2enmod remoteip
        
        # Enable Cloudflare config
        a2enconf cloudflare
        
        log "INFO" "Cloudflare configuration completed"
    fi
}

# Validate SSL configuration
if [ "$SSL_TYPE" != "letsencrypt" ] && [ "$SSL_TYPE" != "custom" ]; then
    log "ERROR" "Invalid SSL_TYPE. Must be 'letsencrypt' or 'custom'"
    exit 1
fi

# Enable required Apache modules early
if ! a2enmod ssl headers http2 remoteip; then
    log "ERROR" "Failed to enable required Apache modules"
    exit 1
fi

# Validate Cloudflare configuration
if [ "$ENABLE_CLOUDFLARE" = "true" ]; then
    log "INFO" "Validating Cloudflare configuration..."
    
    # Check if domain is proxied through Cloudflare
    if ! dig +short "$DOMAIN" | grep -q '^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}$' > /dev/null 2>&1; then
        log "ERROR" "Domain $DOMAIN does not appear to be proxied through Cloudflare"
        log "INFO" "Please ensure:"
        log "INFO" "1. Domain DNS is pointing to Cloudflare nameservers"
        log "INFO" "2. DNS A/CNAME record exists for $DOMAIN"
        log "INFO" "3. Cloudflare proxy status is enabled (orange cloud)"
        exit 1
    fi
    
    # Check SSL type compatibility
    if [ "$SSL_TYPE" = "custom" ]; then
        log "WARN" "Using custom SSL with Cloudflare - ensure your certificate is compatible with Cloudflare's SSL/TLS mode"
        log "INFO" "For production use, Cloudflare's 'Full (strict)' mode requires a valid public certificate"
    fi
fi

# Backup existing configuration
backup_ssl_config

if [ "$SSL_TYPE" = "custom" ]; then
    if [ -z "$SSL_CERT_PATH" ] || [ -z "$SSL_KEY_PATH" ]; then
        log "ERROR" "SSL_CERT_PATH and SSL_KEY_PATH must be set when using custom SSL"
        exit 1
    fi
    
    if [ ! -f "$SSL_CERT_PATH" ] || [ ! -f "$SSL_KEY_PATH" ]; then
        log "ERROR" "SSL certificate or key file not found"
        exit 1
    fi
    
    # Copy and secure custom certificates
    cp "$SSL_CERT_PATH" "/etc/ssl/whmcs/cert.pem"
    cp "$SSL_KEY_PATH" "/etc/ssl/whmcs/key.pem"
    chmod 600 "/etc/ssl/whmcs/key.pem"
    chmod 644 "/etc/ssl/whmcs/cert.pem"
    
    # Check for chain file
    if [ ! -z "$SSL_CHAIN_PATH" ] && [ -f "$SSL_CHAIN_PATH" ]; then
        cp "$SSL_CHAIN_PATH" "/etc/ssl/whmcs/chain.pem"
        chmod 644 "/etc/ssl/whmcs/chain.pem"
    fi
    
    log "INFO" "Custom SSL certificates installed successfully"
else
    # Install Certbot and Apache plugin
    log "INFO" "Installing Certbot..."
    if ! apt install -y certbot python3-certbot-apache; then
        log "ERROR" "Failed to install Certbot"
        exit 1
    fi
    
    # Build certbot command
    certbot_cmd="certbot --apache -d $DOMAIN --non-interactive --agree-tos -m $EMAIL --redirect"
    
    if [ "$SSL_STAGING" = "true" ]; then
        log "INFO" "Using Let's Encrypt staging environment..."
        certbot_cmd="$certbot_cmd --test-cert"
    fi
    
    # Configure SSL mode
    configure_ssl_mode

    # Run Certbot
    log "INFO" "Obtaining SSL certificate..."
    if ! eval $certbot_cmd; then
        log "ERROR" "Failed to obtain SSL certificate"
        exit 1
    fi

    # Verify SSL and Cloudflare settings
    if [ "$ENABLE_CLOUDFLARE" = "true" ]; then
        log "INFO" "SSL certificate obtained. Please ensure Cloudflare SSL/TLS settings:"
        if [ "$SSL_STAGING" = "true" ]; then
            log "INFO" "- Set SSL/TLS mode to 'Full' for staging environment"
        else
            log "INFO" "- Set SSL/TLS mode to 'Full (strict)' for production"
        fi
        log "INFO" "- Enable 'Always Use HTTPS'"
        log "INFO" "- Set minimum TLS version to 1.2"
    fi
    
    # Configure auto-renewal if enabled
    if [ "$SSL_AUTO_RENEW" = "true" ]; then
        log "INFO" "Setting up automatic renewal..."
        systemctl enable certbot.timer
        systemctl start certbot.timer
    fi
    
    log "INFO" "Let's Encrypt SSL certificate installed successfully"
fi

# SSL modules already enabled earlier

# Setup SSL security configurations
setup_ssl_security

# Setup Cloudflare if enabled
setup_cloudflare

# Verify SSL certificate
verify_ssl() {
    local domain=$1
    local cert_path
    local chain_path
    
    if [ "$SSL_TYPE" = "letsencrypt" ]; then
        cert_path="/etc/letsencrypt/live/$domain/cert.pem"
        chain_path="/etc/letsencrypt/live/$domain/chain.pem"
    else
        cert_path="/etc/ssl/whmcs/cert.pem"
        chain_path="/etc/ssl/whmcs/chain.pem"
    fi
    
    # Check certificate validity
    if ! openssl x509 -in "$cert_path" -noout -checkend 0; then
        log "ERROR" "SSL certificate is not valid"
        return 1
    fi
    
    # Check certificate matches domain
    local cert_domain=$(openssl x509 -in "$cert_path" -noout -subject | grep -oP "CN = \K[^,]*")
    if [[ "$cert_domain" != "$domain" && "$cert_domain" != "*.$domain" ]]; then
        log "ERROR" "Certificate domain mismatch"
        return 1
    fi

    # Check key strength (minimum 2048 bits for RSA)
    local key_size=$(openssl x509 -in "$cert_path" -noout -text | grep "Public-Key:" | grep -oP "\d+")
    if [ "$key_size" -lt 2048 ]; then
        log "ERROR" "Certificate key size ($key_size bits) is too weak. Minimum 2048 bits required."
        return 1
    fi

    # Verify certificate chain if available
    if [ -f "$chain_path" ]; then
        if ! openssl verify -CAfile "$chain_path" "$cert_path" > /dev/null 2>&1; then
            log "ERROR" "Certificate chain verification failed"
            return 1
        fi
    fi
    
    # Check SSL protocol and cipher compatibility
    local protocols=$(openssl s_client -connect "$domain:443" -tls1_3 < /dev/null 2>/dev/null | grep "Protocol" | awk '{print $2}')
    if ! echo "$protocols" | grep -q "TLSv1.3"; then
        log "WARN" "TLS 1.3 not detected on the server"
    fi
    
    log "INFO" "SSL certificate verification passed all security checks"
    return 0
}

if ! verify_ssl "$DOMAIN"; then
    log "ERROR" "SSL verification failed"
    exit 1
fi

# Restart Apache to apply changes
systemctl restart apache2

# Test Apache configuration
if ! apache2ctl -t; then
    log "ERROR" "Apache configuration test failed"
    exit 1
fi

log "INFO" "SSL setup completed successfully"
