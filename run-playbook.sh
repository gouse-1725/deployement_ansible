#!/bin/bash
############################################################
# Run Ansible Playbook with config.env variables
############################################################

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$BASE_DIR/config.env"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ ERROR: config.env not found"
  exit 1
fi

# Export all variables from config.env
set -a
source "$CONFIG_FILE"
set +a

# Change to ansible directory and run playbook
cd "$BASE_DIR/ansible"

echo "🚀 Running Ansible playbook with environment variables loaded..."
sudo -E ansible-playbook main-playbook.yml "$@"
