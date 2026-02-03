#!/bin/bash
############################################################
# PathflowDX Deployment - Quick Start
############################################################

cat << 'EOF'
╔══════════════════════════════════════════════════════════╗
║     PathflowDX On-Prem Deployment - Quick Start         ║
╔══════════════════════════════════════════════════════════╝

📋 STEP 1: Pre-flight Test
───────────────────────────
sudo bash test_deployment.sh

This will check:
  ✓ OS compatibility
  ✓ Disk space & memory
  ✓ Required software
  ✓ Configuration file
  ✓ Port availability

📝 STEP 2: Configure
───────────────────────────
nano config.env

MUST CHANGE:
  • APP_PASSWORD (currently: "replace me")
  • DB_PASSWORD (currently: empty)
  • SPRING_DATASOURCE_PASSWORD (match DB_PASSWORD)
  • DZI_PASSWORD (currently: empty)
  • DOMAIN (your actual domain)
  • CERTBOT_EMAIL (for SSL)
  • All IP addresses (103.121.115.94 → your server IP)

OPTIONAL (for private images):
  • DOCKER_USERNAME
  • DOCKER_PASSWORD

🚀 STEP 3: Deploy
───────────────────────────
sudo bash bootstrap.sh

Or manually:
  source config.env
  export $(grep -v '^#' config.env | xargs)
  sudo -E ansible-playbook ansible/main-playbook.yml

✅ STEP 4: Verify
───────────────────────────
cd /opt/pathflowdx
sudo docker compose ps

Expected: All containers "Up"

Check application:
  curl http://localhost:8080

Check logs:
  sudo docker compose logs -f

🔍 STEP 5: Test by Component
───────────────────────────
sudo -E ansible-playbook ansible/main-playbook.yml --tags infra
sudo -E ansible-playbook ansible/main-playbook.yml --tags docker
sudo -E ansible-playbook ansible/main-playbook.yml --tags app
sudo -E ansible-playbook ansible/main-playbook.yml --tags nginx

📚 Full Documentation
───────────────────────────
See TESTING_GUIDE.md for complete testing instructions

🆘 Common Issues
───────────────────────────
Issue: Permission denied
Fix:   Run with sudo

Issue: Port already in use
Fix:   sudo lsof -i :8080 (check what's using it)

Issue: Docker login fails
Fix:   Check DOCKER_USERNAME and DOCKER_PASSWORD in config.env

Issue: Containers won't start
Fix:   cd /opt/pathflowdx && sudo docker compose logs

🔄 Rollback
───────────────────────────
cd /opt/pathflowdx
sudo docker compose down
sudo rm -rf /opt/pathflowdx

📊 Health Check
───────────────────────────
sudo docker ps
curl -I http://localhost:8080
sudo nginx -t
systemctl status docker nginx

═══════════════════════════════════════════════════════════
EOF
