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

# Validate environment variables
validate_env() {
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
