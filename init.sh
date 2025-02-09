# First, update and upgrade system
apt update
apt upgrade -y

# Install basic requirements
apt install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common

# Configure Cloudflare mirror
rm /etc/apt/sources.list
cat > /etc/apt/sources.list << EOF
deb https://cloudflaremirrors.com/debian bookworm main contrib non-free
deb https://cloudflaremirrors.com/debian bookworm-updates main contrib non-free
deb https://cloudflaremirrors.com/debian-security bookworm-security main contrib non-free
EOF

apt update

# Setup PHP 8.1
curl -sSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg
echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ bookworm main" > /etc/apt/sources.list.d/sury-php.list
apt update

# Install PHP and extensions
apt install -y php8.1 php8.1-cli php8.1-common php8.1-curl php8.1-gd php8.1-intl \
    php8.1-mbstring php8.1-mysql php8.1-xml php8.1-zip php8.1-bcmath \
    php8.1-soap php8.1-imap php8.1-gmp

# Configure PHP
sed -i "s/memory_limit = .*/memory_limit = 256M/" /etc/php/8.1/apache2/php.ini
sed -i "s/upload_max_filesize = .*/upload_max_filesize = 64M/" /etc/php/8.1/apache2/php.ini
sed -i "s/post_max_size = .*/post_max_size = 64M/" /etc/php/8.1/apache2/php.ini
sed -i "s/max_execution_time = .*/max_execution_time = 300/" /etc/php/8.1/apache2/php.ini
sed -i "s/max_input_time = .*/max_input_time = 300/" /etc/php/8.1/apache2/php.ini

# Install MariaDB
curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version="mariadb-10.11.11"
apt install -y mariadb-server

# Generate secure passwords (you should save these)
MYSQL_PASSWORD=$(openssl rand -base64 32)
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)

# Secure MariaDB installation
mysql -e "UPDATE mysql.user SET Password=PASSWORD('${MYSQL_ROOT_PASSWORD}') WHERE User='root';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"

# Create WHMCS database and user
mysql -e "CREATE DATABASE whmcs CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
mysql -e "CREATE USER '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';"
mysql -e "GRANT ALL PRIVILEGES ON whmcs.* TO '${MYSQL_USER}'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Install UFW and configure firewall
apt install -y ufw
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh

# Download Cloudflare IPs and add to UFW
curl -s https://www.cloudflare.com/ips-v4 > /tmp/cf-ipv4
curl -s https://www.cloudflare.com/ips-v6 > /tmp/cf-ipv6

while IFS= read -r ip; do
    ufw allow from "$ip" to any port 80,443 proto tcp
    ufw allow from "$ip" to any port 80,443 proto udp
done < /tmp/cf-ipv4

while IFS= read -r ip; do
    ufw allow from "$ip" to any port 80,443 proto tcp
    ufw allow from "$ip" to any port 80,443 proto udp
done < /tmp/cf-ipv6

echo "y" | ufw enable

# Install and configure Apache
apt install -y apache2
a2enmod rewrite headers ssl http2

# Create Apache configuration
cat > /etc/apache2/sites-available/whmcs.conf << 'EOF'
<VirtualHost *:443>
    ServerAdmin webmaster@${DOMAIN}
    ServerName ${DOMAIN}
    DocumentRoot /var/www/whmcs/public_html
    
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/${DOMAIN}/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/${DOMAIN}/privkey.pem
    
    Protocols h2 http/1.1
    
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-XSS-Protection "1; mode=block"
    Header always set X-Content-Type-Options "nosniff"
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
    
    <Directory /var/www/whmcs/public_html>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    <DirectoryMatch .*\.(ini|php|inc|po|sh|.*sql)$>
        Require all denied
    </DirectoryMatch>
    
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>

<VirtualHost *:80>
    ServerName ${DOMAIN}
    Redirect permanent / https://${DOMAIN}/
</VirtualHost>
EOF

# Enable the site and disable default
a2ensite whmcs.conf
a2dissite 000-default.conf

# Create WHMCS directories
mkdir -p /var/www/whmcs/public_html
mkdir -p /var/www/whmcs/secure/includes
mkdir -p /var/www/whmcs/secure/downloads
mkdir -p /var/www/whmcs/secure/attachments

# Set permissions
chown -R www-data:www-data /var/www/whmcs
find /var/www/whmcs -type d -exec chmod 755 {} \;
find /var/www/whmcs -type f -exec chmod 644 {} \;
chmod 750 /var/www/whmcs/secure
chmod 750 /var/www/whmcs/secure/includes
chmod 750 /var/www/whmcs/secure/downloads
chmod 750 /var/www/whmcs/secure/attachments

# Install IonCube Loader
cd /tmp
wget https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz
tar xfz ioncube_loaders_lin_x86-64.tar.gz
PHP_EXT_DIR=$(php -i | grep "extension_dir" | sed 's/.*=> //' | sed 's/ =>.*//')
cp "/tmp/ioncube/ioncube_loader_lin_8.1.so" "${PHP_EXT_DIR}"
echo "zend_extension=${PHP_EXT_DIR}/ioncube_loader_lin_8.1.so" > "/etc/php/8.1/mods-available/ioncube.ini"
ln -s "/etc/php/8.1/mods-available/ioncube.ini" "/etc/php/8.1/apache2/conf.d/00-ioncube.ini"

# Install and configure ModSecurity
apt install -y libapache2-mod-security2 modsecurity-crs
cp /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf
sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/modsecurity/modsecurity.conf
ln -s /usr/share/modsecurity-crs/owasp-crs.load /etc/apache2/mods-enabled/

# Restart services
systemctl restart apache2
systemctl restart mariadb
