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
```

See `.env.example` for all available options.

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
