# FocusPad AWS EC2 Deployment Guide

This guide walks you through deploying FocusPad on an AWS EC2 instance with SSL/HTTPS support.

## Prerequisites

### AWS Requirements
- AWS account with EC2 access
- EC2 instance (recommended: t3.small or larger)
- Ubuntu 20.04 LTS or 22.04 LTS
- Security group configured for:
  - SSH (port 22)
  - HTTP (port 80) 
  - HTTPS (port 443)
- Elastic IP (recommended for production)

### Domain Requirements
- Domain name pointed to your EC2 instance
- Access to DNS settings for your domain

### Required Credentials
- Google OAuth credentials
- Strong passwords for database and secrets
- OpenAI API key (optional, for AI features)

## Quick Start

### 1. Launch EC2 Instance

1. Launch Ubuntu 20.04/22.04 EC2 instance
2. Configure security group with ports 22, 80, 443
3. Assign Elastic IP
4. Connect via SSH

### 2. Upload Application Files

Upload the FocusPad application files to your EC2 instance:

```bash
# On your local machine
scp -r focuspad/ ubuntu@your-ec2-ip:/home/ubuntu/
```

Or clone from your repository:
```bash
# On EC2 instance
git clone https://github.com/yourusername/focuspad.git
cd focuspad
```

### 3. Configure Environment

Copy and configure the production environment file:

```bash
cp .env.production.example .env.production
nano .env.production
```

Update these critical values:
```bash
# Generate strong secrets
SECRET_KEY=your-super-secret-key-here-make-it-very-long-and-random
DB_PASSWORD=your-strong-database-password-here
FOCUSPAD_MASTER_KEY=your-base64-encoded-master-key-here
JWT_SECRET_KEY=your-jwt-secret-key-here

# Google OAuth (required)
GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-google-client-secret

# Application URL
BASE_URL=http://your-ec2-ip-or-domain

# OpenAI (optional)
OPENAI_API_KEY=sk-your-openai-api-key-here
```

### 4. Run Deployment Script

```bash
chmod +x deploy.sh
./deploy.sh
```

The script will:
- Install Docker and Docker Compose
- Configure firewall
- Build and start the application
- Set up the database
- Configure encryption

### 5. Set Up SSL (Optional but Recommended)

After your domain points to the EC2 instance:

```bash
chmod +x setup-ssl.sh
./setup-ssl.sh
```

This will:
- Install and configure Nginx
- Obtain Let's Encrypt SSL certificate
- Set up automatic renewal
- Configure HTTPS redirect

## Manual Configuration

### Environment Variables

#### Required Variables
- `SECRET_KEY`: Flask secret key for sessions
- `DB_PASSWORD`: PostgreSQL password
- `FOCUSPAD_MASTER_KEY`: Encryption master key
- `GOOGLE_CLIENT_ID`: Google OAuth client ID
- `GOOGLE_CLIENT_SECRET`: Google OAuth client secret

#### Optional Variables
- `OPENAI_API_KEY`: For AI features
- `JWT_ACCESS_TOKEN_EXPIRES`: Token expiry (default: 3600)

### Google OAuth Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable Google+ API
4. Create OAuth 2.0 credentials
5. Add authorized redirect URLs:
   - `http://your-domain/auth/google/callback`
   - `https://your-domain/auth/google/callback`

### Generating Secure Keys

```bash
# Secret key
python3 -c "import secrets; print(secrets.token_urlsafe(32))"

# Master key (base64)
python3 -c "import base64, os; print(base64.b64encode(os.urandom(32)).decode())"
```

## Management Commands

### Application Management
```bash
# View logs
docker-compose -f docker-compose.prod.yml logs -f

# Restart application
docker-compose -f docker-compose.prod.yml restart

# Stop application
docker-compose -f docker-compose.prod.yml down

# Update application
git pull
docker-compose -f docker-compose.prod.yml up -d --build
```

### Database Management
```bash
# Database backup
docker-compose -f docker-compose.prod.yml exec db pg_dump -U focuspad_user focuspad > backup.sql

# Database restore
docker-compose -f docker-compose.prod.yml exec -T db psql -U focuspad_user focuspad < backup.sql

# Database shell
docker-compose -f docker-compose.prod.yml exec db psql -U focuspad_user focuspad
```

### SSL Management
```bash
# Check SSL certificates
sudo certbot certificates

# Manual renewal
sudo certbot renew

# Nginx status
sudo systemctl status nginx
sudo systemctl reload nginx
```

## Security Considerations

### EC2 Security
- Use security groups to restrict access
- Keep system updated: `sudo apt update && sudo apt upgrade`
- Use key-based SSH authentication
- Consider changing default SSH port
- Enable CloudWatch monitoring

### Application Security
- Use strong, unique passwords
- Keep environment variables secure
- Regularly update dependencies
- Monitor application logs
- Set up automated backups

### Database Security
- Use strong database passwords
- Regularly backup database
- Consider encryption at rest
- Monitor database access logs

## Monitoring and Logs

### Application Logs
- Application logs: `docker-compose logs web`
- Access logs: `./logs/access.log`
- Error logs: `./logs/error.log`

### System Monitoring
- CPU/Memory: `htop`
- Disk usage: `df -h`
- Docker stats: `docker stats`

### Health Checks
- Application health: `curl http://localhost/health`
- Database connection: Check application logs

## Troubleshooting

### Common Issues

#### Port 80/443 Already in Use
```bash
sudo netstat -tulpn | grep :80
sudo systemctl stop apache2  # if Apache is running
```

#### Docker Permission Denied
```bash
sudo usermod -aG docker $USER
# Log out and back in
```

#### SSL Certificate Issues
```bash
sudo certbot certificates
sudo nginx -t
sudo systemctl reload nginx
```

#### Database Connection Issues
- Check environment variables
- Verify database container is running
- Check database logs

### Support
- Check application logs for detailed error messages
- Verify all environment variables are set correctly
- Ensure all required ports are open
- Check Docker container status

## Cost Optimization

### EC2 Instance Sizing
- **Development**: t3.micro (1 vCPU, 1GB RAM)
- **Small production**: t3.small (2 vCPU, 2GB RAM)
- **Medium production**: t3.medium (2 vCPU, 4GB RAM)

### Storage
- Use gp3 EBS volumes for better performance/cost ratio
- Set up lifecycle policies for log rotation
- Consider S3 for file storage if needed

### Monitoring Costs
- Use AWS Cost Explorer
- Set up billing alerts
- Consider Reserved Instances for long-term use

## Backup Strategy

### Database Backups
```bash
# Daily backup script
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
docker-compose -f docker-compose.prod.yml exec db pg_dump -U focuspad_user focuspad > /backup/focuspad_$DATE.sql
```

### Application Backups
- Source code: Use Git repository
- Configuration: Backup `.env.production`
- Logs: Archive older logs to S3

## Scaling Considerations

### Horizontal Scaling
- Use Application Load Balancer
- Deploy multiple EC2 instances
- Use RDS for managed database
- Consider container orchestration (ECS/EKS)

### Vertical Scaling
- Increase EC2 instance size
- Add more Gunicorn workers
- Optimize database connections

---

## Quick Reference

### Important Files
- `docker-compose.prod.yml`: Production Docker configuration
- `.env.production`: Production environment variables
- `deploy.sh`: Main deployment script
- `setup-ssl.sh`: SSL setup script
- `Dockerfile`: Application container configuration

### Key URLs
- Application: `https://your-domain`
- Health check: `https://your-domain/health`
- Admin access: Login with Google OAuth

### Default Ports
- Application: 5000 (internal), 80/443 (external)
- Database: 5432
- SSH: 22 