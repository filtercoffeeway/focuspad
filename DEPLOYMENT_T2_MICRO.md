# FocusPad Deployment Guide for AWS t2.micro

This guide is specifically designed for deploying FocusPad on AWS t2.micro instances (1 vCPU, 1GB RAM).

## ⚠️ **t2.micro Reality Check**

**What t2.micro offers:**
- 1 vCPU (burstable performance)
- 1 GB RAM
- Free tier eligible (750 hours/month for 12 months)
- Low-cost option for development/testing

**Performance expectations:**
- ✅ Works for development and light testing
- ✅ Supports 1-3 concurrent users
- ⚠️ Slower response times (2-5 seconds)
- ⚠️ Limited search performance on large datasets
- ❌ Not recommended for production with multiple users

## 🚀 **Quick Start for t2.micro**

### 1. Launch t2.micro Instance

```bash
# EC2 Instance Requirements
- Instance Type: t2.micro
- OS: Ubuntu 20.04 LTS or 22.04 LTS
- Storage: 8GB+ (20GB recommended)
- Security Group: Ports 22, 80, 443
- Key Pair: For SSH access
```

### 2. Upload Application Files

```bash
# From your local machine
scp -r focuspad/ ubuntu@your-ec2-ip:/home/ubuntu/

# Or clone from repository
ssh ubuntu@your-ec2-ip
git clone https://github.com/yourusername/focuspad.git
cd focuspad
```

### 3. Configure Environment

```bash
# Use the t2.micro optimized environment
cp .env.micro.example .env.production
nano .env.production

# Update these essential values:
SECRET_KEY=your-generated-secret-key
DB_PASSWORD=your-strong-password
FOCUSPAD_MASTER_KEY=your-base64-master-key
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
BASE_URL=http://your-ec2-ip
```

### 4. Deploy with t2.micro Script

```bash
chmod +x deploy-micro.sh
./deploy-micro.sh
```

**What the script does:**
- ✅ Creates 1GB swap file (CRITICAL for t2.micro)
- ✅ Installs Docker with minimal footprint
- ✅ Optimizes system settings for low memory
- ✅ Builds containers with resource limits
- ✅ Configures PostgreSQL for 1GB RAM
- ✅ Sets up single Gunicorn worker
- ✅ Monitors memory usage throughout

### 5. Optional: Set Up SSL (After Domain Setup)

```bash
chmod +x setup-ssl-micro.sh
./setup-ssl-micro.sh
```

## 🔧 **t2.micro Optimizations Applied**

### **Application Level:**
- **Gunicorn:** 1 worker instead of 4
- **Timeouts:** Extended to 180s
- **Logging:** Reduced to WARNING level
- **Health checks:** Less frequent (60s intervals)

### **Database Level:**
- **PostgreSQL memory:** 64MB shared_buffers
- **Connections:** Limited to 20 max
- **Work memory:** 512kB per query
- **Cache:** 256MB effective cache size

### **System Level:**
- **Swap:** 1GB swap file enabled
- **Swappiness:** Set to 80 (aggressive swapping)
- **Memory limits:** Container memory caps
- **CPU limits:** Shared CPU allocation

### **Docker Optimizations:**
- **Single-stage build:** Minimal layers
- **Removed packages:** Development tools stripped
- **Resource limits:** Memory and CPU constraints
- **Lightweight base:** python:3.11-slim

## 📊 **Performance Monitoring**

### **Essential Commands:**

```bash
# System resource monitoring
htop                                    # Interactive system monitor
free -h                                # Memory usage
df -h                                  # Disk usage
swapon -s                              # Swap usage

# Docker monitoring
docker stats                           # Container resource usage
docker-compose -f docker-compose.micro.yml logs -f  # Application logs

# Application monitoring
curl http://localhost/health           # Health check
docker-compose -f docker-compose.micro.yml ps       # Container status
```

### **Key Metrics to Watch:**

1. **Memory Usage:**
   - Total: Should stay under 900MB
   - Swap: Monitor swap usage
   - OOM kills: Check `dmesg` for out-of-memory events

2. **CPU Burst Credits:**
   - Monitor in AWS CloudWatch
   - Credits deplete with sustained CPU usage
   - Performance degrades when credits exhausted

3. **Response Times:**
   - Normal: 2-5 seconds for page loads
   - Slow: 10+ seconds indicates resource constraints
   - Timeout: May need to restart containers

## 🚨 **Performance Issues & Solutions**

### **Problem: High Memory Usage**
```bash
# Check memory
free -h

# Restart containers to clear memory
docker-compose -f docker-compose.micro.yml restart

# Emergency: Clear all Docker cache
docker system prune -af
```

### **Problem: Slow Response Times**
```bash
# Check CPU burst credits in AWS Console
# Check swap usage
swapon -s

# Restart if swap usage is high
docker-compose -f docker-compose.micro.yml restart
```

### **Problem: Search Timeouts**
```bash
# Search is CPU intensive - may timeout on large datasets
# Limit search queries to smaller datasets
# Consider upgrading to t3.small for better search performance
```

### **Problem: Database Connection Issues**
```bash
# Check database container
docker-compose -f docker-compose.micro.yml logs db

# Restart database if needed
docker-compose -f docker-compose.micro.yml restart db
```

## 💰 **Cost Considerations**

### **Free Tier Benefits:**
- **t2.micro:** 750 hours/month (essentially 24/7 for one instance)
- **Duration:** 12 months from AWS account creation
- **Storage:** 30GB EBS storage included
- **Data Transfer:** 15GB outbound data transfer

### **After Free Tier:**
- **t2.micro cost:** ~$8.50/month
- **Alternative:** t3.small (~$15/month) for better performance
- **Recommendation:** Upgrade to t3.small when free tier expires

## 🔄 **Upgrade Path**

### **When to Upgrade from t2.micro:**

1. **Consistent slow performance** (>10s response times)
2. **Frequent out-of-memory errors**
3. **Multiple concurrent users needed**
4. **Search timeouts on normal datasets**
5. **CPU burst credits consistently exhausted**

### **Recommended Upgrade:**
- **t3.small:** 2 vCPU, 2GB RAM (~$15/month)
- **Migration:** Update docker-compose to use 2-4 workers
- **Benefits:** 2x faster performance, better reliability

## 🛠️ **Troubleshooting Guide**

### **Container Won't Start:**
```bash
# Check system resources
free -h
df -h

# Check Docker logs
docker-compose -f docker-compose.micro.yml logs

# Clean up and retry
docker system prune -af
docker-compose -f docker-compose.micro.yml up -d
```

### **Database Connection Errors:**
```bash
# Wait longer for database startup (t2.micro is slow)
sleep 30
docker-compose -f docker-compose.micro.yml exec web python3 -c "from app import db; db.create_all()"
```

### **SSL Issues:**
```bash
# Check Nginx status
sudo systemctl status nginx

# Check SSL certificates
sudo certbot certificates

# Restart Nginx
sudo systemctl restart nginx
```

### **Memory Issues:**
```bash
# Enable swap if not working
sudo swapon /swapfile

# Check for memory leaks
docker stats

# Emergency restart
sudo reboot
```

## 📋 **t2.micro Deployment Checklist**

### **Pre-deployment:**
- [ ] EC2 t2.micro instance launched
- [ ] Security group configured (ports 22, 80, 443)
- [ ] SSH key pair configured
- [ ] Domain pointed to EC2 IP (if using SSL)

### **Environment Setup:**
- [ ] `.env.production` created from `.env.micro.example`
- [ ] Strong passwords generated
- [ ] Google OAuth credentials configured
- [ ] BASE_URL updated with your domain/IP

### **Deployment:**
- [ ] `deploy-micro.sh` executed successfully
- [ ] Swap file created and enabled
- [ ] Containers running with resource limits
- [ ] Health check responds at `/health`
- [ ] Application accessible via browser

### **Optional SSL:**
- [ ] Domain DNS configured
- [ ] `setup-ssl-micro.sh` executed
- [ ] SSL certificate obtained
- [ ] HTTPS accessible
- [ ] HTTP redirects to HTTPS

### **Post-deployment:**
- [ ] Google OAuth URLs updated for HTTPS
- [ ] Performance monitoring set up
- [ ] Backup strategy implemented
- [ ] CloudWatch alarms configured (optional)

## 🎯 **Best Practices for t2.micro**

1. **Monitor CPU burst credits** in AWS CloudWatch
2. **Set up CloudWatch alarms** for high memory/CPU usage
3. **Implement log rotation** to save disk space
4. **Regular backups** of database and configuration
5. **Keep system updated** with security patches
6. **Plan upgrade path** to t3.small for production
7. **Test thoroughly** with expected load before production use

## 📞 **Support & Resources**

### **AWS Resources:**
- [EC2 Instance Types](https://aws.amazon.com/ec2/instance-types/)
- [CloudWatch Monitoring](https://aws.amazon.com/cloudwatch/)
- [Free Tier Usage](https://aws.amazon.com/free/)

### **Performance Monitoring:**
- Monitor memory: `watch -n 5 free -h`
- Monitor containers: `watch -n 5 docker stats`
- Monitor disk: `watch -n 30 df -h`

### **Emergency Contacts:**
- If containers stop: Run `deploy-micro.sh` again
- If memory issues: Restart instance via AWS Console
- If performance degrades: Check CPU burst credits in CloudWatch

---

## 🎉 **Summary**

Your FocusPad application is now optimized for t2.micro with:

- ✅ **1GB swap file** for memory overflow
- ✅ **Single Gunicorn worker** optimized for 1 vCPU
- ✅ **PostgreSQL tuned** for 1GB RAM environment
- ✅ **Resource limits** preventing memory exhaustion
- ✅ **Monitoring tools** for performance tracking
- ✅ **Upgrade path** ready when needed

**Remember:** t2.micro is perfect for development and testing, but consider upgrading to t3.small for production workloads with multiple users.

**Access your app:** http://your-ec2-ip (or https://your-domain if SSL configured)
**Health check:** http://your-ec2-ip/health 