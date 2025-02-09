#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Load and validate environment
load_env
check_root

log "INFO" "Starting security configuration..."

# Install UFW if enabled
if [ "$ENABLE_UFW" = "true" ]; then
    log "INFO" "Installing and configuring UFW..."
    apt install -y ufw

    # Reset UFW to default state
    log "INFO" "Resetting UFW to default state..."
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing

    # Allow SSH (before enabling the firewall)
    log "INFO" "Allowing SSH connections..."
    ufw allow ssh

    # If Cloudflare is enabled, only allow web traffic from Cloudflare IPs
    if [ "$ENABLE_CLOUDFLARE" = "true" ]; then
        log "INFO" "Configuring Cloudflare IP allowlist..."
        
        # Create temporary files for Cloudflare IPs
        curl -s https://www.cloudflare.com/ips-v4 > /tmp/cf-ipv4
        curl -s https://www.cloudflare.com/ips-v6 > /tmp/cf-ipv6

        # Add IPv4 rules
        while IFS= read -r ip; do
            ufw allow from "$ip" to any port 80,443 proto tcp
            ufw allow from "$ip" to any port 80,443 proto udp
        done < /tmp/cf-ipv4

        # Add IPv6 rules
        while IFS= read -r ip; do
            ufw allow from "$ip" to any port 80,443 proto tcp
            ufw allow from "$ip" to any port 80,443 proto udp
        done < /tmp/cf-ipv6

        # Clean up temporary files
        rm -f /tmp/cf-ipv4 /tmp/cf-ipv6
    else
        # If not using Cloudflare, allow all HTTP/HTTPS traffic
        log "INFO" "Allowing HTTP/HTTPS traffic from all sources..."
        ufw allow 80/tcp
        ufw allow 443/tcp
    fi

    # Enable UFW
    log "INFO" "Enabling UFW..."
    echo "y" | ufw enable
    ufw status verbose
fi

# Install and configure ModSecurity if enabled
if [ "$ENABLE_MODSECURITY" = "true" ]; then
    log "INFO" "Installing ModSecurity..."
    apt install -y libapache2-mod-security2 modsecurity-crs

    # Configure ModSecurity
    log "INFO" "Configuring ModSecurity..."
    backup_file "/etc/modsecurity/modsecurity.conf"
    cp /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf
    sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/modsecurity/modsecurity.conf
    
    # Configure OWASP CRS
    if [ ! -f "/etc/apache2/mods-enabled/security2.conf" ]; then
        ln -s /etc/apache2/mods-available/security2.conf /etc/apache2/mods-enabled/
    fi
    
    if [ ! -f "/etc/apache2/mods-enabled/security2.load" ]; then
        ln -s /etc/apache2/mods-available/security2.load /etc/apache2/mods-enabled/
    fi

    # Create custom ModSecurity rules for WHMCS
    cat > "/etc/modsecurity/whmcs-rules.conf" << 'EOF'
# Protect WHMCS admin area
SecRule REQUEST_URI "@beginsWith /admin" "chain,phase:1,t:none,block,msg:'Unauthorized access to admin area',id:1000"
SecRule REMOTE_ADDR "!@ipMatch 127.0.0.1,::1"

# Block common WHMCS attack vectors
SecRule REQUEST_FILENAME "@endsWith configuration.php" "phase:1,t:none,block,msg:'Blocked access to configuration.php',id:1001"
SecRule REQUEST_FILENAME "@endsWith templates_c" "phase:1,t:none,block,msg:'Blocked access to templates_c directory',id:1002"

# Additional security headers
Header always set Content-Security-Policy "default-src 'self' 'unsafe-inline' 'unsafe-eval' https: data:; frame-ancestors 'self'"
Header always set X-Content-Type-Options "nosniff"
Header always set X-XSS-Protection "1; mode=block"
EOF

    # Link WHMCS rules
    ln -sf /etc/modsecurity/whmcs-rules.conf /etc/modsecurity/rules.d/

    # Restart Apache to apply ModSecurity changes
    log "INFO" "Restarting Apache to apply ModSecurity changes..."
    systemctl restart apache2
    wait_for_service "apache2"
fi

# Set up automatic security updates
log "INFO" "Configuring automatic security updates..."
apt install -y unattended-upgrades apt-listchanges
cat > "/etc/apt/apt.conf.d/50unattended-upgrades" << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}:${distro_codename}-updates";
};
Unattended-Upgrade::Package-Blacklist {
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::InstallOnShutdown "false";
Unattended-Upgrade::Mail "root";
Unattended-Upgrade::MailOnlyOnError "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

# Enable unattended upgrades
echo 'APT::Periodic::Update-Package-Lists "1";' > /etc/apt/apt.conf.d/20auto-upgrades
echo 'APT::Periodic::Unattended-Upgrade "1";' >> /etc/apt/apt.conf.d/20auto-upgrades

log "INFO" "Security configuration completed successfully"
