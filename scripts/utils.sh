#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load environment variables
load_env() {
    if [ -f ../.env ]; then
        export $(cat ../.env | grep -v '^#' | xargs)
    else
        echo -e "${RED}Error: .env file not found${NC}"
        exit 1
    fi
}

# Log messages with timestamp
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} ${timestamp} - ${message}"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} ${timestamp} - ${message}"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} ${timestamp} - ${message}"
            ;;
        *)
            echo "${timestamp} - ${message}"
            ;;
    esac
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log "ERROR" "This script must be run as root"
        exit 1
    fi
}

# Validate domain format
validate_domain() {
    local domain=$1
    # RFC 1123 hostname check with common TLD verification
    if ! echo "$domain" | grep -P '^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$' > /dev/null; then
        log "ERROR" "Invalid domain format: $domain"
        return 1
    fi
    return 0
}

# Validate email format
validate_email() {
    local email=$1
    # Basic email format check
    if ! echo "$email" | grep -P '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' > /dev/null; then
        log "ERROR" "Invalid email format: $email"
        return 1
    fi
    return 0
}

# Check system requirements
check_system_requirements() {
    log "INFO" "Checking system requirements..."
    
    # Check CPU cores
    local cpu_cores=$(nproc)
    if [ "$cpu_cores" -lt 2 ]; then
        log "ERROR" "Insufficient CPU cores. Minimum 2 cores required, found $cpu_cores"
        return 1
    fi
    
    # Check available memory (in MB)
    local total_ram=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$total_ram" -lt 2048 ]; then
        log "ERROR" "Insufficient memory. Minimum 2GB required, found ${total_ram}MB"
        return 1
    fi
    
    # Check available disk space (in MB)
    local free_space=$(df -m /var/www | awk 'NR==2 {print $4}')
    if [ "$free_space" -lt 5120 ]; then
        log "ERROR" "Insufficient disk space. Minimum 5GB required, found ${free_space}MB"
        return 1
    fi
    
    return 0
}

# Check required ports availability
check_ports() {
    log "INFO" "Checking port availability..."
    local ports=(80 443 3306)
    local used_ports=()
    
    for port in "${ports[@]}"; do
        if netstat -tuln | grep -q ":$port "; then
            used_ports+=($port)
        fi
    done
    
    if [ ${#used_ports[@]} -ne 0 ]; then
        log "ERROR" "Required ports already in use: ${used_ports[*]}"
        return 1
    fi
    return 0
}

# Check network connectivity
check_network() {
    log "INFO" "Checking network connectivity..."
    
    # Check internet connectivity
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log "ERROR" "No internet connectivity"
        return 1
    fi
    
    # Check DNS resolution
    if ! host -t A debian.org >/dev/null 2>&1; then
        log "ERROR" "DNS resolution not working"
        return 1
    fi
    
    return 0
}

# Check SSL configuration
check_ssl_config() {
    if [ "$ENABLE_SSL" = "true" ]; then
        log "INFO" "Checking SSL configuration..."
        
        if [ "$SSL_TYPE" = "custom" ]; then
            if [ -z "$SSL_CERT_PATH" ] || [ -z "$SSL_KEY_PATH" ]; then
                log "ERROR" "Custom SSL enabled but certificate paths not provided"
                return 1
            fi
        elif [ "$SSL_TYPE" = "letsencrypt" ]; then
            if ! is_package_installed "certbot"; then
                log "WARN" "Certbot not installed, will be installed during setup"
            fi
        else
            log "ERROR" "Invalid SSL_TYPE. Must be 'letsencrypt' or 'custom'"
            return 1
        fi
    fi
    return 0
}

# Validate environment variables and system configuration
validate_env() {
    log "INFO" "Starting environment validation..."
    
    # Check if running as root first
    check_root
    
    # Check required variables
    local required_vars=("DOMAIN" "EMAIL" "MYSQL_USER" "MYSQL_DATABASE")
    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -ne 0 ]; then
        log "ERROR" "Missing required environment variables: ${missing_vars[*]}"
        exit 1
    fi

    # Validate formats
    validate_domain "$DOMAIN" || exit 1
    validate_email "$EMAIL" || exit 1
    
    # System checks
    check_system_requirements || exit 1
    check_network || exit 1
    check_ports || exit 1
    check_ssl_config || exit 1
    
    # If Cloudflare is enabled, check DNS
    if [ "$ENABLE_CLOUDFLARE" = "true" ]; then
        log "INFO" "Checking Cloudflare configuration..."
        if ! host -t A "$DOMAIN" 2>&1 | grep -q "has address"; then
            log "ERROR" "Domain $DOMAIN does not have a valid A record"
            exit 1
        fi
    fi
    
    log "INFO" "Environment validation completed successfully"
}

# Generate secure password
generate_password() {
    openssl rand -base64 32
}

# Check command status
check_status() {
    if [ $? -eq 0 ]; then
        log "INFO" "$1 completed successfully"
    else
        log "ERROR" "$1 failed"
        exit 1
    fi
}

# Backup file before modification
backup_file() {
    local file=$1
    if [ -f "$file" ]; then
        cp "$file" "${file}.bak.$(date +%Y%m%d%H%M%S)"
        log "INFO" "Created backup of ${file}"
    fi
}

# Create directory if it doesn't exist
ensure_directory() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        check_status "Creating directory ${dir}"
    fi
}

# Check if a package is installed
is_package_installed() {
    dpkg -l "$1" &> /dev/null
    return $?
}

# Set secure permissions
set_secure_permissions() {
    local path=$1
    local owner=${2:-"www-data:www-data"}
    local dir_perms=${3:-"755"}
    local file_perms=${4:-"644"}

    chown -R "$owner" "$path"
    find "$path" -type d -exec chmod "$dir_perms" {} \;
    find "$path" -type f -exec chmod "$file_perms" {} \;
}

# Wait for service to be ready
wait_for_service() {
    local service=$1
    local max_attempts=${2:-30}
    local attempt=1

    while ! systemctl is-active --quiet "$service"; do
        if [ $attempt -ge $max_attempts ]; then
            log "ERROR" "Service ${service} failed to start after ${max_attempts} attempts"
            exit 1
        fi
        log "INFO" "Waiting for ${service} to start (attempt ${attempt}/${max_attempts})"
        sleep 1
        ((attempt++))
    done
}
