#!/bin/bash

# Exit on error in non-interactive shells
set -e

# Reopen stdin from the terminal when piped
if [ ! -t 0 ]; then
    exec < /dev/tty
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_header() {
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}\n"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root (use sudo)"
    exit 1
fi

clear
echo -e "${CYAN}"
cat << "EOF"
╦  ╦╔═╗╔═╗  ╦ ╦╔═╗╔═╗╔╦╗╦╔╗╔╔═╗  ╔═╗╔═╗╔╦╗╦ ╦╔═╗
╚╗╔╝╠═╝╚═╗  ╠═╣║ ║╚═╗ ║ ║║║║║ ╦  ╚═╗║╣  ║ ║ ║╠═╝
 ╚╝ ╩  ╚═╝  ╩ ╩╚═╝╚═╝ ╩ ╩╝╚╝╚═╝  ╚═╝╚═╝ ╩ ╚═╝╩  
        Easy MEAN Stack Hosting Setup
EOF
echo -e "${NC}\n"

# ============================================
# Step 1: Collect Information
# ============================================
print_header "Step 1: Domain Configuration"

# Domain name (required)
while true; do
    read -p "Enter your domain name (e.g., example.com): " DOMAIN
    if [ -z "$DOMAIN" ]; then
        print_error "Domain name cannot be empty! Please try again."
    else
        break
    fi
done

print_header "Step 2: Project Configuration"

print_info "Add your projects one by one"
echo ""

# Arrays to store project configurations
declare -a PROJECT_NAMES
declare -a PROJECT_PORTS
declare -a PROJECT_PATHS
declare -a PROJECT_SUBDOMAINS
declare -a PROJECT_RUN_COMMANDS

# Loop to add projects
while true; do
    echo -e "${CYAN}──────────────────────────────────────────${NC}"
    
    # Get project name
    read -p "Project name: " project_name
    
    # If empty, must have at least one project
    if [ -z "$project_name" ]; then
        if [ ${#PROJECT_NAMES[@]} -eq 0 ]; then
            print_error "At least one project is required!"
            continue
        else
            print_error "Project name cannot be empty!"
            continue
        fi
    fi
    
    # Get port
    while true; do
        read -p "Port: " project_port
        if [ -z "$project_port" ]; then
            print_error "Port is required!"
        elif [[ "$project_port" =~ ^[0-9]+$ ]] && [ "$project_port" -ge 1 ] && [ "$project_port" -le 65535 ]; then
            break
        else
            print_error "Please enter a valid port number (1-65535)"
        fi
    done
    
    # Get subdomain
    read -p "Subdomain (empty=main, ,www=main+www, any=any.domain): " project_subdomain
    # Trim whitespace
    project_subdomain=$(echo "$project_subdomain" | xargs)
    
    # Get path
    read -p "Path (default: /var/www/$project_name): " project_path
    project_path=${project_path:-/var/www/$project_name}
    
    # Get run command
    read -p "Run command (default: npm start): " project_run_command
    project_run_command=${project_run_command:-npm start}
    
    # Store configuration
    PROJECT_NAMES+=("$project_name")
    PROJECT_PORTS+=("$project_port")
    PROJECT_PATHS+=("$project_path")
    PROJECT_SUBDOMAINS+=("$project_subdomain")
    PROJECT_RUN_COMMANDS+=("$project_run_command")
    
    print_success "Project '$project_name' added!"
    echo ""
    
    # Ask if they want to add another project
    while true; do
        read -p "Do you want to add another project? (y/n): " add_more
        if [[ "$add_more" =~ ^[yn]$ ]]; then
            break
        else
            print_error "Please enter 'y' or 'n'"
        fi
    done
    
    if [ "$add_more" = "n" ]; then
        break
    fi
    echo ""
done

echo ""
print_success "Total projects configured: ${#PROJECT_NAMES[@]}"
echo ""

print_header "Step 3: SSL Configuration"

# SSL installation
while true; do
    read -p "Do you want to install SSL certificates? (y/n, default: y): " INSTALL_SSL
    INSTALL_SSL=${INSTALL_SSL:-y}
    if [[ "$INSTALL_SSL" =~ ^[yn]$ ]]; then
        break
    else
        print_error "Please enter 'y' or 'n'"
    fi
done

# SSL email (required if SSL is enabled)
if [ "$INSTALL_SSL" = "y" ]; then
    SSL_EMAIL=""
    attempt=0
    max_attempts=3
    
    while [ $attempt -lt $max_attempts ]; do
        read -p "Enter your email for SSL certificate notifications: " SSL_EMAIL
        
        if [ -z "$SSL_EMAIL" ]; then
            attempt=$((attempt + 1))
            print_error "Email is required for SSL certificates! (Attempt $attempt/$max_attempts)"
            if [ $attempt -ge $max_attempts ]; then
                print_warning "Max attempts reached. Disabling SSL installation."
                INSTALL_SSL="n"
                break
            fi
        elif [[ "$SSL_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            break
        else
            attempt=$((attempt + 1))
            print_error "Please enter a valid email address (Attempt $attempt/$max_attempts)"
            if [ $attempt -ge $max_attempts ]; then
                print_warning "Max attempts reached. Disabling SSL installation."
                INSTALL_SSL="n"
                break
            fi
        fi
    done
fi

# ============================================
# Summary
# ============================================
print_header "Configuration Summary"

echo -e "${CYAN}Domain Configuration:${NC}"
echo "  Main Domain: $DOMAIN"
echo ""

echo -e "${CYAN}Projects Configuration:${NC}"
for i in "${!PROJECT_NAMES[@]}"; do
    echo "  Project $((i+1)): ${PROJECT_NAMES[$i]}"
    echo "    Port: ${PROJECT_PORTS[$i]}"
    echo "    Path: ${PROJECT_PATHS[$i]}"
    echo "    Run Command: ${PROJECT_RUN_COMMANDS[$i]}"
    subdomain="${PROJECT_SUBDOMAINS[$i]}"
    if [ -z "$subdomain" ]; then
        echo "    URL: https://$DOMAIN"
    elif [[ "$subdomain" == *,* ]]; then
        echo "    URLs:"
        IFS=',' read -ra SUBS <<< "$subdomain"
        for sub in "${SUBS[@]}"; do
            sub=$(echo "$sub" | xargs)
            if [ -n "$sub" ]; then
                echo "          https://$sub.$DOMAIN"
            else
                echo "          https://$DOMAIN"
            fi
        done
    else
        echo "    URL: https://$subdomain.$DOMAIN"
    fi
    echo ""
done

echo -e "${CYAN}SSL:${NC}"
if [ "$INSTALL_SSL" = "y" ]; then
    echo "  Enabled (Email: $SSL_EMAIL)"
else
    echo "  Disabled"
fi

echo ""
read -p "Do you want to proceed with this configuration? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    print_warning "Setup cancelled by user."
    exit 0
fi

# ============================================
# Step 5: System Update and Software Installation
# ============================================
print_header "Step 5: Installing Required Software"

# Check if packages are already installed
VPSIFY_SETUP_DONE="/root/.vpsify_setup_done"

if [ -f "$VPSIFY_SETUP_DONE" ]; then
    print_info "Detected previous installation. Skipping package installation..."
    print_success "All required software is already installed!"
else
    print_info "Updating system packages..."
    apt update && apt upgrade -y

    print_info "Installing NGINX, Node.js, Git, and other dependencies..."
    apt install -y nginx curl unzip git certbot python3-certbot-nginx

    print_info "Installing Node.js 24.x..."
    curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
    apt install -y nodejs

    print_info "Installing PM2 globally..."
    npm i -g pm2

    print_info "Enabling and starting NGINX..."
    systemctl enable nginx
    systemctl start nginx

    # Mark installation as complete
    touch "$VPSIFY_SETUP_DONE"
    print_success "All software installed successfully!"
fi

# ============================================
# Step 6: Project Setup
# ============================================
print_header "Step 6: Project Setup"

for i in "${!PROJECT_NAMES[@]}"; do
    project_name="${PROJECT_NAMES[$i]}"
    project_path="${PROJECT_PATHS[$i]}"
    
    if [ -d "$project_path" ]; then
        print_info "Setting up $project_name at $project_path..."
        cd "$project_path"
        
        if [ -f "package.json" ]; then
            print_info "Installing dependencies for $project_name..."
            npm install
            print_success "$project_name dependencies installed!"
        else
            print_warning "No package.json found for $project_name. Skipping npm install."
        fi
    else
        print_warning "$project_name directory not found at $project_path. Please upload your project files."
    fi
done

# ============================================
# Step 7: PM2 Configuration
# ============================================
print_header "Step 7: Starting Applications with PM2"

for i in "${!PROJECT_NAMES[@]}"; do
    project_name="${PROJECT_NAMES[$i]}"
    project_path="${PROJECT_PATHS[$i]}"
    run_command="${PROJECT_RUN_COMMANDS[$i]}"
    
    if [ -d "$project_path" ] && [ -f "$project_path/package.json" ]; then
        print_info "Starting $project_name with PM2 (Command: $run_command)..."
        cd "$project_path"
        pm2 delete "$project_name" 2>/dev/null || true
        pm2 start "$run_command" --name "$project_name"
        print_success "$project_name started successfully!"
    else
        print_warning "Skipping PM2 start for $project_name (directory or package.json not found)"
    fi
done

print_info "Saving PM2 configuration..."
pm2 save

print_info "Setting up PM2 to start on system boot..."
pm2 startup systemd -u root --hp /root
systemctl enable pm2-root

print_success "PM2 configuration completed!"

# ============================================
# Step 8: NGINX Configuration
# ============================================
print_header "Step 8: Configuring NGINX"

print_info "Removing default NGINX configuration..."
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-available/default

# Create NGINX configs for each project
for i in "${!PROJECT_NAMES[@]}"; do
    project_name="${PROJECT_NAMES[$i]}"
    project_port="${PROJECT_PORTS[$i]}"
    project_subdomain="${PROJECT_SUBDOMAINS[$i]}"
    
    # Determine server name and config file
    if [ -z "$project_subdomain" ]; then
        # Main domain only
        server_name="$DOMAIN"
        config_file="$project_name"
    elif [[ "$project_subdomain" == *,* ]]; then
        # Multiple subdomains (comma-separated)
        server_name=""
        IFS=',' read -ra SUBS <<< "$project_subdomain"
        for sub in "${SUBS[@]}"; do
            sub=$(echo "$sub" | xargs)
            if [ -n "$sub" ]; then
                if [ -z "$server_name" ]; then
                    server_name="$sub.$DOMAIN"
                else
                    server_name="$server_name $sub.$DOMAIN"
                fi
            else
                # Empty value means main domain
                if [ -z "$server_name" ]; then
                    server_name="$DOMAIN"
                else
                    server_name="$server_name $DOMAIN"
                fi
            fi
        done
        config_file="$project_name"
    else
        # Single subdomain
        server_name="$project_subdomain.$DOMAIN"
        config_file="$project_name"
    fi
    
    print_info "Creating NGINX configuration for $server_name..."
    
    cat > /etc/nginx/sites-available/$config_file << EOF
server {
    listen 80;
    server_name $server_name;

    location / {
        proxy_pass http://localhost:$project_port;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

    print_info "Enabling NGINX site for $server_name..."
    ln -sf /etc/nginx/sites-available/$config_file /etc/nginx/sites-enabled/
done

print_info "Testing NGINX configuration..."
if nginx -t; then
    print_success "NGINX configuration is valid!"
    systemctl reload nginx
    print_success "NGINX reloaded successfully!"
else
    print_error "NGINX configuration test failed!"
    exit 1
fi

# ============================================
# Step 9: SSL Installation
# ============================================
if [ "$INSTALL_SSL" = "y" ]; then
    print_header "Step 9: Installing SSL Certificates"
    
    # Build domain list
    DOMAINS=""
    for i in "${!PROJECT_NAMES[@]}"; do
        project_subdomain="${PROJECT_SUBDOMAINS[$i]}"
        
        if [ -z "$project_subdomain" ]; then
            # Main domain
            DOMAINS="$DOMAINS -d $DOMAIN"
        elif [[ "$project_subdomain" == *,* ]]; then
            # Multiple subdomains
            IFS=',' read -ra SUBS <<< "$project_subdomain"
            for sub in "${SUBS[@]}"; do
                sub=$(echo "$sub" | xargs)
                if [ -n "$sub" ]; then
                    DOMAINS="$DOMAINS -d $sub.$DOMAIN"
                else
                    # Empty value means main domain
                    DOMAINS="$DOMAINS -d $DOMAIN"
                fi
            done
        else
            # Single subdomain
            DOMAINS="$DOMAINS -d $project_subdomain.$DOMAIN"
        fi
    done
    
    print_info "Installing SSL certificates for:$DOMAINS"
    print_warning "Please make sure your DNS records are properly configured!"
    
    certbot --nginx $DOMAINS --email "$SSL_EMAIL" --agree-tos --no-eff-email --redirect
    
    if [ $? -eq 0 ]; then
        print_success "SSL certificates installed successfully!"
        print_info "Setting up automatic SSL renewal..."
        certbot renew --dry-run
    else
        print_error "SSL installation failed. You can run certbot manually later."
    fi
else
    print_warning "SSL installation skipped."
fi

# ============================================
# Final Summary
# ============================================
print_header "🎉 Setup Complete!"

echo -e "${GREEN}Your applications are now accessible at:${NC}"
echo ""

for i in "${!PROJECT_NAMES[@]}"; do
    project_name="${PROJECT_NAMES[$i]}"
    project_subdomain="${PROJECT_SUBDOMAINS[$i]}"
    protocol="http"
    [ "$INSTALL_SSL" = "y" ] && protocol="https"
    
    if [ -z "$project_subdomain" ]; then
        echo "  🌐 $project_name: $protocol://$DOMAIN"
    elif [[ "$project_subdomain" == *,* ]]; then
        IFS=',' read -ra SUBS <<< "$project_subdomain"
        for sub in "${SUBS[@]}"; do
            sub=$(echo "$sub" | xargs)
            if [ -n "$sub" ]; then
                echo "  🌐 $project_name: $protocol://$sub.$DOMAIN"
            else
                echo "  🌐 $project_name: $protocol://$DOMAIN"
            fi
        done
    else
        echo "  🔧 $project_name: $protocol://$project_subdomain.$DOMAIN"
    fi
done

echo ""
echo -e "${CYAN}Useful Commands:${NC}"
echo ""
echo -e "${YELLOW}PM2 Commands:${NC}"
echo "  pm2 ls                    - List all applications"
echo "  pm2 restart all           - Restart all applications"
echo "  pm2 logs                  - View logs"
echo "  pm2 logs [name]           - View specific app logs"
echo "  pm2 stop [name]           - Stop an application"
echo ""
echo -e "${YELLOW}NGINX Commands:${NC}"
echo "  nginx -t                  - Test configuration"
echo "  systemctl reload nginx    - Reload NGINX"
echo "  systemctl restart nginx   - Restart NGINX"
echo ""
echo -e "${YELLOW}SSL Commands:${NC}"
echo "  certbot renew --dry-run   - Test SSL renewal"
echo "  certbot certificates      - List all certificates"
echo ""

print_success "Setup completed successfully! 🚀"
