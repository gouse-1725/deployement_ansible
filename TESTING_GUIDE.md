# PathflowDX Deployment Testing Guide

## Prerequisites

Before testing the deployment, ensure:

1. **Operating System**: Ubuntu/Debian Linux
2. **User Privileges**: Root or sudo access
3. **Minimum Requirements**:
   - RAM: 2GB+
   - Disk Space: 10GB+ free
   - Internet connection for downloading Docker images

---

## Pre-Deployment Checklist

### 1. Install Ansible (if not installed)

```bash
sudo apt update
sudo apt install -y ansible-core
ansible-playbook --version
```

### 2. Review and Update config.env

**CRITICAL**: Update these variables before deployment:

```bash
# Edit config.env
nano config.env
```

**Required Changes**:
- `APP_PASSWORD` - Change from "replace me"
- `DB_PASSWORD` - Set a secure password
- `SPRING_DATASOURCE_PASSWORD` - Must match DB_PASSWORD
- `DZI_PASSWORD` - Set a secure password
- `DOMAIN` - Your actual domain name
- `CERTBOT_EMAIL` - Your email for SSL certificates
- `DOCKER_USERNAME` - Your Docker Hub username (if using private images)
- `DOCKER_PASSWORD` - Your Docker Hub password (if using private images)

**Network Configuration**:
- Update all IP addresses (103.121.115.94) to your server's IP
- `MINIO_SERVER_URL`, `AWS_ENDPOINT`, `DZI_BASE_URL`, etc.

### 3. Prepare SSH Keys (Optional)

If you want SSH access for a specific user:

```bash
# Create directory for SSH keys
sudo mkdir -p /opt/ssh_keys

# Add your public keys
sudo cp ~/.ssh/id_rsa.pub /opt/ssh_keys/admin.pub
# Or manually create/copy .pub files
```

If you skip this, the playbook will create the directory but won't fail.

---

## Testing Methods

### Method 1: Syntax Validation Only

```bash
cd /home/gouse/pathflowdx_deploy
ansible-playbook ansible/main-playbook.yml --syntax-check
```

Expected output: `playbook: ansible/main-playbook.yml`

### Method 2: Dry Run (Check Mode)

**Note**: Some tasks may fail in check mode because they depend on previous tasks creating resources.

```bash
cd /home/gouse/pathflowdx_deploy
source config.env
export $(grep -v '^#' config.env | xargs)
sudo -E ansible-playbook ansible/main-playbook.yml --check
```

### Method 3: Run Specific Roles Only

Test individual components:

```bash
# Test infrastructure setup only
sudo -E ansible-playbook ansible/main-playbook.yml --tags infra

# Test Docker setup only
sudo -E ansible-playbook ansible/main-playbook.yml --tags docker

# Test application deployment only
sudo -E ansible-playbook ansible/main-playbook.yml --tags app

# Test NGINX setup only
sudo -E ansible-playbook ansible/main-playbook.yml --tags nginx
```

### Method 4: Full Deployment

**WARNING**: This will make actual changes to your system!

```bash
cd /home/gouse/pathflowdx_deploy
sudo bash bootstrap.sh
```

Or manually:

```bash
cd /home/gouse/pathflowdx_deploy
source config.env
export $(grep -v '^#' config.env | xargs)
sudo -E ansible-playbook ansible/main-playbook.yml
```

---

## Validation After Deployment

### 1. Check Docker Containers

```bash
cd /opt/pathflowdx
sudo docker compose ps
```

Expected: All containers should be "Up" or "Running"

### 2. Check Application Health

```bash
# Check if application is responding
curl -I http://localhost:8080

# Check database
sudo docker exec pathflowdx_db psql -U postgres -d sgpgi_db -c '\l'

# Check MinIO
curl http://localhost:9000/minio/health/live
```

### 3. Check Logs

```bash
# Application logs
sudo tail -f /onward/logs/onward/onward.log

# DZI worker logs
sudo tail -f /onward/logs/dzi-worker/dzi.log

# Docker compose logs
cd /opt/pathflowdx
sudo docker compose logs -f
```

### 4. Check NGINX

```bash
sudo nginx -t
sudo systemctl status nginx
curl -I http://localhost
```

### 5. Check SSL (if enabled)

```bash
sudo certbot certificates
curl -I https://$(grep DOMAIN config.env | cut -d= -f2)
```

### 6. Check Backups

```bash
# Database backup script
sudo /usr/local/bin/pathflowdx_db_backup.sh

# Check backup files
ls -lh /backup/db/

# Log backup script
sudo /usr/local/bin/pathflowdx_log_backup.sh

# Check log backups
ls -lh /backup/logs/
```

---

## Troubleshooting Common Issues

### Issue 1: Ansible Not Found

```bash
sudo apt update
sudo apt install -y ansible-core python3-pip
```

### Issue 2: Permission Denied

Make sure you run with sudo:
```bash
sudo bash bootstrap.sh
```

### Issue 3: Docker Login Fails

Check credentials in config.env:
```bash
# Test manually
docker login -u YOUR_USERNAME
```

### Issue 4: Containers Not Starting

```bash
cd /opt/pathflowdx
sudo docker compose logs
sudo docker compose down
sudo docker compose up -d
```

### Issue 5: Port Already in Use

Check what's using the port:
```bash
sudo lsof -i :8080
sudo lsof -i :5432
sudo lsof -i :9000
```

### Issue 6: SSL Certificate Fails

For testing, disable SSL:
```bash
# In config.env
ENABLE_SSL=false
```

Then rerun deployment.

---

## Rollback

If something goes wrong:

```bash
# Stop all containers
cd /opt/pathflowdx
sudo docker compose down

# Remove volumes (WARNING: This deletes data!)
sudo docker volume rm psql-volume

# Remove installation directory
sudo rm -rf /opt/pathflowdx

# Revert NGINX config
sudo rm /etc/nginx/sites-enabled/pathflowdx
sudo systemctl reload nginx
```

---

## Testing in Stages

### Stage 1: Infrastructure (Safe)
```bash
sudo -E ansible-playbook ansible/main-playbook.yml --tags infra,ssh,docker
```

### Stage 2: Application (Creates containers)
```bash
sudo -E ansible-playbook ansible/main-playbook.yml --tags app
```

### Stage 3: Proxy & SSL
```bash
sudo -E ansible-playbook ansible/main-playbook.yml --tags nginx,ssl
```

### Stage 4: Backups
```bash
sudo -E ansible-playbook ansible/main-playbook.yml --tags backup_db,backup_logs
```

---

## Best Practices for Testing

1. **Use a Test VM**: Test on a virtual machine first
2. **Snapshot Before**: Take a VM snapshot before deployment
3. **Review Logs**: Always check logs during deployment
4. **Test Incrementally**: Use tags to test components separately
5. **Verify Variables**: Double-check config.env before running
6. **Monitor Resources**: Watch disk space and memory during deployment

---

## Success Indicators

✅ All pre-checks pass
✅ All Docker containers running
✅ Application accessible on port 8080
✅ NGINX reverse proxy working
✅ SSL certificates installed (if enabled)
✅ Backup scripts created and tested
✅ No errors in logs

---

## Quick Test Commands

```bash
# One-liner health check
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" && \
curl -s -o /dev/null -w "App HTTP: %{http_code}\n" http://localhost:8080 && \
sudo nginx -t && \
systemctl is-active docker nginx

# Check all services
sudo systemctl status docker nginx ssh

# View deployment summary
sudo docker compose ps && sudo docker images | grep pathflowdx
```
