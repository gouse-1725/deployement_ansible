#!/bin/bash
############################################################
# Ansible Configuration Fix Script
############################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ANSIBLE_DIR="$SCRIPT_DIR/ansible"

echo "=========================================="
echo " Fixing Ansible Configuration Issues"
echo "=========================================="
echo ""

# Check if running from correct directory
if [[ ! -f "$ANSIBLE_DIR/main-playbook.yml" ]]; then
    echo "❌ ERROR: Run this script from the pathflowdx_deploy directory"
    exit 1
fi

# Fix 1: Create proper inventory file
echo "✅ Creating inventory.ini file..."
cat > "$ANSIBLE_DIR/inventory.ini" << 'EOF'
# Ansible Inventory for PathflowDX Deployment
[local]
localhost ansible_connection=local ansible_python_interpreter=/usr/bin/python3

[local:vars]
ansible_become=yes
ansible_become_method=sudo
EOF

# Fix 2: Update ansible.cfg to remove deprecated settings
echo "✅ Updating ansible.cfg..."
cat > "$ANSIBLE_DIR/ansible.cfg" << 'EOF'
[defaults]
############################################
# BASIC EXECUTION
############################################
inventory = ./inventory.ini
host_key_checking = False
interpreter_python = auto_silent

############################################
# ROLES & PATHS
############################################
roles_path = ./roles
retry_files_enabled = False

############################################
# OUTPUT & LOGGING
############################################
stdout_callback = default
bin_ansible_callbacks = True
display_skipped_hosts = False
display_args_to_stdout = False

# Log file (VERY IMPORTANT for audits)
log_path = /var/log/ansible-pathflowdx.log

############################################
# PERFORMANCE & STABILITY
############################################
forks = 5
timeout = 30
gathering = explicit

############################################
# ERROR HANDLING
############################################
any_errors_fatal = True

############################################
# SECURITY
############################################
no_log = False

############################################
# DEPRECATION WARNINGS
############################################
deprecation_warnings = False
EOF

echo ""
echo "=========================================="
echo " ✅ Configuration Fixed!"
echo "=========================================="
echo ""
echo "Changes made:"
echo "  1. Created inventory.ini with localhost configuration"
echo "  2. Updated ansible.cfg to remove deprecated settings"
echo "  3. Fixed callback plugin configuration"
echo "  4. Disabled deprecation warnings"
echo ""
echo "Now you can run:"
echo "  cd ansible"
echo "  ansible-playbook main-playbook.yml --syntax-check"
echo ""
echo "Or use the full deployment:"
echo "  sudo bash bootstrap.sh"
echo ""
