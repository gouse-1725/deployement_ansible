#!/bin/bash
############################################################
# Docker Login Troubleshooting Script
############################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"

echo "=========================================="
echo " Docker Login & Permissions Check"
echo "=========================================="
echo ""

# Load config
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "❌ config.env not found"
    exit 1
fi

# Check 1: Docker service
echo "1. Checking Docker service..."
if systemctl is-active --quiet docker; then
    echo "   ✅ Docker service is running"
else
    echo "   ❌ Docker service is not running"
    echo "      Fix: sudo systemctl start docker"
    exit 1
fi
echo ""

# Check 2: Docker socket permissions
echo "2. Checking Docker socket permissions..."
ls -l /var/run/docker.sock
SOCKET_PERMS=$(stat -c "%a" /var/run/docker.sock 2>/dev/null || echo "000")
if [[ "$SOCKET_PERMS" == "660" ]] || [[ "$SOCKET_PERMS" == "666" ]]; then
    echo "   ✅ Docker socket permissions OK"
else
    echo "   ⚠️  Docker socket permissions: $SOCKET_PERMS"
    echo "      Recommended: sudo chmod 660 /var/run/docker.sock"
fi
echo ""

# Check 3: User in docker group
echo "3. Checking docker group membership..."
if groups | grep -q docker; then
    echo "   ✅ Current user is in docker group"
else
    echo "   ❌ Current user is NOT in docker group"
    echo "      Fix: sudo usermod -aG docker $USER"
    echo "      Then logout and login again"
fi
echo ""

# Check 4: Docker access without sudo
echo "4. Testing docker access..."
if docker info >/dev/null 2>&1; then
    echo "   ✅ Docker access OK (without sudo)"
else
    echo "   ⚠️  Docker requires sudo"
    if sudo docker info >/dev/null 2>&1; then
        echo "   ✅ Docker works with sudo"
        echo "      This is normal for Ansible (runs as root)"
    else
        echo "   ❌ Docker not working even with sudo"
        exit 1
    fi
fi
echo ""

# Check 5: Docker Hub connectivity
echo "5. Checking Docker Hub connectivity..."
if ping -c 1 registry-1.docker.io >/dev/null 2>&1; then
    echo "   ✅ Can reach Docker Hub"
else
    echo "   ❌ Cannot reach Docker Hub"
    echo "      Check internet connection"
fi
echo ""

# Check 6: Docker login
echo "6. Testing Docker login..."
if [[ -n "${DOCKER_USERNAME:-}" ]] && [[ -n "${DOCKER_PASSWORD:-}" ]]; then
    echo "   Credentials found in config.env"
    echo "   Username: $DOCKER_USERNAME"
    echo "   Registry: ${DOCKER_REGISTRY:-docker.io}"
    
    echo ""
    echo "   Attempting login..."
    if echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin "${DOCKER_REGISTRY:-docker.io}" 2>&1; then
        echo "   ✅ Docker login successful"
        
        # Check 7: Try pulling private image
        echo ""
        echo "7. Testing image pull access..."
        if docker pull "$APP_IMAGE" 2>&1 | grep -q "Downloaded\|up to date\|Already exists"; then
            echo "   ✅ Can pull image: $APP_IMAGE"
        else
            echo "   ❌ Cannot pull image: $APP_IMAGE"
            echo "      Possible reasons:"
            echo "      1. Repository is private and you don't have access"
            echo "      2. Image name is incorrect"
            echo "      3. Repository doesn't exist"
            echo ""
            echo "   Verify:"
            echo "   - Image name: $APP_IMAGE"
            echo "   - Your Docker Hub account has access to this repository"
            echo "   - Try manually: docker pull $APP_IMAGE"
        fi
    else
        echo "   ❌ Docker login failed"
        echo ""
        echo "   Troubleshooting:"
        echo "   1. Verify username: $DOCKER_USERNAME"
        echo "   2. Check password in config.env (DOCKER_PASSWORD)"
        echo "   3. Ensure account exists on Docker Hub"
        echo "   4. Check if 2FA is enabled (use access token instead of password)"
        exit 1
    fi
else
    echo "   ⚠️  No Docker credentials in config.env"
    echo "      Using public images only"
    echo ""
    echo "   If you need private images, add to config.env:"
    echo "   DOCKER_USERNAME=your_username"
    echo "   DOCKER_PASSWORD=your_password_or_token"
fi
echo ""

# Check 8: Check if running as root
echo "8. Checking user context..."
if [[ $EUID -eq 0 ]]; then
    echo "   ✅ Running as root (recommended for deployment)"
else
    echo "   ℹ️  Running as: $(whoami)"
    echo "      Deployment should run with: sudo bash bootstrap.sh"
fi
echo ""

echo "=========================================="
echo " Summary"
echo "=========================================="
echo ""
echo "If all checks passed, you can deploy with:"
echo "  sudo bash bootstrap.sh"
echo ""
echo "If docker login failed, update config.env with correct credentials"
echo "If you see 'permission denied' during deployment:"
echo "  1. Ensure running with sudo"
echo "  2. Check Docker socket permissions above"
echo "  3. Verify Docker service is running"
echo ""
