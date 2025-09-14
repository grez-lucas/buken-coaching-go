#!/bin/bash

# Production Server Setup Script
# Run this once on your host to prepare for deployment

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[SETUP]${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log "Setting up production environment for Buken Coaching..."

# Create application directory
APP_DIR="/opt/buken-coaching"
log "Creating application directory: $APP_DIR"
sudo mkdir -p "$APP_DIR"
sudo chown $USER:$USER "$APP_DIR"
success "Application directory created"

# Change to app directory
cd "$APP_DIR"

# Download deployment files from repository
log "Downloading deployment configuration..."
curl -sSL https://raw.githubusercontent.com/grez-lucas/buken-coaching-go/main/docker-compose.prod.yml -o docker-compose.prod.yml
curl -sSL https://raw.githubusercontent.com/grez-lucas/buken-coaching-go/main/.env.prod.example -o .env.prod.example
curl -sSL https://raw.githubusercontent.com/grez-lucas/buken-coaching-go/main/scripts/deploy.sh -o deploy.sh
chmod +x deploy.sh
success "Deployment files downloaded"

# Create .env.prod from example
if [[ ! -f ".env.prod" ]]; then
    log "Creating .env.prod file..."
    cp .env.prod.example .env.prod
    warning "Please edit .env.prod with your actual configuration values"
else
    success ".env.prod already exists"
fi

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    log "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    success "Docker installed"
else
    success "Docker already installed"
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    log "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    success "Docker Compose installed"
else
    success "Docker Compose already installed"
fi

# Create systemd service for auto-restart
log "Creating systemd service..."
sudo tee /etc/systemd/system/buken-coaching.service > /dev/null <<EOF
[Unit]
Description=Buken Coaching Application
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=$APP_DIR
ExecStart=/usr/local/bin/docker-compose -f docker-compose.prod.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.prod.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable buken-coaching.service
success "Systemd service created and enabled"

# Setup log rotation
log "Setting up log rotation..."
sudo tee /etc/logrotate.d/buken-coaching > /dev/null <<EOF
/var/lib/docker/containers/*/*-json.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    postrotate
        docker kill --signal=USR1 \$(docker ps -q) 2>/dev/null || true
    endscript
}
EOF
success "Log rotation configured"

# Create backup script
log "Creating backup script..."
tee backup.sh > /dev/null <<'EOF'
#!/bin/bash
# Simple backup script for Buken Coaching

BACKUP_DIR="/opt/backups/buken-coaching"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Backup configuration
tar -czf "$BACKUP_DIR/config_$DATE.tar.gz" .env.prod docker-compose.prod.yml

# Keep only last 7 backups
find "$BACKUP_DIR" -name "config_*.tar.gz" -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR/config_$DATE.tar.gz"
EOF
chmod +x backup.sh
success "Backup script created"

# Setup monitoring script
log "Creating monitoring script..."
tee monitor.sh > /dev/null <<'EOF'
#!/bin/bash
# Simple monitoring for Buken Coaching

CONTAINER_NAME="buken-coaching-prod"
WEBHOOK_URL=""  # Add your Discord/Slack webhook URL here

check_health() {
    if docker ps | grep -q "$CONTAINER_NAME.*healthy"; then
        return 0
    else
        return 1
    fi
}

if ! check_health; then
    echo "$(date): Container $CONTAINER_NAME is not healthy, restarting..."
    docker-compose -f docker-compose.prod.yml restart

    # Optional: Send notification
    if [[ -n "$WEBHOOK_URL" ]]; then
        curl -X POST -H 'Content-type: application/json' \
            --data '{"text":"🚨 Buken Coaching container restarted due to health check failure"}' \
            "$WEBHOOK_URL"
    fi
else
    echo "$(date): Container $CONTAINER_NAME is healthy"
fi
EOF
chmod +x monitor.sh
success "Monitoring script created"

# Add to crontab for monitoring
(crontab -l 2>/dev/null; echo "*/5 * * * * $APP_DIR/monitor.sh >> $APP_DIR/monitor.log 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "0 2 * * * $APP_DIR/backup.sh >> $APP_DIR/backup.log 2>&1") | crontab -
success "Monitoring and backup cron jobs added"

echo ""
success "Production setup complete!"
echo ""
echo "Next steps:"
echo "1. Edit $APP_DIR/.env.prod with your configuration"
echo "2. Configure your Cloudflare Tunnel to point to localhost:3000"
echo "3. Run: $APP_DIR/deploy.sh main"
echo ""
warning "Remember to logout and login again for Docker group changes to take effect"