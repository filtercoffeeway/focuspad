# FocusPad EC2 Deployment Guide

## Overview
This guide walks you through deploying FocusPad to an EC2 instance with all the latest features including markdown content support, encryption, and auto-save functionality.

## ✅ Pre-deployment Checklist

### 1. EC2 Instance Setup
- Launch an EC2 instance (recommended: t3.medium or larger)
- Security groups configured for ports 22, 80, 443, 8080
- Domain name pointed to EC2 public IP
- SSH access configured

### 2. Environment Files
- `.env.prod` - Production environment configuration
- Uses `.env.prod` (NOT `.env.production`)
- All secure keys auto-generated during deployment

### 3. Updated Scripts
- ✅ `scripts/clean-docker-ec2.sh` - EC2-optimized cleanup
- ✅ `scripts/deploy.sh` - Uses `.env.prod`, includes migrations
- ✅ `scripts/start.sh` - Enhanced health checks
- ✅ `scripts/stop.sh` - Improved stopping process

## 🚀 Deployment Steps

### Step 1: Initial Server Setup
```bash
# Run the setup script on your EC2 instance
./scripts/setup-instance.sh
```

### Step 2: Environment Configuration
```bash
# Copy and configure environment file
cp .env.prod.example .env.prod
nano .env.prod
```

**Required Configuration:**
- `GOOGLE_CLIENT_ID` - Your Google OAuth client ID
- `GOOGLE_CLIENT_SECRET` - Your Google OAuth client secret
- `BASE_URL` - Your domain (e.g., https://yourdomain.com)
- Other keys will be auto-generated

### Step 3: Deploy Application
```bash
# Optional: Verify deployment readiness first
./scripts/verify-deployment.sh

# Full deployment with migrations
./scripts/deploy.sh
```

The deployment script will:
- ✅ Generate secure keys automatically
- ✅ Build Docker images
- ✅ Start database first
- ✅ Run database migrations (including markdown_content fields)
- ✅ Start all services
- ✅ Verify health checks
- ✅ Check for new markdown features

### Step 4: Verify Deployment
```bash
# Check all services
./scripts/start.sh

# View logs
docker-compose -f docker-compose.prod.yml --env-file .env.prod logs -f
```

## 🎯 Key Features Verified

### Database Schema
- ✅ `markdown_content` field for primary content storage
- ✅ `encrypted_markdown_content` for secure storage
- ✅ Legacy `content` field maintained for backward compatibility
- ✅ All encryption fields present

### Application Features
- ✅ Markdown syntax helper modal
- ✅ Auto-save on blur and Ctrl/Cmd+S
- ✅ Automatic conversion from JSON to markdown
- ✅ Sub-heading support (## under # main topic)
- ✅ "Description" and "Notes" labels updated

## 📋 Available Commands

### Deployment Commands
```bash
# Verify deployment readiness
./scripts/verify-deployment.sh

# Full deployment
./scripts/deploy.sh

# Start services
./scripts/start.sh

# Stop services (keep containers)
./scripts/stop.sh

# Stop and remove containers
./scripts/stop.sh --remove

# Clean restart
./scripts/clean-docker-ec2.sh && ./scripts/deploy.sh
```

### Maintenance Commands
```bash
# View logs
docker-compose -f docker-compose.prod.yml --env-file .env.prod logs -f

# Check service status
docker-compose -f docker-compose.prod.yml --env-file .env.prod ps

# Database backup
docker-compose -f docker-compose.prod.yml --env-file .env.prod exec db pg_dump -U focuspad_user focuspad > backup.sql

# Shell access to containers
docker-compose -f docker-compose.prod.yml --env-file .env.prod exec web bash
docker-compose -f docker-compose.prod.yml --env-file .env.prod exec db psql -U focuspad_user focuspad
```

## 🔧 Service Configuration

### Services Included
- **Web Application** (Port 8080 → 5000)
- **PostgreSQL Database** (Port 5432, internal)
- **Redis Cache** (Port 6379, internal)
- **Nginx Proxy** (Ports 80, 443)

### Health Checks
All services include health checks:
- Web app: `/health` endpoint
- Database: `pg_isready`
- Redis: `ping` command
- Nginx: configuration test

## 🌐 Access Points

After successful deployment:
- **Direct**: `http://YOUR-IP:8080`
- **Proxy**: `http://YOUR-IP`
- **Domain**: `https://yourdomain.com` (after SSL setup)

## 🔒 SSL Setup

```bash
# Install Certbot (if not done by setup script)
sudo apt update && sudo apt install -y certbot python3-certbot-nginx

# Generate SSL certificate
sudo certbot --nginx -d yourdomain.com
```

## 🗄️ Database Migration Notes

The migration system includes:
- Schema versioning
- Automatic migration execution
- Verification of new fields
- Backward compatibility checks

**New Fields Added:**
- `notes.markdown_content` - Primary markdown content
- `notes.markdown_content_encrypted` - Encrypted markdown
- `notes.markdown_content_salt` - Encryption salt
- `notes.markdown_content_is_encrypted` - Encryption flag

## 🚨 Troubleshooting

### Common Issues

**Database initialization error: "Is a directory"**
```bash
# If you see: psql:/docker-entrypoint-initdb.d/init.sql: error: could not read from input file: Is a directory
# This means the init_prod.sql file is missing. The file should exist at:
ls -la scripts/init_prod.sql

# If missing, it's been created by the deployment process
# Clean restart to fix:
./scripts/clean-docker-ec2.sh --force
./scripts/deploy.sh
```

**Permission errors with logs directory**
```bash
# If you see: Error: '/app/logs/error.log' isn't writable [PermissionError(13, 'Permission denied')]
# Run the permission fix script:
./scripts/fix-permissions.sh

# Or do a clean restart:
./scripts/clean-docker-ec2.sh --force
./scripts/deploy.sh
```

**Port 5000 in use (macOS AirPlay)**
```bash
# Disable AirPlay Receiver in System Preferences → Sharing
# Or use different port in docker-compose.prod.yml
```

**Database connection failed**
```bash
# Check database logs
docker-compose -f docker-compose.prod.yml --env-file .env.prod logs db

# Restart database
docker-compose -f docker-compose.prod.yml --env-file .env.prod restart db
```

**Application not starting**
```bash
# Check application logs
docker-compose -f docker-compose.prod.yml --env-file .env.prod logs web

# Verify environment file
cat .env.prod | grep -v "PASSWORD\|SECRET\|KEY"
```

### Log Locations
- Application logs: `./logs/`
- Container logs: `docker-compose logs`
- Nginx logs: `./logs/nginx/`

## 🔄 Update Process

```bash
# Stop current deployment
./scripts/stop.sh

# Pull latest changes
git pull origin main

# Deploy updates
./scripts/deploy.sh
```

## 📊 Monitoring

### System Resources
```bash
# Docker resource usage
docker stats

# Disk space
df -h

# Memory usage
free -h
```

### Application Metrics
- Health endpoint: `/health`
- Container status: `docker-compose ps`
- Service logs: `docker-compose logs`

## 🎯 Production Checklist

- [ ] Domain configured and pointing to EC2
- [ ] SSL certificate installed
- [ ] Google OAuth configured
- [ ] Environment variables set
- [ ] Database backed up
- [ ] Monitoring configured
- [ ] Log rotation configured
- [ ] Security groups properly configured
- [ ] Regular backup schedule established

## 📞 Support

If you encounter issues:
1. Check the logs first
2. Verify environment configuration
3. Ensure all services are healthy
4. Check network connectivity
5. Review security group settings

**File Locations:**
- Configuration: `.env.prod`
- Logs: `./logs/`
- Backups: `./backups/`
- Scripts: `./scripts/`