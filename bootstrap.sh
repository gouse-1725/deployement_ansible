#!/bin/bash
set -euo pipefail

############################################
# PathflowDX On-Prem Bootstrap Script
############################################

echo "=========================================="
echo " PathflowDX On-Prem Bootstrap Starting"
echo "=========================================="

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
ANSIBLE_DIR="$BASE_DIR/ansible"
CONFIG_FILE="$BASE_DIR/config.env"
PLAYBOOK="$ANSIBLE_DIR/main-playbook.yml"

############################################
# 1. OS VALIDATION
############################################
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "❌ ERROR: Unsupported OS. Linux required."
  exit 1
fi

if [[ ! -f /etc/os-release ]]; then
  echo "❌ ERROR: Cannot determine OS version."
  exit 1
fi

# Load OS info
. /etc/os-release

if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
  echo "❌ ERROR: Unsupported Linux distribution: $ID"
  echo "Only Ubuntu/Debian are supported."
  exit 1
fi

echo "✅ OS validation passed ($PRETTY_NAME)"

############################################
# 2. CONFIG FILE VALIDATION
############################################
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ ERROR: config.env not found in project root"
  exit 1
fi

echo "✅ config.env found"

############################################
# 3. LOAD & VALIDATE VARIABLES
############################################
set -a
source "$CONFIG_FILE"
set +a

REQUIRED_VARS=(
  ENV_NAME
  APP_NAME
  APP_IMAGE
  APP_PORT
  NGINX_SERVER_NAME
  INSTALL_DIR
)

echo "🔍 Validating required configuration variables..."

for VAR in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!VAR:-}" ]]; then
    echo "❌ ERROR: Required variable '$VAR' is missing in config.env"
    exit 1
  fi
done

echo "✅ Required variables validated"

############################################
# 4. INSTALL BASE DEPENDENCIES
############################################
echo "🔧 Installing base system dependencies..."

sudo apt update -y
sudo apt install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  software-properties-common \
  python3 \
  python3-pip \
  git

############################################
# 5. INSTALL ANSIBLE (OFFICIAL REPO)
############################################
if ! command -v ansible >/dev/null 2>&1; then
  echo "📦 Installing Ansible from official repository..."

  # Add Ansible PPA (safe if already exists)
  sudo add-apt-repository --yes --update ppa:ansible/ansible

  # Install Ansible
  sudo apt install -y ansible

  echo "✅ Ansible installed successfully"
else
  echo "✅ Ansible already installed"
fi

# Verify Ansible
ansible --version >/dev/null 2>&1 || {
  echo "❌ ERROR: Ansible installation verification failed"
  exit 1
}

############################################
# 6. FINAL PRE-FLIGHT CHECKS
############################################
if [[ ! -f "$PLAYBOOK" ]]; then
  echo "❌ ERROR: main-playbook.yml not found in ansible directory"
  exit 1
fi

if [[ ! -f "$ANSIBLE_DIR/ansible.cfg" ]]; then
  echo "❌ ERROR: ansible.cfg missing"
  exit 1
fi

echo "✅ Pre-flight checks passed"

############################################
# 7. RUN ANSIBLE
############################################
echo "🚀 Starting Ansible deployment..."

cd "$ANSIBLE_DIR"

# Export environment variables and run ansible with sudo preserving env
if [[ $# -gt 0 ]]; then
  echo "Running with arguments: $@"
  sudo -E ansible-playbook main-playbook.yml "$@"
else
  sudo -E ansible-playbook main-playbook.yml
fi

echo "=========================================="
echo " ✅ PathflowDX Deployment Completed"
echo "=========================================="
