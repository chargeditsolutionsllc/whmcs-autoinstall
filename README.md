# WHMCS Installation Scripts for Debian 12
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Debian](https://img.shields.io/badge/Debian-12_Bookworm-red.svg)](https://www.debian.org)
[![WHMCS](https://img.shields.io/badge/WHMCS-Compatible-blue.svg)](https://www.whmcs.com)

Enterprise-grade installation and configuration scripts for deploying WHMCS on Debian 12 (Bookworm). Automates the complete server setup process with security-first approach.

## System Requirements

| Component | Requirement |
|-----------|-------------|
| OS | Debian 12 (Bookworm) |
| CPU | 2+ cores recommended |
| RAM | 4GB minimum, 8GB recommended |
| Storage | 20GB minimum |
| Network | Static IP address |
| Domain | Valid domain pointed to server |
| License | Valid WHMCS license |

## Table of Contents

- [Quick Start](#quick-start)
- [Features](#features)
- [Basic Configuration](#basic-configuration)
- [Installation Steps](#installation-steps)
- [Post-Installation](#post-installation)
- [Advanced Configuration](#advanced-configuration)
  - [SSL Configuration](#ssl-configuration)
  - [Cloudflare Integration](#cloudflare-integration)
  - [Security Features](#security-features)
- [Configuration Files Reference](#configuration-files-reference)
  - [Core Configuration Files](#core-configuration-files)
  - [SSL Configuration Files](#ssl-configuration-files)
  - [Security Configuration Files](#security-configuration-files)
  - [Log Files](#log-files)
  - [Backup Locations](#backup-locations)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)
- [Support & Contributing](#support--contributing)

## Quick Start

```bash
# 1. Clone repository
git clone https://github.com/chargeditsolutionsllc/whmcs_init.git
cd whmcs_init

# 2. Configure environment
cp .env.example .env
nano .env

# 3. Run installation
chmod +x scripts/*.sh
sudo ./scripts/install.sh
```

## Features

### Core Components
- PHP 8.1 with optimized configuration
- MariaDB 10.11 with security hardening
- Apache with HTTP/2 and SSL support
- ModSecurity WAF with OWASP ruleset

### Security Focus
- Automated security hardening
- File permission management
- Cloudflare integration
- Security headers implementation
- Automatic updates

### Best Practices
- Environment-based configuration
- Modular installation process
- Comprehensive logging
- Automated backups
- Service monitoring

## Basic Configuration

1. **Edit `.env` file with your settings:**
```bash
# Domain Settings
DOMAIN=billing.yourdomain.com
EMAIL=admin@yourdomain.com

# Database Settings
MYSQL_USER=whmcs_user
MYSQL_DATABASE=whmcs

# Installation Path
WHMCS_PATH=/var/www/whmcs
```

2. **Choose SSL Configuration:**
```bash
# SSL Settings
ENABLE_SSL=true
SSL_TYPE=letsencrypt  # Options: letsencrypt, custom
```

See `.env.example` for all available options.

## Installation Steps

The installer performs these steps automatically:

1. **System Preparation**
   - System updates
   - Required dependencies
   - Package mirror optimization

2. **Component Installation**
   - PHP 8.1 with extensions
   - MariaDB 10.11
   - Apache with mods
   - IonCube Loader

3. **Security Configuration**
   - UFW firewall setup
   - ModSecurity configuration
   - File permissions
   - Security headers

## Post-Installation

1. **Upload WHMCS Files**
   ```bash
   # Upload to
   /var/www/whmcs/public_html/
   ```

2. **Complete Setup**
   - Visit `https://your-domain.com/install/install.php`
   - Follow installation wizard
   - Remove install directory

3. **Verify Installation**
   - Check PHP configuration
   - Test database connection
   - Verify SSL setup

## Advanced Configuration

### SSL Configuration

#### Let's Encrypt SSL
```bash
# Production
SSL_TYPE=letsencrypt
SSL_STAGING=false

# Testing
SSL_TYPE=letsencrypt
SSL_STAGING=true
```

#### Custom SSL
```bash
SSL_TYPE=custom
SSL_CERT_PATH=/path/to/cert.pem
SSL_KEY_PATH=/path/to/key.pem
```

### Cloudflare Integration

```bash
# Enable Cloudflare
ENABLE_CLOUDFLARE=true
CLOUDFLARE_TRUSTED_IPS_ENABLE=true
```

#### SSL Modes
1. **Full (strict)** - Production certificates
2. **Full** - Testing/staging certificates
3. **Flexible** - Not recommended

### Security Features

1. **TLS Configuration**
   - TLS 1.2/1.3 support
   - Strong cipher suites
   - OCSP stapling

2. **Headers**
   - HSTS
   - CSP
   - X-Frame-Options

3. **File System**
   - Restricted permissions
   - Regular integrity checks
   - Automated backups

## Configuration Files Reference

### Core Configuration Files
- `/etc/apache2/apache2.conf` - Main Apache configuration
- `/etc/php/${PHP_VERSION}/apache2/php.ini` - PHP configuration
- `/etc/mysql/mariadb.conf.d/50-server.cnf` - MariaDB configuration
- `/var/www/whmcs/.env` - WHMCS environment configuration

### SSL Configuration Files
1. **Apache SSL Configuration**
   - `/etc/apache2/conf-available/ssl-security.conf` - SSL security settings
   - `/etc/apache2/sites-available/[domain].conf` - Virtual host configuration
   - `/etc/letsencrypt/live/${DOMAIN}/` - Let's Encrypt certificates
   - `/etc/ssl/whmcs/` - Custom SSL certificates directory

2. **Let's Encrypt Files**
   - `/etc/letsencrypt/renewal/[domain].conf` - Certificate renewal configuration
   - `/etc/systemd/system/certbot.timer` - Automatic renewal timer
   - `/etc/systemd/system/certbot.service` - Renewal service configuration

### Security Configuration Files
1. **Web Application Firewall**
   - `/etc/modsecurity/modsecurity.conf` - ModSecurity base configuration
   - `/etc/modsecurity/whmcs-rules.conf` - WHMCS-specific rules
   - `/etc/apache2/conf-available/security.conf` - Apache security settings

2. **Firewall Configuration**
   - `/etc/ufw/user.rules` - UFW firewall rules
   - `/etc/ufw/before.rules` - Pre-processing rules
   - `/etc/apache2/conf-available/cloudflare.conf` - Cloudflare configuration

### Log Files
1. **Web Server Logs**
   - `/var/log/apache2/access.log` - Apache access logs
   - `/var/log/apache2/error.log` - Apache error logs
   - `/var/log/apache2/ssl_access.log` - SSL-specific logs

2. **Database Logs**
   - `/var/log/mysql/error.log` - MariaDB error log
   - `/var/log/mysql/slow-query.log` - Slow query log

3. **Security Logs**
   - `/var/log/modsec_audit.log` - ModSecurity audit log
   - `/var/log/ufw.log` - Firewall logs
   - `/var/log/letsencrypt/` - SSL certificate logs

### Backup Locations
- `/var/backups/whmcs/` - Automated backup directory
- `/var/backups/whmcs/database/` - Database backups
- `/var/backups/whmcs/files/` - File backups
- `/var/backups/whmcs/config/` - Configuration backups

## Maintenance

### Regular Updates
```bash
# System updates
apt update && apt upgrade

# Check services
systemctl status apache2
systemctl status mariadb
```

### Monitoring
```bash
# Check logs
tail -f /var/log/apache2/error.log
tail -f /var/log/mysql/error.log

# Database backup
mysqldump -u root -p whmcs > backup.sql
```

## Troubleshooting

### Common Issues

1. **Permission Errors**
   ```bash
   # Fix permissions
   sudo scripts/install.sh --fix-permissions
   ```

2. **SSL Problems**
   ```bash
   # Check SSL
   sudo apache2ctl configtest
   sudo certbot certificates
   ```

3. **Database Connection Issues**
   ```bash
   # Verify MySQL
   sudo systemctl status mariadb
   mysql -u whmcs_user -p whmcs
   ```

### Log Locations
- Apache: `/var/log/apache2/`
- MySQL: `/var/log/mysql/`
- PHP: `/var/log/php/`
- SSL: `/var/log/letsencrypt/`

## Support & Contributing

### Getting Help
- GitHub Issues: Bug reports and feature requests
- Security Reports: security@chargeditsolutions.com
- Documentation: README.md

### Contributing
1. Fork repository
2. Create feature branch
3. Commit changes
4. Open pull request

## License

MIT License - See [LICENSE](LICENSE) file.

## Disclaimer

This is an unofficial installation script. WHMCS is a trademark of WHMCS Ltd.
