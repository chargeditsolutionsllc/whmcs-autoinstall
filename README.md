# WHMCS Installation Scripts for Debian 12

Automated installation and configuration scripts for setting up WHMCS on a Debian 12 (Bookworm) system. These scripts handle the complete server setup process including PHP, MariaDB, Apache, and security configurations.

## Features

- **Automated Setup**
  - PHP 8.1 with all required extensions
  - MariaDB 10.11 with optimized configuration
  - Apache with HTTP/2 and SSL support
  - ModSecurity with OWASP ruleset
  - UFW firewall with Cloudflare integration
  - Automatic security updates

- **Security Focus**
  - Secure default configurations
  - File permission hardening
  - ModSecurity WAF integration
  - Cloudflare IP allowlisting
  - Security headers implementation
  - Automatic security updates

- **Best Practices**
  - Environment-based configuration
  - Modular installation process
  - Comprehensive logging
  - Error handling
  - Backup creation
  - Service verification

## Prerequisites

- Fresh Debian 12 (Bookworm) installation
- Root access
- Domain pointed to your server
- WHMCS license (not included)

## Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/chargeditsolutionsllc/whmcs_init.git
   cd whmcs_init
   ```

2. Configure your environment:
   ```bash
   cp .env.example .env
   nano .env
   ```

3. Make scripts executable:
   ```bash
   chmod +x scripts/*.sh
   ```

4. Run the installation:
   ```bash
   sudo ./scripts/install.sh
   ```

## Environment Configuration

Edit `.env` file with your settings:

```bash
# Domain Configuration
DOMAIN=billing.yourdomain.com
EMAIL=admin@yourdomain.com

# Database Configuration
MYSQL_USER=whmcs_user
MYSQL_DATABASE=whmcs

# Installation Paths
WHMCS_PATH=/var/www/whmcs

# SSL Configuration
ENABLE_SSL=true
SSL_TYPE=letsencrypt        # Options: letsencrypt, custom
SSL_STAGING=false          # Use Let's Encrypt staging for testing
SSL_AUTO_RENEW=true
SSL_HSTS_ENABLE=true      # Enable HTTP Strict Transport Security

# Cloudflare Configuration
ENABLE_CLOUDFLARE=false
CLOUDFLARE_TRUSTED_IPS_ENABLE=true
```

See `.env.example` for all available options.

## SSL Configuration

The installation supports various SSL configurations to accommodate different environments and requirements:

### Let's Encrypt SSL

1. **Production Environment**
   ```bash
   SSL_TYPE=letsencrypt
   SSL_STAGING=false
   ```
   - Uses Let's Encrypt production certificates
   - Suitable for live websites
   - Limited to 50 certificates per domain per week

2. **Staging Environment**
   ```bash
   SSL_TYPE=letsencrypt
   SSL_STAGING=true
   ```
   - Uses Let's Encrypt staging certificates
   - For testing and development
   - No rate limits
   - Browsers will show certificate warnings (expected)

### Custom SSL

```bash
SSL_TYPE=custom
SSL_CERT_PATH=/path/to/cert.pem
SSL_KEY_PATH=/path/to/key.pem
SSL_CHAIN_PATH=/path/to/chain.pem  # Optional
```
- Use your own SSL certificates
- Supports both self-signed and commercial certificates
- Chain certificate optional but recommended

### Cloudflare Integration

When using Cloudflare, configure the following:

```bash
ENABLE_CLOUDFLARE=true
CLOUDFLARE_TRUSTED_IPS_ENABLE=true
```

#### Firewall Configuration

The UFW firewall configuration automatically adjusts based on your Cloudflare settings:

1. **With Cloudflare Enabled** (`ENABLE_CLOUDFLARE=true`)
   - Only Cloudflare IP ranges are whitelisted for ports 80 and 443
   - Provides additional security by blocking direct access
   - Automatically updates with latest Cloudflare IP ranges

2. **Without Cloudflare** (`ENABLE_CLOUDFLARE=false`)
   - Ports 80 and 443 are open to all IPs
   - Standard web server configuration
   - Direct access allowed from any IP

#### Cloudflare SSL Modes:

1. **With Let's Encrypt Production**
   - Set Cloudflare SSL/TLS mode to "Full (strict)"
   - Enables end-to-end encryption
   - Validates certificate authenticity

2. **With Let's Encrypt Staging**
   - Set Cloudflare SSL/TLS mode to "Full"
   - Allows testing with staging certificates
   - Bypasses certificate validation

3. **With Custom SSL**
   - Ensure certificate is compatible with chosen Cloudflare SSL/TLS mode
   - Use valid public certificate for "Full (strict)"
   - Self-signed certificates require "Full" mode

Additional Cloudflare Settings:
- Enable "Always Use HTTPS"
- Set minimum TLS version to 1.2
- Enable HSTS if using `SSL_HSTS_ENABLE=true`

### Security Features

The SSL implementation includes:

1. **Modern TLS Configuration**
   - TLS 1.2 and 1.3 support
   - Strong cipher suite selection
   - OCSP stapling enabled

2. **Security Headers**
   - Strict Transport Security (HSTS)
   - Content Security Policy (CSP)
   - X-Frame-Options
   - Other security headers optimized for WHMCS

3. **Certificate Validation**
   - Automatic key strength verification
   - Certificate chain validation
   - Domain match verification
   - Protocol compatibility checks

### Configuration Files and Locations

#### SSL Configuration

1. **Apache SSL Configuration**
   - Location: `/etc/apache2/conf-available/ssl-security.conf`
   - Purpose: Main SSL security settings including TLS versions, cipher suites, and security headers
   - Required directives:
     - SSLProtocol
     - SSLCipherSuite
     - Security headers (CSP, HSTS, etc.)

2. **Let's Encrypt Certificates**
   - Location: `/etc/letsencrypt/live/[domain]/`
   - Files:
     - `cert.pem`: Domain certificate
     - `privkey.pem`: Private key
     - `chain.pem`: Certificate chain
     - `fullchain.pem`: Complete certificate chain
   - Renewal configuration: `/etc/letsencrypt/renewal/[domain].conf`

3. **Custom SSL Certificates**
   - Location: `/etc/ssl/whmcs/`
   - Files:
     - `cert.pem`: Your certificate
     - `key.pem`: Private key
     - `chain.pem`: Optional chain certificate

#### Cloudflare Integration

1. **Cloudflare Apache Configuration**
   - Location: `/etc/apache2/conf-available/cloudflare.conf`
   - Purpose: Cloudflare IP ranges and SSL proxy settings
   - Key components:
     - RemoteIPHeader settings
     - Trusted proxy IPs
     - SSL proxy configurations

2. **SSL Mode Configuration**
   - Location: `/etc/apache2/conf-available/ssl-mode.conf`
   - Purpose: SSL settings specific to Cloudflare setup
   - Important settings:
     - SSLProxyEngine
     - ProxyCheck directives
     - X-Forwarded-Proto handling

#### Security Configurations

1. **UFW Firewall Rules**
   - Location: `/etc/ufw/`
   - Key files:
     - `user.rules`: Custom firewall rules
     - `before.rules`: Pre-processing rules
   - Purpose: Network access control and Cloudflare IP allowlisting

2. **ModSecurity Configuration**
   - Base config: `/etc/modsecurity/modsecurity.conf`
   - WHMCS rules: `/etc/modsecurity/whmcs-rules.conf`
   - Purpose: Web application firewall rules specific to WHMCS

3. **Apache Virtual Host**
   - Location: `/etc/apache2/sites-available/[domain].conf`
   - Purpose: Domain-specific web server configuration
   - includes SSL certificate paths and security configurations

#### Log Files

1. **SSL Logs**
   - Apache SSL: `/var/log/apache2/ssl_access.log`
   - Let's Encrypt: `/var/log/letsencrypt/`
   - Purpose: SSL-related errors and access logs

2. **Security Logs**
   - ModSecurity: `/var/log/modsec_audit.log`
   - UFW: `/var/log/ufw.log`
   - Purpose: Security events and blocked requests

#### Maintenance and Verification

1. **Let's Encrypt Renewal**
   - Timer config: `/etc/systemd/system/certbot.timer`
   - Service config: `/etc/systemd/system/certbot.service`
   - Purpose: Automatic certificate renewal

2. **Apache Modules**
   - Location: `/etc/apache2/mods-enabled/`
   - Required modules:
     - `ssl.conf` and `ssl.load`
     - `headers.conf` and `headers.load`
     - `remoteip.conf` and `remoteip.load` (for Cloudflare)

## Directory Structure

```
.
├── scripts/
│   ├── install.sh         # Main installation script
│   ├── setup-php.sh       # PHP installation and configuration
│   ├── setup-mysql.sh     # MariaDB setup
│   ├── setup-apache.sh    # Apache configuration
│   ├── setup-security.sh  # Security measures
│   └── utils.sh          # Shared utilities
├── .env.example          # Environment template
└── README.md
```

## Installation Process

1. System Update & Requirements
   - Updates system packages
   - Installs required dependencies
   - Configures package mirrors

2. PHP Setup
   - Installs PHP 8.1 and extensions
   - Configures PHP for optimal performance
   - Installs IonCube Loader

3. Database Setup
   - Installs MariaDB 10.11
   - Creates database and user
   - Applies security configurations

4. Web Server Setup
   - Configures Apache with SSL
   - Sets up virtual hosts
   - Implements security headers

5. Security Configuration
   - Configures UFW firewall
   - Sets up ModSecurity
   - Enables automatic updates

## Post-Installation Steps

1. Upload WHMCS Files:
   ```bash
   # Upload your WHMCS files to
   /var/www/whmcs/public_html/
   ```

2. Complete WHMCS Installation:
   - Navigate to `https://your-domain.com/install/install.php`
   - Follow the installation wizard
   - Remove installation directory when complete

3. Verify Installation:
   - Check PHP info page (then remove it)
   - Verify database connection
   - Test SSL configuration

4. Security Checklist:
   - Remove verification files
   - Secure admin directory
   - Set up regular backups
   - Configure SSL certificate
   - Update passwords

## Maintenance

- Regular updates:
  ```bash
  apt update && apt upgrade
  ```
- Monitor logs:
  ```bash
  tail -f /var/log/apache2/error.log
  ```
- Database backups:
  ```bash
  mysqldump -u root -p whmcs > backup.sql
  ```

## Troubleshooting

Common issues and solutions:

1. Permission Issues:
   ```bash
   # Fix permissions
   sudo scripts/install.sh --fix-permissions
   ```

2. Service Problems:
   ```bash
   # Check service status
   systemctl status apache2
   systemctl status mariadb
   ```

3. Log Locations:
   - Apache: `/var/log/apache2/`
   - MySQL: `/var/log/mysql/`
   - PHP: `/var/log/php/`

## Support

For issues and feature requests, please use the GitHub issue tracker.

## Security

Report security vulnerabilities via email to security@chargeditsolutions.com.

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Disclaimer

This is an unofficial installation script. WHMCS is a trademark of WHMCS Ltd.
