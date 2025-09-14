#!/bin/bash

# Cloudflare Tunnel Setup Script for Buken Coaching
# Run this script on your server to set up the tunnel

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[TUNNEL]${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
    exit 1
}

# Configuration
TUNNEL_NAME="buken-coaching"
DOMAIN="bukencoaching.com"

log "Setting up Cloudflare Tunnel for $DOMAIN"

# Step 1: Install cloudflared
log "Installing cloudflared..."
if ! command -v cloudflared &> /dev/null; then
    curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared.deb
    rm cloudflared.deb
    success "cloudflared installed"
else
    success "cloudflared already installed"
fi

# Step 2: Check authentication
log "Checking authentication..."
if [[ ! -f ~/.cloudflared/cert.pem ]]; then
    warning "You need to authenticate with Cloudflare first"
    echo "Run: cloudflared tunnel login"
    echo "This will open a browser to authenticate"
    exit 1
else
    success "Already authenticated"
fi

# Step 3: Create tunnel if it doesn't exist
log "Creating tunnel '$TUNNEL_NAME'..."
if cloudflared tunnel list | grep -q "$TUNNEL_NAME"; then
    TUNNEL_ID=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')
    success "Tunnel already exists: $TUNNEL_ID"
else
    TUNNEL_ID=$(cloudflared tunnel create "$TUNNEL_NAME" | grep -o '[a-f0-9-]\{36\}')
    success "Tunnel created: $TUNNEL_ID"
fi

# Step 4: Create config directory
log "Setting up configuration..."
mkdir -p ~/.cloudflared

# Step 5: Create config file
log "Creating tunnel configuration..."
cat > ~/.cloudflared/config.yml <<EOF
# Cloudflare Tunnel Configuration for Buken Coaching
tunnel: $TUNNEL_ID
credentials-file: /home/$USER/.cloudflared/$TUNNEL_ID.json

# Ingress rules
ingress:
  # Main production site
  - hostname: $DOMAIN
    service: http://localhost:3000
    originRequest:
      httpHostHeader: $DOMAIN
      connectTimeout: 30s
      tlsTimeout: 10s
      tcpKeepAlive: 30s
      keepAliveTimeout: 90s
      keepAliveConnections: 10

  # WWW redirect
  - hostname: www.$DOMAIN
    service: http://localhost:3000
    originRequest:
      httpHostHeader: $DOMAIN

  # Development subdomain (optional)
  - hostname: dev.$DOMAIN
    service: http://localhost:3001
    originRequest:
      httpHostHeader: dev.$DOMAIN

  # Catch-all rule (required)
  - service: http_status:404

# Logging
logDirectory: /var/log/cloudflared
logLevel: info

# Auto-update
autoupdate-freq: 24h

# Metrics (optional)
metrics: localhost:8081
EOF

success "Configuration created at ~/.cloudflared/config.yml"

# Step 6: Set up DNS (instructions)
log "DNS Configuration Required:"
echo ""
echo "Go to your Cloudflare Dashboard → DNS → Records"
echo "Add the following CNAME record:"
echo ""
echo "Type: CNAME"
echo "Name: @ (or $DOMAIN)"
echo "Content: $TUNNEL_ID.cfargotunnel.com"
echo "Proxy: Enabled (orange cloud)"
echo ""
echo "For www subdomain:"
echo "Type: CNAME"
echo "Name: www"
echo "Content: $DOMAIN"
echo "Proxy: Enabled (orange cloud)"
echo ""

# Step 7: Test configuration
log "Testing tunnel configuration..."
if cloudflared tunnel --config ~/.cloudflared/config.yml ingress validate; then
    success "Tunnel configuration is valid"
else
    error "Tunnel configuration is invalid"
fi

# Step 8: Install as service
read -p "Install as system service? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Installing as system service..."
    sudo cloudflared service install
    sudo systemctl enable cloudflared
    success "Service installed and enabled"

    log "Starting tunnel service..."
    sudo systemctl start cloudflared

    # Check status
    if sudo systemctl is-active --quiet cloudflared; then
        success "Tunnel service is running"
    else
        warning "Service may not be running properly. Check: sudo systemctl status cloudflared"
    fi
else
    log "Service not installed. You can run manually with:"
    echo "cloudflared tunnel --config ~/.cloudflared/config.yml run"
fi

echo ""
success "Cloudflare Tunnel setup complete!"
echo ""
echo "Next steps:"
echo "1. Configure DNS records in Cloudflare Dashboard (see instructions above)"
echo "2. Start your application: docker-compose -f docker-compose.prod.yml up -d"
echo "3. Test your site: https://$DOMAIN"
echo ""
echo "Useful commands:"
echo "• Check tunnel status: sudo systemctl status cloudflared"
echo "• View tunnel logs: sudo journalctl -u cloudflared -f"
echo "• Test tunnel manually: cloudflared tunnel --config ~/.cloudflared/config.yml run"