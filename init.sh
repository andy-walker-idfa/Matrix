#!/bin/bash
###############################################################################
# Matrix/Element Production Initialization Script
#
# This script prepares the Matrix/Element self-hosted messaging system for
# production deployment. It handles:
# - .env file creation with all required secrets
# - Synapse signing key generation
# - Configuration file generation from templates
# - SSL certificate validation
# - Docker volume preparation
# - System prerequisite checks
#
# Usage: ./init.sh
#
# After successful initialization, run: docker-compose up -d
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

###############################################################################
# Utility Functions
###############################################################################

print_header() {
    echo -e "${BLUE}"
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  $1"
    echo "═══════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Generate secure random string
generate_secret() {
    local length=${1:-32}
    openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if variable exists in .env
check_env_var() {
    local var_name=$1
    if [ -f ".env" ]; then
        grep -q "^${var_name}=" .env 2>/dev/null
        return $?
    fi
    return 1
}

# Get value from .env
get_env_var() {
    local var_name=$1
    if [ -f ".env" ]; then
        grep "^${var_name}=" .env 2>/dev/null | cut -d'=' -f2- | sed 's/^"//;s/"$//'
    fi
}

# Add or update variable in .env
add_or_update_env() {
    local var_name=$1
    local var_value=$2

    if check_env_var "$var_name"; then
        # Variable exists, update it
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|^${var_name}=.*|${var_name}=${var_value}|" .env
        else
            sed -i "s|^${var_name}=.*|${var_name}=${var_value}|" .env
        fi
    else
        # Variable doesn't exist, append it
        echo "${var_name}=${var_value}" >> .env
    fi
}

###############################################################################
# Prerequisite Checks
###############################################################################

check_prerequisites() {
    print_header "Checking Prerequisites"

    local missing_deps=0

    # Check Docker
    if command_exists docker; then
        print_success "Docker is installed ($(docker --version))"
    else
        print_error "Docker is not installed"
        missing_deps=1
    fi

    # Check Docker Compose
    if command_exists docker-compose || docker compose version >/dev/null 2>&1; then
        if command_exists docker-compose; then
            print_success "Docker Compose is installed ($(docker-compose --version))"
        else
            print_success "Docker Compose is installed ($(docker compose version))"
        fi
    else
        print_error "Docker Compose is not installed"
        missing_deps=1
    fi

    # Check openssl
    if command_exists openssl; then
        print_success "OpenSSL is installed"
    else
        print_error "OpenSSL is not installed"
        missing_deps=1
    fi

    # Check envsubst
    if command_exists envsubst; then
        print_success "envsubst is installed"
    else
        print_error "envsubst is not installed (install gettext package)"
        missing_deps=1
    fi

    if [ $missing_deps -eq 1 ]; then
        echo
        print_error "Please install missing dependencies before continuing"
        exit 1
    fi

    echo
}

###############################################################################
# Environment File Setup
###############################################################################

setup_env_file() {
    print_header "Environment File Setup"

    if [ -f ".env" ]; then
        print_warning "Found existing .env file"
        read -p "Do you want to keep existing values and only add missing ones? (Y/n): " -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            mv .env .env.backup.$(date +%Y%m%d_%H%M%S)
            print_info "Backed up existing .env file"
            touch .env
            NEW_ENV=true
        else
            NEW_ENV=false
        fi
    else
        print_info "Creating new .env file"
        touch .env
        NEW_ENV=true
    fi

    echo
    print_info "Configuring environment variables..."
    echo

    # Primary domain for Matrix server
    if check_env_var "SYNAPSE_SERVER_NAME"; then
        current=$(get_env_var "SYNAPSE_SERVER_NAME")
        print_info "Current Matrix server domain: $current"
        read -p "Keep this domain? (Y/n): " -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            read -p "Enter Matrix server domain (e.g., matrix.example.com): " SYNAPSE_SERVER_NAME
            add_or_update_env "SYNAPSE_SERVER_NAME" "$SYNAPSE_SERVER_NAME"
        else
            SYNAPSE_SERVER_NAME="$current"
        fi
    else
        read -p "Enter Matrix server domain (e.g., matrix.example.com): " SYNAPSE_SERVER_NAME
        while [ -z "$SYNAPSE_SERVER_NAME" ]; do
            print_error "Domain cannot be empty"
            read -p "Enter Matrix server domain: " SYNAPSE_SERVER_NAME
        done
        add_or_update_env "SYNAPSE_SERVER_NAME" "$SYNAPSE_SERVER_NAME"
    fi

    # SSL certificate domain (can be same as server name or wildcard)
    if check_env_var "SSL_CERT_DOMAIN"; then
        current=$(get_env_var "SSL_CERT_DOMAIN")
        print_info "Current SSL certificate domain: $current"
        read -p "Keep this domain? (Y/n): " -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            read -p "Enter SSL certificate domain (default: $SYNAPSE_SERVER_NAME): " SSL_CERT_DOMAIN
            SSL_CERT_DOMAIN=${SSL_CERT_DOMAIN:-$SYNAPSE_SERVER_NAME}
            add_or_update_env "SSL_CERT_DOMAIN" "$SSL_CERT_DOMAIN"
        else
            SSL_CERT_DOMAIN="$current"
        fi
    else
        read -p "Enter SSL certificate domain (default: $SYNAPSE_SERVER_NAME): " SSL_CERT_DOMAIN
        SSL_CERT_DOMAIN=${SSL_CERT_DOMAIN:-$SYNAPSE_SERVER_NAME}
        add_or_update_env "SSL_CERT_DOMAIN" "$SSL_CERT_DOMAIN"
    fi

    # External IP for LiveKit WebRTC
    if check_env_var "NODE_IP"; then
        current=$(get_env_var "NODE_IP")
        print_info "Current external IP: $current"
        read -p "Keep this IP? (Y/n): " -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            read -p "Enter server external IP address: " NODE_IP
            while [ -z "$NODE_IP" ]; do
                print_error "IP address cannot be empty"
                read -p "Enter server external IP address: " NODE_IP
            done
            add_or_update_env "NODE_IP" "$NODE_IP"
        else
            NODE_IP="$current"
        fi
    else
        # Try to auto-detect external IP
        AUTO_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "")
        if [ -n "$AUTO_IP" ]; then
            print_info "Detected external IP: $AUTO_IP"
            read -p "Use this IP? (Y/n): " -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                NODE_IP="$AUTO_IP"
            else
                read -p "Enter server external IP address: " NODE_IP
            fi
        else
            read -p "Enter server external IP address: " NODE_IP
        fi
        while [ -z "$NODE_IP" ]; do
            print_error "IP address cannot be empty"
            read -p "Enter server external IP address: " NODE_IP
        done
        add_or_update_env "NODE_IP" "$NODE_IP"
    fi

    # Admin email
    if check_env_var "ADMIN_EMAIL"; then
        current=$(get_env_var "ADMIN_EMAIL")
        print_info "Current admin email: $current"
        read -p "Keep this email? (Y/n): " -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            read -p "Enter admin email address: " ADMIN_EMAIL
            add_or_update_env "ADMIN_EMAIL" "$ADMIN_EMAIL"
        fi
    else
        read -p "Enter admin email address (for SSL certificates and notifications): " ADMIN_EMAIL
        while [ -z "$ADMIN_EMAIL" ]; do
            print_error "Email cannot be empty"
            read -p "Enter admin email address: " ADMIN_EMAIL
        done
        add_or_update_env "ADMIN_EMAIL" "$ADMIN_EMAIL"
    fi

    echo
    print_info "Generating/checking secrets..."
    echo

    # Generate secrets if they don't exist
    declare -A SECRETS=(
        ["REGISTRATION_SHARED_SECRET"]="Synapse user registration secret"
        ["MACAROON_SECRET_KEY"]="Synapse authentication token secret"
        ["FORM_SECRET"]="Synapse form security secret"
        ["LIVEKIT_SECRET"]="LiveKit API secret"
        ["APIKey"]="LiveKit API key"
        ["MAS_ENCRYPTION_SECRET"]="MAS database encryption secret"
        ["MAS_SIGNING_KEY"]="MAS JWT signing key"
        ["MAS_SYNAPSE_SECRET"]="MAS-Synapse shared secret"
        ["MAS_ADMIN_TOKEN"]="MAS admin token for Synapse"
    )

    for secret_name in "${!SECRETS[@]}"; do
        if check_env_var "$secret_name"; then
            print_success "${SECRETS[$secret_name]}: Already set"
        else
            secret_value=$(generate_secret 32)
            add_or_update_env "$secret_name" "$secret_value"
            print_success "${SECRETS[$secret_name]}: Generated"
        fi
    done

    # Set timezone
    if ! check_env_var "TZ"; then
        read -p "Enter timezone (default: Europe/Prague, or UTC, America/New_York, etc.): " TIMEZONE
        TIMEZONE=${TIMEZONE:-Europe/Prague}
        add_or_update_env "TZ" "$TIMEZONE"
        print_info "Timezone set to $TIMEZONE (change TZ in .env if needed)"
    fi

    print_success "Environment file configured"
    echo
}

###############################################################################
# Generate Configuration Files
###############################################################################

generate_configs() {
    print_header "Generating Configuration Files"

    # Load environment variables
    print_info "Loading environment variables from .env..."
    set -a
    source .env
    set +a

    # Update livekit.yaml with current values
    print_info "Updating LiveKit configuration..."

    cat > livekit/livekit.yaml << EOF
port: 7880

rtc:
  tcp_port: 7881
  port_range_start: 50000
  port_range_end: 50200
  use_external_ip: false
  ips:
    includes:
      - ${NODE_IP}/32

turn:
  enabled: true
  domain: ${SYNAPSE_SERVER_NAME}
  cert_file: "/etc/letsencrypt/live/${SSL_CERT_DOMAIN}/fullchain.pem"
  key_file: "/etc/letsencrypt/live/${SSL_CERT_DOMAIN}/privkey.pem"
  tls_port: 5349
  udp_port: 3478
  external_tls: true

keys:
  \${APIKey}: \${LIVEKIT_SECRET}

logging:
  level: info

room:
  auto_create: true
  max_participants: 20
  empty_timeout: 300
EOF

    print_success "LiveKit configuration updated"

    # Generate MAS config from template with special handling for secrets
    print_info "Generating MAS configuration..."
    if [ -f "mas/config.yaml.template" ]; then
        # MAS requires hex-encoded encryption secret (64 hex chars = 32 bytes)
        MAS_ENCRYPTION_HEX=$(openssl rand -hex 32)

        # Generate RSA key for MAS signing (if not already exists)
        if [ ! -f "mas/signing.key" ]; then
            openssl genrsa -out mas/signing.key 4096 2>/dev/null
            chmod 600 mas/signing.key
        fi

        # Generate config with substituted encryption secret
        MAS_ENCRYPTION_SECRET="$MAS_ENCRYPTION_HEX" envsubst < mas/config.yaml.template > mas/config.yaml.tmp

        # Insert RSA key after "key: |" line with proper indentation (8 spaces)
        awk '
            /key: \|/ {
                print
                while ((getline line < "mas/signing.key") > 0) {
                    print "        " line
                }
                close("mas/signing.key")
                next
            }
            { print }
        ' mas/config.yaml.tmp > mas/config.yaml

        rm -f mas/config.yaml.tmp

        print_success "Generated mas/config.yaml with hex encryption secret and RSA signing key"
    else
        print_warning "Template not found: mas/config.yaml.template"
    fi

    # Generate configs from templates
    declare -A TEMPLATES=(
        ["element-web/config.json"]="element-web/config.json.template"
        ["element-call/config.json"]="element-call/config.json.template"
    )

    for output in "${!TEMPLATES[@]}"; do
        template="${TEMPLATES[$output]}"
        if [ -f "$template" ]; then
            envsubst < "$template" > "$output"
            print_success "Generated $output"
        else
            print_warning "Template not found: $template"
        fi
    done

    echo
}

###############################################################################
# Generate Synapse Signing Key
###############################################################################

generate_signing_key() {
    print_header "Synapse Signing Key"

    SIGNING_KEY_PATH="synapse/matrix.signing.key"

    if [ -f "$SIGNING_KEY_PATH" ]; then
        print_success "Signing key already exists: $SIGNING_KEY_PATH"
        read -p "Regenerate signing key? (y/N): " -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
        print_warning "Backing up existing signing key..."

        # Use Docker to backup the file with proper permissions
        BACKUP_NAME="matrix.signing.key.backup.$(date +%Y%m%d_%H%M%S)"
        docker run --rm \
            -v "$SCRIPT_DIR/synapse:/data" \
            --entrypoint=/bin/sh \
            matrixdotorg/synapse:latest \
            -c "cp /data/matrix.signing.key /data/$BACKUP_NAME 2>/dev/null || mv /data/matrix.signing.key /data/$BACKUP_NAME"

        if [ ! -f "$SIGNING_KEY_PATH" ]; then
            print_success "Existing key backed up to synapse/$BACKUP_NAME"
        else
            # Fallback: try with sudo
            sudo mv "$SIGNING_KEY_PATH" "synapse/$BACKUP_NAME" 2>/dev/null || \
                print_warning "Could not backup old key, will overwrite"
        fi
    fi

    print_info "Generating new Synapse signing key..."

    # Load SYNAPSE_SERVER_NAME from .env
    if [ -z "$SYNAPSE_SERVER_NAME" ]; then
        source .env
    fi

    # Try using the generate command which is the proper way for recent Synapse versions
    docker run --rm \
        -v "$SCRIPT_DIR/synapse:/data" \
        -e SYNAPSE_SERVER_NAME="$SYNAPSE_SERVER_NAME" \
        -e SYNAPSE_REPORT_STATS=no \
        matrixdotorg/synapse:latest \
        generate

    # The generate command creates a homeserver.yaml with a signing key
    # Extract the signing key path from generated config or look for *.signing.key
    if [ -f "$SIGNING_KEY_PATH" ]; then
        print_success "Signing key generated: $SIGNING_KEY_PATH"
    else
        # Look for any signing key file generated
        FOUND_KEY=$(find "$SCRIPT_DIR/synapse" -name "*.signing.key" -type f 2>/dev/null | head -n 1)
        if [ -n "$FOUND_KEY" ]; then
            # Use Docker to rename the file with proper permissions
            FOUND_KEY_BASENAME=$(basename "$FOUND_KEY")
            docker run --rm \
                -v "$SCRIPT_DIR/synapse:/data" \
                --entrypoint=/bin/sh \
                matrixdotorg/synapse:latest \
                -c "mv /data/$FOUND_KEY_BASENAME /data/matrix.signing.key 2>/dev/null || cp /data/$FOUND_KEY_BASENAME /data/matrix.signing.key"

            # Fix ownership back to host user
            if [ -f "$SIGNING_KEY_PATH" ]; then
                sudo chown $(id -u):$(id -g) "$SIGNING_KEY_PATH" 2>/dev/null || chmod 644 "$SIGNING_KEY_PATH" 2>/dev/null
                print_success "Signing key generated and renamed to: $SIGNING_KEY_PATH"
            else
                print_warning "Signing key generated but couldn't rename automatically"
                print_info "Please rename manually: $FOUND_KEY -> $SIGNING_KEY_PATH"
            fi
        else
            print_error "Failed to generate signing key with Docker"
            print_info "Trying manual generation..."

            # Fallback: Generate using Python one-liner inside container
            docker run --rm \
                -v "$SCRIPT_DIR/synapse:/data" \
                --entrypoint=/bin/sh \
                matrixdotorg/synapse:latest \
                -c "python3 -c \"from signedjson.key import generate_signing_key; print(generate_signing_key('a'))\" > /data/matrix.signing.key && chmod 644 /data/matrix.signing.key"

            if [ -f "$SIGNING_KEY_PATH" ]; then
                sudo chown $(id -u):$(id -g) "$SIGNING_KEY_PATH" 2>/dev/null || true
                print_success "Signing key generated: $SIGNING_KEY_PATH"
            else
                print_error "Failed to generate signing key"
                print_info "Please generate manually after setup using:"
                echo "  docker run --rm -v \$PWD/synapse:/data -e SYNAPSE_SERVER_NAME=$SYNAPSE_SERVER_NAME matrixdotorg/synapse:latest generate"
                echo "  Then rename the generated .signing.key file to synapse/matrix.signing.key"
            fi
        fi
    fi

    echo
}

###############################################################################
# SSL Certificate Check
###############################################################################

check_ssl_certificates() {
    print_header "SSL Certificate Validation"

    source .env

    CERT_PATH="/etc/letsencrypt/live/${SSL_CERT_DOMAIN}/fullchain.pem"
    KEY_PATH="/etc/letsencrypt/live/${SSL_CERT_DOMAIN}/privkey.pem"

    print_info "Checking for SSL certificates at:"
    echo "  Certificate: $CERT_PATH"
    echo "  Private Key: $KEY_PATH"
    echo

    if [ -f "$CERT_PATH" ] && [ -f "$KEY_PATH" ]; then
        print_success "SSL certificates found"

        # Check certificate expiry
        EXPIRY=$(openssl x509 -enddate -noout -in "$CERT_PATH" 2>/dev/null | cut -d= -f2)
        if [ -n "$EXPIRY" ]; then
            print_info "Certificate expires: $EXPIRY"
        fi
    else
        print_warning "SSL certificates not found!"
        echo
        print_info "You need to obtain SSL certificates before starting the services."
        echo
        echo "Recommended: Use certbot to obtain Let's Encrypt certificates:"
        echo
        echo "  sudo apt-get install certbot"
        echo "  sudo certbot certonly --standalone -d ${SSL_CERT_DOMAIN}"
        echo
        echo "Or if you have multiple domains/subdomains:"
        echo "  sudo certbot certonly --standalone -d ${SSL_CERT_DOMAIN} -d ${SYNAPSE_SERVER_NAME}"
        echo
        print_warning "The system will not work properly without SSL certificates!"
    fi

    echo
}

###############################################################################
# Docker Volume Preparation
###############################################################################

prepare_volumes() {
    print_header "Docker Volume Preparation"

    declare -A VOLUMES=(
        ["/var/lib/synapse"]="Synapse data (database, media, uploads)"
        ["/var/lib/matrix/livekit"]="LiveKit persistent data"
        ["/var/lib/matrix/mas"]="MAS data (database, sessions)"
    )

    for vol_path in "${!VOLUMES[@]}"; do
        if [ -d "$vol_path" ]; then
            print_success "$vol_path exists - ${VOLUMES[$vol_path]}"
        else
            print_info "Creating directory: $vol_path"
            sudo mkdir -p "$vol_path"

            # Set appropriate permissions
            if [[ "$vol_path" == "/var/lib/synapse" ]]; then
                sudo chown -R 991:991 "$vol_path" 2>/dev/null || print_warning "Could not set ownership (may need to run as root)"
            fi

            print_success "Created $vol_path"
        fi
    done

    echo
}

###############################################################################
# Final Summary
###############################################################################

print_summary() {
    print_header "Initialization Complete!"

    source .env

    echo "Configuration Summary:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Matrix Server:     ${SYNAPSE_SERVER_NAME}"
    echo "  SSL Domain:        ${SSL_CERT_DOMAIN}"
    echo "  External IP:       ${NODE_IP}"
    echo "  Admin Email:       ${ADMIN_EMAIL}"
    echo "  Timezone:          ${TZ:-UTC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo

    print_success "All configuration files generated"
    print_success "Environment variables configured in .env"
    print_success "Synapse signing key ready"
    echo

    print_header "Next Steps"

    # Check if SSL certs exist
    CERT_PATH="/etc/letsencrypt/live/${SSL_CERT_DOMAIN}/fullchain.pem"
    if [ ! -f "$CERT_PATH" ]; then
        print_warning "1. Obtain SSL certificates (see instructions above)"
        echo "   After obtaining certificates, proceed to step 2"
        echo
    fi

    echo "1. Review configuration files:"
    echo "   - .env (environment variables and secrets)"
    echo "   - element-web/config.json"
    echo "   - element-call/config.json"
    echo "   - mas/config.yaml.template (processed at runtime)"
    echo "   - livekit/livekit.yaml"
    echo

    echo "2. Ensure DNS records point to this server:"
    echo "   ${SYNAPSE_SERVER_NAME} -> ${NODE_IP}"
    echo

    echo "3. Start the services:"
    echo -e "   ${GREEN}docker-compose up -d${NC}"
    echo

    echo "4. Check service health:"
    echo "   docker-compose ps"
    echo "   docker-compose logs -f"
    echo

    echo "5. Access admin console and create users:"
    echo "   Admin Console: https://${SYNAPSE_SERVER_NAME}/admin"
    echo "   Element Web:   https://${SYNAPSE_SERVER_NAME}"
    echo
    echo "   Users can register via MAS at:"
    echo "   https://${SYNAPSE_SERVER_NAME}/register"
    echo
    echo "6. Connect Element X mobile clients:"
    echo "   Server: ${SYNAPSE_SERVER_NAME}"
    echo "   MAS handles authentication automatically"
    echo "   A/V calls work via LiveKit integration"
    echo

    print_info "All services accessible at: https://${SYNAPSE_SERVER_NAME}"
    print_success "MAS-enabled setup complete - Element X mobile ready!"
    echo
}

###############################################################################
# Main Execution
###############################################################################

main() {
    clear
    print_header "Matrix/Element Production Initialization"
    echo
    print_info "This script will prepare your Matrix/Element system for production deployment"
    echo
    read -p "Press Enter to continue or Ctrl+C to abort..."
    echo

    check_prerequisites
    setup_env_file
    generate_configs
    generate_signing_key
    check_ssl_certificates
    prepare_volumes
    print_summary
}

# Run main function
main
