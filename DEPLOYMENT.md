# FocusPad Deployment Guide

## Overview

FocusPad uses a simplified deployment workflow where you pull changes and deploy directly on the EC2 instance.

## Deployment Workflow

### 1. Local Development
```bash
# Make changes locally
git add .
git commit -m "Your changes"
git push origin main
```

### 2. Deploy on EC2
```bash
# SSH to EC2 instance
ssh -i /path/to/focuspad.pem ubuntu@3.18.214.69

# Navigate to app directory
cd /home/ubuntu/focuspad

# Pull latest changes
git pull origin main

# Deploy using one of three options:
./scripts/deploy-to-ec2.sh quick     # ~30s - Restart only
./scripts/deploy-to-ec2.sh standard  # ~2-3min - Rebuild web container  
./scripts/deploy-to-ec2.sh safe      # ~5min - Full rebuild with backup
```

## Deployment Options

### Quick Deployment (~30 seconds)
```bash
./scripts/deploy-to-ec2.sh quick
```
- **Use for**: UI changes, config updates, small fixes
- **What it does**: Restarts web container only
- **Fastest option**: No rebuilding, just restart

### Standard Deployment (~2-3 minutes)
```bash
./scripts/deploy-to-ec2.sh standard
```
- **Use for**: Code changes, dependency updates, most deployments
- **What it does**: Rebuilds web container with latest changes
- **Recommended**: For most deployment scenarios

### Safe Deployment (~5 minutes)
```bash
./scripts/deploy-to-ec2.sh safe
```
- **Use for**: Major updates, database changes, risky deployments
- **What it does**: 
  - Creates database backup
  - Saves container logs
  - Full rebuild of all containers
- **Safest option**: Includes rollback capabilities

## Useful Commands

### Check Application Status
```bash
# Health check
curl -s https://thefocuspad.com/health

# Container status
docker-compose -f docker-compose.prod.yml ps

# View logs
docker-compose -f docker-compose.prod.yml logs -f web
```

### Rollback (if needed)
```bash
# List available backups
ls -la backups/deployments/

# Restore database from backup
cat backups/deployments/TIMESTAMP/database_backup.sql | \
  docker-compose -f docker-compose.prod.yml exec -T db \
  psql -U focuspad_user -d focuspad

# Revert to previous git commit
git reset --hard HEAD~1
./scripts/deploy-to-ec2.sh standard
```

### Environment Management
```bash
# Check environment variables are loaded
docker-compose -f docker-compose.prod.yml exec web env | grep GOOGLE

# View configuration
cat .env.prod

# Restart specific service
docker-compose -f docker-compose.prod.yml restart web
```

## Troubleshooting

### Health Check Fails
```bash
# Check container logs
docker-compose -f docker-compose.prod.yml logs web

# Check if all services are running
docker-compose -f docker-compose.prod.yml ps

# Restart all services
docker-compose -f docker-compose.prod.yml restart
```

### Environment Variables Not Loading
```bash
# Verify env file exists
ls -la .env.prod

# Check docker-compose configuration
grep -A 5 "env_file" docker-compose.prod.yml

# Force rebuild with no cache
docker-compose -f docker-compose.prod.yml build --no-cache web
```

### Port/Permission Issues
```bash
# Check what's using port 80
sudo netstat -tlnp | grep :80

# Restart nginx if needed
sudo systemctl restart nginx

# Check Docker permissions
sudo usermod -aG docker ubuntu
```

## File Locations

- **Application**: `/home/ubuntu/focuspad`
- **Environment**: `/home/ubuntu/focuspad/.env.prod`
- **Backups**: `/home/ubuntu/focuspad/backups/deployments/`
- **Logs**: `docker-compose -f docker-compose.prod.yml logs`
- **SSL Certs**: Managed by Nginx container

## URLs

- **Application**: https://thefocuspad.com
- **Health Check**: https://thefocuspad.com/health
- **Login**: https://thefocuspad.com/login

## Support

For issues:
1. Check container logs first
2. Verify environment variables
3. Try safe deployment with backup
4. Review this guide for troubleshooting steps