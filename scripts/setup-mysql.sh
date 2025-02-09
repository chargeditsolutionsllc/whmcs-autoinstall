#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Load and validate environment
load_env
check_root

log "INFO" "Starting MariaDB installation..."

# Add MariaDB repository
log "INFO" "Adding MariaDB repository..."
curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | \
    bash -s -- --mariadb-server-version="mariadb-${MARIADB_VERSION}"

# Install MariaDB
log "INFO" "Installing MariaDB..."
apt install -y mariadb-server

# Generate passwords if not set
if [ -z "$MYSQL_PASSWORD" ]; then
    MYSQL_PASSWORD=$(generate_password)
    log "INFO" "Generated MySQL password"
    echo "MYSQL_PASSWORD=$MYSQL_PASSWORD" >> ../.env
fi

if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
    MYSQL_ROOT_PASSWORD=$(generate_password)
    log "INFO" "Generated MySQL root password"
    echo "MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD" >> ../.env
fi

# Backup MySQL configuration
backup_file "/etc/mysql/mariadb.conf.d/50-server.cnf"

# Configure MariaDB
log "INFO" "Configuring MariaDB..."
cat > "/etc/mysql/mariadb.conf.d/60-whmcs-optimization.cnf" << EOF
[mysqld]
innodb_buffer_pool_size = 1G
innodb_buffer_pool_instances = 1
innodb_flush_log_at_trx_commit = 2
innodb_log_buffer_size = 32M
innodb_max_dirty_pages_pct = 90
query_cache_type = 1
query_cache_limit = 2M
query_cache_size = 64M
query_cache_min_res_unit = 2K
tmp_table_size = 64M
max_heap_table_size = 64M
table_open_cache = 1024
table_definition_cache = 1024
max_connections = 300
EOF

# Secure MariaDB installation
log "INFO" "Securing MariaDB installation..."
mysql -e "UPDATE mysql.user SET Password=PASSWORD('${MYSQL_ROOT_PASSWORD}') WHERE User='root';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"

# Create WHMCS database and user
log "INFO" "Creating WHMCS database and user..."
mysql -e "CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE} CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';"
mysql -e "GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Verify MySQL installation
log "INFO" "Verifying MariaDB installation..."
if ! mysqladmin ping -u root -p"${MYSQL_ROOT_PASSWORD}" --silent; then
    log "ERROR" "MariaDB verification failed"
    exit 1
fi

# Restart MariaDB
log "INFO" "Restarting MariaDB..."
systemctl restart mariadb
wait_for_service "mariadb"

# Verify database access
log "INFO" "Verifying database access..."
if ! mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -e "USE ${MYSQL_DATABASE}"; then
    log "ERROR" "Database access verification failed"
    exit 1
fi

log "INFO" "MariaDB setup completed successfully"
log "INFO" "MySQL Root Password: ${MYSQL_ROOT_PASSWORD}"
log "INFO" "MySQL User: ${MYSQL_USER}"
log "INFO" "MySQL Password: ${MYSQL_PASSWORD}"
log "INFO" "MySQL Database: ${MYSQL_DATABASE}"
