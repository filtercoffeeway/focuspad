# Quick Fix for t3.micro Deployment Errors

## Issues Identified

Your deployment is failing due to several issues:

1. **Missing MASTER_KEY environment variable** - This is the primary cause
2. **Docker Compose version warning** - Fixed in latest version
3. **Container restart loops** - Caused by missing environment variables
4. **Encryption setup timeout** - Common on t2/t3.micro due to limited resources

## Quick Fix Steps

### Step 1: Fix the Environment Variables
```bash
cd /home/ubuntu/focuspad
./fix-deployment-issues.sh
```

**OR manually:**

```bash
cd /home/ubuntu/focuspad

# Create environment file with secure keys
./setup-env-micro.sh

# Edit to add your Google OAuth credentials (required)
nano .env.production
```

### Step 2: Update the deployment configuration (already fixed)
The Docker Compose version warning has been fixed by removing the obsolete `version` attribute.

### Step 3: Restart the deployment
```bash
# Stop everything and clean up
docker-compose -f docker-compose.micro.yml down --remove-orphans

# Clean up Docker to save space (important for t3.micro)
docker system prune -af --volumes

# Start fresh
docker-compose -f docker-compose.micro.yml up -d

# Monitor the startup
docker-compose -f docker-compose.micro.yml logs -f
```

### Step 4: Manual fixes if needed

**If database setup fails:**
```bash
# Wait for containers to start, then setup database manually
sleep 30
docker-compose -f docker-compose.micro.yml exec web python3 -c "
from app import create_app, db
app = create_app()
with app.app_context():
    db.create_all()
    print('Database setup completed')
"
```

**If encryption setup times out:**
```bash
# This is normal on t3.micro - run manually with longer timeout
timeout 300 docker-compose -f docker-compose.micro.yml exec web python3 scripts/setup_encryption.py
```

**Check health endpoints:**
```bash
curl http://localhost/health
curl http://localhost/
```

## Environment Variables Required

Make sure your `.env.production` has these set:

```bash
# Critical - these must be set
SECRET_KEY=<generated-secure-key>
FOCUSPAD_MASTER_KEY=<base64-encoded-key>
DB_PASSWORD=<secure-password>

# Required for Google login
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-secret-key

# Your server URL
BASE_URL=http://your-ec2-public-ip
```

## Troubleshooting Commands

**Check container status:**
```bash
docker-compose -f docker-compose.micro.yml ps
```

**View logs:**
```bash
docker-compose -f docker-compose.micro.yml logs -f web
docker-compose -f docker-compose.micro.yml logs -f db
```

**Check environment variables in container:**
```bash
docker-compose -f docker-compose.micro.yml exec web env | grep FOCUSPAD
```

**Restart if containers become unresponsive:**
```bash
docker-compose -f docker-compose.micro.yml restart
```

**Memory monitoring (important for t3.micro):**
```bash
free -h
docker stats --no-stream
```

## t3.micro Performance Notes

- Expect 2-5 second response times
- Limit to 2-3 concurrent users
- Monitor CPU burst credits in AWS CloudWatch
- Encryption setup may timeout (this is normal)
- Consider upgrading to t3.small for production use

## Success Indicators

Your deployment is working when:
- `curl http://localhost/health` returns 200 OK
- `docker-compose -f docker-compose.micro.yml ps` shows both containers as "Up"
- No "MASTER_KEY not set" errors in logs
- Database setup completes without errors

## If Problems Persist

1. Check that swap is enabled: `swapon -s`
2. Verify you have at least 500MB free disk space: `df -h`
3. Ensure your EC2 security group allows HTTP (port 80) inbound
4. Check AWS CloudWatch for CPU credit exhaustion
5. Consider upgrading to t3.small if performance is consistently poor 