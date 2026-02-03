#!/bin/bash
############################################################
# PathflowDX Deployment Pre-flight Test Script
############################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"

echo "=========================================="
echo " PathflowDX Deployment Pre-flight Tests"
echo "=========================================="
echo ""

ERRORS=0
WARNINGS=0

############################################################
# Test 1: OS Validation
############################################################
echo "🔍 Test 1: Operating System"
if [[ "$(uname -s)" != "Linux" ]]; then
    echo "   ❌ FAIL: Not running on Linux"
    ((ERRORS++))
else
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "$ID" == "ubuntu" ]] || [[ "$ID" == "debian" ]]; then
            echo "   ✅ PASS: Running on $PRETTY_NAME"
        else
            echo "   ⚠️  WARN: Running on $ID (Ubuntu/Debian recommended)"
            ((WARNINGS++))
        fi
    else
        echo "   ⚠️  WARN: Cannot determine OS version"
        ((WARNINGS++))
    fi
fi
echo ""

############################################################
# Test 2: Privileges
############################################################
echo "🔍 Test 2: Root/Sudo Privileges"
if [[ $EUID -ne 0 ]]; then
    echo "   ❌ FAIL: Not running as root. Use: sudo $0"
    ((ERRORS++))
else
    echo "   ✅ PASS: Running with root privileges"
fi
echo ""

############################################################
# Test 3: Disk Space
############################################################
echo "🔍 Test 3: Disk Space"
AVAILABLE=$(df -BG /opt | tail -1 | awk '{print $4}' | sed 's/G//')
if [[ $AVAILABLE -lt 10 ]]; then
    echo "   ❌ FAIL: Insufficient disk space (${AVAILABLE}GB available, 10GB+ required)"
    ((ERRORS++))
else
    echo "   ✅ PASS: ${AVAILABLE}GB available"
fi
echo ""

############################################################
# Test 4: Memory
############################################################
echo "🔍 Test 4: System Memory"
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
if [[ $TOTAL_MEM -lt 2048 ]]; then
    echo "   ⚠️  WARN: Low memory (${TOTAL_MEM}MB, 2048MB+ recommended)"
    ((WARNINGS++))
else
    echo "   ✅ PASS: ${TOTAL_MEM}MB total memory"
fi
echo ""

############################################################
# Test 5: Config File
############################################################
echo "🔍 Test 5: Configuration File"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "   ❌ FAIL: config.env not found at $CONFIG_FILE"
    ((ERRORS++))
else
    echo "   ✅ PASS: config.env found"
    
    # Load config
    source "$CONFIG_FILE"
    
    # Check critical variables
    CRITICAL_VARS=(
        "INSTALL_DIR"
        "APP_IMAGE"
        "APP_PORT"
        "DOMAIN"
        "DB_NAME"
        "DB_USER"
        "DB_PASSWORD"
    )
    
    echo "   Checking critical variables:"
    for VAR in "${CRITICAL_VARS[@]}"; do
        if [[ -z "${!VAR:-}" ]]; then
            echo "      ❌ $VAR is not set"
            ((ERRORS++))
        else
            if [[ "$VAR" == *"PASSWORD"* ]]; then
                echo "      ✅ $VAR is set (hidden)"
            else
                echo "      ✅ $VAR = ${!VAR}"
            fi
        fi
    done
    
    # Check for default passwords
    echo "   Checking for default passwords:"
    if [[ "${APP_PASSWORD:-}" == *"replace"* ]]; then
        echo "      ⚠️  WARN: APP_PASSWORD still contains 'replace me'"
        ((WARNINGS++))
    fi
    if [[ -z "${DB_PASSWORD:-}" ]]; then
        echo "      ⚠️  WARN: DB_PASSWORD is empty"
        ((WARNINGS++))
    fi
fi
echo ""

############################################################
# Test 6: Ansible Installation
############################################################
echo "🔍 Test 6: Ansible"
if ! command -v ansible-playbook &> /dev/null; then
    echo "   ❌ FAIL: Ansible not installed"
    echo "      Install with: sudo apt install -y ansible-core"
    ((ERRORS++))
else
    VERSION=$(ansible-playbook --version | head -1)
    echo "   ✅ PASS: $VERSION"
fi
echo ""

############################################################
# Test 7: Python and Pip
############################################################
echo "🔍 Test 7: Python Dependencies"
if ! command -v python3 &> /dev/null; then
    echo "   ❌ FAIL: Python3 not installed"
    ((ERRORS++))
else
    PYTHON_VERSION=$(python3 --version)
    echo "   ✅ PASS: $PYTHON_VERSION"
fi

if ! command -v pip3 &> /dev/null; then
    echo "   ⚠️  WARN: pip3 not installed"
    ((WARNINGS++))
else
    echo "   ✅ PASS: pip3 installed"
fi
echo ""

############################################################
# Test 8: Internet Connectivity
############################################################
echo "🔍 Test 8: Internet Connectivity"
if ping -c 1 8.8.8.8 &> /dev/null; then
    echo "   ✅ PASS: Internet connection available"
else
    echo "   ⚠️  WARN: No internet connection (required for downloading packages)"
    ((WARNINGS++))
fi
echo ""

############################################################
# Test 9: Port Availability
############################################################
echo "🔍 Test 9: Port Availability"
PORTS=(80 443 8080 5432 9000 9001)
for PORT in "${PORTS[@]}"; do
    if lsof -i:$PORT &> /dev/null; then
        echo "   ⚠️  WARN: Port $PORT is already in use"
        ((WARNINGS++))
    else
        echo "   ✅ Port $PORT available"
    fi
done
echo ""

############################################################
# Test 10: Ansible Playbook Syntax
############################################################
echo "🔍 Test 10: Ansible Playbook Syntax"
if command -v ansible-playbook &> /dev/null; then
    if ansible-playbook "$SCRIPT_DIR/ansible/main-playbook.yml" --syntax-check &> /dev/null; then
        echo "   ✅ PASS: Playbook syntax is valid"
    else
        echo "   ❌ FAIL: Playbook syntax errors detected"
        ((ERRORS++))
    fi
else
    echo "   ⏭️  SKIP: Ansible not installed"
fi
echo ""

############################################################
# Summary
############################################################
echo "=========================================="
echo " Test Summary"
echo "=========================================="
echo "Errors:   $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if [[ $ERRORS -gt 0 ]]; then
    echo "❌ FAILED: Fix errors before deployment"
    echo ""
    echo "Common fixes:"
    echo "  - Run with sudo: sudo bash $0"
    echo "  - Install Ansible: sudo apt install -y ansible-core"
    echo "  - Update config.env with correct values"
    echo "  - Free up disk space"
    exit 1
elif [[ $WARNINGS -gt 0 ]]; then
    echo "⚠️  WARNINGS: Review warnings above"
    echo ""
    echo "You can proceed, but consider fixing warnings for production use."
    exit 0
else
    echo "✅ ALL TESTS PASSED"
    echo ""
    echo "Ready for deployment! Run:"
    echo "  sudo bash bootstrap.sh"
    exit 0
fi
