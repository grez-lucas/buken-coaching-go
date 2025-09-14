#!/bin/bash

# Production Deployment Script for Buken Coaching
# Usage: ./scripts/deploy.sh [main|dev]

set -euo pipefail

# Configuration
BRANCH=${1:-main}
COMPOSE_FILE="docker-compose.prod.yml"
CONTAINER_NAME="buken-coaching-prod"
IMAGE_NAME="ghcr.io/grez-lucas/buken-coaching-go"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
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

# Validate branch
if [[ "$BRANCH" != "main" && "$BRANCH" != "dev" ]]; then
    error "Invalid branch. Use 'main' or 'dev'"
fi

# Set image tag based on branch
if [[ "$BRANCH" == "main" ]]; then
    IMAGE_TAG="latest"
else
    IMAGE_TAG="dev"
fi

FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

log "Starting deployment for branch: $BRANCH"
log "Image: $FULL_IMAGE"

# Check if .env.prod exists
if [[ ! -f ".env.prod" ]]; then
    error ".env.prod file not found. Copy .env.prod.example and configure it."
fi

# Pull latest image
log "Pulling latest Docker image..."
if docker pull "$FULL_IMAGE"; then
    success "Image pulled successfully"
else
    error "Failed to pull image"
fi

# Stop existing container if running
log "Stopping existing container..."
if docker-compose -f "$COMPOSE_FILE" down 2>/dev/null; then
    success "Container stopped"
else
    warning "No existing container to stop"
fi

# Remove old images (keep latest 3)
log "Cleaning up old images..."
docker images "$IMAGE_NAME" --format "table {{.Repository}}:{{.Tag}}\t{{.CreatedAt}}" | \
    tail -n +2 | \
    sort -k2 -r | \
    tail -n +4 | \
    awk '{print $1}' | \
    xargs -r docker rmi 2>/dev/null || true

# Start new container
log "Starting new container..."
if docker-compose -f "$COMPOSE_FILE" up -d; then
    success "Container started successfully"
else
    error "Failed to start container"
fi

# Wait for health check
log "Waiting for application to be healthy..."
for i in {1..30}; do
    if docker-compose -f "$COMPOSE_FILE" ps | grep -q "healthy"; then
        success "Application is healthy!"
        break
    elif [[ $i -eq 30 ]]; then
        error "Application failed health check after 30 attempts"
    else
        echo -n "."
        sleep 2
    fi
done

# Show container status
log "Deployment complete! Container status:"
docker-compose -f "$COMPOSE_FILE" ps

# Show logs
log "Recent logs:"
docker-compose -f "$COMPOSE_FILE" logs --tail=20

success "Deployment completed successfully for branch: $BRANCH"
log "Application should be available through your Cloudflare Tunnel"